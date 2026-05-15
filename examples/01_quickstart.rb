#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Minimal end-to-end: start a thread, run one prompt, print the final response.
# Requires `codex` on PATH or OPENAI_CODEX_BIN set to the runtime binary.

require "openai/codex"

OpenAI::Codex.open do |codex|
  thread = codex.thread_start(model: "gpt-5")
  result = thread.run("Say hello in one sentence.")
  puts "final_response: #{result.final_response}"
end
