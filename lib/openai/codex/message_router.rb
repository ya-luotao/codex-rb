# frozen_string_literal: true

require_relative "errors"
require_relative "notification_registry"

module OpenAI
  module Codex
    class MessageRouter
      def initialize
        @mutex = Mutex.new
        @response_waiters = {}
        @turn_notifications = {}
        @pending_turn_notifications = Hash.new { |hash, key| hash[key] = [] }
        @global_notifications = Queue.new
      end

      attr_reader :pending_turn_notifications

      def create_response_waiter(request_id)
        queue = Queue.new
        @mutex.synchronize { @response_waiters[request_id.to_s] = queue }
        queue
      end

      def discard_response_waiter(request_id)
        @mutex.synchronize { @response_waiters.delete(request_id.to_s) }
      end

      def register_turn(turn_id)
        pending = nil
        queue = Queue.new
        @mutex.synchronize do
          return if @turn_notifications.key?(turn_id)

          pending = @pending_turn_notifications.delete(turn_id) || []
          @turn_notifications[turn_id] = queue
        end
        pending.each { |notification| queue << notification }
      end

      def unregister_turn(turn_id)
        @mutex.synchronize { @turn_notifications.delete(turn_id) }
      end

      def next_global_notification
        item = @global_notifications.pop
        raise item if item.is_a?(Exception)

        item
      end

      def next_turn_notification(turn_id)
        queue = @mutex.synchronize { @turn_notifications[turn_id] }
        raise "turn #{turn_id.inspect} is not registered for streaming" unless queue

        item = queue.pop
        raise item if item.is_a?(Exception)

        item
      end

      def route_response(message)
        request_id = message["id"]
        waiter = @mutex.synchronize { @response_waiters.delete(request_id.to_s) }
        return unless waiter

        if message.key?("error")
          error = message["error"]
          waiter << if error.is_a?(Hash)
            Errors.map_jsonrpc_error(error.fetch("code", -32_000).to_i,
              error.fetch("message", "unknown").to_s,
              error["data"])
          else
            AppServerError.new("Malformed JSON-RPC error response")
          end
          return
        end

        waiter << message["result"]
      end

      def route_notification(notification)
        turn_id = NotificationRegistry.turn_id(notification)
        unless turn_id
          @global_notifications << notification
          return
        end

        queue = @mutex.synchronize do
          registered = @turn_notifications[turn_id]
          unless registered
            if notification.method == "turn/completed"
              @pending_turn_notifications.delete(turn_id)
            else
              @pending_turn_notifications[turn_id] << notification
            end
          end
          registered
        end

        queue << notification if queue
      end

      def fail_all(error)
        response_waiters = []
        turn_queues = []
        @mutex.synchronize do
          response_waiters = @response_waiters.values
          @response_waiters = {}
          turn_queues = @turn_notifications.values
          @pending_turn_notifications.clear
        end
        response_waiters.each { |queue| queue << error }
        turn_queues.each { |queue| queue << error }
        @global_notifications << error
      end
    end
  end
end
