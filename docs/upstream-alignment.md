# Upstream Alignment

This Ruby SDK is aligned to the Codex app-server v2 SDK surface in the sibling
`codex/` checkout.

## Upstream Sources

- SDK implementation: `../codex/sdk/python/src/openai_codex/`
- SDK public tests: `../codex/sdk/python/tests/`
- Protocol schemas: `../codex/codex-rs/app-server-protocol/schema/json/`
- Protocol method definitions: `../codex/codex-rs/app-server-protocol/src/protocol/common.rs`
- Generated notification union: `../codex/codex-rs/app-server-protocol/schema/typescript/ServerNotification.ts`

## Local Artifacts

- Full aggregate v2 schema: `data/schemas/json/codex_app_server_protocol.v2.schemas.json`
- Root protocol schemas: `data/schemas/json/*.json`
- v2 protocol schemas: `data/schemas/json/v2/*.json`
- Generated method manifest: `data/protocol_methods.json`
- Generated notification manifest: `data/protocol_notifications.json`

Regenerate the local protocol artifacts with:

```bash
ruby script/sync_upstream.rb
```

## Parity Surface

The Ruby implementation follows the Python SDK in these areas:

- stdio JSON-RPC app-server transport
- initialize/initialized handshake
- schema-backed params, responses, and notifications
- method response coercion from the generated manifest
- notification typing with unknown-payload fallback
- turn-scoped notification routing and early-event buffering
- high-level thread lifecycle helpers
- turn streaming, steering, interrupt, and run-result collection
- approval-mode mapping for new and existing work
- overload-style JSON-RPC error mapping and retry helper

The package intentionally does not bundle a Codex runtime binary. Use `codex`
on `PATH`, `OPENAI_CODEX_BIN`, or `AppServerConfig.new(codex_bin: "...")`.
