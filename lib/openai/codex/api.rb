# frozen_string_literal: true

require_relative "client"
require_relative "inputs"
require_relative "run_result"

module OpenAI
  module Codex
    module ApprovalMode
      DENY_ALL = "deny_all"
      AUTO_REVIEW = "auto_review"
      VALUES = [DENY_ALL, AUTO_REVIEW].freeze
    end

    module ApprovalModes
      module_function

      def settings(mode)
        normalized = mode.to_s
        unless ApprovalMode::VALUES.include?(normalized)
          raise ArgumentError, "approval_mode must be one of: #{ApprovalMode::VALUES.join(", ")}"
        end

        case normalized
        when ApprovalMode::AUTO_REVIEW
          ["on-request", "auto_review"]
        when ApprovalMode::DENY_ALL
          ["never", nil]
        end
      end

      def override_settings(mode)
        return [nil, nil] if mode.nil?

        settings(mode)
      end
    end

    class Codex
      attr_reader :metadata

      def initialize(config: nil)
        @client = AppServerClient.new(config: config)
        begin
          @client.start
          @metadata = self.class.validate_initialize(@client.initialize_app_server)
        rescue Exception
          @client.close
          raise
        end
      end

      def self.open(config: nil)
        codex = new(config: config)
        return codex unless block_given?

        begin
          yield codex
        ensure
          codex.close
        end
      end

      def self.validate_initialize(payload)
        user_agent = payload.user_agent.to_s.strip
        server = payload.server_info

        server_name = (server && server.respond_to?(:name)) ? server.name.to_s.strip : ""
        server_version = (server && server.respond_to?(:version)) ? server.version.to_s.strip : ""

        if (server_name.empty? || server_version.empty?) && !user_agent.empty?
          parsed_name, parsed_version = split_user_agent(user_agent)
          server_name = parsed_name.to_s if server_name.empty?
          server_version = parsed_version.to_s if server_version.empty?
        end

        if user_agent.empty? || server_name.empty? || server_version.empty?
          raise "initialize response missing required metadata " \
                              "(user_agent=#{user_agent.inspect}, server_name=#{server_name.inspect}, " \
                              "server_version=#{server_version.inspect})"
        end

        payload[:server_info] = {name: server_name, version: server_version}
        payload
      end

      def self.split_user_agent(user_agent)
        raw = user_agent.strip
        return [nil, nil] if raw.empty?
        return raw.split("/", 2) if raw.include?("/")

        parts = raw.split(/\s+/, 2)
        (parts.length == 2) ? parts : [raw, nil]
      end

      def close
        @client.close
      end

      def thread_start(approval_mode: ApprovalMode::AUTO_REVIEW,
        base_instructions: nil,
        config: nil,
        cwd: nil,
        developer_instructions: nil,
        ephemeral: nil,
        model: nil,
        model_provider: nil,
        personality: nil,
        sandbox: nil,
        service_name: nil,
        service_tier: nil,
        session_start_source: nil,
        thread_source: nil)
        approval_policy, approvals_reviewer = ApprovalModes.settings(approval_mode)
        params = Types::ThreadStartParams.new(
          approval_policy: approval_policy,
          approvals_reviewer: approvals_reviewer,
          base_instructions: base_instructions,
          config: config,
          cwd: cwd,
          developer_instructions: developer_instructions,
          ephemeral: ephemeral,
          model: model,
          model_provider: model_provider,
          personality: personality,
          sandbox: sandbox,
          service_name: service_name,
          service_tier: service_tier,
          session_start_source: session_start_source,
          thread_source: thread_source
        )
        started = @client.thread_start(params)
        ConversationThread.new(@client, started.thread.id)
      end

      def thread_list(archived: nil,
        cursor: nil,
        cwd: nil,
        limit: nil,
        model_providers: nil,
        search_term: nil,
        sort_direction: nil,
        sort_key: nil,
        source_kinds: nil,
        use_state_db_only: nil)
        params = Types::ThreadListParams.new(
          archived: archived,
          cursor: cursor,
          cwd: cwd,
          limit: limit,
          model_providers: model_providers,
          search_term: search_term,
          sort_direction: sort_direction,
          sort_key: sort_key,
          source_kinds: source_kinds,
          use_state_db_only: use_state_db_only
        )
        @client.thread_list(params)
      end

      def thread_resume(thread_id,
        approval_mode: nil,
        base_instructions: nil,
        config: nil,
        cwd: nil,
        developer_instructions: nil,
        model: nil,
        model_provider: nil,
        personality: nil,
        sandbox: nil,
        service_tier: nil)
        approval_policy, approvals_reviewer = ApprovalModes.override_settings(approval_mode)
        params = Types::ThreadResumeParams.new(
          thread_id: thread_id,
          approval_policy: approval_policy,
          approvals_reviewer: approvals_reviewer,
          base_instructions: base_instructions,
          config: config,
          cwd: cwd,
          developer_instructions: developer_instructions,
          model: model,
          model_provider: model_provider,
          personality: personality,
          sandbox: sandbox,
          service_tier: service_tier
        )
        resumed = @client.thread_resume(thread_id, params)
        ConversationThread.new(@client, resumed.thread.id)
      end

      def thread_fork(thread_id,
        approval_mode: nil,
        base_instructions: nil,
        config: nil,
        cwd: nil,
        developer_instructions: nil,
        ephemeral: nil,
        model: nil,
        model_provider: nil,
        sandbox: nil,
        service_tier: nil,
        thread_source: nil)
        approval_policy, approvals_reviewer = ApprovalModes.override_settings(approval_mode)
        params = Types::ThreadForkParams.new(
          thread_id: thread_id,
          approval_policy: approval_policy,
          approvals_reviewer: approvals_reviewer,
          base_instructions: base_instructions,
          config: config,
          cwd: cwd,
          developer_instructions: developer_instructions,
          ephemeral: ephemeral,
          model: model,
          model_provider: model_provider,
          sandbox: sandbox,
          service_tier: service_tier,
          thread_source: thread_source
        )
        forked = @client.thread_fork(thread_id, params)
        ConversationThread.new(@client, forked.thread.id)
      end

      def thread_archive(thread_id)
        @client.thread_archive(thread_id)
      end

      def thread_unarchive(thread_id)
        unarchived = @client.thread_unarchive(thread_id)
        ConversationThread.new(@client, unarchived.thread.id)
      end

      def models(include_hidden: false)
        @client.model_list(include_hidden: include_hidden)
      end
    end

    class ConversationThread
      attr_reader :id

      def initialize(client, id)
        @client = client
        @id = id
      end

      def run(input,
        approval_mode: nil,
        cwd: nil,
        effort: nil,
        model: nil,
        output_schema: nil,
        personality: nil,
        sandbox_policy: nil,
        service_tier: nil,
        summary: nil)
        handle = turn(
          Inputs.normalize_run_input(input),
          approval_mode: approval_mode,
          cwd: cwd,
          effort: effort,
          model: model,
          output_schema: output_schema,
          personality: personality,
          sandbox_policy: sandbox_policy,
          service_tier: service_tier,
          summary: summary
        )
        RunResultCollector.collect(handle.stream, turn_id: handle.id)
      end

      def turn(input,
        approval_mode: nil,
        cwd: nil,
        effort: nil,
        model: nil,
        output_schema: nil,
        personality: nil,
        sandbox_policy: nil,
        service_tier: nil,
        summary: nil)
        wire_input = Inputs.to_wire_input(input)
        approval_policy, approvals_reviewer = ApprovalModes.override_settings(approval_mode)
        params = Types::TurnStartParams.new(
          thread_id: @id,
          input: wire_input,
          approval_policy: approval_policy,
          approvals_reviewer: approvals_reviewer,
          cwd: cwd,
          effort: effort,
          model: model,
          output_schema: output_schema,
          personality: personality,
          sandbox_policy: sandbox_policy,
          service_tier: service_tier,
          summary: summary
        )
        started = @client.turn_start(@id, wire_input, params)
        TurnHandle.new(@client, @id, started.turn.id)
      end

      def read(include_turns: false)
        @client.thread_read(@id, include_turns: include_turns)
      end

      def set_name(name)
        @client.thread_set_name(@id, name)
      end

      def compact
        @client.thread_compact(@id)
      end
    end

    Thread = ConversationThread

    class TurnHandle
      attr_reader :thread_id, :id

      def initialize(client, thread_id, id)
        @client = client
        @thread_id = thread_id
        @id = id
      end

      def steer(input)
        @client.turn_steer(@thread_id, @id, Inputs.to_wire_input(input))
      end

      def interrupt
        @client.turn_interrupt(@thread_id, @id)
      end

      def stream
        Enumerator.new do |yielder|
          @client.register_turn_notifications(@id)
          begin
            loop do
              event = @client.next_turn_notification(@id)
              yielder << event
              break if event.method == "turn/completed" &&
                event.payload.is_a?(Types::TurnCompletedNotification) &&
                event.payload.turn.id == @id
            end
          ensure
            @client.unregister_turn_notifications(@id)
          end
        end
      end

      def run
        completed = nil
        stream.each do |event|
          payload = event.payload
          completed = payload if payload.is_a?(Types::TurnCompletedNotification) && payload.turn.id == @id
        end
        raise "turn completed event not received" unless completed

        completed.turn
      end
    end
  end
end
