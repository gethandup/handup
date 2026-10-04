---
name: handup
description: Human approval for consequential agent actions. Use before destructive, published, costly, credential-related, or ambiguous actions; not routine read-only work.
---

# handup

Ask before destructive/irreversible actions, external publication or messages, costly resource use, credential changes/access, or ambiguous intent. Include the exact proposed action and its effects. Do not execute while pending. Only approved/answered permits the approved action; bind execution to content_hash and re-request if the action changes. A deny is a normal human answer, not a transport error. Read feedback, stop, and revise only when requested. Never retry the same request or treat expired, cancelled, or error as permission.

## Before using handup

This skill supplies instructions and complete offline reference docs, not the
handup binary, daemon, MCP server configuration or native hooks. Use MCP only
when its tools are available; shell-capable agents can use an installed `handup`
CLI. If neither is available, stop the consequential action and report the
missing setup. Installing a skill alone does not intercept any tools.

## Read on demand

Paths below are relative to this installed skill directory. Load the matching
reference only when needed; do not load the entire bundle for a routine approval.

| Condition | Read |
| --- | --- |
| Installation, missing prerequisites, an unlisted topic or the complete guide/schema inventory | [Offline reference index](references/index.md), then the relevant guide |
| Binary/daemon setup and first request | [Getting started](references/docs/public/index.md) |
| GitHub/GitLab npx installation, supported agents or bundle regeneration | [Skill installation](references/docs/public/agents/skill.md) |
| MCP setup, tool arguments, polling or client timeouts | [MCP](references/docs/public/agents/mcp.md) |
| Adding handup to an agent or harness without a dedicated guide (own agent loop, SDK app, framework, remote HTTP) | [Any agent or custom harness](references/docs/public/agents/custom.md) |
| Claude Code permission hooks and fail-closed fallback | [Claude Code](references/docs/public/agents/claude-code.md) |
| Cursor MCP configuration | [Cursor](references/docs/public/agents/cursor.md) |
| Shell/CI execution gates and nonzero decisions | [Shell and CI](references/docs/public/agents/shell-ci.md) |
| Asking before sending an email draft, editable drafts and what to send after approval | [Email drafts](references/docs/public/agents/email.md) |
| Scoped rules, presence, YOLO or terminal inbox | [Rules](references/docs/public/rules.md) |
| Webhook/exec integrations or event payloads | [Integrations](references/docs/public/integrations/index.md), [event hooks](references/docs/public/integrations/hooks.md), [event schema](references/docs/public/schema/event.schema.json) |
| Submit-only tokens, verified integration identity, GitHub Actions or n8n | [Submit tokens](references/docs/public/integrations/tokens.md) |
| Per-request callback URLs, signing, allowlisting or delivery diagnostics | [Callbacks](references/docs/public/integrations/callbacks.md) |
| Remote pairing, device scopes or notifications | [Remote access](references/docs/public/remote.md) |
| Encrypted relay deployment or troubleshooting | [Relay](references/docs/public/relay.md) |
| Desktop previews, inbox layouts (Split, Stacked, Focus, Rail), pane resizing, grouped Settings, test requests/questions, searchable read-aloud voices or pairing UI | [Desktop](references/docs/public/desktop.md) |
| Android/iOS setup, grouped Settings, per-computer tests, voice search and Android read aloud (system default TTS engine), offline queued decisions, background delivery limits, biometric decisions or mobile notifications | [Mobile](references/docs/public/mobile.md) |
| Constructing request JSON or interpreting decisions | [Request schema](references/docs/public/schema/request.schema.json), [decision schema](references/docs/public/schema/decision.schema.json) |
| Exit codes, preview limits, timeouts, config keys, storage paths or notification behavior | [CLI and daemon reference](references/docs/public/cli.md) |
| Direct daemon API calls, including `POST /v1/requests/test` (remote `decide` only, never `view`/`submit`) | [CLI API guide](references/docs/public/cli.md#test-requests), [OpenAPI](references/docs/public/openapi.json) |
| Runnable request/preview recipes or approval-gated shell flows | [Examples](references/examples/README.md); run from `references/` |
| A full offline human-readable reference is explicitly needed | [Full public guide text](references/llms-full.txt) |

For Codex and omp native setup or limitations, read the matching guide under
**Native adapters** below. The reference tree is generated from canonical user
docs; do not hand-edit bundled copies.

Android can deliver durable queued decisions while the app is backgrounded;
its sending notification is not an approval result. A phone decision still
waiting to send is pending at the daemon. Keep waiting on the same request id
and act only on its returned approved/answered decision. For service limits,
force-stop behavior and high-risk confirmation, read the Mobile guide.

## Workflow

1. Describe the exact action, scope, risk, rollback, and reason in title/summary. Remove secrets from previews.
2. Snapshot relevant evidence; use the recipes below. Start with MCP or the shell command.
3. Wait for the human, or save the id and poll. Do not execute while pending.
4. On deny, read feedback and stop. A revised request must materially address feedback and have a new content hash. Never resubmit unchanged.
5. On approval, check `run_result` first: consume it and do not run again, even on failure. Otherwise apply returned fields and execute only the reviewed action. Report failures honestly.

## MCP

MCP tools: `request_approval`, `ask_question`, `check_request`, `wait_requests`, `cancel_request`, `list_requests`.
`request_approval` accepts title (required), summary, kind, risk, previews [{type, path OR content OR email, lang?}], input (editable object; edits return in `fields`), options [{id,label,outcome,style?}], timeout (duration or `"none"`), on_timeout (`deny`|`expire`|`approve`), dedupe_key, callback_url, session, session_title, and wait (default true). Relative paths use server cwd; files upload as immutable blobs. Pass your session id and title when known.
Example: {"title":"Deploy staging","kind":"command","previews":[{"type":"command","content":"./deploy staging"}],"wait":false}.
MCP decision JSON: `{id, status, option, feedback, content_hash}` plus `fields` (approvals) or `answers` (questions); it has no `expires_at`. Denials return isError=false; daemon/API failures return isError=true, never approval.

Desktop Run adds `run_result` = `{exit_code?, stdout_tail, stderr_tail,
duration_ms, truncated, elevated, error?}` to approval decisions. Output tails
are redacted and capped at 64 KiB each; `exit_code` may be null/absent for launch
failure or signal exit. A reported run is **approved regardless of exit or error**.
If nothing starts, the claim is released and the request stays pending; agent
cancellation leaves it cancelled.
Consume the result and **do not run again**, even on failure. Hooks deny/block
the original tool call with the run summary to prevent duplicate execution,
not to reverse approval. Without a result, execute only the reviewed action.
Run is desktop-only; phone/web/relay never execute or submit results.
While running, the request stays pending with `run` metadata and phone/web show
Running. Other decisions return 409 `running in the desktop app`; agent cancel
stops the run. Expiry is paused during the 12-minute claim lease. See
[Desktop](references/docs/public/desktop.md#run-a-command) for elevation/cancellation limits.
Short client timeouts (omp 30s, Codex 60s): pass `"wait":false`, save the id, then call `wait_requests` {"ids":[…], "max_wait_seconds"?} (default 25, max 300) until `pending` is empty, before ending the turn. Result: `{"decided":[decision JSON], "pending":[ids], "message"}`. Blocking calls stop after 300s with `status: pending`. Pending is neither approval nor an answer; the same id recovers the decision after a reconnect, so never create a duplicate. `check_request` {"id"} reads status without waiting; `list_requests` {"status"?, "session"?, "agent"?, "limit"?} recovers ids after context loss; `cancel_request` {"id"} retracts a request you no longer need, never to dodge a decision.
Requests wait for the human by default (`requests.default_timeout: none`); an explicit timeout opts into expiry and `on_timeout` (default deny) applies only then. A client tool timeout does not approve or expire anything.
`ask_question`: {"question":"Which region?","choices":["eu","us"],"allow_free_text":true}; `question` and `allow_free_text` are required. It creates a `kind: question` request with one question (id `answer`) and Submit/Decline options. Submit returns `status: answered` and `answers.answer` = `{"selected":["eu"],"text":"…"}` (`text` only when typed). Decline returns `status: denied` with optional feedback and no answers. It accepts `wait`, `session` and `session_title` like `request_approval`.
Structured questions (`handup ask --request -`): `kind: "question"`, `input.questions` = 1–10 of {id, question, header?, multi?, recommended? (option index), allow_free_text?, options: [{label, description?, preview? (markdown)}]}, plus options with one `approve` (Submit) and one `deny` (Decline). Submit returns `decision.fields.answers` = {QID: {selected: [labels], text?}}; every question is answered, single-choice questions select at most one label, and `text` appears only where free text is allowed.

## Commands

| Command | Agent use |
| --- | --- |
| `ask` | Submit: `handup ask --title 'Deploy staging' --command './deploy staging' --wait --json`; full JSON: `handup ask --request - --wait --json` |
| `wait` | `handup wait ID --json` blocks until terminal status; desktop execution returns top-level `run_result` |
| `status` | `handup status ID --json` checks current status; desktop execution returns `decision.run_result` |
| `cancel` | `handup cancel ID --json` cancels pending work |
| `ls` | `handup ls --status pending --session ID --json` lists queue (`--agent`, `--limit`) |
| `show` | `handup show ID --json` shows immutable previews |
| `approve` | Human: `handup approve ID --json` |
| `deny` | Human: `handup deny ID -m 'Use staging' --json` |
| `answer` | Human: `handup answer ID --select eu --text 'eu-west-1' --json`; several questions: `--select QID=LABEL`, `--text QID=TEXT` |
| `schema` | `handup schema request`, `decision`, `event`, or `openapi` |
| `serve` | `handup serve --foreground` starts daemon |
| `service` | `handup service install`, `uninstall`, or `status` (`--dry-run`) |
| `demo` | `handup demo --json` seeds preview examples |
| `doctor` | `handup doctor --json` diagnoses local environment |
| `ui` | Human: `handup ui --next` opens or focuses the desktop app |
| `inbox` | Human: `handup inbox` live terminal queue, requires TTY |
| `rules` | Human: `handup rules list`, `test request.json` (or ID), `rm RULE_ID` |
| `log` | `handup log --json` tails the append-only audit with rule IDs |
| `pair` | Human only: `handup pair --scope decide` prints a one-time QR pairing link for a phone or browser (needs `remote.mode`); agents never pair devices |
| `devices` | Human only: `handup devices list [--json]` shows enabled, push and scope; `handup devices disable DEVICE_ID` / `enable DEVICE_ID` pauses/resumes access and push without unpairing; `handup devices mute DEVICE_ID` / `unmute DEVICE_ID` stops/resumes push only; `handup devices scope DEVICE_ID view|decide` changes access; `handup devices revoke DEVICE_ID` unpairs immediately |
| `tokens` | Human only: `handup tokens create NAME [--expires 90d]`, `tokens list`, `tokens revoke NAME`. Submit credentials create and access only their own requests; never decide. See [submit tokens](references/docs/public/integrations/tokens.md) |
| `yolo` | Human only: `handup yolo on --for 1h` auto-approves new low/medium-risk requests (`hard`: every risk; `off`); bare `handup yolo --json` prints `{mode, until}`. Agents never turn it on |
| `mcp` | `handup mcp` serves stdio; stdout is protocol only |
| `hook` | `handup hook claude` reads PermissionRequest JSON |
| `integrate` | `handup integrate mcp --client codex --dry-run`; `handup integrate claude`; `handup integrate --list`; `--uninstall` removes only handup entries |
| `prompt` | `handup prompt --agent generic` prints project instructions |
| `version` | `handup version --plain` reports version |
| `completion` | `handup completion bash` generates completions |
| `config` | `handup config init`, `show`, `path`, `edit`, `get`, `set`, `toggle`, `keys` |
| `uninstall` | `handup uninstall --yes` removes binary, preserves config |
| `help` | `handup help COMMAND` explains parameters |

## Preview recipes

| Preview | Recipe |
| --- | --- |
| text | `--preview text:notes.txt` or `--preview -` |
| markdown | `--preview markdown:plan.md` |
| code | `--preview code:src/main.rs` (directory bundles supported) |
| diff | `--git-diff` or `--preview diff:change.diff` |
| files | `--preview files:output/` snapshots a directory; symlinks inside it are rejected |
| command | `--command './deploy staging'` snapshots the command; submission does not execute it, but desktop Run can |
| json | `--preview json:payload.json` requires valid JSON |
| html | `--preview html:mockup/` bundles assets; include index.html; bundle is represented as files + entry |
| image | `--preview image:mockup.png` |
| video | `--preview video:demo.mp4` |
| audio | `--preview audio:voiceover.wav` |
| file | `--preview file:artifact.zip` |
| pdf | `--preview pdf:contract.pdf` |
| email | `--preview email:draft.json` previews a draft and makes it the editable `input`; read [email drafts](references/docs/public/agents/email.md) |

## Exit codes

Blocking `ask --wait` and `wait` exit codes. Nonblocking `ask`, `status` and `show` also exit 0 while pending, so read `status` there.

| Exit | Meaning |
| --- | --- |
| 0 | approved/answered |
| 1 | denied |
| 2 | expired/timeout |
| 3 | cancelled |
| 4 | error |
| 5 | ran in the desktop app |

`ask --wait`, `wait`, `status` and `show` exit 5 when `run_result` is present,
regardless of command success. Inspect `run_result.exit_code` and `error`; do
not execute again. Text `wait` prints the run summary, output tails and human
feedback; text `status` does not—use `status --json`.

## Shell examples

```sh
handup ask --title "Review changes" --kind edit --git-diff --wait --json
handup ask --title "Publish voiceover" --preview audio:voiceover.wav --risk medium --wait --json
```

For a client's configuration or timeout behavior, read its bundled guide above.
For full request JSON, read the bundled request schema or `handup schema request`.

## Rules and scoped allow

Read [rules](references/docs/public/rules.md) when inspecting auto decisions, presence routing, or terminal triage. Humans may grant `handup approve ID --scope session|project|always`; agents must never grant themselves broader approval. Rules use first-match precedence and invalid files fail closed. Auto decisions carry `decided_by: rule` and `rule_id` (or `decided_by: yolo` when the human turned on YOLO mode) in decision metadata and the append-only audit. `presence.mode: away` retains Claude's native prompt while present; defaults are always routing and `presence.idle_after: 2m`. Terminal inbox keys: j/k, a/d, 1–9, s/p, u held undo, / filter, ? help, q quit.

## Event integrations

Top-level `hooks:` sends versioned lifecycle events to webhook receivers or exec
commands; it is not an approval bypass. Use `handup hooks list` to validate/list
configuration and `handup hooks test <name> --event request.decided` for synthetic
delivery. Content is excluded by default; signing secrets are env variable names.
See [event hooks](references/docs/public/integrations/hooks.md) for templates and recipes.

## Native adapters

Skill installation does not install native gates. Read the matching
guide before installing or diagnosing an adapter; each documents its
supported host contract, coverage and fail-closed fallback.

- [Codex](references/docs/public/agents/codex.md): native setup, permission routing and limitations.
- [omp](references/docs/public/agents/omp.md): native setup, permission routing and limitations.
