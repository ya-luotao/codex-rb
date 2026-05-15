#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Async variant of the quickstart. Each AsyncCodex call returns an OpenAI::Codex::Future
# whose #value! blocks until the underlying worker thread resolves it. This mirrors the
# Python `async with AsyncCodex()` pattern; Ruby callers can plug in their own scheduler
# (Fibers, the async gem, threadpools) without the SDK forcing one.

require "openai/codex"

OpenAI::Codex::AsyncCodex.open do |codex|
  thread = codex.thread_start(model: "gpt-5").value!
  result = thread.run("Say hello in one sentence.").value!
  puts "final_response: #{result.final_response}"
end
