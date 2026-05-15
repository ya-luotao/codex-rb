# frozen_string_literal: true

require_relative "test_helper"

class PublicApiTest < Minitest::Test
  PYTHON_SYNC_PUBLIC = %w[
    AppServerConfig
    AppServerClient
    Codex
    Thread
    TurnHandle
    RunResult
    TextInput
    ImageInput
    LocalImageInput
    SkillInput
    MentionInput
    AppServerError
    TransportClosedError
    JsonRpcError
    AppServerRpcError
    ParseError
    InvalidRequestError
    MethodNotFoundError
    InvalidParamsError
    InternalRpcError
    ServerBusyError
    RetryLimitExceededError
  ].freeze

  PYTHON_ASYNC_PUBLIC = %w[
    AsyncCodex
    AsyncThread
    AsyncTurnHandle
    AsyncAppServerClient
  ].freeze

  def test_all_python_sync_public_symbols_have_ruby_counterparts
    missing = PYTHON_SYNC_PUBLIC.reject { |sym| OpenAI::Codex.const_defined?(sym, false) }
    assert_empty missing, "Missing Python-aligned sync symbols: #{missing.inspect}"
  end

  def test_all_python_async_public_symbols_have_ruby_counterparts
    missing = PYTHON_ASYNC_PUBLIC.reject { |sym| OpenAI::Codex.const_defined?(sym, false) }
    assert_empty missing, "Missing Python-aligned async symbols: #{missing.inspect}"
  end

  def test_public_exports_include_every_documented_symbol
    documented = OpenAI::Codex::PUBLIC_EXPORTS
    sync_ok = PYTHON_SYNC_PUBLIC.all? { |sym| documented.include?(sym.to_sym) }
    async_ok = PYTHON_ASYNC_PUBLIC.all? { |sym| documented.include?(sym.to_sym) }

    assert sync_ok, "PUBLIC_EXPORTS missing one of #{PYTHON_SYNC_PUBLIC.inspect}"
    assert async_ok, "PUBLIC_EXPORTS missing one of #{PYTHON_ASYNC_PUBLIC.inspect}"
  end

  def test_codex_top_level_open_helper_delegates_to_class
    original_open = OpenAI::Codex::Codex.method(:open)
    captured_config = nil
    verbose, $VERBOSE = $VERBOSE, nil
    OpenAI::Codex::Codex.singleton_class.define_method(:open) do |config: nil, &block|
      captured_config = config
      block&.call(:fake_codex)
    end
    $VERBOSE = verbose
    begin
      cfg = OpenAI::Codex::AppServerConfig.new(launch_args_override: ["/bin/true"])
      OpenAI::Codex.open(config: cfg)
      assert_same cfg, captured_config
    ensure
      verbose, $VERBOSE = $VERBOSE, nil
      OpenAI::Codex::Codex.singleton_class.define_method(:open, original_open)
      $VERBOSE = verbose
    end
  end

  def test_approval_mode_constants_resolve_to_wire_strings
    assert_equal "auto_review", OpenAI::Codex::ApprovalMode::AUTO_REVIEW
    assert_equal "deny_all", OpenAI::Codex::ApprovalMode::DENY_ALL
    assert_includes OpenAI::Codex::ApprovalMode::VALUES, "auto_review"
    assert_includes OpenAI::Codex::ApprovalMode::VALUES, "deny_all"
  end

  def test_thread_alias_is_conversation_thread
    assert_equal OpenAI::Codex::ConversationThread, OpenAI::Codex::Thread
    assert_equal OpenAI::Codex::AsyncConversationThread, OpenAI::Codex::AsyncThread
  end
end
