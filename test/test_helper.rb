# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "minitest/autorun"
require "stringio"
require "tempfile"
require "openai/codex"

module TestHelpers
  def fixture_agent_delta(turn_id, delta)
    {
      "delta" => delta,
      "itemId" => "item-#{delta}",
      "threadId" => "thread-1",
      "turnId" => turn_id
    }
  end

  def fixture_completed_turn(turn_id, status: "completed")
    {
      "threadId" => "thread-1",
      "turn" => {
        "id" => turn_id,
        "items" => [],
        "status" => status
      }
    }
  end
end
