# Rules, scoped allow, presence, and terminal inbox

Rules live beside the selected config file: `~/.config/handup/rules.yaml` on Linux by default. `--config /tmp/handup/config.yaml` or `HANDUP_CONFIG` also isolates the rules file. The daemon validates the entire file before starting and reloads changed contents before evaluating new requests. Invalid YAML, unknown fields, invalid regex/globs, duplicate IDs, and empty matchers are errors; no approval occurs from an invalid file.

```yaml
- id: safe-status
  match: {agent: claude-code, kind: command, command: '^git status$'}
  action: approve
- id: destructive
  match: {command: 'rm -rf|sudo|curl .*\| *sh'}
  action: ask
  risk: high
- id: scratch
  match: {cwd: '~/repos/scratch/**'}
  action: approve
```

Rules are evaluated top to bottom; the **first matching rule wins**, including `ask`. All fields in a matcher must match. Supported fields are `agent`, `kind`, `command` (Rust regex), `cwd` and `repo` (globs, with `~` expanded using the daemon's HOME), `tool`, `risk`, and `session`. Missing source fields do not match. `command` comes from command previews (shell or joined argv, outer whitespace trimmed); `tool` comes from the request's optional `tool` field, or `input.tool`/`input.tool_name`. Actions are `approve`, `deny`, and `ask`. Optional `risk` overrides request risk; optional `feedback` is valid only for deny. `ask` leaves the request pending and only adjusts risk.

Auto decisions use the normal hash-bound decision path and append-only audit. Their decision metadata includes `decided_by: rule` and `rule_id`. The desktop **Auto-handled** tab shows them, and [YOLO mode](#yolo-mode) approvals, read-only. A request decided on arrival is announced on the event stream with its final status (`request.created`, then `request.decided`), never as pending. API callers can use `GET /v1/requests?decided_by=rule` and `GET /v1/log?limit=100`; `handup log --json` prints the newest audit entries first, including rule IDs.

Rule, scoped-allow and YOLO approvals do not execute request commands.
Desktop **Run** requires an explicit human click (or `r`) on a pending request and
returns `run_result`; an agent must not run that command again. See
[Desktop](desktop.md#run-a-command).

## YOLO mode

```sh
handup yolo on --for 1h   # auto-approve new low and medium risk requests for an hour
handup yolo hard          # every risk, including high, until turned off
handup yolo off
handup yolo               # YOLO: on (low+medium risk) until 16:05; --json for {mode, until}
```

YOLO mode is a runtime daemon switch, off by default and never persisted: a daemon restart turns it off. `on` approves newly arriving requests with risk `low` or `medium`; `hard` approves every risk. `--for` (or the duration in the UI's header switch) turns it off again automatically; without it, it stays on until turned off. Requests already pending when you turn it on are not touched.

Rules run first and win: a request matched by any rule (`approve`, `deny`, or `ask`) is handled by that rule, so a `deny` or `ask` rule still stops a request under YOLO. Requests that need a human answer always stay pending: questions (`kind: question`), forms (`input.fields`), free-text answers (`input.allow_free_text`), a feedback policy (`input.feedback: required_on_deny`), and requests with several (or no) approve options.

YOLO approvals take the normal decision path with `decided_by: yolo` in the decision and audit (`GET /v1/requests?decided_by=yolo`), appear in the **Auto-handled** tab, and count as `auto` in history. The API is `GET /v1/yolo` and `PUT /v1/yolo` with `{"mode": "on", "for": "1h"}`; every change emits a `yolo.changed` event (`{type, yolo: {mode, until}}`) so all open clients update live, and the daemon log records who changed it. Paired `view` devices can see the mode; changing it needs `decide` scope. On the phone app, turning on Hard YOLO asks for the same biometric confirmation as a high-risk approval. Agents must never turn YOLO on: it is a human decision.

## Scoped allow

```sh
handup approve ID --scope session
handup approve ID --scope project
handup approve ID --scope always
handup rules list
handup rules test request.json    # or an existing request ID
handup rules rm RULE_ID
handup log --json --limit 50
```

The decision API accepts optional `scope: session|project|always` on approvals. Session scope matches the exact agent and session and remains in daemon memory (cleared on restart). Project scope matches the exact agent and escaped repo path, not neighboring repos. Always scope matches the agent and normalized command prefix, or the exact tool if no command exists. Plain prefixes normalize whitespace and permit additional plain arguments (letters, digits, `_./=:@%+,-`), never shell operators/substitution/quotes. Commands already containing shell syntax are matched exactly. It intentionally does **not** widen to the first executable: `git status; rm -rf ...` must not inherit approval for `git status`. Generated IDs start with `scope-`. Project/always rules are atomically saved in rules.yaml, after existing rules so earlier deny/ask policies retain precedence. Scoped allow requires the relevant source fields, and cannot be combined with edited input. Sources remain self-declared/unverified, not authentication boundaries.

Desktop action buttons expose all three scopes; `s` allows for session and `Shift+P` in project (plain `p` widens the preview), within the held undo window. Agents should not grant themselves scopes: these are human decisions.

## Presence routing

```yaml
presence:
  mode: always       # default; away only routes while idle
  idle_after: 2m
```

`GET /v1/presence` reports mode, backend, `idle_ms`, `route_to_handup`, and an optional warning. On Linux, handup tries ScreenSaver `GetSessionIdleTime`, then logind `IdleHint`/`IdleSinceHintMonotonic`. These use D-Bus without additional system packages. The compositor/session must maintain these signals; a Hyprland installation without a ScreenSaver provider should configure hypridle to set logind idle hints. Unknown/unreachable sources fall back to always routing, and `handup doctor` reports a warning and backend. macOS uses an `ioreg HIDIdleTime` implementation; it is not validated on the Linux development host.

The Claude PermissionRequest hook consults presence before submitting. When the user is present in away mode, it emits no decision so Claude retains its native prompt. Missing presence support/unreachable daemon never produces an allow. CLI/MCP requests always enter the queue; only integrations with a native fallback use presence routing.

## Terminal inbox

`handup inbox` requires stdin and stdout TTYs (otherwise exit 4). It uses a split list/detail view, WebSocket updates, immutable text blob previews, colored diffs, and raw metadata fallbacks for binary/media/HTML previews. HTML is displayed as text, never executed. Long text previews are capped at 256 KiB.

Keys: `j/k` or arrows move; `a` approves; `d` opens a feedback prompt; `1–9` selects a custom option; `s/p` grant session/project allow; `u` cancels a held decision; `/` filters titles; `?` toggles help; PageUp/PageDown scroll detail; `q` quits. Enter submits feedback/filter and Esc cancels the prompt. Decisions send the displayed content_hash after `decisions.undo_window` (default 5s); approvals with 0s are immediate, while denies retain 3s undo. Quit waits for a held decision or requires undo, preventing silent loss of a staged decision. A daemon disconnect exits with an error; restart inbox to reconnect.
