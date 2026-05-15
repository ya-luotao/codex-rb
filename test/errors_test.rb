# frozen_string_literal: true

require_relative "test_helper"

class ErrorsTest < Minitest::Test
  Errors = OpenAI::Codex::Errors

  def test_parse_error_code_maps
    assert_instance_of OpenAI::Codex::ParseError, Errors.map_jsonrpc_error(-32_700, "bad json")
  end

  def test_invalid_request_code_maps
    assert_instance_of OpenAI::Codex::InvalidRequestError, Errors.map_jsonrpc_error(-32_600, "bad request")
  end

  def test_method_not_found_code_maps
    assert_instance_of OpenAI::Codex::MethodNotFoundError, Errors.map_jsonrpc_error(-32_601, "missing")
  end

  def test_invalid_params_code_maps
    assert_instance_of OpenAI::Codex::InvalidParamsError, Errors.map_jsonrpc_error(-32_602, "bad params")
  end

  def test_internal_error_code_maps
    assert_instance_of OpenAI::Codex::InternalRpcError, Errors.map_jsonrpc_error(-32_603, "boom")
  end

  def test_server_overload_maps_to_server_busy
    err = Errors.map_jsonrpc_error(-32_010, "busy", "server_overloaded")

    assert_instance_of OpenAI::Codex::ServerBusyError, err
    assert Errors.retryable_error?(err)
  end

  def test_retry_limit_text_maps_to_retry_limit_exceeded
    err = Errors.map_jsonrpc_error(-32_010, "retry limit reached", "server_overloaded")

    assert_instance_of OpenAI::Codex::RetryLimitExceededError, err
    assert Errors.retryable_error?(err)
  end

  def test_retry_limit_text_outside_overload_still_classified
    err = Errors.map_jsonrpc_error(-32_010, "too many failed attempts", nil)

    assert_instance_of OpenAI::Codex::RetryLimitExceededError, err
  end

  def test_overload_payload_detection_in_nested_codex_error_info
    err = Errors.map_jsonrpc_error(-32_010, "busy", {"codexErrorInfo" => "server_overloaded"})

    assert_instance_of OpenAI::Codex::ServerBusyError, err
  end

  def test_overload_payload_detection_in_nested_hash_value
    err = Errors.map_jsonrpc_error(-32_010, "busy", {"extra" => {"errorInfo" => {"kind" => "server_overloaded"}}})

    assert_instance_of OpenAI::Codex::ServerBusyError, err
  end

  def test_overload_payload_detection_in_array_value
    err = Errors.map_jsonrpc_error(-32_010, "busy", ["other", "server_overloaded"])

    assert_instance_of OpenAI::Codex::ServerBusyError, err
  end

  def test_non_overload_server_error_maps_to_app_server_rpc_error
    err = Errors.map_jsonrpc_error(-32_010, "service error", nil)

    assert_instance_of OpenAI::Codex::AppServerRpcError, err
    refute Errors.retryable_error?(err)
  end

  def test_unknown_code_maps_to_generic_jsonrpc_error
    err = Errors.map_jsonrpc_error(-1, "weird", nil)

    assert_instance_of OpenAI::Codex::JsonRpcError, err
  end

  def test_rpc_message_accessor_preserves_server_text
    err = Errors.map_jsonrpc_error(-32_602, "bad params payload", nil)

    assert_equal "bad params payload", err.rpc_message
    assert_includes err.message, "JSON-RPC error -32602"
  end
end
