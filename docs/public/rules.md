# Rules, scoped allow, presence, and terminal inbox

Rules live under `rules:` in the selected config file (`~/.config/handup/config.yaml` on Linux by default; `--config` or `HANDUP_CONFIG` isolates them with the rest of the config). They apply when the config is saved ([live reload](cli.md#live-reload)). Invalid YAML, unknown fields, invalid regex/globs, duplicate IDs, and empty matchers are errors: the daemon refuses to start on an invalid file, and an invalid save keeps the previous rules in force and logs `path:line: message`.

```yaml
rules:
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

Older versions kept rules in a separate `rules.yaml` beside the config. On start, if that file exists and the config has no `rules:` key, the daemon moves its rules into `rules:` and renames the old file to `rules.yaml.migrated` (logged). If the config already has `rules:` (even `[]`), the legacy file is not read and is ignored with a warning.

Rules are evaluated top to bottom; the **first matching rule wins**, including `ask`. All fields in a matcher must match. Supported fields are `agent`, `kind`, `command` (Rust regex), `cwd` and `repo` (globs, with `~` expanded using the daemon's HOME), `tool`, `risk`, and `session`. Missing source fields do not match. `command` comes from command previews (shell or joined argv, outer whitespace trimmed); `tool` comes from the request's optional `tool` field, or `input.tool`/`input.tool_name`. Actions are `approve`, `deny`, `ask`, and `dismiss`. Optional `risk` overrides request risk; optional `feedback` is valid only for deny. `ask` leaves the request pending and only adjusts risk.

Info notices (`kind: info`) are matched only by `dismiss` rules, and `dismiss` rules match only info notices: an `approve`, `deny` or `ask` rule never touches a notice, and a `dismiss` rule never touches anything else. A `dismiss` rule whose matcher sets `kind` to anything but `info` is a config error. A matching notice is recorded as `status: dismissed` (option `dismiss`) with `decided_by: rule` and `rule_id`, and sends no notification. Use it to silence a sender of unwanted notices:

```yaml
rules:
  - id: noisy-hook-notices
    match: {agent: my-hook, kind: info}
    action: dismiss
```

To route one kind of action several ways, tag each request with a specific `tool` name and match it here; see [Route email by sender](cookbook/email-routing.md).

Auto decisions use the normal hash-bound decision path and append-only audit. Their decision metadata includes `decided_by: rule` and `rule_id`. **N auto-handled · View** above the Inbox list opens a read-only view of them, [YOLO mode](#yolo-mode) approvals, and [decide hook](integrations/hooks.md#decide-hooks) decisions (`decided_by: hook:<name>`). **← Inbox** returns to pending requests; **Mark read** leaves the decisions in History. A request decided on arrival is announced on the event stream with its final status (`request.created`, then `request.decided`), never as pending. API callers can use `GET /v1/requests?decided_by=rule` (or `decided_by=hook:` for every hook) and `GET /v1/log?limit=100`; `handup log --json` prints the newest audit entries first, including rule IDs.

**Mark read** shares the read state across every device connected to the same
daemon, separately for each computer, and survives daemon restarts. It hides
those decisions from Auto-handled without removing History or audit evidence.
`GET /v1/auto-read` returns `{"at":...}`; `PUT /v1/auto-read` max-merges that
watermark and emits `auto_read.changed` only when it rises. Remote/relay writes
need `decide` scope; `view` devices can read and follow changes. See the
[read-state API](cli.md#auto-handled-read-state).

For conditions rules cannot express (amount thresholds, allowlists), a [`decide:` hook](integrations/hooks.md#decide-hooks) runs a local policy program on requests still pending after rules and YOLO.

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

Rules run first and win: a request matched by any rule (`approve`, `deny`, or `ask`) is handled by that rule, so a `deny` or `ask` rule still stops a request under YOLO. YOLO never decides info notices (`kind: info`); only a person, a `dismiss` rule (above) or a [mute with `--dismiss-notices`](#floods-and-mutes) dismisses them. Requests that need a human answer always stay pending: questions (`kind: question`), forms (`input.fields`), free-text answers (`input.allow_free_text`), a feedback policy (`input.feedback: required_on_deny`), and requests with several (or no) approve options.

YOLO approvals take the normal decision path with `decided_by: yolo` in the decision and audit (`GET /v1/requests?decided_by=yolo`), appear in the read-only **Auto-handled** view opened through **N auto-handled · View** above the Inbox list, and count as `auto` in history. The API is `GET /v1/yolo` and `PUT /v1/yolo` with `{"mode": "on", "for": "1h"}`; every change emits a `yolo.changed` event (`{type, yolo: {mode, until}}`) so all open clients update live, and the daemon log records who changed it. Paired `view` devices can see the mode; changing it needs `decide` scope. On the phone app, turning on Hard YOLO asks for the same biometric confirmation as a high-risk approval. Agents must never turn YOLO on: it is a human decision.

## Floods and mutes

A broken hook or a runaway agent can send hundreds of requests or notices in a few minutes. handup groups them by **source**: the request's agent plus its session (`source.agent`, `source.session`). A request without an agent counts as agent `unknown`; requests without a session form their own group for that agent. Four tools help, from gentlest to strongest.

**Fewer pings.** Each source may raise `notifications.burst.max` notifications (default `20`) per `notifications.burst.window` (default `1m`). This counts new-request, reminder and expiry notifications on every backend (desktop, ntfy, fcm, push). Past the limit the rest are skipped, and when the window ends handup sends one summary instead, reading like `5 more from my-hook: <latest title>`. Quiet hours and mutes still apply to the summary. A skipped reminder or expiry notification also skips its `request.reminder` or `request.expiring` [hook event](integrations/hooks.md). `notifications.burst.max: 0` turns this off. The requests themselves are not affected: they all stay in the inbox.

**See the flood.** A source that creates `requests.flood_threshold` requests (default `40`; `0` turns it off) within one minute is listed as flooding. Every created request counts, including ones a rule or YOLO decided on arrival; a [dedupe](cli.md#timeouts-dedupe-and-durability) hit that returns an existing request does not. A source stays listed until five minutes pass with no new request from it, or until you clear it. The inbox shows a banner per flooding source at the top of the list: "*agent* · *session* sent *N* requests in the last minute", with **Mute 1h**, **Dismiss all (N pending)** (asks to confirm first) and **×** to hide it until the page reloads. A muted source shows **Muted until hh:mm** (or **Muted** with no end) and **Unmute** instead of **Mute 1h**. With several paired computers, each banner names its computer. View-only devices see the banner without the buttons. From a terminal:

```sh
handup flood                               # list flooding sources; --json for the raw list
handup flood clear --agent my-hook --session abc123
```

For each flooding source, `handup flood` prints how many requests it sent in the last minute and how many are pending, then a ready-to-run `handup mute …` line, a `handup flood clear …` line, and a `rules:` snippet you can paste into your config: an `action: deny` rule for that agent and session and an `action: dismiss` rule for its notices.

**Clear it.** `handup flood clear --agent A [--session S]` (or **Dismiss all** in the banner) acts on every pending request from exactly that source; without `--session` it covers only that agent's requests that have no session. Info notices are dismissed, and other requests are denied with the feedback "Cleared as a flood". A request with no deny-outcome option stays pending. The decisions are recorded as yours (`local-human`, or `device:<id>` from a paired device) and the source leaves the flood list; it prints `Dismissed N notices; denied M requests` (`--json`: `{"dismissed": N, "denied": M}`).

**Mute it.** A mute silences a source without deciding anything:

```sh
handup mute --agent my-hook --for 1h       # or --session ID, or both
handup mute --agent my-hook --dismiss-notices   # also dismiss its notices on arrival
handup mute                                # list active mutes; --json for the raw list
handup unmute <id>                         # or --all
```

A mute needs `--agent`, `--session`, or both; every field it names must match, so `--session ID` alone mutes that session for any agent. `--for` takes a duration (up to one year); without it the mute lasts until removed. Requests from a muted source are created and wait in the inbox as usual, but send no notifications of any kind: no new-request, reminder, expiry or burst-summary notification, and no message clearing a phone notification once the request is decided. They also do not emit `request.reminder` or `request.expiring` [hook events](integrations/hooks.md). With `--dismiss-notices`, the source's info notices are dismissed on arrival with `decided_by: mute`, unless a rule matched them first. A mute never approves or denies anything else. Mutes are runtime only, like YOLO mode: a daemon restart removes them all.

**Cap it.** As a last resort, a source that already created `requests.max_per_minute` requests (default `120`; `0` turns it off) in the last minute gets new requests refused until its count drops. Refused requests are not stored. The daemon answers HTTP 429:

```json
{"error": "rate limited: my-hook (session abc123) created more than 120 requests in the last minute; raise requests.max_per_minute or fix the sender", "code": "rate_limited"}
```

`handup ask` then exits 4 with `daemon HTTP 429 Too Many Requests: …` and MCP tools return that text as an error. Other sources are not affected.

All four settings apply live. The API is `GET /v1/floods` (`[{agent, session, session_title, count, pending, since, muted}]`, `since` in Unix ms), `POST /v1/floods/dismiss` with `{"agent": "…", "session": "…"}`, `GET /v1/mutes`, `POST /v1/mutes` with `{"agent", "session", "for", "dismiss_notices"}` (returns `{id, agent, session, until, dismiss_notices}`), `DELETE /v1/mutes/{id}` and `DELETE /v1/mutes` for all. A `floods.changed` event (`{type, floods}`) is sent when a source starts or stops flooding or its muted state changes, and `mutes.changed` (`{type, mutes}`) on every mute change, including when a timer ends. Paired `view` devices can read both lists; changing them needs `decide` scope.

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

The decision API accepts optional `scope: session|project|always` on approvals. Session scope matches the exact agent and session and remains in daemon memory (cleared on restart). Project scope matches the exact agent and escaped repo path, not neighboring repos. Always scope matches the agent and normalized command prefix, or the exact tool if no command exists. Plain prefixes normalize whitespace and permit additional plain arguments (letters, digits, `_./=:@%+,-`), never shell operators/substitution/quotes. Commands already containing shell syntax are matched exactly. It intentionally does **not** widen to the first executable: `git status; rm -rf ...` must not inherit approval for `git status`. Generated IDs start with `scope-`. Project/always rules are atomically saved under `rules:` in config.yaml, after existing rules so earlier deny/ask policies retain precedence; `handup rules rm` (`POST /v1/rules/{id}/remove`) removes them from there. Scoped allow requires the relevant source fields, and cannot be combined with edited input. Sources remain self-declared/unverified, not authentication boundaries.

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

Keys: `j/k` or arrows move; `a` approves; `d` opens a feedback prompt; `1–9` selects a custom option; `s/p` grant session/project allow; `u` cancels a held decision; `/` filters titles; `?` toggles help; PageUp/PageDown scroll detail; `q` quits. On an info notice `a` picks **OK** and `d` picks **Dismiss**. Enter submits feedback/filter and Esc cancels the prompt. Decisions send the displayed content_hash after `decisions.undo_window` (default 5s); approvals with 0s are immediate, while denies retain 3s undo. Quit waits for a held decision or requires undo, preventing silent loss of a staged decision. A daemon disconnect exits with an error; restart inbox to reconnect.
