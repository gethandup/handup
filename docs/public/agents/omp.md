# omp

## Quickstart (MCP)

```sh
handup serve --foreground                 # or install the handup service
handup integrate mcp --client omp --dry-run
handup integrate mcp --client omp
```

Then run `/mcp reload` in omp (or restart it). This adds `handup mcp` to the active agent directory's `mcp.json`, so the model can call `request_approval`, `ask_question`, `check_request` and `wait_requests`. No extension and no `--approval-mode yolo` are needed. For named profiles, set `PI_CODING_AGENT_DIR` to the profile's agent directory when installing. Read [MCP](mcp.md) for the tool arguments and the rules the model must follow.

MCP approvals are explicit: handup sees only what the model chooses to ask. It does not intercept omp's built-in ask dialog or its own tool approval prompts, which keep working as configured. For automatic forwarding of those, add the optional native bridge below.

Questions from `ask_question` appear in the app as clickable cards: radio buttons for single choice, checkboxes for multi choice, plus free text when allowed. Raw JSON stays hidden until you open its toggle. handup renders only structured `input.questions`; it never infers a question form from arbitrary JSON.

**Long waits.** A human may take minutes to decide, but omp's bash tool stops a command after its default timeout (300s). When an agent waits with the CLI (`handup ask --wait`, `handup wait <id>`), run it in the background with `timeout: 0`. If the waiter is killed anyway, the request is still pending in handup: reattach with `handup wait <id>` or read it with `handup status <id> --json`. MCP clients with short tool timeouts can call `request_approval` with `wait=false` and then call `wait_requests` with the pending ids, repeating until none are pending; each call returns at the first decision or after `max_wait_seconds` (default 25s, inside omp's 30s MCP tool timeout).

**Background waiters wake the session.** Start one CLI waiter per request as an async bash job with `timeout: 0`. Its completion wakes an idle omp session, so the agent may end its turn and act on each decision when it arrives; no extension or new user message is needed. Never use one loop over several IDs, which reports nothing until the last answer. MCP alone does not wake an idle session; without a CLI waiter or the optional extension's decision push, keep the turn open and poll.

To keep a waiter attached across daemon restarts, run this in its async job:

```sh
while :; do handup wait <id> --json; rc=$?; [ $rc -eq 4 ] || exit $rc; sleep 5; done
```

Exit 4 includes daemon-unreachable errors (and other CLI errors); pending requests survive restarts. The loop exits on a decision, preserving its exit code. Investigate persistent errors rather than treating them as a decision.

## Optional native bridge (extension)

```sh
handup integrate omp --dry-run
handup integrate omp
omp --approval-mode yolo                  # or a policy allowing the gated tools
```

The installer embeds the reviewed repository source `integrations/omp/handup.ts` and installs it into `$PI_CODING_AGENT_DIR/extensions/handup.ts` (default `~/.omp/agent/extensions/handup.ts`). It also adds `handup mcp` to the same agent directory's `mcp.json`, exactly as the MCP quickstart does; pass `--no-mcp` to install the bridge alone, and `--uninstall` removes both (or only the bridge with `--no-mcp`). Every file is checked before any is written, so a refused step changes nothing. `--dry-run` prints the diffs and changes nothing. Reapply is idempotent. Restart omp after any install, upgrade or uninstall to load the changed bridge. For isolated or explicit loading, use `--no-extensions --extension /path/to/handup.ts --no-session`. Installing MCP alone does not install this gate.

**Upgrades and custom files.** Never edit the installed file: configure it through handup instead (see the tool list below), so every upgrade applies cleanly. An existing file that exactly matches a previously shipped handup version (by SHA-256 of its full bytes) and is otherwise unmodified is upgraded automatically: the old bytes are kept in a unique backup beside it (`handup.handup.bak`, then `.bak.1`, …) and the new file is replaced atomically. Any other existing file, including a shipped version with local edits, is treated as yours: the installer shows the diff to the current source and leaves the file unchanged. There is no force flag. Move your copy aside, move its customizations into handup config, and run the installer again. `handup integrate omp --uninstall` removes only a recognized handup file, never a custom one.

**Use `--approval-mode yolo`, or a policy allowing the gated tools.** The extension is a `tool_call` preflight, not a callback capable of approving omp's built-in gate. Otherwise omp may ask a second time after handup approves; in print mode that second prompt fails closed. Yolo does not bypass this extension's gate, explicit deny policies, or provider safety checks.

