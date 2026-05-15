# frozen_string_literal: true

module OpenAI
  module Codex
    class AppServerError < StandardError; end

    class ValidationError < AppServerError; end

    class TransportClosedError < AppServerError; end

    class JsonRpcError < AppServerError
      attr_reader :code, :rpc_message, :data

      def initialize(code, message, data = nil)
        @code = code
        @rpc_message = message
        @data = data
        super("JSON-RPC error #{code}: #{message}")
      end
    end

    class AppServerRpcError < JsonRpcError; end
    class ParseError < AppServerRpcError; end
    class InvalidRequestError < AppServerRpcError; end
    class MethodNotFoundError < AppServerRpcError; end
    class InvalidParamsError < AppServerRpcError; end
    class InternalRpcError < AppServerRpcError; end
    class ServerBusyError < AppServerRpcError; end
    class RetryLimitExceededError < ServerBusyError; end

    module Errors
      module_function

      def map_jsonrpc_error(code, message, data = nil)
        case code
        when -32_700
          ParseError.new(code, message, data)
        when -32_600
          InvalidRequestError.new(code, message, data)
        when -32_601
          MethodNotFoundError.new(code, message, data)
        when -32_602
          InvalidParamsError.new(code, message, data)
        when -32_603
          InternalRpcError.new(code, message, data)
        when -32_099..-32_000
          map_server_error(code, message, data)
        else
          JsonRpcError.new(code, message, data)
        end
      end

      def retryable_error?(error)
        return true if error.is_a?(ServerBusyError)
        return overloaded_payload?(error.data) if error.is_a?(JsonRpcError)

        false
      end

      def map_server_error(code, message, data)
        if overloaded_payload?(data)
          return RetryLimitExceededError.new(code, message, data) if retry_limit_message?(message)

          return ServerBusyError.new(code, message, data)
        end

        return RetryLimitExceededError.new(code, message, data) if retry_limit_message?(message)

        AppServerRpcError.new(code, message, data)
      end

      def retry_limit_message?(message)
        text = message.to_s.downcase
        text.include?("retry limit") || text.include?("too many failed attempts")
      end

      def overloaded_payload?(value)
        case value
        when String
          value.downcase == "server_overloaded"
        when Hash
          direct = value["codex_error_info"] || value["codexErrorInfo"] || value["errorInfo"]
          return overloaded_payload?(direct) if direct

          value.values.any? { |item| overloaded_payload?(item) }
        when Array
          value.any? { |item| overloaded_payload?(item) }
        else
          false
        end
      end
    end
  end
end
