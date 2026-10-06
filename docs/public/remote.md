# Remote access

Approve requests from a phone or another computer. Remote access is off by
default: the daemon listens only on its unix socket and `127.0.0.1`.

| `remote.mode` | Use it for | How it works |
| --- | --- | --- |
| `off` | default | Unix socket plus the authenticated loopback API only |
| `tailscale` | **recommended** | Binds the tailnet IP (`tailscale ip -4`). Only your tailnet can connect, and each device still needs a paired token |
| `direct` | **not recommended** | Binds a LAN or public IP over TLS. Needs `remote.direct.accept_risk: true` |

Phones that are not on your tailnet can use a self-hosted
[end-to-end encrypted relay](relay.md) instead (`remote.relay.url`, `handup
pair --relay`). The relay works with any `remote.mode`, including `off`.

A remote listener accepts paired device tokens and named
[submit tokens](integrations/tokens.md). The loopback bearer token in
`$XDG_STATE_HOME/handup/token` never works on it. Device tokens view or decide
but cannot create requests or upload; submit tokens create, upload and read only
their own requests. Rules, the audit log, pairing, and device and token
management stay local-only.

## Tailscale (recommended)

[Tailscale](https://tailscale.com) puts your computer and phone on a private
network that only your devices can join, and it works from anywhere: home
Wi-Fi, mobile data, a café. The free Personal plan is enough. You don't need
to open ports, set up a router or learn any networking.

First-time setup takes about five minutes:

1. **Computer:** install Tailscale from
   [tailscale.com/download](https://tailscale.com/download) and sign in. On
   Linux, run `sudo tailscale up` and open the link it prints.
2. **Phone:** install the Tailscale app (Play Store or App Store) and sign in
   with the **same account**. Leave it connected.
3. **Check:** `tailscale status` on the computer lists both devices.
4. **Turn on remote access** and restart the daemon:

   ```sh
   handup config set remote.mode tailscale
   systemctl --user restart handup.service                       # Linux
   launchctl kickstart -k gui/$(id -u)/com.handup.daemon        # macOS
   ```

   If you run the daemon yourself instead of as a service, stop it and start
   `handup serve --foreground` again.
5. **Pair:** run `handup pair` (or **Pair a phone** in the desktop app) and
   scan the QR code with the handup app; see [Mobile](mobile.md#pairing). On
   iPhone, open the link in Safari instead ([downloads](downloads.md)).

If the phone shows "Can't reach handup", check that the Tailscale app is
connected and that `tailscale status` shows the computer online.

The daemon discovers the tailnet IP with the read-only `tailscale ip -4` (or
set `remote.bind` to it) and serves the web UI and API on `remote.port`
(default 7466). HTML previews use a second port, `remote.preview_port`
(default 7467), which is a separate browser origin. Traffic between tailnet
devices is encrypted by WireGuard.

handup never runs `tailscale serve`, `tailscale funnel`, or any other command
that changes your Tailscale configuration. If you want a browser-trusted HTTPS
name, set it up yourself and tell handup the URL so pairing links and
Host/Origin checks use it:

```sh
tailscale serve --bg --https=8443 http://100.x.y.z:7466   # you run this, not handup
handup config set remote.public_url https://your-host.your-tailnet.ts.net:8443
```

Never use `tailscale funnel` for handup: it publishes the listener to the internet.

## Pairing

`handup pair [--scope view|decide] [--name NAME] [--json]` prints a QR code in
the terminal. The desktop app shows the same code under **Pair a phone** (see
[Desktop app](desktop.md#pair-a-phone)); both use the local-only
`POST /v1/pair`, which answers 409 while remote access is off. The QR code encodes:

```text
http://100.x.y.z:7466/pair#code=<32 hex chars>&scope=decide&fp=&name=
```

- The one-time code (128 random bits) sits in the URL **fragment**, so it never reaches server or
  proxy logs. It expires after 2 minutes, works once, and is compared in constant time.
- `fp` is the SHA-256 fingerprint of the TLS certificate when TLS is on. Compare
  it with your browser's certificate details before you pair.
- The pairing page trades the code (`POST /v1/pair/exchange`) for a device token.
  Browsers receive it as an `HttpOnly; SameSite=Strict` cookie (`Secure` over
  HTTPS) that page scripts cannot read. API clients can request the token in
  the JSON response instead.

Tokens are `hu_` plus 64 hex characters (256 random bits). The daemon stores
only their SHA-256 digest, with the device name, scope, creation time, and last
use.

### Scopes

| Scope | Can |
| --- | --- |
| `view` | List and show requests, browse decision history and each request's audit trail, see storage usage, cleanup estimates and progress (`GET /v1/storage*`), see the [license](license.md) state (`GET /v1/license`), fetch blobs and previews, see YOLO mode, and receive live events. The web UI is read-only. The global audit log (`/v1/log`) stays local |
| `decide` | Everything `view` can, plus approve, deny, answer, cancel, stop a command running in the desktop app (`POST /v1/requests/{id}/run/stop`), send server-built test requests/questions (`POST /v1/requests/test`), change [YOLO mode](rules.md#yolo-mode), replace [keyboard shortcut overrides](cli.md#shortcut-api) (`PUT /v1/keys`), activate, import or remove the computer's license (`PUT`/`DELETE /v1/license`), and clean up storage or change history retention (`POST /v1/storage/cleanup`, its cancel, `PUT /v1/storage/retention`; the daemon log names the device) |
| `submit` | Create requests and upload blobs; show, wait for, and cancel only requests created by that token. Never decide, list, send synthetic tests, change shortcuts, or read/change YOLO mode. See [integration tokens](integrations/tokens.md) |

Scoped allow (session, project, or always rules) writes local policy, so it is
available only on the machine itself. Remote decisions are recorded in the audit log as
`device:<id>`.

`PUT /v1/keys` needs paired `decide` scope on remote HTTP and relay connections;
`view` and submit tokens get 403. It saves the computer's `keys:` config and
applies the complete override map live to all connected clients, not just the
calling device. `GET /v1/ui-settings` supplies current overrides and
`keys.changed` events update them; the daemon log names the device that changed
them. View devices can read the keys, but cannot edit them. Every config save
also emits `config.changed` (applied keys, restart-only keys, and any file
error; see [live reload](cli.md#live-reload)), which the web UI shows as a
header notice.

`POST /v1/requests/test` is available on the remote HTTP listener and encrypted
relay tunnel as well as locally. Only paired `decide` devices can call it
remotely; `view` devices and submit tokens get 403. Unlike arbitrary request
submission, it accepts no caller-supplied content. See the
[test request contract](cli.md#test-requests).

### Managing devices

```sh
handup devices list          # id, scope, name, enabled/disabled, push state, timestamps
handup devices list --json   # includes enabled and push booleans
handup devices disable ID    # pause access and push without unpairing
handup devices enable ID     # resume with the same device token
handup devices mute ID       # stop push notifications, keep API/event access
handup devices unmute ID     # resume push notifications
handup devices scope ID view # read-only; use decide to restore decision access
handup devices revoke ID     # immediate, permanent unpairing
```

Disabling rejects device requests and preview links with HTTP 403
(`device disabled`) and closes open event WebSockets with code 4403. Reconnects
are refused while disabled. Decisions already in flight cannot commit after
disable. Push delivery stops, but the stored push token and relay pairing are
kept; enabling resumes access and push without registering or pairing again.

Muting stops FCM delivery and relay wake-ups without closing event streams or
blocking API access. Push defaults to on, including for existing pairings.
Scope changes apply to the next call, including calls on already-open relay
connections; a device downgraded to `view` cannot decide.

Revocation takes effect on the next request (HTTP 401), and open event
WebSockets for that device close at once with close code 4401. A decision or
cancel commits only if the device still exists with `decide` scope inside the
same database transaction, so a request that is already in flight cannot
approve after its device is revoked. Request bodies are read only after the
token, CSRF, and scope checks pass, and must arrive within 10 seconds (1 MiB
max). Each remote listener serves at most 64 connections at once, and open
event WebSockets count toward that limit. Each paired device may hold at most
16 event subscriptions across listener sockets and relay streams combined; excess requests return
HTTP 429. Slots are released when sockets close. The server pings every 25
seconds and closes sockets that fail to return Pong for two ping intervals.
Connections that send no request
headers within 10 seconds (including the TLS handshake and idle keep-alive
connections) are closed. The API equivalents are local-only:
`GET /v1/devices`, `PATCH /v1/devices/{id}` with any combination of
`{"enabled": false, "push": false, "scope": "view"}`, and `DELETE /v1/devices/{id}`.
PATCH requires at least one field, accepts only `view` or `decide` scope, and
returns the updated device, 404 for an unknown id, or 400 for an invalid/empty
body or a scope change to a submission token. Unknown fields are rejected. None of these
management routes are available through the remote listener or relay tunnel.

## Web UI

The remote listener serves installed web assets from `remote.web_dir`,
`$HANDUP_WEB_DIR` or `<prefix>/share/handup/web`. Distribution must include
these assets; customers should not compile a web UI from application source.
A `view` device sees a read-only inbox.

The browser UI never executes command requests, even on the same computer as
the daemon. **Run** and **Run as admin** exist only in the local desktop app;
phone/web/relay clients only review and decide. The daemon rejects
`run_result` from paired-device credentials, including relay connections.
While a desktop runs a command, the browser shows its elapsed time and limit,
and a `decide` pairing can press **Stop** to ask that desktop to stop it
(`POST /v1/requests/{id}/run/stop`, on the remote listener and relay tunnel;
see [stop from another device](desktop.md#stop-from-another-device)).

The header's **Settings** button opens collapsible **Appearance**, **Decisions**, **Sync**,
**Read aloud**, **Storage**, [**License**](license.md), **Test**, **Keyboard shortcuts**,
[**Help & feedback**](index.md#report-a-bug-or-request-a-feature), and **About** groups. **About** lists the
web UI's version, commit, build date and platform, the daemon's version (a paired
browser shows **see Settings › About on the computer**) and, when the daemon
reports it, the license state; **Copy** puts it all on the clipboard for a bug
report. **Decisions** contains the undo window,
approve button side, and **Swipe cards** on narrow screens; window focus and
**Show output after Run** are desktop-app-only. **Sync** holds **Resync while
open** (Off, 10s, 15s, 30s, 1m, 5m; default 15s, saved per browser): while the
tab is visible the inbox quietly refetches its queue on that timer; it also
resyncs when the tab regains focus or the network comes back. **Storage** shows the computer's
disk use and retention; a `decide` pairing can also clean up and change
retention, a `view` pairing points to the desktop app or `handup storage clean`. **Test** offers **Send test request** and **Send test question**
to the connected daemon (requires `decide` scope). **Keyboard shortcuts** lists
the keys this pairing can use (no decision keys on a `view` pairing, no rule
or Run keys from a browser) and, on touch screens, the swipe and tap gestures.
With a fine pointer and `decide` scope, select a key and press its replacement;
conflicts are refused inline, and **Reset**/**Reset all** restore defaults.
Touch/coarse-pointer and `view` devices keep a read-only list. Overrides save to
the connected computer and update all clients live, not just this browser.
**Settings → Appearance → Layout**, beside **Density**, opens a page with previews: **Split**
(default) puts the list beside the request in windows at least 56rem (896px)
wide, or shows list then request on phones and narrower windows; **Stacked** puts the list above the request on any screen; **Focus**
shows one request at a time; **Rail** uses an icon column with risk dots on
desktop or a horizontal chip strip on phones. Focus and Rail offer **‹ ›**,
**N of M**, and **Queue** to open the full list sheet; desktop Focus also shows
**Next: title**. Density applies inside every layout.

Drag the Split or Stacked divider with a mouse or touch to resize, including
on phones. Arrow keys adjust a focused divider; double-click, double-tap, or
Enter resets it. The Layout page offers **Reset sizes** after resizing.
Split width is 240–640px (default 380px), narrowed so the request keeps at
least 36rem; Stacked height is 15–75% (default 38%).
Layout and pane sizes save per device in the browser's localStorage, not the
daemon config; see the [desktop guide](desktop.md) for the other Settings controls.

Browser protections on the remote listener:

- A **Host** allow-list (the listener address, `remote.public_url`, and
  `remote.web_origin`) blocks DNS rebinding.
- An **Origin** allow-list applies to every request that sends an Origin.
  Cookie-authenticated state changes and WebSocket upgrades must send an
  allowed Origin.
- A **CSRF** check: cookie-authenticated `POST` requests must also send
  `x-handup-csrf`. Its value is derived from the token and exposed to page
  scripts through the non-HttpOnly `handup_csrf` cookie.
- A strict CSP on the app (`default-src 'self'`, `frame-ancestors 'none'`).
- HTML and file previews load from the separate preview port using short-lived
  capabilities bound to the device and request. They get the same sandbox and
  CSP as the desktop app: `sandbox="allow-scripts"` without
  `allow-same-origin`, and network blocked unless `previews.html.allow_network`.
  A revoked or disabled device's preview links stop working.
- Blobs (`/v1/blobs/{hash}`) are agent-supplied, so they never run as the app
  origin. Every response carries `Content-Security-Policy: sandbox;
  default-src 'none'` and `X-Content-Type-Options: nosniff`. Anything other
  than passive images, audio, video, PDF, and plain text (for example HTML,
  SVG, or XML) is sent with `Content-Disposition: attachment`, and the web UI's
  Open button downloads those types instead of opening a tab.

### Read aloud

In a browser with Web Speech synthesis, the speaker button (**Read aloud**) in
a pending request's header reads the agent, title, shortened summary, risk,
questions and, by default, numbered options—not previews, diffs or tool input.
Click **Stop reading** to stop. Changing or deciding the request or leaving
its view stops playback; History has no read-aloud button.

**Settings → Read aloud** saves voice, **Speed**, **Pitch**, **Read options** and
scope per device; **Test voice** plays a sample. Search the voice picker by name,
language name or code, or **Natural**/**Online** labels. **This request** is the default;
**Whole queue** reads the visible pending requests after the open one, selecting
each in turn. **Read new requests** is off by default; when enabled, it can read
a newly arrived request while handup is open and idle, but not the requests
already waiting at first load. Browsers may require a user gesture before
speech can start.

The web UI uses the browser's Web Speech backend and available voices; the
native [desktop](desktop.md#read-aloud) and [Android](mobile.md#read-aloud) apps
use `tauri-plugin-tts` instead. Unsupported browsers hide the request button
and explain the limitation in Read aloud settings. On Linux, install
`speech-dispatcher` and a voice such as `espeak-ng` if the browser offers no
voices. Online voices send the spoken text to the voice provider.

## Direct mode (not recommended)

```yaml
remote:
  mode: direct
  bind: 192.168.1.20          # LAN address; plaintext non-loopback binds are refused
  direct: { accept_risk: true }
  tls: { enabled: true }      # self-signed cert generated and persisted; or set cert + key
```

The daemon refuses to start in direct mode without `accept_risk: true` and TLS,
and it refuses plaintext listeners outside loopback and the tailnet. When `tls.cert` and
`tls.key` are empty, handup generates a self-signed certificate under the state
directory, reuses it across restarts, and pins its fingerprint in the pairing
QR code. At every start the daemon prints this warning, `handup doctor` reports
it, and every UI shows it as a persistent red banner (`remote_warning` in
`GET /v1/ui-settings`):

> Anyone who can reach this port and obtain a device token can approve arbitrary actions your agents take, including running commands on this machine. Prefer `tailscale` mode. Never port-forward without TLS; use short token lifetimes and revoke unused devices.

### Rate limits

In every remote mode, and per peer IP:

- 5 pairing exchanges per minute. Every attempt counts, even before its body arrives.
- 10 failed authentications per minute. After that, requests get HTTP 429 until the window passes.

## Notification backends

`notifications.backends` accepts `desktop`, `ntfy`, and `fcm`. Every
backend follows `on_new_request`, `on_high_risk` (high risk bypasses
`quiet_hours`), `on_expiring`, `remind_every`, and `quiet_hours`. Delivery runs
in the background with bounded timeouts (10 seconds; FCM 15 seconds per HTTP call), and failures are logged without
blocking the queue.
Requests without a deadline do not emit `on_expiring` notifications.
`remind_every` (off by default) re-notifies while they wait for the human.

```yaml
notifications:
  backends: [desktop, ntfy]
  ntfy: { server: https://ntfy.sh, topic: "", token_env: HANDUP_NTFY_TOKEN, include_content: false }
```

**fcm** delivers Android native notifications to registered paired devices.
Configure `notifications.fcm.service_account` with a Firebase service-account
JSON key path and `notifications.fcm.payload` with `title` (default) or `wake`
(generic title). Payloads contain only request id, risk, and redacted title,
never previews. Decide/cancel/expire also send cancellation messages, independent
of quiet hours. Invalid/unregistered provider tokens are removed automatically.
The app registers or removes its own token at `PUT` / `DELETE
/v1/devices/self/push` with device-token auth (view or decide scope). Device
revocation removes registration. See [Android notifications](mobile.md#notifications)
for Firebase project and APK setup.

**ntfy** publishes JSON to `<server>/` with the topic, the redacted title, and
the deep link `handup://r/<id>` as the message. When remote access is on, the
click URL opens `<web UI>/#/r/<id>`. Priorities: 5 (urgent) for high risk, 4
for medium, 3 for low. Preview content is never sent unless
`include_content: true`, which adds the summary, inline preview text and email previews. If the
environment variable named by `token_env` is set, its value is sent as a bearer
token. handup refuses to send that token over plaintext `http://` to anything
other than loopback: the notification is skipped and a warning is logged. Use
a hard-to-guess topic, or better, a self-hosted server. Anyone who knows a
public topic can read it.

Lifecycle webhooks and local commands are configured separately under top-level
`hooks:`. They run independently of notification policies and also receive
decisions, cancellations, and expirations. See [event hooks](integrations/hooks.md)
for signing, templates, migration, and automation recipes. The old
`notifications.webhook` configuration and `webhook` notification backend are
removed; loading them reports a migration hint.

## Keys

| Key | Default | Meaning |
| --- | --- | --- |
| `remote.mode` | `off` | `off`, `tailscale`, or `direct`; restart the daemon to apply |
| `remote.bind` | empty | Listener IP; tailscale discovers it when empty |
| `remote.port` | `7466` | API and web UI |
| `remote.preview_port` | `7467` | Separate preview origin |
| `remote.public_url` | empty | Externally visible origin for pairing links and Host checks |
| `remote.web_dir` | empty | Built UI directory |
| `remote.web_origin` | empty | Extra trusted browser origin |
| `remote.tls.enabled` | `false` | TLS on the remote listener (required for direct) |
| `remote.tls.cert`, `remote.tls.key` | empty | Your PEM cert and key; empty generates a self-signed pair |
| `remote.direct.accept_risk` | `false` | Required for direct mode |

Every `remote.*` key (relay included) applies only after a daemon restart; the
clients show **Restart daemon to apply** until then. Other settings, such as
`notifications.*`, apply when the config is saved ([live reload](cli.md#live-reload)).

The Android app is a native client of the same remote listener; see
[mobile.md](mobile.md). Native FCM push and the end-to-end encrypted
[relay](relay.md) (FCM/APNs wake-ups) are available; native APNs delivery from
the daemon is not.
