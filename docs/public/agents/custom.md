# Any agent or custom harness

Use this guide to add handup to an agent or harness without a dedicated adapter
(your own agent loop, an SDK app, a framework, a CI job). Named clients have
shorter guides: [Claude Code](claude-code.md), [Codex](codex.md),
[Cursor](cursor.md), [omp](omp.md).

Your harness asks and waits for the human. Ordinary approval permits it to run
the reviewed action; desktop Run returns `run_result` instead, which the
harness must consume without executing the command again.

## 1. Install the binary and daemon

Install the compiled program from [downloads and releases](../downloads.md),
then start the daemon:

```sh
handup service install                 # user service; or: handup serve --foreground
handup doctor --json                   # daemon reachable, versions match
```

`handup ask` starts the daemon on demand unless `daemon.autostart` is false;
`wait`, `status` and MCP do not. A harness running in a container or on another
host needs the HTTP route in step 2.

## 2. Pick a transport

| Harness can | Use | Wait mechanism |
| --- | --- | --- |
| Speak MCP (stdio) | `handup mcp` | `request_approval` / `ask_question` with `wait`, or `wait:false` + `wait_requests` |
| Run shell commands | `handup` CLI | `ask --wait --json`, `wait ID --json`, exit codes |
| Only make HTTP calls | Daemon API (local) or remote listener with a [submit token](../integrations/tokens.md) | `GET /v1/requests/{id}/wait?timeout=60s` loop |
| Intercept its own tool calls | Any of the above from your permission hook | Map the decision to allow/deny; see the [Claude hook](claude-code.md) as a model |

Prefer MCP when the model itself decides what needs approval; prefer a hook in
the harness when every call to a tool must be gated regardless of the model.

**MCP.** Register a stdio server whose command is `handup mcp`, started in the
project directory. `handup integrate mcp --client claude-code|codex|cursor|omp`
writes the entry for known clients; for others add the equivalent of:

```json
{"mcpServers":{"handup":{"command":"handup","args":["mcp"]}}}
```

Tools: `request_approval`, `ask_question`, `notify`, `check_request`,
`wait_requests`, `cancel_request`, `list_requests`. Arguments and response
shapes: [MCP](mcp.md).

**CLI.** `handup ask --request - --wait --json < request.json` takes full request
JSON (`handup schema request`); flags cover common cases (`--title`, `--command`,
`--git-diff`, `--preview TYPE:PATH`). Queue commands emit JSON only with `--json`,
whatever `output_format` says. See [Shell and CI](shell-ci.md).

**HTTP.** Locally, the API listens on the Unix socket
(`$XDG_RUNTIME_DIR/handup/handup.sock`, no auth beyond file permissions) and on
`daemon.listen` (`127.0.0.1:7465`, bearer token from
`$XDG_STATE_HOME/handup/token`, loopback Host only). Remote harnesses use a named
submit token, which can create and read only its own requests. Routes:
[OpenAPI](../openapi.json).

```sh
curl --unix-socket "$XDG_RUNTIME_DIR/handup/handup.sock" \
  -H 'Content-Type: application/json' http://handup/v1/requests \
  -d '{"title":"Deploy staging","kind":"command","previews":[{"type":"command","content":"./deploy staging"}]}'
```

## 3. Build the request

Required: `title`. Describe the exact action, its scope, risk and rollback in
`title`/`summary`, and snapshot the evidence the human needs as previews
(command, diff, file, JSON, image, email, …). Strip secrets first: previews are
stored and shown on every paired device.

