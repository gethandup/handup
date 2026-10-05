# CLI and daemon reference

Request limits, exit codes, timeouts, storage paths, the daemon API, and
notification and configuration details. `handup help COMMAND` describes every
flag.

## Commands

```sh
handup serve --foreground    # unix socket + authenticated loopback API
handup ask --title "Review README" --preview text:README.md --wait --json
handup ask --title "Run a command" --command "echo hello" --timeout 10m
handup ask --title "Run tests" --command "make test" --run-timeout 30m  # desktop Run limit
handup ask --title "Review changes" --git-diff HEAD --wait
handup ask --title "Deploy finished" --summary "All checks passed" --kind info  # notice: no reply
handup ask --request - --wait --json  # full request JSON on stdin
handup ls --status pending --json
handup show <id> --json
handup status <id> --json
handup wait <id> --json
handup approve <id> --option approve -m "Looks good"
handup approve <id> --scope session  # also project or always
handup deny <id> -m "Please revise the migration"
handup cancel <id>
handup stop <id>             # stop a command the desktop app is running for it
handup schema request        # or decision, event, openapi
handup service install --dry-run  # inspect unit/plist without writing/enabling
handup service install       # install and start user service
handup service status
handup service uninstall
handup demo --json           # one sample request per available preview type
handup doctor --json         # OK/WARN/FAIL diagnostics
handup inbox                 # live terminal inbox (requires a TTY)
handup rules list
handup rules test request.json       # or a request ID
handup rules rm <rule-id>
handup log --json            # append-only audit, newest first
handup storage --json        # disk use by category, retention, last cleanup
handup storage clean history --older-than 30d  # background cleanup; or files, --all
handup license status        # trial days left or license; activate KEY | import FILE | deactivate
handup pair --scope decide   # QR pairing link for a phone (needs remote.mode)
handup devices list          # enabled/disabled and push state; --json includes enabled and push
handup devices disable <id>  # pause access and push without unpairing
handup devices enable <id>   # resume the same pairing
handup devices mute <id>     # stop push notifications, keep API/event access
handup devices unmute <id>   # resume push notifications
handup devices scope <id> view # read-only; use decide to restore decision access
handup devices revoke <id>   # permanently unpair
handup yolo on --for 1h      # auto-approve new low/medium risk (hard: all); handup yolo off
handup report                # support page in the browser; --feature, --question, --print
handup version --plain       # alias: handup v
handup config init           # --force overwrites existing config
handup config show|path|edit|keys
handup config show --effective  # every setting, marked file or default
handup config get no_color
handup config set output_format json
handup config unset output_format  # back to the default
handup config toggle no_color
handup config validate      # check the active config, or a given path
handup integrate all         # every detected agent: Claude Code, Codex, Cursor, omp
handup integrate --list      # detected agent homes and installed handup entries
handup prompt               # generic instructions; --agent claude|codex|cursor|omp tailors them
handup skill install         # bundled agent skill; --agent claude|codex, --project, --dir, --dry-run
handup skill uninstall       # removes only a handup-installed skill
handup completion zsh        # bash, zsh, fish, powershell, elvish
handup uninstall             # --yes skips confirmation
```

`ask` starts the daemon automatically when its socket is absent unless
`daemon.autostart` is false.

## Agent integration

`handup integrate all [--dry-run] [--uninstall] [--no-mcp]` uses the same
agent-home detection as `--list`:

- Claude Code: `~/.claude/` or `~/.claude.json`.
- Codex: `$CODEX_HOME/`, default `~/.codex/`.
- Cursor: `~/.cursor/`.
- omp: `$PI_CODING_AGENT_DIR/`, default `~/.omp/agent/`.

Missing config files in detected homes are created by the normal installer.
It installs hooks plus MCP for Claude Code and Codex, and MCP only for Cursor
and omp. For omp, an existing `extensions/handup.ts` is upgraded safely; no
tool-gating extension is added by default. A customized or unknown
`extensions/handup.ts` fails validation, so no agent is written until you move
it aside. Add gating explicitly with
`handup integrate omp` (see [omp](agents/omp.md) for the approval policy).
`--no-mcp` keeps hooks/existing extensions only and skips Cursor and MCP-only
omp. Individual targets remain `claude`, `codex`, `omp` and
`mcp --client claude-code|codex|cursor|omp`.

