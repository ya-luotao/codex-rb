# Security Policy

This Ruby SDK exposes a stdio JSON-RPC client for a locally launched `codex`
app-server process. It does not open network sockets on its own; the runtime
binary is responsible for any outbound network activity.

## Reporting a Vulnerability

Please report security issues against the upstream Codex repository at
<https://github.com/openai/codex/security/advisories>. Coordinated disclosure
for SDK-specific issues (Ruby parsing/transport concerns) should also be filed
there; the repository owners will route them to this SDK.

## Threat Model Summary

- The SDK launches and communicates with a child `codex` process. Treat the
  binary path supplied via `AppServerConfig#codex_bin` or `OPENAI_CODEX_BIN` as
  trusted; do not point it at untrusted executables.
- JSON-RPC payloads from the child are parsed with the standard library `JSON`
  module and validated against the bundled JSON Schemas. Schema validation is
  best-effort against the upstream protocol; consumers should not rely on it as
  a security boundary against a hostile server.
- Approval requests (`item/commandExecution/requestApproval`,
  `item/fileChange/requestApproval`) default to **accept**. Callers that need to
  gate destructive actions must inject a custom `approval_handler` when
  constructing `AppServerClient` (see `examples/04_approval_handler.rb`).
