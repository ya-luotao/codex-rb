# frozen_string_literal: true

require_relative "api"
require_relative "async_client"

module OpenAI
  module Codex
    # Async mirror of {Codex}. Initialization is lazy on the first call to
    # `ensure_initialized!`, matching the Python `AsyncCodex` semantics where
    # the handshake happens on first awaited use (or on `async with`).
    class AsyncCodex
      attr_reader :metadata

      def initialize(config: nil)
        @client = AsyncAppServerClient.new(config: config)
        @metadata = nil
        @init_mutex = Mutex.new
        @initialized = false
      end

      def self.open(config: nil)
        codex = new(config: config)
        codex.ensure_initialized!
        return codex unless block_given?

        begin
          yield codex
        ensure
          codex.close.value!
        end
      end

      def ensure_initialized!
        return if @initialized

        @init_mutex.synchronize do
          return if @initialized

          begin
            @client.start.value!
            payload = @client.initialize_app_server.value!
            @metadata = Codex.validate_initialize(payload)
            @initialized = true
          rescue Exception
            @client.close.value!
            @metadata = nil
            @initialized = false
            raise
          end
        end
      end

      def close
        Future.run do
          @client.close.value!
          @metadata = nil
          @initialized = false
        end
      end

      def thread_start(approval_mode: ApprovalMode::AUTO_REVIEW, **kwargs)
        Future.run do
          ensure_initialized!
          approval_policy, approvals_reviewer = ApprovalModes.settings(approval_mode)
          params = Types::ThreadStartParams.new(
            approval_policy: approval_policy,
            approvals_reviewer: approvals_reviewer,
            **kwargs
          )
          started = @client.thread_start(params).value!
          AsyncConversationThread.new(@client, started.thread.id)
        end
      end

      def thread_list(**kwargs)
        Future.run do
          ensure_initialized!
          @client.thread_list(Types::ThreadListParams.new(**kwargs)).value!
        end
      end

      def thread_resume(thread_id, approval_mode: nil, **kwargs)
        Future.run do
          ensure_initialized!
          approval_policy, approvals_reviewer = ApprovalModes.override_settings(approval_mode)
          params = Types::ThreadResumeParams.new(
            thread_id: thread_id,
            approval_policy: approval_policy,
            approvals_reviewer: approvals_reviewer,
            **kwargs
          )
          resumed = @client.thread_resume(thread_id, params).value!
          AsyncConversationThread.new(@client, resumed.thread.id)
        end
      end

      def thread_fork(thread_id, approval_mode: nil, **kwargs)
        Future.run do
          ensure_initialized!
          approval_policy, approvals_reviewer = ApprovalModes.override_settings(approval_mode)
          params = Types::ThreadForkParams.new(
            thread_id: thread_id,
            approval_policy: approval_policy,
            approvals_reviewer: approvals_reviewer,
            **kwargs
          )
          forked = @client.thread_fork(thread_id, params).value!
          AsyncConversationThread.new(@client, forked.thread.id)
        end
      end

      def thread_archive(thread_id)
        Future.run do
          ensure_initialized!
          @client.thread_archive(thread_id).value!
        end
      end

      def thread_unarchive(thread_id)
        Future.run do
          ensure_initialized!
          unarchived = @client.thread_unarchive(thread_id).value!
          AsyncConversationThread.new(@client, unarchived.thread.id)
        end
      end

      def models(include_hidden: false)
        Future.run do
          ensure_initialized!
          @client.model_list(include_hidden: include_hidden).value!
        end
      end
    end

    class AsyncConversationThread
      attr_reader :id

      def initialize(client, id)
        @client = client
        @id = id
      end

      def run(input, approval_mode: nil, **kwargs)
        Future.run do
          handle = turn(Inputs.normalize_run_input(input), approval_mode: approval_mode, **kwargs).value!
          RunResultCollector.collect(handle.stream, turn_id: handle.id)
        end
      end

      def turn(input, approval_mode: nil, **kwargs)
        Future.run do
          wire_input = Inputs.to_wire_input(input)
          approval_policy, approvals_reviewer = ApprovalModes.override_settings(approval_mode)
          params = Types::TurnStartParams.new(
            thread_id: @id,
            input: wire_input,
            approval_policy: approval_policy,
            approvals_reviewer: approvals_reviewer,
            **kwargs
          )
          started = @client.turn_start(@id, wire_input, params).value!
          AsyncTurnHandle.new(@client, @id, started.turn.id)
        end
      end

      def read(include_turns: false)
        Future.run { @client.thread_read(@id, include_turns: include_turns).value! }
      end

      def set_name(name)
        Future.run { @client.thread_set_name(@id, name).value! }
      end

      def compact
        Future.run { @client.thread_compact(@id).value! }
      end
    end

    AsyncThread = AsyncConversationThread

    class AsyncTurnHandle
      attr_reader :thread_id, :id

      def initialize(client, thread_id, id)
        @client = client
        @thread_id = thread_id
        @id = id
      end

      def steer(input)
        Future.run { @client.turn_steer(@thread_id, @id, Inputs.to_wire_input(input)).value! }
      end

      def interrupt
        Future.run { @client.turn_interrupt(@thread_id, @id).value! }
      end

      def stream
        @client.sync.register_turn_notifications(@id)
        Enumerator.new do |yielder|
          loop do
            event = @client.next_turn_notification(@id).value!
            yielder << event
            break if event.method == "turn/completed" &&
              event.payload.is_a?(Types::TurnCompletedNotification) &&
              event.payload.turn.id == @id
          end
        ensure
          @client.sync.unregister_turn_notifications(@id)
        end
      end

      def run
        Future.run do
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
end
