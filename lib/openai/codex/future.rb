# frozen_string_literal: true

require "thread"

module OpenAI
  module Codex
    # Lightweight future used to surface asynchronous calls without binding to a
    # specific concurrency runtime. Each future owns one Ruby Thread that runs
    # the wrapped block. The mirrors the Python SDK's `asyncio.to_thread`
    # pattern: callers say `fut.value!` (Ruby) where Python says `await ...`.
    class Future
      def self.run(&block)
        new(&block)
      end

      def initialize(&block)
        raise ArgumentError, "Future requires a block" unless block

        @mutex = Mutex.new
        @condvar = ConditionVariable.new
        @completed = false
        @value = nil
        @error = nil
        @thread = ::Thread.new do
          begin
            value = block.call
            @mutex.synchronize do
              @value = value
              @completed = true
              @condvar.broadcast
            end
          rescue Exception => error # rubocop:disable Lint/RescueException
            @mutex.synchronize do
              @error = error
              @completed = true
              @condvar.broadcast
            end
          end
        end
      end

      def completed?
        @mutex.synchronize { @completed }
      end

      def wait(timeout = nil)
        @mutex.synchronize do
          @condvar.wait(@mutex, timeout) unless @completed
          @completed
        end
      end

      def value!(timeout = nil)
        completed = wait(timeout)
        raise TimeoutError, "Future did not complete within #{timeout}s" unless completed

        @mutex.synchronize do
          raise @error if @error

          @value
        end
      end

      class TimeoutError < StandardError; end
    end
  end
end
