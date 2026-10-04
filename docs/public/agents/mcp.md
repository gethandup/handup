# MCP stdio

Run `handup mcp` in the project directory. MCP version 2025-11-25 is negotiated using rmcp. Initialize, send notifications/initialized, then tools/list or tools/call. No logs go to stdout.

MCP is the simplest way to use handup from any client, including [omp](omp.md): the model asks explicitly and no extension is needed. It does not intercept a client's built-in approval prompts; omp's native bridge extension that forwards those is optional.

MCP tools: `request_approval`, `ask_question`, `check_request`, `wait_requests`, `cancel_request`, `list_requests`.

- `request_approval`: title (required), summary, kind, risk, previews [{type, path OR content OR email, lang?}], input (editable object, returned edited in decision `fields`), options [{id,label,outcome,style?}], timeout (duration string or `"none"`), on_timeout (`deny`|`expire`|`approve`, timed requests only), dedupe_key (identical pending requests share one id), callback_url ([callbacks](../integrations/callbacks.md)), session, session_title, and wait (default true). Relative paths use the server cwd; files upload as immutable blobs. With a progressToken, blocking calls emit progress notifications every long-poll cycle.
- `ask_question`: question and allow_free_text (both required, even with choices), choices, session, session_title, wait. Example: {"question":"Which region?","choices":["eu","us"],"allow_free_text":true}. It creates a `kind: question` request with one question (id `answer`) and Submit/Decline options. Use `request_approval` with `kind: "question"` and `input.questions` for several questions, multi-select or a timeout.
- `check_request` {"id"}: current decision JSON without waiting.
- `wait_requests` {"ids":[…], "max_wait_seconds"?}: returns every decided request among ids at once, otherwise long-polls until the first decision or `max_wait_seconds` (default 25, max 300, within omp's 30s and Codex's 60s tool timeouts). Result: `{"decided":[decision JSON], "pending":[ids], "message"}`. Act on each decision and call it again with the pending ids until none remain, before ending the turn: without a shell, answers reach the agent only this way.
- `cancel_request` {"id"}: retract a pending request you no longer need (plan changed, task abandoned). Never cancel to dodge a decision. Cancelling a request that is no longer pending is an error.
- `list_requests` {"status"?, "session"?, "agent"?, "limit"? (default 20, max 200)}: compact rows `{id,status,title,kind,risk,created_at,…}` to recover your own ids after context loss; pass your session id.

Decision JSON (MCP shape): `{id, status, option, feedback, content_hash}` plus `fields` (approvals; edited input) or `answers` (questions: `answers.answer` = `{"selected":["eu"],"text":"…"}`, `text` only when typed). It omits `expires_at` and other request fields; use `handup status ID --json` for the full request. Denials and declines return `status: denied` with optional feedback, isError=false. Blocking calls (`wait` true) stop after 300s and return `status: pending` with the id: pending is neither approval nor an answer. With wait=false save the id and call wait_requests until it is decided; the same id recovers the decision after an MCP reconnect, so never create a duplicate request when a client stops waiting.
Email drafts use `{"type":"email","email":{…}}` previews plus `input` {to,cc,bcc,subject,body}; see [email drafts](email.md).
Example: {"title":"Deploy staging","kind":"command","previews":[{"type":"command","content":"./deploy staging"}],"wait":false}.

## Desktop Run results

For command requests, the human may choose **Run** or **Run as admin** in the
local desktop app. The resulting decision has `status: "approved"` and a
top-level `run_result` in MCP responses, including `request_approval`,
`check_request` and each decided entry from `wait_requests`. CLI wait JSON
also returns it at the top level; HTTP and CLI status JSON nest it under
`decision.run_result`.

| `run_result` field | Meaning |
| --- | --- |
| `exit_code` | Command exit status, or absent/null when it never started or a signal ended it |
| `stdout_tail`, `stderr_tail` | Redacted last bytes of each stream, at most 64 KiB each |
| `duration_ms` | Wall time in milliseconds |
| `truncated` | Earlier output was dropped from either tail |
| `elevated` | Execution used pkexec (Linux) or osascript's administrator prompt (macOS) |
| `error` | Optional launch/authentication failure, timeout, cancellation or signal explanation |

A completed run returns an **approve outcome regardless of exit code or error**:
approval here means the human chose execution, not that it succeeded.
If nothing starts (including administrator authentication refusal), the claim
is released and the request stays pending; agent cancellation instead leaves
it cancelled. A result that cannot be submitted is reported in the desktop.
Inspect `exit_code` and `error`, consume the returned output and **do not run
the command again**, even if it failed. Ordinary approval without `run_result`
still permits the agent to execute the reviewed action. Native permission
hooks deny/block the original tool call with a run summary and appended human
feedback when a result is present, preventing a second execution; that block
is not a human denial. CLI `ask --wait`, `wait`, `status` and `show` return
**exit 5** for decisions carrying a result, not the command's own exit code.
Phones, browsers and the relay never execute commands; paired devices cannot
submit a result. See [Desktop](../desktop.md#run-a-command) for Run, Cancel,
the 10-minute execution timeout and administrator setup.


The MCP initialize `clientInfo.name` supplies `source.agent` (fallback `mcp`);
this is self-declared identity, not a verified `source.integration` marker.
If the client advertises roots, handup uses the first local `file://` root for
`source.cwd`, decoding escaped paths. A roots error, no usable root, or a response
taking more than 500 ms falls back to the server process directory. Preview paths
remain relative to the server process directory.

Both `request_approval` and `ask_question` accept optional `session` (stable ID)
and `session_title` (display name). Automatically pass your current ID and title
when known. The UI displays the title, falling back to the ID; session-scoped
allow rules still use only the ID. An absent title is omitted from request JSON.

Requests wait for the human by default: `requests.default_timeout` is `none`.
Omit `timeout` to use that configuration, or pass `"none"` to disable a configured
deadline. An explicit duration (for example `"10m"`) opts into expiry; `on_timeout`
defaults to `deny` for timed requests. `wait` controls tool waiting, not request
expiry. A client tool timeout does not approve or expire the pending request.

Ask before destructive/irreversible actions, external publication or messages, costly resource use, credential changes/access, or ambiguous intent. Include the exact proposed action and its effects. Do not execute while pending. Only approved/answered permits the approved action; bind execution to content_hash and re-request if the action changes. A deny is a normal human answer, not a transport error. Read feedback, stop, and revise only when requested. Never retry the same request or treat expired, cancelled, or error as permission.

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"inspector","version":"1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"request_approval","arguments":{"title":"Review deploy","wait":false}}}
```

Tool cancellation stops waiting but preserves the pending request; use wait_requests to resume, or cancel_request to retract it. Daemon/API failures return isError=true, never approval. MCP path previews cannot read stdin. For content use UTF-8 text; use path for binary media.

Sources: https://modelcontextprotocol.io/specification/2025-11-25/server/tools and https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/progress
