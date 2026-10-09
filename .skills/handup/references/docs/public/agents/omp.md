# omp

## Quickstart (MCP)

```sh
handup serve --foreground                 # or install the handup service
handup integrate mcp --client omp --dry-run
handup integrate mcp --client omp
```

Then run `/mcp reload` in omp (or restart it). This adds `handup mcp` to the active agent directory's `mcp.json`, so the model can call `request_approval`, `ask_question`, `notify`, `check_request` and `wait_requests`. No extension and no `--approval-mode yolo` are needed. For named profiles, set `PI_CODING_AGENT_DIR` to the profile's agent directory when installing. Read [MCP](mcp.md) for the tool arguments and the rules the model must follow.

MCP approvals are explicit: handup sees only what the model chooses to ask. It does not intercept omp's built-in ask dialog or its own tool approval prompts, which keep working as configured. For automatic forwarding of those, add the optional native bridge below.

Questions from `ask_question` appear in the app as clickable cards: radio buttons for single choice, checkboxes for multi choice, plus free text when allowed. Raw JSON stays hidden until you open its toggle. handup renders only structured `input.questions`; it never infers a question form from arbitrary JSON.

**Long waits and turn end.** With the optional extension loaded, a pending `wait:false` result for a watched id carries a `handup push active` note: end the turn and the human's decision wakes you. Do not also start a background CLI waiter or poll those ids. Without that note, follow the pending result and call `wait_requests` with every pending id until none remain before ending the turn. Each call returns at the first decision or after `max_wait_seconds` (default 25s). A timeout is not an answer: save the id and recover it with `list_requests` after a reconnect, rather than creating a duplicate.

## Optional native bridge (extension)

```sh
handup integrate omp --dry-run
handup integrate omp
omp --approval-mode yolo                  # or a policy allowing the gated tools
```

`handup integrate all` detects the active agent directory and installs MCP only
by default. If `extensions/handup.ts` already exists, the same safety checks
upgrade it; a customized file fails validation and blocks every agent's writes
until moved aside. New tool gating is opt-in with `handup integrate omp`.
`--no-mcp` keeps an existing extension only (MCP-only omp is skipped), and
`--uninstall` removes installed handup entries from every agent.

The installer embeds the reviewed repository source `integrations/omp/handup.ts` and installs it into `$PI_CODING_AGENT_DIR/extensions/handup.ts` (default `~/.omp/agent/extensions/handup.ts`). It also adds `handup mcp` to the same agent directory's `mcp.json`, exactly as the MCP quickstart does; pass `--no-mcp` to install the bridge alone, and `--uninstall` removes both (or only the bridge with `--no-mcp`). Every file is checked before any is written, so a refused step changes nothing. `--dry-run` prints the diffs and changes nothing. Reapply is idempotent. Restart omp after any install, upgrade or uninstall to load the changed bridge. For isolated or explicit loading, use `--no-extensions --extension /path/to/handup.ts --no-session`. Installing MCP alone does not install this gate.

**Upgrades and custom files.** Never edit the installed file: configure it through handup instead (see the tool list below), so every upgrade applies cleanly. An existing file that exactly matches a previously shipped handup version (by SHA-256 of its full bytes) and is otherwise unmodified is upgraded automatically: the old bytes are kept in a unique backup beside it (`handup.handup.bak`, then `.bak.1`, …) and the new file is replaced atomically. Any other existing file, including a shipped version with local edits, is treated as yours: the installer shows the diff to the current source and leaves the file unchanged. There is no force flag. Move your copy aside, move its customizations into handup config, and run the installer again. `handup integrate omp --uninstall` removes only a recognized handup file, never a custom one.

**Use `--approval-mode yolo`, or a policy allowing the gated tools.** The extension is a `tool_call` preflight, not a callback capable of approving omp's built-in gate. Otherwise omp may ask a second time after handup approves; in print mode that second prompt fails closed. Yolo does not bypass this extension's gate, explicit deny policies, or provider safety checks.

### Behavior and fallback

The default filter gates `bash,python,edit,write,notebook,apply_patch,notebook_edit`. Choose the gated tool names (exact omp names) with `handup config set integrations.omp.tools '[bash, edit, write]'`; `[]` gates nothing, leaving only the question bridge, and `handup config unset integrations.omp.tools` restores the default. The extension reads the setting through `handup config get` when omp loads it, so restart omp after changing it. A `HANDUP_OMP_TOOLS` environment variable (comma-separated) overrides the setting for one omp process. If handup is not on `PATH` or its config is unreadable, the default list applies. Read tools remain ungated by default. Include every write/exec tool you use, including custom tools. Bash shows an exact command preview; old/new text edits show a diff, and other edits show JSON. Requests carry agent `omp`, session ID, cwd and tool name. The extension never executes the proposed action itself.
The bridge also sends the session manager's current display name
(`getSessionName()`) as optional `source.session_title`. Titles are display-only;
session-scoped allow rules continue to match the stable session ID.

With a UI, handup races the native Approve/Deny select: the first answer wins, the losing native dialog is aborted or the pending handup request is cancelled. Approve returns no block. Deny, expiry, cancellation, or a handup error blocks with human feedback or a safe reason, visible to the model. With the daemon unreachable, a license required answer (HTTP 402), or presence routing to the keyboard, only the native select is used; with no UI (including `-p`) the action blocks. No fallback ever automatically approves, and the extension does not auto-start the daemon.

