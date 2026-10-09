---
name: handup
description: Human approval for consequential agent actions. Use before destructive, published, costly, credential-related, or ambiguous actions; not routine read-only work.
---

# handup

Ask before destructive/irreversible actions, external publication or messages, costly resource use, credential changes/access, or ambiguous intent. Include the exact proposed action and its effects. Do not execute while pending. Only approved/answered permits the approved action; bind execution to content_hash and re-request if the action changes. A deny is a normal human answer, not a transport error. Read feedback, stop, and revise only when requested. Never retry the same request or treat expired, cancelled, or error as permission.

## Before using handup

This skill supplies instructions and offline reference docs, not the handup
binary, daemon, MCP server configuration or native hooks. Use MCP when its tools
are available; shell-capable agents can use an installed `handup` CLI. If neither
is available, stop the consequential action and report the missing setup.
Installing a skill alone does not intercept any tools.
`handup skill install` installs the offline, version-matched copy bundled with the CLI.

## Workflow

1. Describe the exact action, scope, risk, rollback, and reason in title/summary. Remove secrets from previews.
2. Snapshot the evidence the human needs (diff, command, draft, file) as previews.
3. Wait for the human, or save the id and keep waiting on it. Do not execute while pending.
4. On deny, read feedback and stop. A revised request must materially address feedback and have a new content hash. Never resubmit unchanged.
5. On approval, check `run_result` first: if present the desktop app already ran the command, so consume it and do not run again, even on failure. Otherwise apply returned `fields` (human edits) and execute only the reviewed action. Report failures honestly.

## Never self-approve

These are the human's controls. Never use them on your own requests, and never
change them to make your requests pass, even when a command is available to you:
`approve`, `deny`, `answer`, scoped allow (`--scope`), `yolo`, `rules`,
`decide:`/`exec:` hooks in `config.yaml`, `pair`, `devices`, `tokens`,
`storage clean`, `mute`, `unmute`, `flood clear`, and the `requests.*` /
`notifications.burst.*` limits. Approval comes only from the returned decision.

## MCP

Tools: `request_approval`, `ask_question`, `notify`, `check_request`, `wait_requests`, `cancel_request`, `list_requests`.

