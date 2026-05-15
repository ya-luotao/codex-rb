# frozen_string_literal: true

require_relative "lib/openai/codex/version"

Gem::Specification.new do |spec|
  spec.name = "codex-rb"
  spec.version = OpenAI::Codex::VERSION
  spec.authors = ["OpenAI"]
  spec.summary = "Ruby SDK for Codex app-server JSON-RPC v2"
  spec.description = "Schema-backed Ruby SDK for the Codex app-server v2 protocol over stdio."
  spec.homepage = "https://github.com/ya-luotao/codex-rb"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 2.6"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "lib/**/*.rb",
      "data/**/*.json",
      "docs/**/*.md",
      "examples/**/*.rb",
      "README.md",
      "CHANGELOG.md",
      "CONTRIBUTING.md",
      "SECURITY.md",
      "LICENSE"
    ]
  end
  spec.require_paths = ["lib"]

  spec.metadata = {
    "source_code_uri" => "https://github.com/ya-luotao/codex-rb",
    "changelog_uri" => "https://github.com/ya-luotao/codex-rb/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.add_development_dependency "minitest", "~> 5.16"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "standard", "~> 1.0"
end
