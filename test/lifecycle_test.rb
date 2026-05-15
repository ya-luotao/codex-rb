# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class LifecycleTest < Minitest::Test
  def test_resolve_codex_bin_uses_explicit_path
    file = Tempfile.new(["codex", ""])
    file.close
    File.chmod(0o755, file.path)
    config = OpenAI::Codex::AppServerConfig.new(codex_bin: file.path)
    client = OpenAI::Codex::AppServerClient.new(config: config)

    assert_equal file.path, client.send(:resolve_codex_bin)
  ensure
    file.unlink if file
  end

  def test_resolve_codex_bin_raises_when_explicit_path_missing
    config = OpenAI::Codex::AppServerConfig.new(codex_bin: "/definitely/missing/codex")
    client = OpenAI::Codex::AppServerClient.new(config: config)

    assert_raises(Errno::ENOENT) { client.send(:resolve_codex_bin) }
  end

  def test_resolve_codex_bin_honors_openai_codex_bin_env
    file = Tempfile.new(["codex-env", ""])
    file.close
    File.chmod(0o755, file.path)
    original = ENV["OPENAI_CODEX_BIN"]
    ENV["OPENAI_CODEX_BIN"] = file.path
    client = OpenAI::Codex::AppServerClient.new

    assert_equal file.path, client.send(:resolve_codex_bin)
  ensure
    ENV["OPENAI_CODEX_BIN"] = original
    file.unlink if file
  end

  def test_resolve_codex_bin_falls_back_to_path
    dir = Dir.mktmpdir("codex-path-")
    candidate = File.join(dir, "codex")
    File.write(candidate, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, candidate)

    original_path = ENV["PATH"]
    original_codex_bin = ENV["OPENAI_CODEX_BIN"]
    original_legacy = ENV["CODEX_BIN"]
    ENV["PATH"] = dir
    ENV.delete("OPENAI_CODEX_BIN")
    ENV.delete("CODEX_BIN")

    client = OpenAI::Codex::AppServerClient.new

    assert_equal candidate, client.send(:resolve_codex_bin)
  ensure
    ENV["PATH"] = original_path
    ENV["OPENAI_CODEX_BIN"] = original_codex_bin if original_codex_bin
    ENV["CODEX_BIN"] = original_legacy if original_legacy
    FileUtils.rm_rf(dir) if dir
  end

  def test_close_is_idempotent_when_never_started
    client = OpenAI::Codex::AppServerClient.new

    assert_nil client.close
    refute client.running?
  end

  def test_launch_args_override_supersedes_resolution
    config = OpenAI::Codex::AppServerConfig.new(launch_args_override: ["/bin/sh", "--noop"])
    client = OpenAI::Codex::AppServerClient.new(config: config)

    assert_equal ["/bin/sh", "--noop"], client.send(:launch_args)
  end

  def test_config_overrides_are_passed_as_repeated_config_args
    fake_bin = "/bin/sh"
    config = OpenAI::Codex::AppServerConfig.new(codex_bin: fake_bin,
      config_overrides: ["a=1", "b=2"])
    client = OpenAI::Codex::AppServerClient.new(config: config)

    args = client.send(:launch_args)

    assert_equal [fake_bin, "--config", "a=1", "--config", "b=2", "app-server", "--listen", "stdio://"], args
  end
end
