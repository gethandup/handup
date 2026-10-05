# MCP stdio

Run `handup mcp` in the project directory. It uses rmcp and supports MCP versions 2024-11-05, 2025-03-26, 2025-06-18, 2025-11-25 and 2026-07-28. Clients through 2025-11-25 initialize, receive their requested supported version, send notifications/initialized, then tools/list or tools/call. This includes Gemini CLI 0.62, which requests 2025-06-18. 2026-07-28 clients (Claude Code 2.1.285+) skip initialize: they may probe with server/discover and send the protocol version, clientInfo and client capabilities in each request's `_meta`. tools/list returns the cache hints `ttlMs: 0` and `cacheScope: "public"`. Tool results include text content blocks as well as structuredContent, so clients predating 2025-06-18 can still read them. No logs go to stdout.

MCP is the simplest way to use handup from any client, including [omp](omp.md): the model asks explicitly and no extension is needed. It does not intercept a client's built-in approval prompts; omp's native bridge extension that forwards those is optional.

## Client setup

Start with `handup integrate all --dry-run`, then `handup integrate all` to
configure every detected agent: hooks plus MCP for Claude Code and Codex,
MCP only for Cursor and omp. An existing omp extension is upgraded, but new
tool gating requires `handup integrate omp`. Detection uses agent homes,
just like `handup integrate --list`; missing configs are created.
All selected configs are validated before any writes. `--uninstall` removes
handup from every installed agent; `--no-mcp` installs hooks/extensions only
and skips Cursor and MCP-only omp. See [CLI integration](../cli.md#agent-integration) for
summaries and failure behavior. For MCP alone, use
`handup integrate mcp --client claude-code|codex|cursor|omp`.

See the dedicated guides for [Claude Code](claude-code.md), [Codex](codex.md),
[Cursor](cursor.md) and [omp](omp.md). Gemini CLI and opencode have also been
tested with `handup mcp`; configure them directly:

**Gemini CLI**

```sh
gemini mcp add -s user --trust handup handup mcp
```

This writes `mcpServers.handup` in `~/.gemini/settings.json` with
`{"command":"handup","args":["mcp"],"trust":true}`. Gemini starts stdio MCP
servers only in trusted folders; run it from a trusted project folder.

**opencode**

Add the following `handup` entry under `mcp` in
`~/.config/opencode/opencode.json`, preserving other configuration:

```json
{"mcp":{"handup":{"type":"local","command":["handup","mcp"],"enabled":true}}}
```

opencode exposes the tools with a server prefix, for example
`handup_list_requests`.

## Tools

MCP tools: `request_approval`, `ask_question`, `notify`, `check_request`, `wait_requests`, `cancel_request`, `list_requests`.

- `request_approval`: title (required), summary, kind, risk, previews [{type, path OR content OR email, lang?}], input (editable object, returned edited in decision `fields`), options [{id,label,outcome,style?}], timeout (duration string or `"none"`), on_timeout (`deny`|`expire`|`approve`, timed requests only), run_timeout (limit for a desktop Run of the command preview, e.g. `"30m"`; default `run.timeout`, capped at `run.max_timeout`; 1ms to one year; separate from `timeout`), dedupe_key (identical pending requests share one id), callback_url ([callbacks](../integrations/callbacks.md)), session, session_title, and wait (default true). Relative paths use the server cwd; files upload as immutable blobs. With a progressToken, blocking calls emit progress notifications every long-poll cycle.
- `ask_question`: question and allow_free_text (both required, even with choices), choices, session, session_title, wait. Example: {"question":"Which region?","choices":["eu","us"],"allow_free_text":true}. It creates a `kind: question` request with one question (id `answer`) and Submit/Decline options. Offer at least two distinct choices, free text with no choices, or both: a single choice is rejected even with free text, and labels must be distinct after trimming. Use `notify` for status or results and `request_approval` for permission. Use `request_approval` with `kind: "question"` and `input.questions` for several questions, multi-select or a timeout; the single-choice guard applies only to MCP `ask_question`, not these forms or omp's native question bridge.
- `notify`: title (required), summary, previews, session, session_title, timeout, dedupe_key. Put the message text in summary, shown under the one-line title; there is no body or message field, and a notice without summary or previews shows only its title. Tells the human something that needs no reply (status update, finished result, heads-up). It creates a `kind: info` notice and returns at once with `{id, status, message}`; never wait for or poll it. The human reads it and picks **OK** or **Dismiss** (status `dismissed` either way, `option` `ok` or `dismiss`), optionally with a reply; a timeout expires it. Rules and YOLO never decide notices. A reply reaches the agent by itself in later tool results ([notice replies](#notice-replies)). Example: {"title":"Staging deploy finished","summary":"All checks passed."}.
- `check_request` {"id"}: current decision JSON without waiting.
- `wait_requests` {"ids":[…], "max_wait_seconds"?}: returns every decided request among ids at once, otherwise long-polls until the first decision or `max_wait_seconds` (default 25, max 300, within omp's 30s and Codex's 60s tool timeouts). Result: `{"decided":[decision JSON], "pending":[ids], "message"}`, plus `notices` {ids, message} for undismissed info ids, which it never waits on or reports as pending. Act on each decision and obey the pending result: with the omp extension's push note, end the turn and the decision wakes you; otherwise call again with the pending ids until `pending` is empty before ending the turn.
- `cancel_request` {"id"}: retract a pending request you no longer need (plan changed, task abandoned). Never cancel to dodge a decision. Cancelling a request that is no longer pending is an error.
- `list_requests` {"status"?, "session"?, "agent"?, "limit"? (default 20, max 200)}: compact rows `{id,status,title,kind,risk,created_at,…}` to recover your own ids after context loss; pass your session id.

Decision JSON (MCP shape): `{id, status, option, feedback, content_hash}` plus `fields` (approvals; edited input) or `answers` (questions: `answers.answer` = `{"selected":["eu"],"text":"…"}`, `text` only when typed). It omits `expires_at` and other request fields; use `handup status ID --json` for the full request. Denials and declines return `status: denied` with optional feedback, isError=false. Blocking calls (`wait` true) stop after 300s and return `status: pending` with the id: pending is neither approval nor an answer. With wait=false save the id and follow the pending result's message to receive the decision; the same id recovers the decision after an MCP reconnect, so never create a duplicate request when a client stops waiting.
Email drafts use `{"type":"email","email":{…}}` previews plus `input` {to,cc,bcc,subject,body}; see [email drafts](email.md).
Example: {"title":"Deploy staging","kind":"command","previews":[{"type":"command","content":"./deploy staging"}],"wait":false}.

## Turn end

Server text is client-neutral: without a `handup push active` note, keep the turn open and call `wait_requests` with every pending id until none remain. The omp extension adds that trusted note only for ids it is actively watching, including pending ids in `wait_requests` results. End the turn for those ids: a `handup-decision` message wakes you, so do not also poll or start a background CLI waiter for them. Other pending ids still need waiting. After a restart or session switch, recover ids with `list_requests {"session":…, "status":"pending"}` and follow the result; installing MCP alone does not enable push.

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
| `error` | Optional launch/authentication failure or why it was stopped, with how: `cancelled`, `timed out`, `stopped from <device>` or `the request was cancelled while it ran`, then `; terminated` (ended on SIGTERM) or `; killed` (SIGKILL after 5 s) |

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
submit a result, but can ask the desktop to stop a run. See
[Desktop](../desktop.md#run-a-command) for Run, Cancel, the run limit
(`run_timeout`, default 10 minutes) and administrator setup.


The MCP initialize `clientInfo.name` (for 2026-07-28 clients, the
`io.modelcontextprotocol/clientInfo` name in request `_meta`) supplies
`source.agent` (fallback `mcp`); this is self-declared identity, not a verified
`source.integration` marker. If an initialized client advertises roots, handup
uses the first local `file://` root for `source.cwd`, decoding escaped paths. A
roots error, no usable root, a response taking more than 500 ms, or a 2026-07-28
client (no roots/list) falls back to the server process directory. Preview paths
remain relative to the server process directory.

`request_approval`, `ask_question` and `notify` accept optional `session` (stable ID)
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

When handup's trial has ended or its license was revoked, tools that create a
request return isError=true with `{"error":"license required: …","code":"license_required"}`.
That is not a decision: tell the human to activate a license (`handup license
activate KEY` or Settings → License) and do not act. `check_request`,
`wait_requests`, `cancel_request` and `list_requests` keep working on pending
requests. See [License](../license.md).

## Notice replies

A human may type an optional reply under a notice before choosing **OK** or
**Dismiss**. An empty reply stays silent. The `handup mcp` server remembers the
ids of notices it created and, once one is no longer pending, claims its reply;
it also claims replies for the session it last saw (a `session` argument, or the
session of a request named by `id`/`ids`). Unread replies are appended to the
result of every later handup tool call, whichever tool it is: structured content
gains `notice_replies` `[{id, title, feedback}]` and the text gains one line per
reply, `Reply from the human to your notice TITLE: FEEDBACK`. Each reply is
delivered once, to the first consumer (this server, the omp extension or a
Claude Code hook), so an agent never polls for it. Under Claude Code, requests
without a `session` argument default to `CLAUDE_CODE_SESSION_ID`, so its hooks
deliver replies and wake an idle Claude ([Claude Code](claude-code.md#notice-replies)).
Act on a reply as new instructions from the human.

Sources: https://modelcontextprotocol.io/specification/2025-11-25/server/tools and https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/progress
