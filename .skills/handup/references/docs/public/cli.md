# CLI and daemon reference

Request limits, exit codes, timeouts, storage paths, the daemon API, and
notification and configuration details. `handup help COMMAND` describes every
flag.

## Commands

```sh
handup serve --foreground    # unix socket + authenticated loopback API
handup ask --title "Review README" --preview text:README.md --wait --json
handup ask --title "Run a command" --command "echo hello" --timeout 10m
handup ask --title "Review changes" --git-diff HEAD --wait
handup ask --request - --wait --json  # full request JSON on stdin
handup ls --status pending --json
handup show <id> --json
handup status <id> --json
handup wait <id> --json
handup approve <id> --option approve -m "Looks good"
handup approve <id> --scope session  # also project or always
handup deny <id> -m "Please revise the migration"
handup cancel <id>
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
handup pair --scope decide   # QR pairing link for a phone (needs remote.mode)
handup devices list          # enabled/disabled and push state; --json includes enabled and push
handup devices disable <id>  # pause access and push without unpairing
handup devices enable <id>   # resume the same pairing
handup devices mute <id>     # stop push notifications, keep API/event access
handup devices unmute <id>   # resume push notifications
handup devices scope <id> view # read-only; use decide to restore decision access
handup devices revoke <id>   # permanently unpair
handup yolo on --for 1h      # auto-approve new low/medium risk (hard: all); handup yolo off
handup version --plain       # alias: handup v
handup config init           # --force overwrites existing config
handup config show|path|edit|keys
handup config get no_color
handup config set output_format json
handup config toggle no_color
handup completion zsh        # bash, zsh, fish, powershell, elvish
handup uninstall             # --yes skips confirmation
```

`ask` starts the daemon automatically when its socket is absent unless
`daemon.autostart` is false.

## Exit codes and output

| Exit | Meaning |
| --- | --- |
| 0 | approved/answered, or successfully submitted/pending |
| 1 | denied |
| 2 | expired |
| 3 | cancelled |
| 4 | error |
| 5 | ran in the desktop app |

These apply to `ask`, `wait`, `status`, `show`, `approve`, `deny`, and `cancel`;
`ls` returns 0 on success. Non-TTY queue commands never prompt or print banners.
`ask --wait --json` and `wait --json` print the decision (including feedback and
`content_hash`) with `id` and `status`; a cancellation prints those three fields.
Other queue commands print Request JSON. `--option id:label[:approve|deny]` adds
custom choices (default outcome approve, except id `deny`).

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

## Configuration

Config path: `--config` > `HANDUP_CONFIG` > `$XDG_CONFIG_HOME/handup/config.yaml`
(default `~/.config/handup/config.yaml`). A missing file uses defaults;
`handup config init` seeds commented examples. `handup config keys` lists the
keys `config get`/`set` accept; relay settings (`remote.relay.*`) are edited in
YAML (`handup config edit`), see [relay](relay.md).

```sh
handup config set daemon.listen 127.0.0.1:7465
handup config set requests.default_timeout 10m
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
```

Storage settings accept nonnegative integer bytes/days, not size suffixes.
`history.max_bytes` defaults to **0 (no disk cap)**; `history.files_keep_days`
defaults to **0 (files live as long as their request)**. Retention runs at startup
and hourly, first applying the age/count caps, then file expiry and the byte cap.
The cap measures live database bytes (`(page_count - freelist_count) * page_size`),
WAL bytes after checkpoint/truncation, and blob files. It removes oldest resolved
requests first, never pending requests or files still needed by kept requests,
until under the cap or no resolved requests remain. `handup doctor` reports the
same live-storage measure. It is best-effort: pending data cannot be removed,
and the physical database file can remain larger because reusable free pages do
not shrink without VACUUM. File-only expiry preserves request and audit rows;
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

## Daemon API

API v1 covers health/OpenAPI, requests, long-poll wait, hash-bound decisions,
cancellation, blob upload/Range download, and WebSocket `/v1/events`. The same
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
a required-feedback policy. `notifications.suppress_when_focused` is reserved.

The `ntfy` backend sends only the title, risk, and a `handup://r/<id>` link
(never preview content unless `ntfy.include_content`); `token_env` names an
environment variable, not a secret value. See
[notification backends](remote.md#notification-backends). Lifecycle webhooks
live under top-level `hooks:` ([event hooks](integrations/hooks.md)).

`handup doctor` checks Linux GStreamer H.264, VP9, and Opus plugins and idle
detection support. It also warns when the daemon runs a different build than
the CLI (local `GET /v1/version`) and, on Linux, lists handup processes still
running a binary that was replaced on disk, such as a `handup mcp` server or the
daemon left over from before `make install-global`; restart those. Daemon
replies ignore fields a client does not know, so older clients keep working
against a newer daemon, while request and decision input still rejects unknown
fields. `handup demo` creates PNG/WAV/HTML/diff/bundle/JSON/command/PDF
samples at runtime; video requires ffmpeg and is skipped when absent.

## Uninstall

`handup uninstall` removes the installed binary and backups and preserves
configuration. `HANDUP_INSTALL_DIR` overrides `~/.local/bin`. `install.sh`
downloads GitLab release archives with SHA-256 verification; `HANDUP_VERSION`
selects a version.
