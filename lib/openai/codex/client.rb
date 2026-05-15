# frozen_string_literal: true

require "json"
require "open3"
require "securerandom"
require_relative "app_server_config"
require_relative "errors"
require_relative "message_router"
require_relative "retry"
require_relative "types"
require_relative "util"

module OpenAI
  module Codex
    class AppServerClient
      RUNTIME_ENV_KEYS = ["OPENAI_CODEX_BIN", "CODEX_BIN"].freeze

      attr_reader :config

      def initialize(config: nil, approval_handler: nil)
        @config = config || AppServerConfig.new
        @approval_handler = approval_handler || method(:default_approval_handler)
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
        @reader_thread = nil
        @stderr_thread = nil
        @write_mutex = Mutex.new
        @router = MessageRouter.new
        @stderr_lines = []
      end

      attr_reader :router

      def self.open(config: nil, approval_handler: nil)
        client = new(config: config, approval_handler: approval_handler)
        client.start
        return client unless block_given?

        begin
          yield client
        ensure
          client.close
        end
      end

      def start
        return if running?

        args = launch_args
        env = ENV.to_h.merge(@config.env || {})
        options = {}
        options[:chdir] = @config.cwd if @config.cwd
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(env, *args, options)
        start_stderr_drain_thread
        start_reader_thread
        nil
      end

      def close
        return unless @wait_thread

        begin
          @stdin.close unless @stdin.closed?
        rescue IOError
          nil
        end

        terminate_process
        [@stderr_thread, @reader_thread].compact.each { |thread| thread.join(0.5) }
        @stdin = @stdout = @stderr = @wait_thread = @stderr_thread = @reader_thread = nil
        nil
      end

      def running?
        @wait_thread && @wait_thread.alive?
      end

      def initialize_app_server
        result = request(
          "initialize",
          {
            clientInfo: {
              name: @config.client_name,
              title: @config.client_title,
              version: @config.client_version
            },
            capabilities: {
              experimentalApi: @config.experimental_api
            }
          },
          response_type: Types::InitializeResponse
        )
        notify("initialized")
        result
      end

      def request(method, params = nil, response_type: nil)
        result = request_raw(method, params)
        response_type ||= response_class_for(method)
        return result unless response_type

        unless result.is_a?(Hash)
          raise AppServerError, "#{method} response must be a JSON object"
        end

        response_type.from_wire(result, validate: true)
      end

      def request_raw(method, params = nil)
        request_id = SecureRandom.uuid
        waiter = @router.create_response_waiter(request_id)

        begin
          write_message("id" => request_id, "method" => method, "params" => params_dict(params))
        rescue Exception
          @router.discard_response_waiter(request_id)
          raise
        end

        item = waiter.pop
        raise item if item.is_a?(Exception)

        item
      end

      def notify(method, params = nil)
        write_message("method" => method, "params" => params_dict(params))
        nil
      end

      def next_notification
        @router.next_global_notification
      end

      def register_turn_notifications(turn_id)
        @router.register_turn(turn_id)
      end

      def unregister_turn_notifications(turn_id)
        @router.unregister_turn(turn_id)
      end

      def next_turn_notification(turn_id)
        @router.next_turn_notification(turn_id)
      end

      def thread_start(params = nil)
        request("thread/start", params, response_type: Types::ThreadStartResponse)
      end

      def thread_resume(thread_id, params = nil)
        request("thread/resume", {threadId: thread_id}.merge(params_dict(params)), response_type: Types::ThreadResumeResponse)
      end

      def thread_list(params = nil)
        request("thread/list", params, response_type: Types::ThreadListResponse)
      end

      def thread_read(thread_id, include_turns: false)
        request("thread/read", {threadId: thread_id, includeTurns: include_turns}, response_type: Types::ThreadReadResponse)
      end

      def thread_fork(thread_id, params = nil)
        request("thread/fork", {threadId: thread_id}.merge(params_dict(params)), response_type: Types::ThreadForkResponse)
      end

      def thread_archive(thread_id)
        request("thread/archive", {threadId: thread_id}, response_type: Types::ThreadArchiveResponse)
      end

      def thread_unarchive(thread_id)
        request("thread/unarchive", {threadId: thread_id}, response_type: Types::ThreadUnarchiveResponse)
      end

      def thread_set_name(thread_id, name)
        request("thread/name/set", {threadId: thread_id, name: name}, response_type: Types::ThreadSetNameResponse)
      end

      def thread_compact(thread_id)
        request("thread/compact/start", {threadId: thread_id}, response_type: Types::ThreadCompactStartResponse)
      end

      def turn_start(thread_id, input_items, params = nil)
        payload = params_dict(params).merge("threadId" => thread_id, "input" => normalize_input_items(input_items))
        started = request("turn/start", payload, response_type: Types::TurnStartResponse)
        register_turn_notifications(started.turn.id)
        started
      end

      def turn_interrupt(thread_id, turn_id)
        request("turn/interrupt", {threadId: thread_id, turnId: turn_id}, response_type: Types::TurnInterruptResponse)
      end

      def turn_steer(thread_id, expected_turn_id, input_items)
        request(
          "turn/steer",
          {threadId: thread_id, expectedTurnId: expected_turn_id, input: normalize_input_items(input_items)},
          response_type: Types::TurnSteerResponse
        )
      end

      def model_list(include_hidden: false)
        request("model/list", {includeHidden: include_hidden}, response_type: Types::ModelListResponse)
      end

      def request_with_retry_on_overload(method, params = nil, response_type: nil,
        max_attempts: 3, initial_delay_s: 0.25, max_delay_s: 2.0)
        Retry.retry_on_overload(max_attempts: max_attempts,
          initial_delay_s: initial_delay_s,
          max_delay_s: max_delay_s) do
          request(method, params, response_type: response_type)
        end
      end

      def wait_for_turn_completed(turn_id)
        register_turn_notifications(turn_id)
        begin
          loop do
            event = next_turn_notification(turn_id)
            return event.payload if event.method == "turn/completed" &&
              event.payload.is_a?(Types::TurnCompletedNotification) &&
              event.payload.turn.id == turn_id
          end
        ensure
          unregister_turn_notifications(turn_id)
        end
      end

      def stream_text(thread_id, text, params = nil)
        Enumerator.new do |yielder|
          started = turn_start(thread_id, text, params)
          turn_id = started.turn.id
          register_turn_notifications(turn_id)
          begin
            loop do
              event = next_turn_notification(turn_id)
              if event.method == "item/agentMessage/delta" &&
                  event.payload.is_a?(Types::AgentMessageDeltaNotification) &&
                  event.payload.turn_id == turn_id
                yielder << event.payload
                next
              end
              break if event.method == "turn/completed" &&
                event.payload.is_a?(Types::TurnCompletedNotification) &&
                event.payload.turn.id == turn_id
            end
          ensure
            unregister_turn_notifications(turn_id)
          end
        end
      end

      def coerce_notification(method, params)
        NotificationRegistry.coerce(method, params)
      end

      def params_dict(params)
        case params
        when nil
          {}
        when Model
          params.to_h(exclude_nil: true)
        when Hash
          Util.deep_wire_value(params, exclude_nil: true)
        else
          raise TypeError, "expected params to be a Hash or OpenAI::Codex::Model"
        end
      end

      def normalize_input_items(input_items)
        case input_items
        when String
          [{"type" => "text", "text" => input_items}]
        when Hash
          [Util.deep_wire_value(input_items, exclude_nil: true)]
        when Model
          [input_items.to_h(exclude_nil: true)]
        when Array
          input_items.map { |item| Util.deep_wire_value(item.respond_to?(:to_wire) ? item.to_wire : item, exclude_nil: true) }
        else
          if input_items.respond_to?(:to_wire)
            [Util.deep_wire_value(input_items.to_wire, exclude_nil: true)]
          else
            raise TypeError, "unsupported input items: #{input_items.class}"
          end
        end
      end

      private

      def launch_args
        return Array(@config.launch_args_override) if @config.launch_args_override

        args = [resolve_codex_bin]
        @config.config_overrides.each do |override|
          args.concat(["--config", override])
        end
        args.concat(["app-server", "--listen", "stdio://"])
      end

      def resolve_codex_bin
        explicit = @config.codex_bin || RUNTIME_ENV_KEYS.map { |key| ENV[key] }.compact.first
        if explicit
          raise Errno::ENOENT, "Codex binary not found at #{explicit}" unless File.exist?(explicit)

          return explicit
        end

        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
          candidate = File.join(dir, "codex")
          return candidate if File.executable?(candidate)
        end

        raise Errno::ENOENT, "Codex binary not found. Set AppServerConfig#codex_bin or OPENAI_CODEX_BIN."
      end

      def response_class_for(method)
        type_name = SchemaStore.response_type_for(method)
        type_name && SchemaStore.class_for(type_name)
      end

      def default_approval_handler(method, _params)
        case method
        when "item/commandExecution/requestApproval", "item/fileChange/requestApproval"
          {decision: "accept"}
        else
          {}
        end
      end

      def start_stderr_drain_thread
        @stderr_thread = ::Thread.new do
          @stderr.each_line do |line|
            @stderr_lines << line.chomp
            @stderr_lines.shift while @stderr_lines.length > 400
          end
        rescue IOError
          nil
        end
      end

      def start_reader_thread
        @reader_thread = ::Thread.new { reader_loop }
      end

      def reader_loop
        loop do
          message = read_message
          if message.key?("method") && message.key?("id")
            response = @approval_handler.call(message["method"], message["params"].is_a?(Hash) ? message["params"] : nil)
            write_message("id" => message["id"], "result" => Util.deep_wire_value(response || {}, exclude_nil: true))
          elsif message.key?("method")
            method = message["method"]
            @router.route_notification(coerce_notification(method, message["params"])) if method.is_a?(String)
          else
            @router.route_response(message)
          end
        end
      rescue Exception => error
        @router.fail_all(error)
      end

      def write_message(payload)
        raise TransportClosedError, "app-server is not running" unless @stdin

        @write_mutex.synchronize do
          @stdin.write(JSON.generate(payload))
          @stdin.write("\n")
          @stdin.flush
        end
      end

      def read_message
        raise TransportClosedError, "app-server is not running" unless @stdout

        line = @stdout.gets
        unless line
          raise TransportClosedError, "app-server closed stdout. stderr_tail=#{stderr_tail[0, 2000]}"
        end

        message = JSON.parse(line)
        raise AppServerError, "Invalid JSON-RPC payload: #{message.inspect}" unless message.is_a?(Hash)

        message
      rescue JSON::ParserError => error
        raise AppServerError, "Invalid JSON-RPC line: #{line.inspect}: #{error.message}"
      end

      def stderr_tail(limit = 40)
        @stderr_lines.last(limit).join("\n")
      end

      def terminate_process
        return unless @wait_thread

        pid = @wait_thread.pid
        begin
          Process.kill("TERM", pid)
          return if @wait_thread.join(2)
        rescue Errno::ESRCH
          return
        end
        begin
          Process.kill("KILL", pid)
        rescue Errno::ESRCH
          nil
        end
      end
    end

    def self.default_codex_home
      File.join(Dir.home, ".codex")
    end
  end
end
