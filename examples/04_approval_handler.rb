#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Demonstrate an interactive approval handler. The default policy auto-approves
# command and file-change requests, which is convenient for prototyping but is
# almost certainly unsafe in production. Pass `approval_handler:` to gate those
# requests on whatever policy you need.

require "openai/codex"

approval_handler = lambda do |method, params|
  case method
  when "item/commandExecution/requestApproval"
    print "Allow command #{params&.dig("command").inspect}? [y/N] "
    answer = $stdin.gets&.strip&.downcase
    {decision: (answer == "y") ? "accept" : "deny"}
  when "item/fileChange/requestApproval"
    print "Allow file change to #{params&.dig("path").inspect}? [y/N] "
    answer = $stdin.gets&.strip&.downcase
    {decision: (answer == "y") ? "accept" : "deny"}
  else
    {}
  end
end

client = OpenAI::Codex::AppServerClient.new(approval_handler: approval_handler)
client.start
client.initialize_app_server
begin
  codex = OpenAI::Codex::Codex.allocate
  codex.instance_variable_set(:@client, client)
  thread = codex.thread_start(model: "gpt-5",
    approval_mode: OpenAI::Codex::ApprovalMode::DENY_ALL)
  puts thread.run("Try to read /etc/hosts and tell me what's there.").final_response
ensure
  client.close
end
