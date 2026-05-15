# frozen_string_literal: true

require_relative "client"
require_relative "future"

module OpenAI
  module Codex
    # Async mirror of {AppServerClient}. Each method returns a {Future} that runs
    # the wrapped blocking call on a worker thread, matching the Python
    # `AsyncAppServerClient` semantics (`asyncio.to_thread` per call).
    class AsyncAppServerClient
      def initialize(config: nil, approval_handler: nil)
        @sync = AppServerClient.new(config: config, approval_handler: approval_handler)
      end

      attr_reader :sync

      def start
        Future.run { @sync.start }
      end

      def close
        Future.run { @sync.close }
      end

      def initialize_app_server
        Future.run { @sync.initialize_app_server }
      end

      def register_turn_notifications(turn_id)
        @sync.register_turn_notifications(turn_id)
      end

      def unregister_turn_notifications(turn_id)
        @sync.unregister_turn_notifications(turn_id)
      end

      def request(method, params = nil, response_type: nil)
        Future.run { @sync.request(method, params, response_type: response_type) }
      end

      def request_with_retry_on_overload(method, params = nil, response_type: nil,
                                         max_attempts: 3, initial_delay_s: 0.25, max_delay_s: 2.0)
        Future.run do
          @sync.request_with_retry_on_overload(
            method,
            params,
            response_type: response_type,
            max_attempts: max_attempts,
            initial_delay_s: initial_delay_s,
            max_delay_s: max_delay_s
          )
        end
      end

      def thread_start(params = nil)
        Future.run { @sync.thread_start(params) }
      end

      def thread_resume(thread_id, params = nil)
        Future.run { @sync.thread_resume(thread_id, params) }
      end

      def thread_list(params = nil)
        Future.run { @sync.thread_list(params) }
      end

      def thread_read(thread_id, include_turns: false)
        Future.run { @sync.thread_read(thread_id, include_turns: include_turns) }
      end

      def thread_fork(thread_id, params = nil)
        Future.run { @sync.thread_fork(thread_id, params) }
      end

      def thread_archive(thread_id)
        Future.run { @sync.thread_archive(thread_id) }
      end

      def thread_unarchive(thread_id)
        Future.run { @sync.thread_unarchive(thread_id) }
      end

      def thread_set_name(thread_id, name)
        Future.run { @sync.thread_set_name(thread_id, name) }
      end

      def thread_compact(thread_id)
        Future.run { @sync.thread_compact(thread_id) }
      end

      def turn_start(thread_id, input_items, params = nil)
        Future.run { @sync.turn_start(thread_id, input_items, params) }
      end

      def turn_interrupt(thread_id, turn_id)
        Future.run { @sync.turn_interrupt(thread_id, turn_id) }
      end

      def turn_steer(thread_id, expected_turn_id, input_items)
        Future.run { @sync.turn_steer(thread_id, expected_turn_id, input_items) }
      end

      def model_list(include_hidden: false)
        Future.run { @sync.model_list(include_hidden: include_hidden) }
      end

      def next_notification
        Future.run { @sync.next_notification }
      end

      def next_turn_notification(turn_id)
        Future.run { @sync.next_turn_notification(turn_id) }
      end

      def wait_for_turn_completed(turn_id)
        Future.run { @sync.wait_for_turn_completed(turn_id) }
      end

      def stream_text(thread_id, text, params = nil)
        @sync.stream_text(thread_id, text, params)
      end
    end
  end
end
