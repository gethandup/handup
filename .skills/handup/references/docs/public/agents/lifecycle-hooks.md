# Agent lifecycle hooks (advanced)

Agent harnesses run hooks at lifecycle events such as "the turn finished". Wire
them to the installed `handup` CLI to get an info notice for every finished
turn, so you can read the result on any device and type a reply. This guide
covers the end-of-turn event of each harness, the field holding the final
message, and whether a later reply can wake the agent.

Everything here is opt-in. handup never sends turn-end notices by default:
omp's and Claude Code's built-in notices stay off until you turn them on, and
every other harness needs a hook you add yourself.

| Harness | End-of-turn event | Final-text field | Can a later reply wake it? |
| --- | --- | --- | --- |
| omp | built in (`session_stop`) | handled by the extension | Yes, through the extension |
| Claude Code | built in (`Stop`) | handled by `handup hook claude` | Yes, through the installed `asyncRewake` Stop hook |
| Codex | `Stop` (legacy: `notify`) | `last_assistant_message` (`last-assistant-message`) | No; only a synchronous Stop hook waiting within its timeout, or on the next prompt |
| Cursor | `stop`, after `afterAgentResponse` | `afterAgentResponse` `text` | No; only a synchronous `stop` hook returning `followup_message` |
| Gemini CLI | `AfterAgent` | `prompt_response` | No; only a synchronous hook, within its timeout |
| opencode | `session.idle` plugin event | none; read the messages through the SDK | Yes, while the server runs: the plugin sends `client.session.prompt` |

Harness contracts were checked against the vendor documentation on 2026-10-07
(sources at the end). Harnesses change these contracts; recheck them when you
upgrade.

## Rules for every hook

- Post with `handup ask --kind info` and never `--wait`: a notice needs no
  decision. Put the message in `--summary` under a one-line `--title`.
- Pass the harness's session id as `--session` and the harness name as
  `--agent`. Replies are routed by session.
- Hook stdout belongs to the harness (it may be parsed as JSON or shown to the
  model). Send handup's own output to `/dev/null`.
- The daemon must be running. If it is not, `handup ask` fails, the scripts
  below ignore it, and the agent carries on.
