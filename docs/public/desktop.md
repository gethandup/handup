# Desktop app

The desktop app is a window onto the same local queue that `handup ls` shows.
It talks to the daemon over the unix socket from its Rust process; the bearer
token never reaches the web view.

## Install (Linux)

Build locally with `make app-build` (needs `cargo install tauri-cli --locked`,
pnpm, and the webkit2gtk-4.1, libayatana-appindicator, and librsvg dev
packages). Read aloud also needs Speech Dispatcher headers and libclang:
on Arch, install `speech-dispatcher` and `clang`; on Debian/Ubuntu, install
`libspeechd-dev libclang-dev`. The bundles land in `target/release/bundle/`:

- AppImage: `chmod +x handup_*.AppImage && ./handup_*.AppImage`
- Debian/Ubuntu: `sudo apt install ./handup_*_amd64.deb`

Both bundles ship the `handup` CLI next to the app. If no daemon is running,
the app starts `handup serve`. You can also start it from the "Daemon not
running" screen.

From a checkout, `make app-install` builds the CLI and app and installs them to
`~/.local/bin`.

Run `handup ui` to open the inbox, or `handup ui --next` to open the compact
quick window on the oldest pending request. Only one instance runs at a time,
so a second launch focuses the existing window. Closing the main window hides
it to the tray, and the tray icon shows the pending count. If the app binary
was replaced since the running instance started (an upgrade), re-opening it
from the launcher, `handup ui`, or the tray menu starts the new version and
exits the old one.

## Run a command

Run is offered only for a request with exactly one command preview and one
approve option, with no question, nonempty form fields or free-text answer.

For an eligible pending command request, **Run** executes the command shown
on this computer. It uses the command preview's working directory, then the
request's source cwd, or your home directory if neither is set. Shell commands
use a supported `$SHELL` as a login shell, falling back to `/bin/sh`; argv
commands run directly. Review the command and cwd before clicking: this is
execution, not just permission for the agent.

Output streams into the request while it runs. **Cancel** stops the run;
commands still running after **10 minutes** are stopped automatically. Ordinary
runs stop the process group. The final result includes redacted stdout/stderr
tails (up to 64 KiB each), exit code, duration and any error, and appears in History.
Output is shown as a terminal would leave it: colour and other escape codes are
stripped, `\r` progress updates keep only their last state, and control characters
are dropped. The request view and History show every stored line.

`R` presses **Run** (or **Run as admin**) for the request on screen. When the run
finishes, the request leaves the queue and the inbox moves to the next one; the
footer notice says how it went and its **Output** button opens the full output.
Settings → Decisions → **Show output after Run** opens that output by itself:
**Never** (default), **On failure** (nonzero exit, error, or result not sent to
the agent) or **Always**.

Before starting, the desktop claims the request in the daemon. Its status stays
`pending` with `run` metadata (`started_at`, `lease_until`, `elevated`); phone and
web show **Running**. Other decision surfaces receive HTTP **409**,
`running in the desktop app`, while the claim is active. Agent cancellation
remains allowed and tells the desktop to stop the run. Request expiry and timeout
decisions are paused while claimed. The claim has a **12-minute lease**: if the
app crashes or cannot report, the claim lapses and ordinary decisions and expiry
resume. This does not extend the command's 10-minute execution limit.

The local-only API routes are `POST /v1/requests/{id}/run` with
`{"content_hash":"…","elevated":false}` to claim, and
`POST /v1/requests/{id}/run/release` to release a claim if nothing started.
They are available on the Unix socket and authenticated loopback listener,
not the remote/relay router; paired devices cannot claim or release runs.

For a command starting with `sudo`, the button is **Run as admin** instead.
Linux uses `pkexec` with polkit's graphical authentication prompt; install
pkexec/polkit and ensure a polkit authentication agent is running in your desktop
session. macOS uses `osascript` with the system administrator prompt (macOS is
untested). handup does not store or pipe passwords. It removes only the leading
`sudo`; sudo options such as `sudo -u root …` are unsupported. A later or nested
`sudo` is not rewritten or given this admin path: copy complex commands and run
them yourself.

