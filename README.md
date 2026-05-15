# OpenAI Codex Ruby SDK

Ruby SDK for `codex app-server` JSON-RPC v2 over stdio.

The protocol model layer is loaded from the upstream Codex app-server v2 JSON
Schema bundle. Runtime values are represented by schema-backed model objects
with Ruby `snake_case` accessors and `camelCase` wire serialization.

## Install

```ruby
gem "openai-codex-rb"
```

The Ruby package does not bundle the Codex runtime binary. Use an installed
`codex` on `PATH`, set `OPENAI_CODEX_BIN`, or pass
`AppServerConfig.new(codex_bin: "...")`.

## Quickstart (sync)

```ruby
require "openai/codex"

OpenAI::Codex.open do |codex|
  thread = codex.thread_start(model: "gpt-5")
  result = thread.run("Say hello in one sentence.")
  puts result.final_response
end
```

## Quickstart (async)

```ruby
require "openai/codex"

OpenAI::Codex::AsyncCodex.open do |codex|
  thread = codex.thread_start(model: "gpt-5").value!
  result = thread.run("Say hello in one sentence.").value!
  puts result.final_response
end
```

`AsyncCodex` mirrors the Python `AsyncCodex` SDK: every method returns an
`OpenAI::Codex::Future` whose `#value!` blocks until the wrapped worker thread
completes. The SDK does not bind to a specific concurrency runtime—plug into
Fibers, the `async` gem, or your own thread pool by composing futures.

## Protocol coverage

`OpenAI::Codex::Types` defines schema-backed classes for every definition in
the upstream `codex_app_server_protocol.v2.schemas.json` bundle. Low-level
`AppServerClient#request` uses the generated method manifest to coerce known
responses automatically; high-level helpers mirror the Python SDK's ergonomic
thread, turn, model, notification, and run-result surface.

- 106 RPC methods (`data/protocol_methods.json`)
- 64 server notifications (`data/protocol_notifications.json`)
- 204 v2 JSON schemas mirrored under `data/schemas/json/v2/`
- ~580 runtime-generated Ruby type constants

## Examples

| Example | What it shows |
|---|---|
| [`examples/01_quickstart.rb`](examples/01_quickstart.rb) | start → run → final response |
| [`examples/02_streaming.rb`](examples/02_streaming.rb) | iterate `agentMessage/delta` events live |
| [`examples/03_async.rb`](examples/03_async.rb) | `AsyncCodex` with `Future#value!` |
| [`examples/04_approval_handler.rb`](examples/04_approval_handler.rb) | gate command / file-change approvals |
| [`examples/05_error_handling_and_retry.rb`](examples/05_error_handling_and_retry.rb) | `request_with_retry_on_overload` + error taxonomy |
| [`examples/06_thread_lifecycle.rb`](examples/06_thread_lifecycle.rb) | list / fork / rename / archive |

## Approval policy

The default approval handler **accepts** every `item/commandExecution/requestApproval`
and `item/fileChange/requestApproval` request, matching the Python SDK default.
Production callers should construct `AppServerClient` with their own
`approval_handler:`—see `examples/04_approval_handler.rb`.

Top-level approval defaults can also be passed on `thread_start` /
`thread_resume` / `thread_fork` via `approval_mode:`:

| Ruby constant | Wire effect |
|---|---|
| `OpenAI::Codex::ApprovalMode::AUTO_REVIEW` *(default)* | `approvalPolicy: "on-request"`, `approvalsReviewer: "auto_review"` |
| `OpenAI::Codex::ApprovalMode::DENY_ALL` | `approvalPolicy: "never"`, `approvalsReviewer: null` |

## Retry helper

`OpenAI::Codex::Retry.retry_on_overload` wraps a block with exponential
backoff that fires only for transient overload-class errors. The
`AppServerClient#request_with_retry_on_overload` helper does the same for a
single typed RPC call. Permanent failures (`InvalidParamsError`,
`MethodNotFoundError`, ...) propagate immediately.

## Errors

All RPC errors live under `OpenAI::Codex` and inherit from `AppServerError`:

| Class | When it is raised |
|---|---|
| `JsonRpcError` | generic JSON-RPC error wrapper |
| `AppServerRpcError` | server-defined `-32099..-32000` error |
| `ParseError` (`-32700`) | malformed request payload |
| `InvalidRequestError` (`-32600`) | request envelope rejected |
| `MethodNotFoundError` (`-32601`) | unsupported RPC method |
| `InvalidParamsError` (`-32602`) | params failed validation |
| `InternalRpcError` (`-32603`) | server-side internal error |
| `ServerBusyError` | overload-classified `-32099..-32000` |
| `RetryLimitExceededError` | overload + "retry limit" / "too many failed attempts" |
| `TransportClosedError` | stdio pipe closed mid-flight |
| `ValidationError` | local schema validation rejected a wire payload |

`OpenAI::Codex::Errors.retryable_error?(err)` is the predicate the retry helper
uses internally.

## Documented divergences from the Python SDK

The Ruby surface is deliberately faithful to the Python `openai-codex` SDK with
a few unavoidable Ruby renamings:

| Python | Ruby | Why |
|---|---|---|
| `error.message` (RPC text) | `error.rpc_message` | `StandardError#message` is reserved by Ruby |
| `class Thread` | `OpenAI::Codex::ConversationThread` (aliased as `Thread`) | Avoid shadowing stdlib `::Thread` |
| `client.initialize()` | `client.initialize_app_server` | `#initialize` is the Ruby constructor |
| `class ApprovalMode(str, Enum)` | `module ApprovalMode` with `AUTO_REVIEW` / `DENY_ALL` consts | Ruby has no string-Enum class |
| `await fut` | `fut.value!` | Standard library has no `asyncio`; `Future#value!` waits |
| `request_with_retry_on_overload` | same name, same signature | exact parity |

## Development

```sh
bundle install
bundle exec rake test
```

The test suite is `minitest` driven and has no network dependency. Tests cover
lifecycle, transport routing, error taxonomy, retry policy, approval handlers,
streaming, type generation, public-API parity with Python, and the async
surface.

Regenerate protocol artifacts from a sibling `../codex/` checkout:

```sh
ruby script/sync_upstream.rb
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), and
[SECURITY.md](SECURITY.md).

## License

Apache-2.0 — see [LICENSE](LICENSE).