All selected agents are validated before any file is written. Invalid config
aborts all writes, but validation continues to report every failed agent.
Successful plans retain the per-target diffs, backups and idempotent reapply;
`--dry-run` displays valid agents' proposed changes even if another agent fails
validation, without writing. A write failure names the failing file and does
not stop attempts for remaining agents. Writes are not transactional, even
within one agent: a failure can leave that agent half-written; idempotent
reapply completes it after the cause is fixed. Config symlinks and existing
permissions are preserved, JSON key order is retained, and files changed since
planning are refused with "changed during install" instead of overwritten.
The final summary reports each agent as installed, already up to date, removed,
skipped or failed; dry-run outcomes are marked as previews.
`--uninstall` selects every agent with an installed handup entry. Exit 0 means
success, including no detected agents or nothing installed; exit 4 means an
agent failed. `--client` and `--list` are rejected with `all` (exit 4). Bare
`handup integrate` requires a target and suggests `all` or `--list`.

## Exit codes and output

| Exit | Meaning |
| --- | --- |
| 0 | approved/answered/dismissed, or successfully submitted/pending |
| 1 | denied |
| 2 | expired |
| 3 | cancelled |
| 4 | error |
| 5 | ran in the desktop app |
| 6 | license required |

These apply to `ask`, `wait`, `status`, `show`, `approve`, `deny`, and `cancel`;
`ls` returns 0 on success. Non-TTY queue commands never prompt or print banners.
Exit 6 means the trial ended or the license was revoked; see [License](license.md).
`ask --wait --json` and `wait --json` print the decision (including feedback and
`content_hash`) with `id` and `status`; a cancellation prints those three fields.
Other queue commands print Request JSON. `--option id:label[:approve|deny]` adds
custom choices (default outcome approve, except id `deny`).

