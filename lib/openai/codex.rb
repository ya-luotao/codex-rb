# frozen_string_literal: true

require_relative "codex/version"
require_relative "codex/errors"
require_relative "codex/types"
require_relative "codex/client"
require_relative "codex/api"
require_relative "codex/retry"
require_relative "codex/future"
require_relative "codex/async_client"
require_relative "codex/async_api"

module OpenAI
  module Codex
    PUBLIC_EXPORTS = [
      :VERSION,
      :UPSTREAM_VERSION,
      :AppServerConfig,
      :AppServerClient,
      :AsyncAppServerClient,
      :Codex,
      :AsyncCodex,
      :ApprovalMode,
      :Thread,
      :AsyncThread,
      :ConversationThread,
      :AsyncConversationThread,
      :TurnHandle,
      :AsyncTurnHandle,
      :RunResult,
      :Future,
      :TextInput,
      :ImageInput,
      :LocalImageInput,
      :SkillInput,
      :MentionInput,
      :Retry,
      :Errors,
      :AppServerError,
      :TransportClosedError,
      :ValidationError,
      :JsonRpcError,
      :AppServerRpcError,
      :ParseError,
      :InvalidRequestError,
      :MethodNotFoundError,
      :InvalidParamsError,
      :InternalRpcError,
      :ServerBusyError,
      :RetryLimitExceededError
    ].freeze

    def self.open(config: nil, &block)
      Codex.open(config: config, &block)
    end

    def self.open_async(config: nil, &block)
      AsyncCodex.open(config: config, &block)
    end
  end
end
