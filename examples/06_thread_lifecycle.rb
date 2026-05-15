#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Inspect the broader thread surface: list, resume, fork, rename, archive.

require "openai/codex"

OpenAI::Codex.open do |codex|
  page = codex.thread_list(limit: 5)
  puts "Recent threads:"
  page.items.each { |t| puts "  #{t.id}  #{t.name.inspect}" }

  thread = codex.thread_start(model: "gpt-5")
  thread.run("Pick a number between 1 and 100.")
  thread.set_name("number game")
  forked = codex.thread_fork(thread.id)
  puts "Forked thread #{forked.id} from #{thread.id}"
  codex.thread_archive(thread.id)
end
