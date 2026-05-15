# frozen_string_literal: true

require_relative "test_helper"

class RunResultTest < Minitest::Test
  def test_collects_final_response_from_completed_items
    events = [
      OpenAI::Codex::Notification.new(
        method: "item/completed",
        payload: OpenAI::Codex::Types::ItemCompletedNotification.new(
          "completedAtMs" => 1,
          "threadId" => "thread-1",
          "turnId" => "turn-1",
          "item" => {
            "type" => "agentMessage",
            "id" => "item-1",
            "text" => "done",
            "phase" => "final_answer"
          }
        )
      ),
      OpenAI::Codex::Notification.new(
        method: "turn/completed",
        payload: OpenAI::Codex::Types::TurnCompletedNotification.new(
          "threadId" => "thread-1",
          "turn" => {
            "id" => "turn-1",
            "items" => [],
            "status" => "completed"
          }
        )
      )
    ]

    result = OpenAI::Codex::RunResultCollector.collect(events.each, turn_id: "turn-1")

    assert_equal "done", result.final_response
    assert_equal 1, result.items.length
  end
end
