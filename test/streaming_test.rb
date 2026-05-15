# frozen_string_literal: true

require_relative "test_helper"

class StreamingTest < Minitest::Test
  include TestHelpers

  def test_turn_handle_stream_yields_until_turn_completed
    router = OpenAI::Codex::MessageRouter.new
    client = OpenAI::Codex::AppServerClient.new
    client.instance_variable_set(:@router, router)

    handle = OpenAI::Codex::TurnHandle.new(client, "thread-1", "turn-1")

    # Register early so route_notification reaches the live queue rather than the
    # pending buffer (which gets dropped on a turn/completed for an unregistered turn).
    router.register_turn("turn-1")
    router.route_notification(
      OpenAI::Codex::NotificationRegistry.coerce("item/agentMessage/delta",
        fixture_agent_delta("turn-1", "a"))
    )
    router.route_notification(
      OpenAI::Codex::NotificationRegistry.coerce("item/agentMessage/delta",
        fixture_agent_delta("turn-1", "b"))
    )
    router.route_notification(
      OpenAI::Codex::NotificationRegistry.coerce("turn/completed",
        fixture_completed_turn("turn-1"))
    )

    deltas = handle.stream.map(&:method)

    assert_equal ["item/agentMessage/delta", "item/agentMessage/delta", "turn/completed"], deltas
  end

  def test_turn_handle_run_returns_completed_turn
    router = OpenAI::Codex::MessageRouter.new
    client = OpenAI::Codex::AppServerClient.new
    client.instance_variable_set(:@router, router)

    handle = OpenAI::Codex::TurnHandle.new(client, "thread-1", "turn-1")

    router.register_turn("turn-1")
    router.route_notification(
      OpenAI::Codex::NotificationRegistry.coerce("turn/completed",
        fixture_completed_turn("turn-1"))
    )

    turn = handle.run

    assert_equal "turn-1", turn.id
    assert_equal "completed", turn.status
  end

  def test_run_result_collector_propagates_token_usage
    breakdown = {
      "cachedInputTokens" => 0,
      "inputTokens" => 11,
      "outputTokens" => 5,
      "reasoningOutputTokens" => 0,
      "totalTokens" => 16
    }
    events = [
      OpenAI::Codex::NotificationRegistry.coerce(
        "thread/tokenUsage/updated",
        {
          "threadId" => "thread-1",
          "turnId" => "turn-1",
          "tokenUsage" => {
            "last" => breakdown,
            "total" => breakdown
          }
        }
      ),
      OpenAI::Codex::NotificationRegistry.coerce(
        "turn/completed",
        fixture_completed_turn("turn-1")
      )
    ]

    result = OpenAI::Codex::RunResultCollector.collect(events.each, turn_id: "turn-1")

    refute_nil result.usage
    assert_equal 11, result.usage.total.input_tokens
    assert_equal 5, result.usage.last.output_tokens
  end

  def test_run_result_raises_when_turn_failed
    error_event = OpenAI::Codex::NotificationRegistry.coerce(
      "turn/completed",
      {
        "threadId" => "thread-1",
        "turn" => {
          "id" => "turn-1",
          "items" => [],
          "status" => "failed",
          "error" => {"message" => "model exploded"}
        }
      }
    )

    assert_raises(RuntimeError) do
      OpenAI::Codex::RunResultCollector.collect([error_event].each, turn_id: "turn-1")
    end
  end

  def test_run_result_raises_when_completion_event_missing
    error_event = OpenAI::Codex::NotificationRegistry.coerce(
      "item/agentMessage/delta",
      fixture_agent_delta("turn-1", "a")
    )

    assert_raises(RuntimeError) do
      OpenAI::Codex::RunResultCollector.collect([error_event].each, turn_id: "turn-1")
    end
  end
end
