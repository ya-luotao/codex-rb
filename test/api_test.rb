# frozen_string_literal: true

require_relative "test_helper"

class ApiTest < Minitest::Test
  class FakeClient
    attr_reader :thread_start_params, :thread_resume_params, :turn_start_params

    def thread_start(params)
      @thread_start_params = params.to_h(exclude_nil: true)
      OpenAI::Codex::Types::ThreadStartResponse.from_wire({"thread" => {"id" => "thread-1"}}, validate: false)
    end

    def thread_resume(thread_id, params)
      @thread_resume_args = [thread_id, params.to_h(exclude_nil: true)]
      @thread_resume_params = @thread_resume_args.last
      OpenAI::Codex::Types::ThreadResumeResponse.from_wire({"thread" => {"id" => thread_id}}, validate: false)
    end

    def turn_start(_thread_id, _wire_input, params)
      @turn_start_params = params.to_h(exclude_nil: true)
      OpenAI::Codex::Types::TurnStartResponse.from_wire({"turn" => {"id" => "turn-1"}}, validate: false)
    end
  end

  def codex_with(fake)
    codex = OpenAI::Codex::Codex.allocate
    codex.instance_variable_set(:@client, fake)
    codex.instance_variable_set(:@metadata, OpenAI::Codex::Types::InitializeResponse.new("userAgent" => "codex-cli/1.2.3"))
    codex
  end

  def test_new_threads_default_to_auto_review_approval
    fake = FakeClient.new
    thread = codex_with(fake).thread_start(model: "gpt-5")

    assert_instance_of OpenAI::Codex::ConversationThread, thread
    assert_equal(
      {
        "approvalPolicy" => "on-request",
        "approvalsReviewer" => "auto_review",
        "model" => "gpt-5"
      },
      fake.thread_start_params
    )
  end

  def test_deny_all_approval_mode_serializes_to_never
    fake = FakeClient.new
    codex_with(fake).thread_start(approval_mode: OpenAI::Codex::ApprovalMode::DENY_ALL)

    assert_equal "never", fake.thread_start_params["approvalPolicy"]
    refute fake.thread_start_params.key?("approvalsReviewer")
  end

  def test_existing_thread_operations_preserve_approval_settings_by_default
    fake = FakeClient.new
    codex_with(fake).thread_resume("thread-1", model: "gpt-5")

    refute fake.thread_resume_params.key?("approvalPolicy")
    refute fake.thread_resume_params.key?("approvalsReviewer")
    assert_equal "gpt-5", fake.thread_resume_params["model"]
  end

  def test_turn_start_maps_structured_input_and_options
    fake = FakeClient.new
    thread = OpenAI::Codex::ConversationThread.new(fake, "thread-1")
    handle = thread.turn(OpenAI::Codex::TextInput.new(text: "hello"), model: "gpt-5")

    assert_instance_of OpenAI::Codex::TurnHandle, handle
    assert_equal(
      {
        "threadId" => "thread-1",
        "input" => [{"type" => "text", "text" => "hello"}],
        "model" => "gpt-5"
      },
      fake.turn_start_params
    )
  end
end