Desktop **Run** is an exception to ordinary approval: `run_result` means the
command was already attempted, so the extension blocks the original tool call
with its run summary and **do not run again** instruction, even for a failed
run. The request itself remains approved. MCP-only agents must inspect
`run_result` themselves; see [result fields](mcp.md#desktop-run-results).

The extension also wraps `ctx.ui.askDialog` where available. Questions race the native dialog against a handup `question` request whose `input.questions` keep omp's ids, headers, single/multi choice, recommended option, option descriptions and previews; each question also permits free text. The app shows them as the same clickable radio/checkbox cards (keyboard: Enter submits once every question is answered, otherwise steps into the open question's answers, then ↑/↓ or j/k between options and Esc back to the list, Space/Enter or 1–9 to choose, `f` to type a reply, ⌘/Ctrl+Enter to submit), with Raw JSON hidden until requested. Submit returns `decision.fields.answers` (`{QID: {selected, text?}}`), mapped back to omp's submit-result shape (`selectedOptions`, `customInput`). A decline, expiry or daemon-side cancellation is also returned as an answer with no selection: `customInput` reads `Declined in handup: <feedback>` (or names the expiry or cancellation), so the agent sees the decline and continues instead of reporting "Ask tool was cancelled by the user". Answering the native dialog first, or aborting the agent turn, still cancels the handup request. From a terminal: `handup answer ID --select QID=LABEL --text QID=TEXT`.

### Decision push

With the extension loaded, pending requests created by this session through MCP `request_approval` / `ask_question` (including `wait=false` and harness-mounted tools) or non-blocking `handup ask` CLI output are watched over the local socket. A human decision sends one visible `handup-decision` message containing the title, status, selected option, feedback and question answers. It wakes an idle agent or steers an active turn; there is no need for another human message.
For ids it is actually watching, the extension adds a trusted `handup push active` instruction through omp's `additionalContext` channel, leaving the tool result unchanged. It names those ids and tells the agent to end its turn rather than call `wait_requests`, `check_request` or start a background `handup wait`. The note also marks `wait_requests` results whose pending ids already have watchers; unwatched ids get no push promise. After a session switch, follow the server's waiting guidance for recovered ids.
For desktop Run decisions, the pushed message also includes the run summary
and tells the agent not to run the command again.

Info notices from MCP `notify` or `handup ask --kind info` are watched the same way, but push only a non-empty human reply: one visible `handup-notice-reply` message, `Reply from the human to your notice TITLE: FEEDBACK`, which wakes or steers the agent. An OK or Dismiss without a reply pushes nothing. Each reply is delivered once; if the [MCP server](mcp.md#notice-replies) already handed it to the agent in a later tool result, the extension stays silent.

If a tool result already showed the final state (for example `check_request`, `wait_requests`, `handup wait`, `handup status`, or a blocking MCP call), the extension suppresses that push. Its own approval gates and question-dialog races remain inline and never push. Watchers stop on session switch/branch, shutdown or abort, retry daemon failures with backoff, and silently stop when a request is gone. Only requests observed in the current session are tracked; installing MCP alone does not enable push.

### Turn-end notices

Opt in to see each finished turn in handup without the agent calling `notify`:

```sh
handup config set integrations.omp.turn_notice true   # default false
```

Restart omp afterwards: the extension reads the setting once, through `handup config get`, when omp loads it. At each turn end (omp's `session_stop`, interactive main session only: never subagents, task sessions, or headless runs such as `omp -p`) the extension posts the final assistant message as an info notice: the title is its first non-empty line without Markdown markers (at most 120 characters), the summary is the full text (cut at 16,000 characters), and the source is the omp session (agent, session id and title, cwd). It skips the notice when the run was aborted, the message has no text, or the agent already created a handup request in that run (MCP `request_approval`, `ask_question` or `notify`, or `handup ask` through bash); each new agent run resets that check. The notice is watched like any other: a typed reply arrives as one `handup-notice-reply` message that wakes or steers omp, and OK or Dismiss without a reply does nothing. Posting runs in the background, never delays or continues the turn, and silently ignores daemon errors. It needs the native extension (`handup integrate omp`); MCP alone cannot post it. For other agents, see [Agent lifecycle hooks](lifecycle-hooks.md).

Too many notices? Turn them off with `handup config set integrations.omp.turn_notice false`; new omp sessions pick it up, and sessions already open keep the value they loaded until restarted. The extension tells interactive sessions from headless ones by omp's `ctx.hasUI` (verified `false` under `omp -p` in omp 18.8.6), so headless runs post nothing even though omp treats them as main sessions and fires `session_stop` for them. Before this release, headless runs (scripted evals, tools that launch `omp -p`) also sent notices and could flood the inbox; update with `handup integrate omp` and restart omp, since a running session keeps the extension code it loaded.

### Limitations

The extension uses omp's `additionalContext` tool-result channel (declared in 18.4.9; consumption verified in the installed 18.6.1 binary). It gates the configured names regardless of omp's approval tier; it is not a replacement for the entire omp policy engine. Because it races omp's native prompts, whichever side answers first decides; a native answer cancels the pending handup request. Native question chat/image answers remain native-only; remote answers support option labels and free text. It uses handup's local Unix socket (`HANDUP_SOCKET`, then the standard runtime/state location), not a remote relay.

Sources: https://github.com/can1357/oh-my-pi/tree/v18.4.9/packages/coding-agent/src/extensibility/extensions and https://github.com/can1357/oh-my-pi/blob/v18.4.9/packages/coding-agent/src/extensibility/shared-events.ts
