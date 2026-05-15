# frozen_string_literal: true

require_relative "version"

module OpenAI
  module Codex
    class AppServerConfig
      attr_accessor :codex_bin,
        :launch_args_override,
        :config_overrides,
        :cwd,
        :env,
        :client_name,
        :client_title,
        :client_version,
        :experimental_api

      def initialize(codex_bin: nil,
        launch_args_override: nil,
        config_overrides: [],
        cwd: nil,
        env: nil,
        client_name: "codex_ruby_sdk",
        client_title: "Codex Ruby SDK",
        client_version: VERSION,
        experimental_api: true)
        @codex_bin = codex_bin
        @launch_args_override = launch_args_override
        @config_overrides = Array(config_overrides)
        @cwd = cwd
        @env = env
        @client_name = client_name
        @client_title = client_title
        @client_version = client_version
        @experimental_api = experimental_api
      end
    end
  end
end