On Linux, pkexec starts a root supervisor that owns the command's process group.
Cancel, timeout or desktop exit closes its stdin, telling it to kill the group;
a root-side timer also stops it if the desktop loses control. On macOS,
cancelling or timing out can stop the administrator prompt, but handup **cannot
stop the command once it runs as root**; it may continue running.

After a command starts, the desktop sends an **approve** decision with
`run_result`, even for a nonzero exit, desktop cancellation or timeout.
If nothing starts (including launch failure or administrator authentication
refusal), it releases the claim and leaves the request pending. Agent
cancellation leaves the request cancelled, so a later run result cannot replace
that decision. If submission fails, the desktop reports that the result was
not sent to the agent. An approved status does not mean the command succeeded:
agents must read the result and **not run it again**; permission hooks block
the original tool call with a run summary to prevent duplicate execution.
If validation fails before starting, the request stays pending. Run decisions
are sent immediately, not held for Undo; Undo cannot reverse command side effects.
CLI `ask --wait`, `wait`, `status` and `show` return **exit 5** for a decision
carrying `run_result`, regardless of the command's exit code. Human feedback is
preserved in the decision and appended to the run summary.

The manual path is unchanged: copy, run it yourself, then Approve. Ordinary
Approve does not execute the command. **Phone, browser/web and relay clients
never run commands**, and the daemon rejects `run_result` submitted by paired
devices. Execution exists only in the local desktop app.

## Keys

| Key | Action |
| --- | --- |
| `j` / `k` | Next / previous request |
| `a` | Approve |
| `d` | Deny |
| `u` | Undo the newest decision still waiting to be sent; press again for the one before |
| `f` | Focus the feedback box |
| `r` | Run / Run as admin (desktop app, eligible command requests) |
| `o` / `Enter` | Open the file on screen in its default app (in a file bundle, the file picked in the list) |
| `p` | Widen the preview (hide the list); `p` or `Esc` to go back |
| `Shift+P` | Allow in project |
| `t` | Toggle light/dark theme |
| `h` | Switch between Inbox and History |
| `i` | Back to the Inbox |
| `m` | Devices (desktop app) |
| `?` | Show all shortcuts |

While the app stays visible, decisions wait 5 seconds before they reach the
daemon. Hiding or leaving the app sends held decisions immediately, ending
their undo window, and tries every queued decision, even for computers whose
connection looked down. Decisions that still fail stay in the outbox.
Press `u` (or click Undo) within that window and the request stays pending;
each press takes back
the newest decision still waiting. Decide several in a row and each one keeps
its own countdown and **Undo**: the newest sits in the footer, older ones stack
just above it (up to four, then "+N more"), so you can take back any of them
without the footer moving. Change the wait per device under
**Settings → Decisions → Undo window** (3s to 30s), or for every client with
`handup config set decisions.undo_window 10s`.

Approve, Submit and an agent's primary option sit on the right of the action
row, with Deny and Decline to their left and extras such as **Edit & approve**,
**Allow for session** and **Raw JSON** on the far side; Undo appears above the
primary action. Left-handed? `handup config set decisions.primary_side left`
mirrors every decision row for all clients, and **Settings → Decisions →
Approve button side** (Default, Right, Left) overrides it on one device.

`t` switches to an explicit light or dark theme. The **Settings** button in the
header opens a dialog with collapsible **Appearance**, **Decisions**,
**Read aloud**, and **Test** groups. **Appearance** sets the theme (System,
Light, Dark), color palette, density, and layout. **Decisions** holds the undo
window, approve button side, **Swipe cards** on narrow screens (on by default),
and the desktop-only **Focus on new requests** switch and **Show output after Run**.
**Palette** picks the colors for the whole app and for code in diffs and file
previews: handup (default), Catppuccin, Gruvbox, Solarized, Rosé Pine, GitHub,
Everforest, Tokyo Night, Nord, One, Kanagawa, Ayu, Flexoki, or Dracula. Each has
a light and a dark variant (for example Catppuccin Latte and Mocha), and the
theme picks which one you see. **Density** opens its own page with a live
preview of each choice: **Compact** (default) shows expiry, agent, and location
as small tabs on the preview, **Comfortable** shows them in a roomy header, and
**Ultra-compact** also trims list rows and headers. The risk badge always sits
in the request header. Density applies inside every layout. Theme, palette,
density, layout, pane sizes, undo window and Approve button side are saved per device.

