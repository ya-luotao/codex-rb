# frozen_string_literal: true

require_relative "test_helper"

class RetryTest < Minitest::Test
  def test_returns_value_when_block_succeeds_first_time
    calls = 0
    value = OpenAI::Codex::Retry.retry_on_overload do
      calls += 1
      "ok"
    end

    assert_equal "ok", value
    assert_equal 1, calls
  end

  def test_retries_on_retryable_error_until_success
    attempts = 0
    overload = OpenAI::Codex::Errors.map_jsonrpc_error(-32_010, "busy", "server_overloaded")

    value = OpenAI::Codex::Retry.retry_on_overload(max_attempts: 3, initial_delay_s: 0, max_delay_s: 0) do
      attempts += 1
      raise overload if attempts < 3

      "done"
    end

    assert_equal "done", value
    assert_equal 3, attempts
  end

  def test_raises_after_exhausting_attempts
    overload = OpenAI::Codex::Errors.map_jsonrpc_error(-32_010, "busy", "server_overloaded")

    assert_raises(OpenAI::Codex::ServerBusyError) do
      OpenAI::Codex::Retry.retry_on_overload(max_attempts: 2, initial_delay_s: 0, max_delay_s: 0) do
        raise overload
      end
    end
  end

  def test_does_not_retry_non_retryable_jsonrpc_error
    invalid = OpenAI::Codex::Errors.map_jsonrpc_error(-32_602, "bad params", nil)
    attempts = 0

    assert_raises(OpenAI::Codex::InvalidParamsError) do
      OpenAI::Codex::Retry.retry_on_overload(max_attempts: 5, initial_delay_s: 0, max_delay_s: 0) do
        attempts += 1
        raise invalid
      end
    end
    assert_equal 1, attempts
  end

  def test_client_request_with_retry_on_overload_uses_retry_helper
    client = OpenAI::Codex::AppServerClient.new
    attempts = 0
    overload = OpenAI::Codex::Errors.map_jsonrpc_error(-32_010, "busy", "server_overloaded")
    client.define_singleton_method(:request) do |_method, _params, response_type: nil|
      attempts += 1
      raise overload if attempts < 2

      OpenAI::Codex::Types::ModelListResponse.from_wire({"models" => []}, validate: false)
    end

    response = client.request_with_retry_on_overload(
      "model/list",
      {"includeHidden" => false},
      response_type: OpenAI::Codex::Types::ModelListResponse,
      max_attempts: 4,
      initial_delay_s: 0,
      max_delay_s: 0
    )

    assert_kind_of OpenAI::Codex::Model, response
    assert_equal 2, attempts
  end
end