`--kind info` submits a notice that needs no reply: it gets **OK** (`ok`,
approve outcome) and **Dismiss** (`dismiss`, deny outcome) options,
`on_timeout: expire`, takes no `input`, and is never decided by rules or YOLO.
Either choice records `status: dismissed` (exit 0); `decision.option` says which.
Do not `--wait` on a notice; agents with MCP use `notify`. A human's optional
reply is delivered once through `POST /v1/notice-replies` (MCP, the omp
extension and Claude Code hooks claim it; see
[notice replies](agents/mcp.md#notice-replies)).

Desktop **Run** decisions carry `run_result`. `handup wait ID --json` (and
`ask --wait --json`) includes it at the top level beside `id` and `status`;
`handup status ID --json` includes it under `decision.run_result` in the full
Request. Text output from wait prints a run summary: exit code or error,
duration, elevation and the last 40 lines of each redacted output tail, followed
by human feedback when present; text status shows the request and previews, so
use `status --json` for the result. Run is an approval even when execution fails,
but `ask --wait`, `wait`, `status` and `show` exit **5** for a decision carrying
`run_result`, regardless of the command's own exit code. Read
`run_result.exit_code` and `error`, and **do not run the command again**.
See [MCP's result contract](agents/mcp.md#desktop-run-results) for the fields.

## Previews and limits

Preview types: `text`, `markdown`, `code`, `diff`, `files`, `command`, `json`,
`html`, `image`, `video`, `audio`, `file`, `pdf`, and `email`. Repeat
`--preview TYPE:PATH`, or use `TYPE:-` for stdin. `email:FILE` reads an email
draft JSON object and also sets it as the editable `input` (see
[email drafts](agents/email.md)). Files are uploaded as
immutable, SHA-256-addressed blobs. Directories use `files` previews; an
`index.html` becomes the bundle entry. Symlinks inside a bundled directory are
rejected; a symlink given as the preview path itself is followed. `--command` adds a
shell snapshot; submitting it does not execute it. The human can explicitly
choose [Run in the desktop app](desktop.md#run-a-command). `--git-diff [RANGE]`
snapshots Git's unified diff. MIME is sniffed from bytes and extensions.

Inline JSON-request previews over `previews.inline_max` (64 KiB) move into
blobs. Limits: 512-byte title, 64 KiB summary/input, 64 previews, 32 choices,
4096 bundle files, 16 MiB inline preview. `previews.max_file_bytes` defaults to
268435456 (256 MiB) and caps uploads and previews with a known size; oversized
uploads return 413 naming that key. CLI file and stdin previews also stop at a
fixed 256 MiB even if that key is raised. The remote listener still has its own
1 MiB request-body limit. Questions: 4096-byte question text and option
descriptions, 32 options, 16 KiB option previews and answer text. Email drafts:
500 recipients, 64 attachments, 998-byte subject.

Sources auto-detect cwd, Git root/branch and host. `--agent`, `--session`, and
`--cwd` override self-declared, **unverified** provenance, including with
`--request -`; explicit JSON source fields are otherwise preserved.

## Timeouts, dedupe and durability

Requests wait for a human by default (`requests.default_timeout: none`).
`--timeout` or a configured duration opts into expiry. `--on-timeout deny`
(default) records an expired, denied decision; `expire` expires without
approving; `approve` explicitly opts into automatic approval. Identical pending
requests with the same `--dedupe-key` collapse into one ID. Pending requests
and decisions survive daemon restart, and audit rows cannot be updated or
deleted.

### Run limits

A desktop [Run](desktop.md#run-a-command) is stopped when it reaches its limit:
the request's `run_timeout` (`ask --run-timeout 30m`, MCP `request_approval`
`run_timeout`, or the request JSON field), else `run.timeout` (default `10m`),
never more than `run.max_timeout` (default `1h`). Both are humantime durations
between 1ms and one year (as is `run_timeout`), apply live, and `run.timeout`
must not exceed `run.max_timeout`. `run_timeout`
is separate from the request's decision `timeout`. The claim's `run.timeout_ms`
holds the limit in force; its lease ends 2 minutes after it.

`handup stop ID [--json]` asks the desktop running the request's command to
stop it (`POST /v1/requests/{id}/run/stop`); it prints the request with
`run.stop` set. The desktop sends SIGTERM, then SIGKILL after 5 seconds, and
reports `stopped from this computer; terminated` (or `killed`) as `run_result`.
It fails with 409 `not running in the desktop app` when nothing runs. See
[stop from another device](desktop.md#stop-from-another-device).

## Configuration

Config path: `--config` > `HANDUP_CONFIG` > `$XDG_CONFIG_HOME/handup/config.yaml`
(default `~/.config/handup/config.yaml`). A missing file uses defaults;
`handup config init` seeds commented examples. `handup config keys` lists the
keys `config get`/`set`/`unset` accept, including every remappable `keys.<id>`
action, its label and default shortcut. Relay settings (`remote.relay.*`) are
edited in YAML (`handup config edit`), see [relay](relay.md).

| Command | Effect |
| --- | --- |
| `config show [--effective] [--json]` | Print the file; `--effective` lists every setting as built-in defaults merged with the file, each line `key: value  # file` or `# default`, including the client preferences `output_format` (`text`), `no_color` (`false`) and `display.theme` (`auto`) |
| `config get <key> [--json]` | Print one value; JSON `{"key": "...", "value": ...}` (`null` when unset) |
| `config keys [--json]` | List settable keys; JSON array of `{key, type, description}` |
| `config set <key> <value>` | Validate and write one override |
| `config unset <key>` | Remove an override so the default applies (empty parent maps are pruned); prints "is not set" when absent |
| `config toggle <key>` | Flip a boolean |
| `config edit` | Edit a temp copy in `$VISUAL`/`$EDITOR`, validate on close, then replace the file |
| `config validate [path]` | Check a file (default: the active config) with the daemon's own validation |

`set`, `unset`, `toggle` and `edit` write through the daemon's validated atomic
writer: an invalid change writes nothing, a saved change is synced to disk, and a
symlinked `config.yaml` is written through to its target (the link stays). They
print the changed dotted keys and then what happened: "No daemon running: the
change applies when it starts."; "The running daemon uses \<path\>; this file
applies when a daemon starts with it." when `--config`/`HANDUP_CONFIG` names a
different file than the running daemon's; once the daemon watching this file has
handled the saved content (checked via `GET /v1/config/status` for up to 3 s),
"Applied live: …" and/or "Restart the daemon to apply: …" (`daemon.listen`,
`previews.max_file_bytes`, `remote.*`), or "The running daemon kept its previous
config: path:line: message"; otherwise "The running daemon has not picked up this
save yet." or "Could not read the running daemon's config status; restart it to
be sure."

`config edit` accepts editor arguments (`EDITOR="code --wait"`) and starts from
the default template when the file is missing. Closing without changes prints
"No changes.". An invalid result prints `path:line: message` and asks
`[r]e-open or [d]iscard?`; discard (or end of input) exits 2 and leaves the file
unchanged. `config validate` prints `<path>: valid` and exits 0, or prints
`path:line: message` on stderr and exits 2.

```sh
handup config show --effective --json   # {"<dotted.key>": {"value": ..., "source": "file"|"default"}, ...}
handup config get keys.approve --json
handup config unset requests.default_timeout
handup config validate ~/.config/handup/config.yaml.new
```

```sh
handup config set daemon.listen 127.0.0.1:7465
handup config set requests.default_timeout 10m
handup config set run.timeout 30m           # desktop Run limit; run.max_timeout caps it
handup config set notifications.type visual
handup config set notifications.quiet_hours 22:00-08:00
handup config set notifications.backends '[desktop, ntfy]'
handup config set notifications.ntfy.topic my-private-topic
handup config set remote.mode tailscale
handup config set history.keep_days 30      # 0 disables the age cap
handup config set history.max_requests 500  # 0 disables the count cap
handup config set history.max_bytes 1073741824  # best-effort 1 GiB live-storage cap
handup config set history.files_keep_days 7    # files only; keep decisions/audit
handup config set previews.max_file_bytes 268435456
handup config set decisions.primary_side left  # Approve/Submit on the left
handup config set keys.approve shift+y
handup config set keys.help f1
handup config get keys.approve
```

### Live reload

The daemon watches its config file (atomic-rename saves from editors included)
and applies every save, whether from an editor, `handup config set`, Settings,
`PUT /v1/keys` or `PUT /v1/storage/retention`. Keys, rules, `decisions.*`,
`notifications.*`, `previews.*`, `history.*`, hooks, callbacks, `requests.*` and
all other settings apply live. Only `daemon.listen`, `previews.max_file_bytes`
and everything under `remote` (mode, bind, ports, relay) need a daemon restart;
until then they are reported as restart required.

Every save is validated first. An invalid file, including one whose rule ids
collide with a session rule, keeps the previous config, rules included, in force
and logs `path:line: message` until a valid save. A save made while the daemon is
starting is applied once the watcher starts. Each save
emits on `/v1/events`:

```json
{"type":"config.changed","config":{"applied":["decisions.undo_window"],"restart_required":["daemon.listen"]}}
```

`error` is set to `path:line: message` when the file is invalid. `restart_required`
lists every restart-only key changed since the daemon started, so it empties
again when a change is reverted. `GET /v1/ui-settings` carries the same state as
`config_restart_required` and `config_error`. `GET /v1/config/status` (local
listener only, not the remote one) returns `{path, sha256, restart_required,
error}`: the config file the daemon loads and watches, the SHA-256 hex of the
content it last handled, pending restart-only keys and the file's current error.
Clients refetch settings and show
a header notice beside the connection pill (its own row below the header on phones):
"Config reloaded" briefly, "Restart daemon to apply: …" until dismissed (it
returns once the set of restart-only keys changes or empties) or applied, and
"config.yaml invalid (line N), kept previous" until a valid save.
Credentials (Firebase and Google services JSON) stay in their own files; do not
put secrets in `config.yaml`.

### Keyboard shortcut configuration

The daemon's `keys:` map overrides desktop/web shortcuts by action id; omitted
actions keep their defaults. `handup config keys` lists the supported ids (for
example `approve`, `deny`, `next`, `previous`, `search`, `help`, and `undo`).
This does not change the terminal inbox's keys.

```yaml
keys:
  approve: shift+y
  help: f1
```

Keys are case-insensitive and normalized to lowercase. Combine `mod`, `ctrl`,
`alt`, `meta`, or `shift` with `+` and one key, such as `shift+y`, `alt+a`, or
`mod+f2`. `mod` means Command on macOS and Ctrl elsewhere; do not combine it
with `ctrl` or `meta`, and do not combine `ctrl` with `meta`. A key is one
printable ASCII character, `f1`–`f12` (not `f01`), or `enter`, `esc`, `space`,
`tab`, `backspace`, `delete`, `up`, `down`, `left`, `right`, `home`, `end`,
`pageup`, `pagedown`, `insert`, or `plus` (for `+`). Shift combines with letters
and named keys other than `plus`; use the resulting symbol for punctuation
(`?`, not `shift+/`). Duplicate modifiers and unknown keys are rejected.

Two actions cannot use the same effective key in an overlapping view (Inbox
or History), including unchanged defaults and built-in keys. `mod` conflicts
with both the equivalent `ctrl` and `meta` binding, so the config works across
platforms. Disjoint-view actions may share a key. Built-in `Esc`, `Enter`,
arrows/Shift+arrows, `Home`/`End` (question answers), `Space`, `Tab`, `1`–`9`,
and `mod+enter` remain reserved where they apply and cannot be remapped
(`mod+shift+enter` is free). Unknown action ids, malformed keys and
conflicts are refused without saving. To reuse a taken key, move the other
action first. Remove an override from YAML to restore that action's default.

CLI/YAML edits apply live (see [Live reload](#live-reload)), and so does
**Settings → Keyboard shortcuts**; its editor needs a fine pointer and
local access or a paired device with `decide` scope. Overrides belong to the
computer, not one device. The sheet and button hints show the effective keys.

#### Shortcut API

`GET /v1/ui-settings` includes `keys`, the current override map (not all defaults).
`PUT /v1/keys` replaces the complete map:

```json
{"keys":{"approve":"shift+y","help":"f1"}}
```

Omitted actions revert to defaults; `{"keys":{}}` resets all. Local, remote HTTP
and relay tunnel routers expose the endpoint. Paired devices need `decide`
scope; `view` devices and submit tokens get 403. A successful response is 200
with `{"keys":{...}}` in canonical form. Unknown/built-in actions, invalid keys,
conflicts, or no daemon config file return 400. The daemon saves `keys:` to its
config and applies it without restarting, logs the actor (including the paired
device name/id), and emits `{"type":"keys.changed","keys":{...}}` (plus
`config.changed`) on `/v1/events` so open clients rebind. See [OpenAPI](openapi.json).

### Storage configuration

Storage settings accept nonnegative integer bytes/days, not size suffixes.
Storage settings apply live when the config is saved (`handup config set history.*`
or an editor); Settings → Storage in the desktop app also changes
`keep_days`/`files_keep_days` (see [Storage usage and cleanup](#storage-usage-and-cleanup)).
`history.max_bytes` defaults to **0 (no disk cap)**; `history.files_keep_days`
defaults to **0 (files live as long as their request)**. Retention runs at startup
and hourly, first applying the age/count caps, then file expiry and the byte cap.
`history.keep_days: 0` (**Forever** in Settings) removes only the age cap;
`history.max_requests` (2000 by default) still bounds history.
The cap measures live database bytes (`(page_count - freelist_count) * page_size`),
WAL bytes after checkpoint/truncation, and blob files. It removes oldest resolved
requests first, never pending requests or files still needed by kept requests,
until under the cap or no resolved requests remain. `handup doctor` reports the
same live-storage measure. It is best-effort: pending data cannot be removed,
and hourly retention never shrinks the database file: freed pages stay as free
space that new requests reuse. Only a storage cleanup returns them, and only on
databases created with `auto_vacuum=incremental` (new databases since storage
cleanup shipped). File-only expiry preserves request and audit rows;
files shared with pending or newer resolved requests stay stored.
Expired blob/preview downloads return 410 Gone; the UI shows
“File no longer stored (history.files_keep_days)”.

`output_format` (text/json/yaml) is validated but no command reads it yet: queue
commands (`ask`, `wait`, `status`, `ls`, …) print JSON only with `--json`.
Themes: auto/light/dark. Primary side:
right (default)/left; each app may override it per device. Global `--no-color` and
`NO_COLOR` disable color; redirected output is plain.

## Storage

Linux data: `$XDG_DATA_HOME/handup/handup.db` (SQLite WAL) and
`blobs/sha256/<2>/<62>`; state: `$XDG_STATE_HOME/handup/token` (0600); socket:
`$XDG_RUNTIME_DIR/handup/handup.sock` (0600, parent 0700), falling back to the
state directory. macOS uses the platform application-support directory for
data and state. `HANDUP_DATA_DIR`, `HANDUP_STATE_DIR`, and `HANDUP_SOCKET`
override these paths. Existing data/state/socket-parent directories must already
be private (0700); shared directories and symlinks are rejected rather than
chmodded. A process lock prevents a second daemon on the same state directory.

### Storage usage and cleanup

`handup storage` shows the daemon's disk use by category: **History**
(request rows with inline previews, resolutions and their indexes), **Audit log**,
**Files** (preview blobs on disk plus their metadata), **Free** (free database
pages, reused before the file grows) and **Other** (devices, tokens, schema and
the write-ahead log). The categories add up to the total. It also prints pending
and resolved counts, the retention policy and the running or last cleanup;
`--json` prints the `GET /v1/storage` report, which includes
`oldest_resolved_at` and `compacts` (whether cleanups can shrink the file).

```sh
handup storage clean history --older-than 30d  # resolved requests, audit, unshared files
handup storage clean files --older-than 1w     # only files; decisions and audit stay
handup storage clean history --keep 100        # all but the newest 100 resolved requests
handup storage clean history --all --json      # every resolved request
```

`clean` needs `--older-than DURATION` (at least `1d`, rounded down to whole days),
`--keep N` (keep the newest N resolved requests; with `--older-than`, both
apply) or `--all`. Requests resolved in the same millisecond as the last one
kept stay too. It starts a background cleanup on the daemon, follows its progress
and prints what it removed; it exits 0 when the cleanup finished and 1 when it
was cancelled or failed. Pending requests are never touched, nor files a pending
(or, for `files`, a newer) request references. `history` deletes resolved
requests with their audit events and the files no remaining request uses;
`files` removes only files and keeps the metadata, so later downloads return 410
Gone. Only one cleanup runs at a time (409 otherwise). It works in small
batches, so requests and decisions keep flowing, then compacts the database where
supported. Stopping the CLI does not stop the cleanup; cancel it from Settings →
Storage or with `POST /v1/storage/cleanup/{id}/cancel`.

Storage endpoints (local, plus the paired-device scope noted):

| Endpoint | Purpose |
| --- | --- |
| `GET /v1/storage` | Usage, retention, running or last cleanup. `view` |
| `GET /v1/storage/estimate?target=history\|files&older_than_days=N&keep_newest=N` | What a cleanup would remove now (requests, files, approximate bytes); `0`/absent disables each limit (both = every resolved request). `view` |
| `POST /v1/storage/cleanup` | Body `{target, older_than_days?, keep_newest?}`; 202 with the job, 409 with the running `job`. `decide` |
| `GET /v1/storage/cleanup/{id}` | Progress: `state` (`running`, `done`, `cancelled`, `failed`), `done`/`total`, deleted counts, `bytes_freed`, `compacting`. `view` |
| `POST /v1/storage/cleanup/{id}/cancel` | Stops after the current batch; what was removed stays removed. `decide` |
| `PUT /v1/storage/retention` | Body `{keep_days?, files_keep_days?}` (0–36500, 0 = forever / with request). Saves to the daemon's config file and applies without a restart; a shorter period starts a cleanup at once (`job` in the response, null if another cleanup runs). `decide` |

Only the running or most recent cleanup is kept, in memory; a daemon restart
forgets it.

## Daemon API

API v1 covers health/OpenAPI, requests, long-poll wait, hash-bound decisions,
cancellation, blob upload/Range download, and WebSocket `/v1/events` (pinged
every 25 s; treat a longer silence as a dead connection). The same
API runs on the Unix socket and `daemon.listen` (default `127.0.0.1:7465`). Unix
access relies on filesystem permissions. TCP requires a bearer token, a loopback
Host, and an absent or trusted Origin (Tauri origins or `remote.web_origin`).
`daemon.listen` must be loopback; remote access is a separate listener
(`remote.mode`) that accepts paired device tokens and named submit tokens. See
[remote access](remote.md) and the generated [OpenAPI](openapi.json).

### Test requests

`POST /v1/requests/test` creates a fixed synthetic request to try the inbox and
notifications. Send no body or `{}` for an approval, or
`{"kind":"approval"}` / `{"kind":"question"}`. The daemon returns **201** with
the created `ApprovalRequest`; unknown kinds, extra fields, or malformed JSON
return **400**. No custom title, source, preview, or other request fields are
accepted.

The server sets the title to **Test request** or **Test question**, agent to
`handup`, session to `handup-test`, risk to `low`, and timeout to `15m`. The
question includes sample choices and free text. Approving, denying, or answering
performs no action. These samples use the normal request and decision flow.

The route exists on the local Unix socket/authenticated loopback listener,
remote HTTP listener, and relay tunnel. Remote paired devices need `decide`
scope; `view` devices and submit tokens receive **403**. Arbitrary remote request
submission remains a separate [submit-token](integrations/tokens.md) capability.

```sh
curl --unix-socket "$XDG_RUNTIME_DIR/handup/handup.sock" \
  -H 'Content-Type: application/json' http://handup/v1/requests/test \
  -d '{"kind":"question"}'
```

## Notifications

Native notifications support sound/visual/both, new requests, critical
high-risk urgency on Linux (bypasses quiet hours), expiry warnings, reminders,
and quiet hours. Sound uses `paplay` (Linux) or `afplay` (macOS), with a
platform sound or `notifications.sound_file`. Notification text redacts common
credentials and includes the request ID. Linux notification actions follow
`none|low_risk|all`; macOS actions are not supported. Deny actions cannot bypass
a required-feedback policy. An info notice reads "Notice: title" with its
redacted summary as the body, and its actions are **OK** and **Dismiss**.
`notifications.suppress_when_focused` is reserved.

On macOS the daemon posts banners as the handup desktop app (`handup.app`), so
click **Allow** when macOS asks whether handup may send notifications. Without
`handup.app` installed (the CLI-only download) banners are posted as Finder and
macOS does not show them. Banners also stay hidden while Screen Sharing is
connected. See [desktop app on macOS](desktop.md#macos).

The `ntfy` backend sends only the title, risk, and a `handup://r/<id>` link
(never preview content unless `ntfy.include_content`); `token_env` names an
environment variable, not a secret value. See
[notification backends](remote.md#notification-backends). Lifecycle webhooks
live under top-level `hooks:` ([event hooks](integrations/hooks.md)).

`handup doctor` checks Linux GStreamer H.264, VP9, and Opus plugins and idle
detection support. It also warns when the daemon runs a different build than
the CLI (local `GET /v1/version`) and, on Linux, lists handup processes still
running a binary that was replaced on disk, such as a `handup mcp` server or the
daemon left over from before a binary upgrade; restart those. Daemon
replies ignore fields a client does not know, so older clients keep working
against a newer daemon, while request and decision input still rejects unknown
fields. `handup demo` creates PNG/WAV/HTML/diff/bundle/JSON/command/PDF
samples at runtime; video requires ffmpeg and is skipped when absent.

## Uninstall

`handup uninstall` removes the installed binary and backups and preserves
configuration. `HANDUP_INSTALL_DIR` overrides `~/.local/bin`. See
[downloads and releases](downloads.md) for customer binary availability;
the private repository's maintainer installer is not a customer source-access
or distribution requirement.