**Settings → Appearance → Layout** opens its own page with a preview of each choice:

- **Split** (default): the list sits beside the request; on phones, open a
  request from the list.
- **Stacked**: the list sits above the request, including on phones.
- **Focus**: one request at a time, with **‹ ›**, **N of M**, and a **Queue**
  button that opens the full list in a sheet. Desktop also shows **Next: title**.
- **Rail**: an icon column with risk dots on desktop, or a horizontal chip strip
  on phones, plus **‹ ›** and **Queue**.

Drag the divider in Split or Stacked to resize with a mouse or touch, on
desktop or mobile. Focus the divider and use arrow keys to adjust it;
double-click, double-tap, or press Enter to reset. The Layout page also offers
**Reset sizes** after resizing. Split width is 240–640px (default 380px);
Stacked height is 15–75% (default 38%).

**Settings → Decisions → Focus on new requests** (off by default) brings the handup window to
the front when a request needs a decision: the quick window if it is open,
otherwise the inbox, also when the inbox was closed to the tray. It watches the
daemon's event stream itself, so it works while desktop notifications are
silenced. Requests that rules or YOLO mode decide on arrival do not raise it.

While it is on, **Ignore input after focus** (Off, 0.5s, 1s default, 2s)
protects against typing meant for another app, as browsers do for permission
prompts: for that long after the window gains focus, keys and clicks are
ignored, and a key already held down stays ignored until it is released, so a
stray `a`, `d`, or Enter cannot approve or deny. A short **Input ignored**
notice appears when it drops input.

