# Changelog

All notable changes to `codex-rb` are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
package follows [Semantic Versioning](https://semver.org/) once it reaches `1.0.0`.
Prior to `1.0.0`, the version is pinned to the upstream Codex app-server protocol
release (`UPSTREAM_VERSION` in `lib/openai/codex/version.rb`).

## [0.131.0a4] — 2026-05-15

### Added
- Initial Ruby port of the Codex app-server v2 SDK aligned with `openai-codex==0.131.0a4`.
- Synchronous `OpenAI::Codex::Codex` facade with thread, turn, model, and run-result helpers.
- `OpenAI::Codex::AsyncCodex` / `AsyncThread` / `AsyncTurnHandle` future-based wrappers
  around the sync client via the standard library `Thread` pool.
- `OpenAI::Codex::AppServerClient#request_with_retry_on_overload` convenience helper
  mirroring the Python client surface.
- Schema-backed `OpenAI::Codex::Types::*` constants generated at load time from the
  upstream v2 schema bundle (204 schemas, 106 RPC methods, 64 server notifications).
- `OpenAI::Codex::Errors.map_jsonrpc_error` mapping for all JSON-RPC error code ranges,
  including overload classification and retry-limit detection.
- `OpenAI::Codex::Retry.retry_on_overload` backoff helper with optional jitter.
- Examples under `examples/` covering quickstart, streaming, approvals, retry, and
  async usage.
- GitHub Actions CI matrix (`.github/workflows/test.yml`) running tests on Ruby 3.1+.

### Documented divergences from the Python SDK
- The JSON-RPC error attribute is `#rpc_message` rather than `#message`, because
  `StandardError#message` already exists on Ruby exceptions.
- `OpenAI::Codex::Thread` is an alias for `OpenAI::Codex::ConversationThread` to avoid
  shadowing the stdlib `::Thread` class.
- The initialize handshake is exposed as `AppServerClient#initialize_app_server`
  because `#initialize` is reserved for object construction in Ruby.

[0.131.0a4]: https://github.com/openai/codex/releases/tag/rust-v0.131.0-alpha.4