### Behavior and fallback

The default filter gates `bash,python,edit,write,notebook,apply_patch,notebook_edit`. Choose the gated tool names (exact omp names) with `handup config set integrations.omp.tools '[bash, edit, write]'`; `[]` gates nothing, leaving only the question bridge, and removing the key (`handup config edit`) restores the default. The extension reads the setting through `handup config get` when omp loads it, so restart omp after changing it. A `HANDUP_OMP_TOOLS` environment variable (comma-separated) overrides the setting for one omp process. If handup is not on `PATH` or its config is unreadable, the default list applies. Read tools remain ungated by default. Include every write/exec tool you use, including custom tools. Bash shows an exact command preview; old/new text edits show a diff, and other edits show JSON. Requests carry agent `omp`, session ID, cwd and tool name. The extension never executes the proposed action itself.
The bridge also sends the session manager's current display name
(`getSessionName()`) as optional `source.session_title`. Titles are display-only;
session-scoped allow rules continue to match the stable session ID.

With a UI, handup races the native Approve/Deny select: the first answer wins, the losing native dialog is aborted or the pending handup request is cancelled. Approve returns no block. Deny, expiry, cancellation, or a handup error blocks with human feedback or a safe reason, visible to the model. With the daemon unreachable, or presence routing to the keyboard, only the native select is used; with no UI (including `-p`) the action blocks. No fallback ever automatically approves, and the extension does not auto-start the daemon.

Desktop **Run** is an exception to ordinary approval: `run_result` means the
command was already attempted, so the extension blocks the original tool call
with its run summary and **do not run again** instruction, even for a failed
run. The request itself remains approved. MCP-only agents must inspect
`run_result` themselves; see [result fields](mcp.md#desktop-run-results).

The extension also wraps `ctx.ui.askDialog` where available. Questions race the native dialog against a handup `question` request whose `input.questions` keep omp's ids, headers, single/multi choice, recommended option, option descriptions and previews; each question also permits free text. The app shows them as the same clickable radio/checkbox cards (keyboard: ↑/↓ or j/k between options, Space/Enter or 1–9 to choose, ⌘/Ctrl+Enter to submit), with Raw JSON hidden until requested. Submit returns `decision.fields.answers` (`{QID: {selected, text?}}`), mapped back to omp's submit-result shape (`selectedOptions`, `customInput`). A decline, expiry or daemon-side cancellation is also returned as an answer with no selection: `customInput` reads `Declined in handup: <feedback>` (or names the expiry or cancellation), so the agent sees the decline and continues instead of reporting "Ask tool was cancelled by the user". Answering the native dialog first, or aborting the agent turn, still cancels the handup request. From a terminal: `handup answer ID --select QID=LABEL --text QID=TEXT`.

### Decision push

With the extension loaded, pending requests created by this session through MCP `request_approval` / `ask_question` (including `wait=false` and harness-mounted tools) or non-blocking `handup ask` CLI output are watched over the local socket. A human decision sends one visible `handup-decision` message containing the title, status, selected option, feedback and question answers. It wakes an idle agent or steers an active turn; there is no need for another human message.
For desktop Run decisions, the pushed message also includes the run summary
and tells the agent not to run the command again.

If a tool result already showed the final state (for example `check_request`, `wait_requests`, `handup wait`, `handup status`, or a blocking MCP call), the extension suppresses that push. Its own approval gates and question-dialog races remain inline and never push. Watchers stop on session switch/branch, shutdown or abort, retry daemon failures with backoff, and silently stop when a request is gone. Only requests observed in the current session are tracked; installing MCP alone does not enable push.

### Limitations

The extension targets omp 18.4.4. It gates the configured names regardless of omp's approval tier; it is not a replacement for the entire omp policy engine. Because it races omp's native prompts, whichever side answers first decides; a native answer cancels the pending handup request. Native question chat/image answers remain native-only; remote answers support option labels and free text. It uses handup's local Unix socket (`HANDUP_SOCKET`, then the standard runtime/state location), not a remote relay.

Sources: https://github.com/can1357/oh-my-pi/tree/v18.4.4/packages/coding-agent/src/extensibility/extensions and https://github.com/can1357/oh-my-pi/blob/v18.4.4/packages/coding-agent/src/extensibility/shared-events.ts
