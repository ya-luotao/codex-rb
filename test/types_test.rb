# frozen_string_literal: true

require_relative "test_helper"

class TypesTest < Minitest::Test
  def test_params_models_dump_snake_case_to_camel_case_wire_keys
    params = OpenAI::Codex::Types::ThreadListParams.new(search_term: "needle", limit: 5)

    assert_equal({"searchTerm" => "needle", "limit" => 5}, params.to_h(exclude_nil: true))
  end

  def test_enum_constants_are_generated_from_schema_values
    assert_equal "auto_review", OpenAI::Codex::Types::ApprovalsReviewer::AUTO_REVIEW
    assert_equal "read-only", OpenAI::Codex::Types::SandboxMode::READ_ONLY
  end

  def test_initialize_metadata_accepts_user_agent_only_shape
    payload = OpenAI::Codex::Types::InitializeResponse.new("userAgent" => "codex-cli/1.2.3")

    parsed = OpenAI::Codex::Codex.validate_initialize(payload)

    assert_equal "codex-cli/1.2.3", parsed.user_agent
    assert_equal "codex-cli", parsed.server_info.name
    assert_equal "1.2.3", parsed.server_info.version
  end

  def test_initialize_metadata_requires_identity
    error = assert_raises(RuntimeError) do
      OpenAI::Codex::Codex.validate_initialize(OpenAI::Codex::Types::InitializeResponse.new)
    end

    assert_includes error.message, "missing required metadata"
  end

  def test_invalid_notification_payload_can_fail_schema_validation
    assert_raises(OpenAI::Codex::ValidationError) do
      OpenAI::Codex::Types::ThreadTokenUsageUpdatedNotification.new("threadId" => "missing")
    end
  end
end
