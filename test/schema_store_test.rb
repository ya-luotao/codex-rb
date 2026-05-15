# frozen_string_literal: true

require_relative "test_helper"
require "json"

class SchemaStoreTest < Minitest::Test
  def test_copied_aggregate_schema_matches_upstream_when_present
    local = File.join(__dir__, "..", "data", "schemas", "json", "codex_app_server_protocol.v2.schemas.json")
    upstream = File.expand_path("../../codex/codex-rs/app-server-protocol/schema/json/codex_app_server_protocol.v2.schemas.json", __dir__)
    skip "upstream checkout not present" unless File.exist?(upstream)

    assert_equal File.read(upstream), File.read(local)
  end

  def test_protocol_manifests_cover_exported_methods_and_notifications
    methods = OpenAI::Codex::SchemaStore.methods
    notifications = OpenAI::Codex::SchemaStore.notifications

    assert_includes methods.map { |entry| entry["method"] }, "thread/start"
    assert_includes methods.map { |entry| entry["method"] }, "turn/start"
    assert_includes methods.map { |entry| entry["method"] }, "model/list"
    assert_includes notifications.map { |entry| entry["method"] }, "turn/completed"
    assert_includes notifications.map { |entry| entry["method"] }, "item/agentMessage/delta"
    assert methods.length >= 79
    assert notifications.length >= 64
  end

  def test_types_are_defined_for_all_manifest_param_and_response_names
    missing = OpenAI::Codex::SchemaStore.methods.flat_map do |entry|
      [entry["params"], entry["response"]]
    end.compact.uniq.reject { |name| OpenAI::Codex::Types.const_defined?(name, false) }

    assert_empty missing
  end
end
