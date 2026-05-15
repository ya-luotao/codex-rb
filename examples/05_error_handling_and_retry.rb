#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Wrap any client request with retry-on-overload semantics. The helper retries
# only on transient overload-class errors (-32099..-32000 + "server_overloaded"
# data); permanent failures like InvalidParamsError surface immediately.

require "openai/codex"

OpenAI::Codex.open do |codex|
  begin
    response = codex.instance_variable_get(:@client).request_with_retry_on_overload(
      "model/list",
      { "includeHidden" => false },
      response_type: OpenAI::Codex::Types::ModelListResponse,
      max_attempts: 4,
      initial_delay_s: 0.25,
      max_delay_s: 2.0
    )
    puts "model count: #{response.models.length}"
  rescue OpenAI::Codex::RetryLimitExceededError => err
    warn "Server kept signaling overload: #{err.rpc_message}"
  rescue OpenAI::Codex::AppServerRpcError => err
    warn "RPC error #{err.code}: #{err.rpc_message}"
  end
end