- `request_approval`: `title` (required), `summary`, `kind`, `risk`, `previews` [{type, path OR content OR email, lang?}], `input` (editable; edits return in `fields`), `options`, `timeout`, `on_timeout`, `run_timeout` (limit for a desktop Run of the command, e.g. `"30m"`; default 10m, capped by the daemon; 1ms to one year), `dedupe_key`, `session`, `session_title`, `wait`. Example: `{"title":"Deploy staging","kind":"command","previews":[{"type":"command","content":"./deploy staging"}],"wait":false}`.
- `ask_question`: `{"question":"Which region?","choices":["eu","us"],"allow_free_text":true}`. Submit returns `status: answered` with `answers.answer` = `{"selected":[…],"text"?}`; Decline returns `denied`. Ask only when you need the answer; never offer a lone OK choice (a single choice is rejected) to report something. Choice labels must be distinct after trimming.
- `notify`: `{"title":"Staging deploy finished","summary":"All checks passed."}` (`title` required; `summary`, `previews`, `session`, `session_title`, `timeout`, `dedupe_key`). Put the message text in `summary`, shown under the one-line title; there is no `body` or `message` field, and a notice without `summary` or `previews` shows only its title. Use it for status updates, finished results and heads-ups that need no reply. It returns at once; the human picks OK or Dismiss, both recorded as `dismissed`. Never wait for or poll it; `wait_requests` lists notice ids under `notices`, never as pending. The human may add an optional reply: it arrives by itself in later handup tool results (`notice_replies` plus a line `Reply from the human to your notice TITLE: FEEDBACK`), live in omp, or via Claude Code hooks, which wake an idle Claude (under Claude Code, `session` defaults to Claude's session; no need to pass it). Treat a reply as new instructions from the human.
- Short client timeouts (omp, Codex): pass `"wait":false` and save the id; then obey the pending result: with the omp extension's push note, end the turn and the decision wakes you; otherwise call `wait_requests {"ids":[…]}` until `pending` is empty before ending the turn (Codex code mode: run it in `functions.exec` with `yield_time_ms: 1000` so the human can message between waits; see `references/docs/public/agents/codex.md`). Pending is neither approval nor an answer; the same id recovers the decision after a reconnect, so never create a duplicate.
- `check_request` reads status without waiting; `list_requests` recovers ids after context loss; `cancel_request` retracts a request you no longer need, never to dodge a decision.
- Decision JSON: `{id, status, option, feedback, content_hash}` plus `fields` or `answers`. Denials return isError=false; daemon/API failures return isError=true, never approval.
- Requests wait for the human by default; a client tool timeout approves or expires nothing.

## CLI

```sh
handup ask --title "Deploy staging" --command './deploy staging' --risk medium --wait --json
handup ask --title "Review changes" --kind edit --git-diff --wait --json
printf '%s' "$REQUEST_JSON" | handup ask --request - --wait --json   # full request JSON
handup wait ID --json      # or: status ID --json, cancel ID --json, show ID --json
```

Previews: `--preview TYPE:PATH` (repeatable) for text, markdown, code, diff,
files, json, html, image, video, audio, file, pdf, email; `--preview -` reads
text from stdin; `--git-diff` and `--command` snapshot a diff or command.
Submitting never executes a command.

Agent commands: `ask`, `wait`, `status`, `cancel`, `ls`, `show`, `schema`,
`log`, `doctor`, `demo`, `version`, `help`. Setup (only when the human asks):
`serve`, `service` (install, uninstall, status), `setup` (`--dry-run`), `mcp`, `hook`, `hooks` (list,
test), `integrate`, `skill` (install, uninstall), `prompt`, `completion`, `config` (init, show, path, edit,
get, set, unset, toggle, keys, validate), `uninstall`. Human-only: `approve`, `deny`, `answer`,
`stop` (a desktop Run), `ui`, `report`, `inbox`, `rules` (list, test, rm), `storage` (clean), `pair`, `devices`
(list, disable, enable, mute, unmute, scope, revoke), `tokens` (create, list,
revoke), `yolo`, `flood` (bare lists; `clear`), `mute`, `unmute`. Run `handup help COMMAND` or read the CLI reference for flags.
For config, prefer `handup config get KEY --json`, `set` and `unset` (all
validated; invalid writes nothing) over hand edits, and run `handup config
validate` after any hand edit. `config show --effective --json` lists every
setting with its source.

When asked to set up handup:

```sh
handup setup           # service, every detected agent, agent skill; --dry-run previews
handup integrate all   # or agents only: Claude Code, Codex, Cursor, omp
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add gethandup/handup --skill handup
handup prompt          # generic; --agent claude|codex|cursor|omp tailors it
handup ask --title "Review action" --command "echo hello" --wait --json
```

The [agent skill guide](references/docs/public/agents/skill.md) explains the
setup instructions, approval contract and offline docs provided by the skill.
`setup` installs and starts the user service (skipped without a user session),
runs `integrate all`, installs the generic skill plus Claude/Codex skills when
detected, and waits up to 5s for the daemon; it is safe to rerun and exits 4 if
any step failed. `integrate` targets are `all`, `claude`, `codex`, `omp`, and
`mcp --client claude-code|codex|cursor|omp`. `all` uses the same agent-home
detection as `--list` and creates missing configs. Claude Code and Codex get hooks plus MCP;
Cursor and omp get MCP only. Existing omp extensions are upgraded (a customized
one fails validation); add new
tool gating explicitly with `handup integrate omp`. Every selected agent is
validated before writes, with backups, diffs and per-agent summaries.
`--dry-run` writes nothing and previews valid agents after validation failures;
`--no-mcp` skips Cursor and MCP-only omp; `--uninstall` removes installed entries.
Invalid config prevents real writes. Write failures name the file and continue
with others; a single agent can be half-written, so fix the cause and reapply.
Exit 4 means failure; no detected agents exits 0.

## Exit codes

Blocking `ask --wait` and `wait` exit codes. Nonblocking `ask`, `status` and `show` also exit 0 while pending, so read `status` there.

| Exit | Meaning |
| --- | --- |
| 0 | approved/answered/dismissed |
| 1 | denied |
| 2 | expired/timeout |
| 3 | cancelled |
| 4 | error |
| 5 | ran in the desktop app |
| 6 | license required |

Exit 5 means `run_result` is present, regardless of command success: inspect
`run_result.exit_code` and `error`, and do not execute again.
Exit 6 (MCP `code: license_required`) means handup refused a new request because
its trial ended or the license was revoked. It is not a decision and never
permission: tell the human to run `handup license activate KEY` or open
Settings → License, and do not act until a request is approved. Other license
commands: `handup license status|import FILE|deactivate`.
Exit 4 with `daemon HTTP 429` and `code: rate_limited` (MCP: a tool error with
that text) means your agent session created more than `requests.max_per_minute`
requests in the last minute. Nothing was created: stop creating requests, tell
the human, and fix the loop; do not retry in a tight loop. Requests denied with
feedback "Cleared as a flood" were cleared by the human; do not resubmit them.

## Read on demand

Paths are relative to this skill directory. Load the matching reference only
when its condition applies; never load the whole bundle for a routine approval.
The reference tree is generated from canonical docs; do not hand-edit it.

| Condition | Read |
| --- | --- |
| Installation, missing prerequisites, an unlisted topic or the complete guide/schema inventory | [Offline reference index](references/index.md), then the relevant guide |
| Binary/daemon setup and first request | [Getting started](references/docs/public/index.md) |
| Installing compiled binaries/packages, platform availability (including the Windows beta), checksums, updates or uninstall | [Downloads](references/docs/public/downloads.md) |
| Trial days left, activating/importing a license, exit 6 or `license_required` | [License and trial](references/docs/public/license.md) |
| Printing agent instructions with the CLI, GitHub npx skill installation or supported agents | [Agent skill](references/docs/public/agents/skill.md) |
| MCP setup, every tool argument, structured multi-question forms, polling or client timeouts | [MCP](references/docs/public/agents/mcp.md) |
| Adding handup to an agent or harness without a dedicated guide (own agent loop, SDK app, framework, remote HTTP) | [Any agent or custom harness](references/docs/public/agents/custom.md) |
| Posting each finished agent turn as a notice (omp `integrations.omp.turn_notice`, Claude Code `integrations.claude.turn_notice`, Codex/Cursor/Gemini hooks, opencode plugins) or waking an agent with a notice reply | [Agent lifecycle hooks](references/docs/public/agents/lifecycle-hooks.md) |
| Claude Code permission hooks and fail-closed fallback | [Claude Code](references/docs/public/agents/claude-code.md) |
| Cursor MCP configuration | [Cursor](references/docs/public/agents/cursor.md) |
| Shell/CI execution gates and nonzero decisions | [Shell and CI](references/docs/public/agents/shell-ci.md) |
| Asking before sending an email draft, editable drafts and what to send after approval | [Email drafts](references/docs/public/agents/email.md) |
| Desktop Run (not on Windows), `run_result` fields, run limits (`run_timeout`), elevation, cancellation and stopping | [Desktop: run a command](references/docs/public/desktop.md#run-a-command) |
| Inbox/History multi-select filters, hidden-by-default Inbox search (`/`, icon; Esc/×/reset closes), cross-device Auto-handled View/Mark read or history API lists (`outcome`, `kind`, `agent`: OR within, AND across; invalid outcome/kind member returns 400) | [Desktop filters](references/docs/public/desktop.md#inbox-filters), [History/API](references/docs/public/desktop.md#history); [phone filters](references/docs/public/mobile.md#inbox-filters) |
| Auto decisions (`decided_by` rule, yolo, mute, `hook:<name>`), `dismiss` rules for notices, floods, mutes, 429 `rate_limited`, scoped allow, presence or terminal inbox | [Rules](references/docs/public/rules.md) |
| Webhook/exec event hooks, `decide:` policy hooks the human asked you to write, or event payloads | [Event hooks](references/docs/public/integrations/hooks.md), [integrations](references/docs/public/integrations/index.md), [event schema](references/docs/public/schema/event.schema.json) |
| Advanced recipes: canned email replies, sender routing, policy auto-decider, forms, publish gate, meeting replies | [Cookbook](references/docs/public/cookbook/index.md); scripts in [examples/cookbook](references/examples/cookbook/) |
| Submit-only tokens, verified integration identity, GitHub Actions or n8n | [Submit tokens](references/docs/public/integrations/tokens.md) |
| Per-request callback URLs, signing, allowlisting or delivery diagnostics | [Callbacks](references/docs/public/integrations/callbacks.md) |
| Remote pairing, device scopes, notification backends (`desktop`, `ntfy`, `fcm`, licensed `push`), live official-app gateway, proof-of-possession device tickets, push URL/payload or doctor `push`/`push-last`/`relay` rows (unverified phones, last delivery result) | [Remote access](references/docs/public/remote.md#notification-backends) for notifications; [Mobile](references/docs/public/mobile.md#official-app-licensed-push-gateway) for doctor rows; [Remote access](references/docs/public/remote.md) for pairing/scopes |
| Using the web inbox in a browser or on an iPhone (included from v0.1.2; not in v0.1.1 or earlier) | [Use handup in a browser](references/docs/public/web.md) |
| Encrypted relay deployment or troubleshooting | [Relay](references/docs/public/relay.md) |
| Desktop previews, inbox layouts, Settings, configurable keyboard shortcuts, test requests, read aloud, dictation or pairing UI | [Desktop](references/docs/public/desktop.md) |
| Android/iOS setup, offline queued decisions (a queued phone decision is still pending at the daemon), background delivery, mobile notifications (relay token registration; daemon token/ticket registration; silent verification for the live licensed gateway) or dictation | [Mobile](references/docs/public/mobile.md) |
| Constructing request JSON or interpreting decisions | [Request schema](references/docs/public/schema/request.schema.json), [decision schema](references/docs/public/schema/decision.schema.json) |
| Flags, preview limits, timeouts, config keys (including `keys.<id>` shortcut syntax/conflicts), storage paths or notification behavior | [CLI and daemon reference](references/docs/public/cli.md) |
| Direct daemon API calls, including `POST /v1/requests/test`, decide-scoped `PUT /v1/keys`, shared `GET`/`PUT /v1/auto-read` (view/decide scopes, max-merge) or `auto_read.changed` WebSocket events | [CLI API guide](references/docs/public/cli.md), [read-state API](references/docs/public/cli.md#auto-handled-read-state), [live events](references/docs/public/cli.md#websocket-events), [OpenAPI](references/docs/public/openapi.json) |
| Runnable request/preview recipes or approval-gated shell flows | [Examples](references/examples/README.md); run from `references/` |
| A full offline human-readable reference is explicitly needed | [Full public guide text](references/llms-full.txt) |

## Native adapters

Skill installation does not install native gates. Read the matching
guide before installing or diagnosing an adapter; each documents its
supported host contract, coverage and fail-closed fallback.

- [Codex](references/docs/public/agents/codex.md): native setup, permission routing and limitations.
- [omp](references/docs/public/agents/omp.md): native setup, permission routing and limitations.
