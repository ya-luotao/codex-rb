# Contributing to openai-codex-rb

This Ruby SDK tracks the upstream OpenAI Codex app-server v2 protocol. Most changes
fall into two buckets: protocol regeneration and Ruby-side ergonomics.

## Development setup

```
bundle install
bundle exec rake test
```

Tests use minitest and have no network dependency. The schema fixture test will
auto-skip if the `../codex` upstream checkout is not present beside this repo.

## Protocol regeneration

When the upstream `openai/codex` repo gains new RPC methods, notifications, or
schema types, regenerate the local protocol artifacts:

```
ruby script/sync_upstream.rb
```

This rewrites `data/protocol_methods.json`, `data/protocol_notifications.json`,
and copies all schema JSON files into `data/schemas/`. It expects the upstream
checkout at `../codex` (relative to this repository root).

Run the test suite again to confirm nothing regresses; new schema definitions
become Ruby type constants automatically via `SchemaStore.define_types!`.

## API parity with the Python SDK

The public surface mirrors the Python SDK in `../codex/sdk/python/src/openai_codex`.
When changing public API:

1. Check the corresponding Python module for the canonical signature.
2. Apply Ruby naming conventions (snake_case kwargs, `?` predicates, etc.).
3. Document any unavoidable divergence in `CHANGELOG.md` under "Documented divergences".

## Testing conventions

- Use minitest assertions with descriptive snake_case method names.
- Inject fakes for the `AppServerClient` rather than spawning the real binary.
- New schema-touching tests should rely on `OpenAI::Codex::Types::*` rather than
  hand-rolled hashes when feasible.

## Releasing

1. Bump `VERSION` and `UPSTREAM_VERSION` in `lib/openai/codex/version.rb`.
2. Update `CHANGELOG.md`.
3. Run `bundle exec rake test`.
4. `gem build openai-codex-rb.gemspec`.
5. `gem push openai-codex-rb-<version>.gem`.
