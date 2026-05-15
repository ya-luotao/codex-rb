#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Stream assistant message deltas as they arrive instead of waiting for the
# final response.

require "openai/codex"

OpenAI::Codex.open do |codex|
  thread = codex.thread_start(model: "gpt-5")
  handle = thread.turn(OpenAI::Codex::TextInput.new(text: "Count to five."))

  handle.stream.each do |event|
    case event.method
    when "item/agentMessage/delta"
      print event.payload.delta
      $stdout.flush
    when "turn/completed"
      puts "\n[turn completed: status=#{event.payload.turn.status}]"
    end
  end
end