- A reply is claimed once, by the first consumer: the hooks below, the
  [MCP server](mcp.md#notice-replies), or your own `POST /v1/notice-replies`
  call with `{"session": "..."}` ([custom harness](custom.md)). Each returned
  item has `id`, `title` and `feedback`.

The scripts use POSIX `sh` and `jq`. Like omp, they title the notice with the
first non-empty line of the message without Markdown markers (at most 120
characters) and cut the summary at 16,000 characters.

## omp

Built in, no hook to write: install the native extension with
`handup integrate omp`, then:

```sh
handup config set integrations.omp.turn_notice true
```

Restart omp. Each finished interactive main-session turn becomes a notice, unless
the agent already asked handup something in that run; a typed reply wakes or steers
omp. Subagents, task sessions and headless runs such as `omp -p` post nothing.

It also skips the notice when kitty reports both this omp's terminal window and its tab focused at turn end (the active tab of the focused OS window). This requires `allow_remote_control yes` and `listen_on` configured in `kitty.conf`, with `KITTY_WINDOW_ID` and `KITTY_LISTEN_ON` set and `TMUX` unset; other terminals, SSH sessions, tmux, missing settings, disabled remote control, errors or a 2-second timeout still send the notice.
Details in [omp turn-end notices](omp.md#turn-end-notices).

## Claude Code

Built in, no hook to write: the Stop hook that `handup integrate claude`
installs (`handup hook claude`, `"asyncRewake": true`) posts the notice when you
turn it on:

```sh
handup config set integrations.claude.turn_notice true   # default false
```

The hook reads the setting at every Stop, so no restart is needed. It posts
Claude's final message (`last_assistant_message`; title from its first line,
summary cut at 16,000 characters) as a notice for the session, then waits for
replies as it always does: a typed reply wakes Claude even when idle, OK or
Dismiss does nothing ([notice replies](claude-code.md#notice-replies)). No
notice is posted when the message is empty or the session is already waiting
on a pending approval or question. Stop does not fire when you interrupt
Claude. Rerunning `handup integrate claude` keeps working: it is the same hook.

**Notification hook.** To hear when Claude waits on you, post a notice from the
`Notification` event. Its input adds `message`, an optional `title` and
`notification_type`; filter with the matcher, for example `idle_prompt` (about
60 seconds after a turn finishes) or `permission_prompt` (about six seconds
after Claude asks for permission; redundant when handup's PermissionRequest
hook already routes permissions). The hook only observes: it cannot answer the
prompt.

```sh
#!/bin/sh
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id')
title=$(printf '%s' "$input" | jq -r '.title // .notification_type')
handup ask --kind info --agent claude --session "$sid" --title "Claude: $title" \
  --summary "$(printf '%s' "$input" | jq -r '.message')" >/dev/null 2>&1
```

```json
{"hooks":{"Notification":[{"matcher":"idle_prompt","hooks":[{"type":"command","command":"/home/you/.claude/hooks/handup-notification.sh","timeout":30}]}]}}
```

`idle_prompt` and the Stop notice both report a finished turn; enable one.

## Codex

Add a Stop hook to `~/.codex/hooks.json` (or a trusted project's
`.codex/hooks.json`, or `[hooks]` in `config.toml`). Codex skips new or changed
hooks until you review and trust them in `/hooks`. Plain-text stdout from a
Stop hook is invalid, so the script prints nothing.

```sh
#!/bin/sh
input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.last_assistant_message // "" | .[0:16000]')
[ -n "$msg" ] || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id')
title=$(printf '%s' "$msg" | jq -Rrs 'split("\n") | map(gsub("^[\\s#>*_-]+|[\\s*_]+$"; "")) | map(select(length > 0)) | (first // "Codex finished") | .[0:120]')
handup ask --kind info --agent codex --session "$sid" \
  --title "$title" --summary "$msg" >/dev/null 2>&1
exit 0
```

```json
{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/home/you/.codex/hooks/handup-stop.sh","timeout":30}]}]}}
```

Treat it as notification-only. A background (`async`) hook cannot wake an idle
Codex. A reply continues Codex only if a synchronous Stop hook waits for it
within its timeout (in seconds, default 600) and returns
`{"decision":"block","reason":"..."}`, which blocks the turn end while it waits.
To read replies with your next prompt, add a `UserPromptSubmit` hook; its
plain-text stdout becomes developer context, not a user message:

```sh
#!/bin/sh
sid=$(jq -r '.session_id')
curl -sf --unix-socket "$XDG_RUNTIME_DIR/handup/handup.sock" \
  -H 'Content-Type: application/json' http://handup/v1/notice-replies \
  -d "$(jq -nc --arg s "$sid" '{session: $s}')" |
  jq -r '.[] | "Reply from the human to your notice \(.title): \(.feedback)"'
```

The legacy `notify` setting in `~/.codex/config.toml`
(`notify = ["/home/you/.codex/hooks/handup-notify.sh"]`) passes one JSON
argument, not stdin, with hyphenated fields: `type` (`agent-turn-complete`),
`thread-id`, `turn-id`, `cwd`, `input-messages` and `last-assistant-message`.
Read them with `printf '%s' "$1" | jq -r '."last-assistant-message"'`. It
cannot deliver replies.

## Cursor

Cursor's `stop` input has `status` (`completed`, `aborted` or `error`) but no
final text; `afterAgentResponse` carries it in `text`. Both share
`conversation_id`, which stays the same across turns, so post from
`afterAgentResponse`:

```sh
#!/bin/sh
input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.text // "" | .[0:16000]')
[ -n "$msg" ] || exit 0
sid=$(printf '%s' "$input" | jq -r '.conversation_id')
title=$(printf '%s' "$msg" | jq -Rrs 'split("\n") | map(gsub("^[\\s#>*_-]+|[\\s*_]+$"; "")) | map(select(length > 0)) | (first // "Cursor finished") | .[0:120]')
handup ask --kind info --agent cursor --session "$sid" \
  --title "$title" --summary "$msg" >/dev/null 2>&1
exit 0
```

```json
{"version":1,"hooks":{"afterAgentResponse":[{"command":".cursor/hooks/handup-response.sh"}]}}
```

Project hooks live in `.cursor/hooks.json` and run from the project root;
global hooks live in `~/.cursor/hooks.json`. A reply reaches Cursor only
synchronously: a `stop` hook that keeps running until a reply arrives (claim it
from `POST /v1/notice-replies` with `{"session": conversation_id}`) and prints
`{"followup_message":"..."}`, which Cursor submits as the next user message.
The handler's `timeout` is in seconds, and `loop_limit` (default 5) caps
automatic follow-ups. Once the hook returns, a later reply cannot wake Cursor.

## Gemini CLI

Add an `AfterAgent` hook to `.gemini/settings.json` (or
`~/.gemini/settings.json`). It fires once per turn after the final response,
with the text in `prompt_response`. Hook timeouts are in **milliseconds**
(default 60000).

```sh
#!/bin/sh
input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.prompt_response // "" | .[0:16000]')
[ -n "$msg" ] || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id')
title=$(printf '%s' "$msg" | jq -Rrs 'split("\n") | map(gsub("^[\\s#>*_-]+|[\\s*_]+$"; "")) | map(select(length > 0)) | (first // "Gemini finished") | .[0:120]')
handup ask --kind info --agent gemini --session "$sid" \
  --title "$title" --summary "$msg" >/dev/null 2>&1
exit 0
```

```json
{"hooks":{"AfterAgent":[{"hooks":[{"name":"handup-turn-end","type":"command","command":"$GEMINI_PROJECT_DIR/.gemini/hooks/handup-after-agent.sh","timeout":60000}]}]}}
```

All Gemini hooks run synchronously. A hook that waits for a reply within its
timeout can return `{"decision":"deny","reason":"..."}` to send the reply back
as a new prompt; there is no wake after the hook returns. These are Gemini CLI
contracts; Antigravity CLI was not checked.

## opencode

opencode has no shell hook: a plugin listens for `session.idle`, which carries
the session id but not the final text. For opencode V1, save as
`.opencode/plugins/handup-notice.js` (or in `~/.config/opencode/plugins/`):

```js
import { execFile } from "node:child_process";

export const HandupNotice = async ({ client }) => ({
  event: async ({ event }) => {
    if (event.type !== "session.idle") return;
    const id = event.properties.sessionID;
    const { data = [] } = await client.session.messages({ path: { id } });
    const last = data
      .filter((m) => m.info.role === "assistant" && m.info.time.completed)
      .sort((a, b) => b.info.time.completed - a.info.time.completed)[0];
    const text = (last?.parts ?? []).filter((p) => p.type === "text").map((p) => p.text).join("\n\n").trim();
    if (!text) return;
    const title = text.split("\n").map((l) => l.replace(/^[\s#>*_-]+|[\s*_]+$/g, "")).find(Boolean).slice(0, 120);
    execFile("handup", ["ask", "--kind", "info", "--agent", "opencode", "--session", id,
      "--title", title, "--summary", text.slice(0, 16000)], () => {});
  },
});
```

The plugin picks the latest completed assistant message by time because the
list order is not documented. To deliver a reply, the plugin can claim it from
`POST /v1/notice-replies` with `{"session": id}` and send it with
`client.session.prompt({ path: { id }, body: { parts: [{ type: "text", text: reply }] } })`,
which wakes the session. Do not pass `noReply: true`: it only adds context.

opencode V2 does not run V1 plugins:

- Import from `@opencode/plugin` and default-export
  `Plugin.define({ id, setup(ctx) { ... } })`; the config key is `plugins`,
  not `plugin`.
- Read events with `for await (const event of ctx.event.subscribe({ signal }))`;
  the idle event is still `session.idle`, but do not assume the V1
  `event.properties.sessionID` location.
- Read messages with `ctx.session.context({ sessionID })`: assistant messages
  have `type: "assistant"` and a `content` array instead of `info.role` and
  `parts`.
- Send a reply with `ctx.session.prompt({ sessionID, text: reply })`.
- The event stream does not replay missed events, and a slow consumer holds
  it up: queue events before waiting on a human.

## Sources

- Claude Code: https://code.claude.com/docs/en/hooks#stop,
  https://code.claude.com/docs/en/hooks#command-hook-fields,
  https://code.claude.com/docs/en/hooks#notification
- Codex: https://learn.chatgpt.com/docs/hooks#stop,
  https://learn.chatgpt.com/docs/hooks#run-hooks-in-the-background,
  https://learn.chatgpt.com/docs/hooks#userpromptsubmit,
  https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks,
  https://learn.chatgpt.com/docs/config-file/config-advanced#notifications
- Cursor: https://cursor.com/docs/hooks#stop,
  https://cursor.com/docs/hooks#afteragentresponse,
  https://cursor.com/docs/hooks#per-script-configuration-options
- Gemini CLI: https://geminicli.com/docs/hooks/,
  https://geminicli.com/docs/hooks/reference/#afteragent
- opencode: https://opencode.ai/docs/plugins/#send-notifications,
  https://opencode.ai/docs/sdk/#sessions,
  https://opencode.ai/v2/docs/build/plugins/migrate-v1,
  https://opencode.ai/v2/docs/build/plugins#sessions