| Field | Use |
| --- | --- |
| `kind`, `risk` | `command`, `edit`, `review`, `question`, `info`, `custom`; `low`/`medium`/`high` drives notification urgency and rules |
| `source.agent`, `source.session`, `source.session_title`, `source.cwd` | Who is asking; self-declared, shown to the human and matched by rules |
| `input` | Editable object; the human's edits come back in `decision.fields` |
| `options` | Custom choices `{id,label,outcome}` (1–32); omit for Approve/Deny |
| `timeout`, `on_timeout` | Default is no deadline; a duration opts into expiry (`deny` by default) |
| `run_timeout` | Limit for a desktop [Run](../desktop.md#run-a-command) of the command (e.g. `30m`); default `run.timeout` (10m), capped at `run.max_timeout` (1h); 1ms to one year |
| `dedupe_key` | Identical pending requests with the same key collapse into one id |
| `callback_url` | Daemon POSTs the decision there ([callbacks](../integrations/callbacks.md)) |

Questions instead of approvals: MCP `ask_question`, or `kind: "question"` with
`input.questions` (see the [MCP guide](mcp.md)).

Information that needs no reply (status, finished results, heads-ups): MCP
`notify`, `handup ask --kind info`, or `kind: "info"`. A notice gets **OK** and
**Dismiss** options (both record `status: dismissed`), never takes `input`, and
is never decided by rules or YOLO. Put the message text in `summary` under a
one-line `title`; there is no body or message field.
Submit it and move on; do not wait for it, poll it, or ask a question with a
lone OK choice instead. The human may add an optional reply; it arrives on its
own (MCP: in later handup tool results; see [notice replies](mcp.md#notice-replies)).
Other clients claim replies with `POST /v1/notice-replies` `{"id"}` or
`{"session"}` (both may be given and must then match); each non-empty reply is
returned once, to the first caller.

## 4. Persist the id, then wait

Save the returned `id` before waiting, keyed to the action it gates. Tool and
shell timeouts kill waiters long before a human decides (omp bash: 300s, MCP
clients: 30–60s); a killed waiter is not an answer and the request stays
pending. Reattach with the same id:

- MCP: `wait_requests {"ids":[…]}` in a loop until `pending` is empty;
  `list_requests {"session":…, "status":"pending"}` recovers ids after context loss.
- CLI: `handup wait ID --json` (timeout disabled), or `handup status ID --json`.
- HTTP: `GET /v1/requests/{id}/wait?timeout=60s` until `status` is not `pending`.
  Local and paired-device clients can instead watch the `GET /v1/events` WebSocket.

Never create a second request because a wait timed out. Keep the agent turn
alive while answers you need are pending unless your client pushes decisions
(the omp extension marks watched ids with a `handup push active` note).

## 5. Gate execution on the decision

| Status | Meaning | Harness action |
| --- | --- | --- |
| `approved` | Human approved | If `run_result` is present, consume it and do not run again; otherwise run exactly the reviewed action with `decision.fields` edits applied |
| `answered` | Question submitted | Use `answers` (MCP) or `fields.answers` (CLI/HTTP decision) |
| `dismissed` | Human read an info notice | Nothing; a notice gates no action |
| `denied` | Human said no | Stop; show `decision.feedback`; revise only if feedback asks |
| `expired`, `cancelled` | No decision | Stop; not permission |
| `pending` | Undecided | Keep waiting; not permission |
| Any error | Transport/validation failure | Stop; fail closed |

Bind execution to `content_hash`: it covers the title, summary, kind, previews,
options, input and callback URL the human saw. If the action you are about to run
differs from the reviewed one, submit a new request instead of reusing the approval.
A denial is a normal answer (MCP `isError=false`, CLI exit 1); never resubmit it
unchanged.

Response shapes differ by transport:

- MCP: `{id,status,option,feedback,content_hash}` plus `fields` (approvals),
  `answers` (questions), or `run_result` (desktop execution).
- CLI `ask --wait --json` / `wait --json`: the decision object (`option`,
  `feedback`, `fields`, `content_hash`, `decided_by`, …) plus `id` and `status`;
  question answers are in `fields.answers`.
- HTTP and other CLI `--json` commands: the full request, decision under `decision`.

CLI `ask --wait`, `wait`, `status` and `show` return 0 approved/answered/dismissed,
1 denied, 2 expired, 3 cancelled, 4 error, or **5 ran in the desktop app**.
Nonblocking `ask`, `status` and `show` also exit 0 while pending, so read
`status` there.

Exit 5 means `run_result` is present, not that the command succeeded.
It can contain a nonzero `exit_code` or `error` while status remains approved.
Read the [result fields](mcp.md#desktop-run-results) and stop duplicate execution
even on failure. Permission hooks should block the intercepted call with the
run summary (including human feedback) rather than returning allow when a
result is present.

## 6. Clean up

Retract requests your harness no longer needs (plan changed, task aborted) with
MCP `cancel_request`, `handup cancel ID`, or `POST /v1/requests/{id}/cancel`.
Never cancel to dodge a pending decision you dislike.

## 7. Tell the model the policy

Add the approval contract to the agent's instructions so it asks before
destructive, published, costly, credential-related or ambiguous actions and
handles denials correctly:

```sh
handup prompt --agent generic >> AGENTS.md
```

The [agent skill](skill.md) bundles the same contract with offline docs for
skill-aware agents. A skill alone does not install handup or intercept tools.

## Checklist

- [ ] `handup doctor --json` passes where the harness runs
- [ ] Transport wired: MCP server entry, CLI on PATH, or HTTP endpoint + credential
- [ ] Request ids persisted before waiting; reattach path tested by killing a waiter
- [ ] Only `approved`/`answered` permits action; `run_result` prevents duplicate execution; edits from `decision.fields` applied
- [ ] Denial feedback reaches the model; no automatic retry
- [ ] Errors, timeouts and unknown statuses fail closed
- [ ] Approval policy present in the agent's instructions
- [ ] End-to-end test: approve once, deny once, and answer a question from `handup inbox`
