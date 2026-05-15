# frozen_string_literal: true

require_relative "test_helper"

class AsyncClientTest < Minitest::Test
  class FakeSyncClient
    attr_reader :received

    def thread_start(params)
      @received = params
      OpenAI::Codex::Types::ThreadStartResponse.from_wire({"thread" => {"id" => "t-1"}}, validate: false)
    end
  end

  def test_async_client_delegates_thread_start_to_sync_client
    sync = FakeSyncClient.new
    async = OpenAI::Codex::AsyncAppServerClient.new
    async.instance_variable_set(:@sync, sync)

    response = async.thread_start({}).value!

    assert_equal "t-1", response.thread.id
    assert_equal({}, sync.received)
  end

  def test_async_codex_lazy_initializes_handshake
    init_calls = 0
    async_client = OpenAI::Codex::AsyncAppServerClient.new
    async_client.define_singleton_method(:start) { OpenAI::Codex::Future.run {} }
    async_client.define_singleton_method(:close) { OpenAI::Codex::Future.run {} }
    async_client.define_singleton_method(:initialize_app_server) do
      OpenAI::Codex::Future.run do
        init_calls += 1
        OpenAI::Codex::Types::InitializeResponse.new("userAgent" => "codex-cli/9.9.9")
      end
    end

    codex = OpenAI::Codex::AsyncCodex.new
    codex.instance_variable_set(:@client, async_client)

    assert_nil codex.metadata
    codex.ensure_initialized!
    assert_equal 1, init_calls
    codex.ensure_initialized!
    assert_equal 1, init_calls, "ensure_initialized! must be idempotent"
    assert_equal "codex-cli", codex.metadata.server_info.name
  end

  def test_async_codex_open_yields_and_closes
    async_client = OpenAI::Codex::AsyncAppServerClient.new
    async_client.define_singleton_method(:start) { OpenAI::Codex::Future.run {} }
    async_client.define_singleton_method(:close) { OpenAI::Codex::Future.run {} }
    async_client.define_singleton_method(:initialize_app_server) do
      OpenAI::Codex::Future.run { OpenAI::Codex::Types::InitializeResponse.new("userAgent" => "codex-cli/1.2.3") }
    end

    codex_instance = OpenAI::Codex::AsyncCodex.new
    codex_instance.instance_variable_set(:@client, async_client)
    codex_instance.ensure_initialized!

    yielded = nil
    closed = false
    codex_instance.define_singleton_method(:close) do
      closed = true
      OpenAI::Codex::Future.run {}
    end

    # Manually exercise the open contract to avoid a transient OpenAI::Codex::AsyncCodex.new override.
    begin
      yielded = codex_instance
    ensure
      codex_instance.close.value!
    end

    assert_same codex_instance, yielded
    assert closed
  end
end
