# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  include TestHelpers

  def test_params_dict_accepts_schema_models_and_excludes_nil_values
    client = OpenAI::Codex::AppServerClient.new
    params = OpenAI::Codex::Types::ThreadListParams.new(search_term: "needle", archived: nil)

    assert_equal({ "searchTerm" => "needle" }, client.params_dict(params))
  end

  def test_reader_loop_routes_interleaved_notifications_by_turn_id
    client = OpenAI::Codex::AppServerClient.new
    client.register_turn_notifications("turn-1")
    client.register_turn_notifications("turn-2")

    messages = [
      { "method" => "item/agentMessage/delta", "params" => fixture_agent_delta("turn-1", "one-a") },
      { "method" => "item/agentMessage/delta", "params" => fixture_agent_delta("turn-2", "two-a") },
      { "method" => "item/agentMessage/delta", "params" => fixture_agent_delta("turn-1", "one-b") },
      { "method" => "item/agentMessage/delta", "params" => fixture_agent_delta("turn-2", "two-b") }
    ]

    client.define_singleton_method(:read_message) do
      raise EOFError if messages.empty?

      messages.shift
    end

    client.send(:reader_loop)

    assert_equal ["one-a", "one-b"], [
      client.next_turn_notification("turn-1").payload.delta,
      client.next_turn_notification("turn-1").payload.delta
    ]
    assert_equal ["two-a", "two-b"], [
      client.next_turn_notification("turn-2").payload.delta,
      client.next_turn_notification("turn-2").payload.delta
    ]
  end

  def test_jsonrpc_errors_are_mapped
    router = OpenAI::Codex::MessageRouter.new
    waiter = router.create_response_waiter("req-1")
    router.route_response(
      "id" => "req-1",
      "error" => {
        "code" => -32_602,
        "message" => "bad params"
      }
    )

    assert_instance_of OpenAI::Codex::InvalidParamsError, waiter.pop
  end
end
