# frozen_string_literal: true

require_relative "test_helper"

class ApprovalHandlerTest < Minitest::Test
  def test_default_handler_accepts_command_approval
    client = OpenAI::Codex::AppServerClient.new

    assert_equal({decision: "accept"},
      client.send(:default_approval_handler, "item/commandExecution/requestApproval", {}))
  end

  def test_default_handler_accepts_file_change_approval
    client = OpenAI::Codex::AppServerClient.new

    assert_equal({decision: "accept"},
      client.send(:default_approval_handler, "item/fileChange/requestApproval", {}))
  end

  def test_default_handler_returns_empty_for_unknown_methods
    client = OpenAI::Codex::AppServerClient.new

    assert_equal({}, client.send(:default_approval_handler, "permissions/request/approval", {}))
  end

  def test_custom_handler_can_deny
    handler = ->(method, _params) { (method == "item/fileChange/requestApproval") ? {decision: "deny"} : {} }
    client = OpenAI::Codex::AppServerClient.new(approval_handler: handler)

    response = client.instance_variable_get(:@approval_handler).call("item/fileChange/requestApproval", {})

    assert_equal({decision: "deny"}, response)
  end

  def test_reader_loop_forwards_server_request_to_handler_and_writes_result
    captured = []
    handler = lambda do |method, params|
      captured << [method, params]
      {decision: "accept"}
    end

    client = OpenAI::Codex::AppServerClient.new(approval_handler: handler)
    write_buffer = StringIO.new
    client.instance_variable_set(:@stdin, write_buffer)

    messages = [
      {"id" => "req-1", "method" => "item/commandExecution/requestApproval", "params" => {"command" => "ls"}},
      {"id" => "req-2", "method" => "item/fileChange/requestApproval", "params" => {"path" => "/tmp"}}
    ]
    client.define_singleton_method(:read_message) do
      raise EOFError if messages.empty?

      messages.shift
    end

    client.send(:reader_loop)

    written = write_buffer.string.split("\n").map { |line| JSON.parse(line) }
    assert_equal "req-1", written[0]["id"]
    assert_equal({"decision" => "accept"}, written[0]["result"])
    assert_equal "req-2", written[1]["id"]
    assert_equal({"decision" => "accept"}, written[1]["result"])
    assert_equal [
      ["item/commandExecution/requestApproval", {"command" => "ls"}],
      ["item/fileChange/requestApproval", {"path" => "/tmp"}]
    ], captured
  end
end
