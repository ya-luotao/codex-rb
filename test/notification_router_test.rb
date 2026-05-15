# frozen_string_literal: true

require_relative "test_helper"

class NotificationRouterTest < Minitest::Test
  include TestHelpers

  def test_known_notifications_are_typed
    event = OpenAI::Codex::NotificationRegistry.coerce(
      "item/agentMessage/delta",
      fixture_agent_delta("turn-1", "hello")
    )

    assert_equal "item/agentMessage/delta", event.method
    assert_instance_of OpenAI::Codex::Types::AgentMessageDeltaNotification, event.payload
    assert_equal "turn-1", event.payload.turn_id
  end

  def test_invalid_known_notifications_fall_back_to_unknown
    event = OpenAI::Codex::NotificationRegistry.coerce(
      "thread/tokenUsage/updated",
      "threadId" => "missing"
    )

    assert_instance_of OpenAI::Codex::UnknownNotification, event.payload
  end

  def test_router_demuxes_registered_turns
    router = OpenAI::Codex::MessageRouter.new
    router.register_turn("turn-1")
    router.register_turn("turn-2")

    router.route_notification(OpenAI::Codex::NotificationRegistry.coerce("item/agentMessage/delta", fixture_agent_delta("turn-2", "two")))
    router.route_notification(OpenAI::Codex::NotificationRegistry.coerce("item/agentMessage/delta", fixture_agent_delta("turn-1", "one")))

    assert_equal "one", router.next_turn_notification("turn-1").payload.delta
    assert_equal "two", router.next_turn_notification("turn-2").payload.delta
  end

  def test_router_buffers_early_turn_events
    router = OpenAI::Codex::MessageRouter.new
    router.route_notification(OpenAI::Codex::NotificationRegistry.coerce("item/agentMessage/delta", fixture_agent_delta("turn-1", "early")))

    router.register_turn("turn-1")

    assert_equal "early", router.next_turn_notification("turn-1").payload.delta
  end

  def test_router_clears_unregistered_turn_when_completed
    router = OpenAI::Codex::MessageRouter.new
    router.route_notification(OpenAI::Codex::NotificationRegistry.coerce("item/agentMessage/delta", fixture_agent_delta("turn-1", "early")))
    router.route_notification(OpenAI::Codex::NotificationRegistry.coerce("turn/completed", fixture_completed_turn("turn-1")))

    assert_empty router.pending_turn_notifications
  end

  def test_unknown_notifications_still_route_by_raw_turn_id
    router = OpenAI::Codex::MessageRouter.new
    router.register_turn("turn-1")
    router.register_turn("turn-2")

    router.route_notification(OpenAI::Codex::Notification.new(method: "unknown/direct", payload: OpenAI::Codex::UnknownNotification.new("turnId" => "turn-1")))
    router.route_notification(OpenAI::Codex::Notification.new(method: "unknown/nested", payload: OpenAI::Codex::UnknownNotification.new("turn" => { "id" => "turn-2" })))

    assert_equal "unknown/direct", router.next_turn_notification("turn-1").method
    assert_equal "unknown/nested", router.next_turn_notification("turn-2").method
  end
end