The **YOLO** switch in the header turns on [YOLO mode](rules.md#yolo-mode):
**YOLO** auto-approves new low and medium risk requests, **Hard YOLO** every
risk, for 15m, 1h, 4h, or until turned off. While it is on the header shows a
warning pill (**HARD YOLO** in the destructive color) with the time left.

If the daemon stops after the inbox has loaded, the inbox stays up and the
header shows **Reconnecting…** then **Offline since hh:mm** (click to retry, or
**Start daemon**). Decisions made meanwhile wait in the outbox with **Undo** and
are sent in order once the daemon is back.

**Settings → Test** offers **Send test request** and **Send test question**.
The desktop app sends to its local daemon; the web UI sends to the daemon it
is connected to. The daemon builds a harmless low-risk sample titled
**Test request** or **Test question**, with agent `handup`, session
`handup-test`, and a 15-minute timeout. Approving or denying it performs no
action. Use it to try previews, questions, notifications, and the decision flow.
Remote clients need `decide` scope; view-only devices cannot send tests.

## Read aloud

Click the speaker button (**Read aloud**) in a pending request's header;
click **Stop reading** to stop. It reads the agent, title, a shortened summary,
risk, questions and, by default, numbered options—not previews, diffs or tool
input. Moving to another request, deciding it, or leaving the request view
stops playback; History has no read-aloud button.

**Settings → Read aloud** saves settings on this device: voice, **Speed**,
**Pitch**, **Read options**, and **Test voice**. The voice picker has a search
field that filters by voice name, language name or code, and **Natural** or
**Online** labels. **Read → This request** is the default;
**Whole queue** continues through the visible pending requests after the open
one, selecting each in turn. **Read new requests** is off by default; when
enabled, it can read a newly arrived request while handup is open and idle,
but does not read the requests already waiting at first load.

The desktop app uses native TTS through `tauri-plugin-tts`, not browser speech
synthesis. On Linux it needs `speech-dispatcher` and an installed voice such as
`espeak-ng`; install them and restart the app if no voices appear. Debian
bundles declare the `libspeechd2` runtime library dependency, but you still need
the Speech Dispatcher service and a voice. Other desktop platforms use their
OS speech backend (macOS remains untested). Voices come from the device;
online voices send the spoken text to the voice provider.

## History

The **Inbox | History** switch at the top of the list (or `h`) shows resolved
requests, newest first and grouped by day. Each row shows the outcome
(approved, denied, expired, cancelled, or auto for rule and YOLO decisions), the agent,
and when it was resolved. Search matches the title, summary, and folder; the
chips filter by outcome, **Files** (file, bundle, image, PDF, audio, or video
previews), and request kind (Command, Edit, Review, Question, or Custom).
Filters combine; tap the selected Files/kind chip again to clear it.
Changing filters discards any older page still loading for the previous filters.
`j`/`k` move and `/` focuses search. Inbox remains the default view.

The detail pane is the request as it was asked, read-only, with a summary of
who decided it (this computer, a paired device by name, a rule, or the timeout),
the chosen option, feedback, and answers, plus any desktop Run's exit status and
full stored output. **Audit trail** expands every event.
Attachments retain their **Open** and **Download** actions in read-only history.

The API is `GET /v1/history` with optional `outcome`, `agent`, `type` (one
preview type), `has=attachments`, `kind`, and `q` (title, summary, folder).
All filters combine. `limit` defaults to 50 (maximum 500); pass `next_cursor`
as `cursor` with the same filters to fetch older results without duplicates.
Paired view/decide devices can also read `GET /v1/requests/{id}/audit`;
submission tokens cannot access history or request audit.
History keeps the last `history.keep_days` days and `history.max_requests`
decisions (90 and 2000 by default); older ones are deleted.

## Pair a phone

The phone button in the header opens **Pair a phone**, the desktop version of
`handup pair`. It shows a QR code for the handup app or the phone's camera,
the link with a Copy button, and the TLS certificate fingerprint when the
remote listener uses TLS. Pick **Can decide** or **View only**. When
`remote.relay.url` is set, **Through the relay** pairs through the
[end-to-end encrypted relay](relay.md) instead; it starts on when
`remote.mode` is `off`.

Each code works once and expires after 2 minutes; the dialog counts down and
**New code** issues a fresh one. When a phone uses the code, the dialog shows
"Paired: <name>". If remote access is off, the dialog explains how to turn it
on (`handup config set remote.mode tailscale`, then restart the daemon) and
links to [Remote access](remote.md). The button exists only in the desktop
app: pairing codes are local-only, so the web UI and the mobile app never
offer it.

## Devices

The devices button in the header (or `m`) opens **Devices**: the phones and
browsers paired with this computer, newest first, with when each was paired
and last seen. Integration credentials are not listed. Per device:

- **Can decide** / **View only** changes its access. It applies at once, also
  to an open app or browser tab.
- **Enabled** off blocks the device (403) without unpairing it; turn it back on
  to restore access.
- **Push** off stops push notifications and relay wake-ups to it; it keeps
  access to the queue.
- **Revoke** (after a confirmation) unpairs it; it has to pair again.

Errors show under the device; the list refreshes after each change. With no
devices, **Pair a phone** opens the pairing view in the same dialog. Like
pairing, device management is local-only (`PATCH`/`DELETE /v1/devices/{id}`),
so only the desktop app offers it.

## Quick window on Hyprland

```ini
bind = SUPER, A, exec, handup ui --next
windowrule = float, title:^(handup: next request)$
```

## Previews

HTML previews load from a separate `handup-preview:` origin inside a sandboxed
iframe with no `allow-same-origin`. The origin's CSP blocks network access, and
Tauri IPC is not exposed to it.

On Linux, audio and video play through GStreamer. If a clip says it could not
be decoded, install `gst-plugins-good`, `gst-plugins-bad`, and `gst-libav`
(package names vary by distro). The Linux and Android apps load the whole clip
before it plays, so they download it only when you tap **Play**; the request
itself opens at once.

## macOS (untested)

`make bundle-macos` on macOS produces a universal `.dmg` signed ad hoc
(`signingIdentity: "-"`), with no Apple Developer ID. This has not been tested
on a Mac. Gatekeeper will refuse the first launch. After copying the app to
`/Applications`, run:

```sh
xattr -dr com.apple.quarantine /Applications/handup.app
```

Or right-click the app and choose Open.
