# frozen_string_literal: true

require_relative "errors"

module OpenAI
  module Codex
    module Retry
      module_function

      def retry_on_overload(max_attempts: 3, initial_delay_s: 0.25, max_delay_s: 2.0)
        attempts = 0
        delay = initial_delay_s

        begin
          attempts += 1
          yield
        rescue JsonRpcError => error
          raise unless Errors.retryable_error?(error) && attempts < max_attempts

          sleep(delay)
          delay = [delay * 2, max_delay_s].min
          retry
        end
      end
    end
  end
end
