# Desktop app

The desktop app is a window onto the same local queue that `handup ls` shows.
It talks to the daemon over the unix socket from its Rust process (on Windows,
the token-gated loopback listener); the bearer token never reaches the web
view.

## Install

Use the compiled desktop package for your OS and architecture from
[downloads and releases](downloads.md): AppImage, `.deb` or `.rpm` (Linux
x86-64), `.dmg` (macOS) or the Windows installer. Linux is the primary
platform. No Rust toolchain or source build is required.

On Windows x86-64 the desktop app is a beta: run
`handup-desktop_<version>_amd64-setup.exe` (see
[downloads](downloads.md#windows); it is not code-signed, so SmartScreen asks
you to confirm with **More info** → **Run anyway**). It installs per user,
bundles `handup.exe` next to the app and starts the daemon on launch. Running
commands from a request is not supported on Windows; the tray is untested
there, and the daemon's desktop notifications have no action buttons.

The desktop app is an inbox for the `handup` daemon; install the CLI too (see
[downloads](downloads.md)) so `handup` is on your PATH. If no daemon is
running, the app starts `handup serve`. You can also start it from the
"Daemon not running" screen.

Run `handup ui` to open the inbox, or `handup ui --next` to open the compact
quick window on the oldest pending request. Only one instance runs at a time,
so a second launch focuses the existing window; `handup ui --next` switches a
running app to the quick window on Linux and macOS alike. On launch the inbox
keeps its default size when it fits, and on small displays shrinks to 90% of
the monitor's work area (menu bar, dock and panels excluded), centered. Closing the main window hides
it to the tray, and the tray icon shows the pending count. If the app binary
was replaced since the running instance started (an upgrade), re-opening it
from the launcher, `handup ui`, or the tray menu starts the new version and
exits the old one.

## Inbox filters

The desktop app, Android app and web inbox share one row of quick filter chips.
In **Inbox**, request types with pending requests show a count; a selected type
stays available even if its count drops to zero. Pick several types to show any
of them, or tap a selected chip again to remove it. There is no **All** chip:
nothing selected shows every pending request.

**Filters** opens a small dialog on desktop or a bottom sheet on phones, with
**Type** and **Agent** sections. Several picks in one section match any of them
(OR); picks across sections must all match (AND). For example, Command or Edit
plus agent `codex` shows only Codex's commands and edits. Agent picks appear
after a divider in the row as removable chips, and the Filters button's badge
counts those picks. A reset icon appears at the row end while filters or an
Inbox query are active; it clears all picks and closes Inbox search. The row
stays on one line and scrolls sideways with a swipe or mouse wheel instead of
hiding chips in a More menu.

Tap the search icon in the Inbox filter row or press `/` to open and focus
search. The field is hidden by default, with no setting to enable it.
It matches a case-insensitive substring in the title, summary, folder (`cwd`),
repo, branch, agent, or session title, and combines with chip/sheet filters
(AND). No matching pending requests shows **No matches**, not **All clear**.
`Esc` in the field or **×** clears and closes search without changing filters;
the reset icon clears both. `/` also focuses search in History. Search is not
available in the Auto-handled view or the compact quick window.

When automatic decisions are unread, a line above the list, such as
**3 auto-handled · View**, opens the read-only **Auto-handled** view. It is not
a filter tab. **← Inbox** returns to pending requests; **Mark read** moves
those decisions out of this view and leaves them available in History. Read
state is shared across every device connected to the same daemon, separately
for each computer, and survives daemon restarts. A paired device needs
`decide` access to update that shared state; `view` access can follow it.
See the [auto-read API](cli.md#auto-handled-read-state).

## Run a command

Run is offered only for a request with exactly one command preview and one
approve option, with no question, nonempty form fields or free-text answer.

For an eligible pending command request, **Run** executes the command shown
on this computer. It uses the command preview's working directory, then the
request's source cwd, or your home directory if neither is set. Shell commands
use a supported `$SHELL` as a login shell, falling back to `/bin/sh`; argv
commands run directly. Review the command and cwd before clicking: this is
execution, not just permission for the agent.

Output streams into the request while it runs, under `<elapsed> elapsed ·
stopped after <limit>`. **Cancel** stops the run, and so does reaching the
limit: `run.timeout` (default **10m**), or the request's own `run_timeout`
(`handup ask --run-timeout 30m`, MCP/API `run_timeout`), never more than
`run.max_timeout` (default **1h**). Both keys apply live (see
[run limits](cli.md#run-limits)). Stopping sends SIGTERM to the command's
process group, waits up to 5 seconds for the command and everything it started
to exit, then sends SIGKILL to what is left; the result arrives only once the
whole group is gone, and its error says which (`cancelled; terminated`,
`timed out; killed`).
The final result includes redacted stdout/stderr
tails (up to 64 KiB each), exit code, duration and any error, and appears in History.
Output is shown as a terminal would leave it: colour and other escape codes are
stripped, `\r` progress updates keep only their last state, and control characters
are dropped. The request view and History show every stored line.

The command's input is closed, so a command waiting for a terminal prompt
fails. One waiting on a window, a dialog or the network can still hang: after
30 seconds without output the running view says **No output for 45s** (the
silent time so far) with that hint. Cancel it, or let the limit stop it.

`R` presses **Run** (or **Run as admin**) for the request on screen. When the run
finishes, the request leaves the queue and the inbox moves to the next one; the
footer notice says how it went and its **Output** button opens the full output.
Settings → Decisions → **Show output after Run** opens that output by itself:
**Never** (default), **On failure** (nonzero exit, error, or result not sent to
the agent) or **Always**.

Before starting, the desktop claims the request in the daemon. Its status stays
`pending` with `run` metadata (`started_at`, `lease_until`, `elevated`,
`timeout_ms`, and `stop` once a stop is asked). Other decision surfaces receive
HTTP **409**, `running in the desktop app`, while the claim is active. Agent
cancellation remains allowed and tells the desktop to stop the run (`the
request was cancelled while it ran; terminated`). Request expiry and timeout
decisions are paused while claimed. The claim's lease is the run limit plus
**2 minutes** to stop the command and report. If the app crashes or stops
responding, the lease lapses: the request shows **Run interrupted (desktop
stopped responding)**, records `run_interrupted` (also an audit event), and
ordinary decisions and expiry resume. No result reaches the agent from that run.

The claim routes are local-only: `POST /v1/requests/{id}/run` with
`{"content_hash":"…","elevated":false}` to claim, and
`POST /v1/requests/{id}/run/release` to release a claim if nothing started.
They are available on the Unix socket and authenticated loopback listener,
not the remote/relay router; paired devices cannot claim or release runs.

For a command starting with `sudo`, the button is **Run as admin** instead.
Linux uses `pkexec` with polkit's graphical authentication prompt; install
pkexec/polkit and ensure a polkit authentication agent is running in your desktop
session. macOS uses `osascript` with the system administrator prompt.
handup does not store or pipe passwords. It removes only the leading
`sudo`; sudo options such as `sudo -u root …` are unsupported. A later or nested
`sudo` is not rewritten or given this admin path: copy complex commands and run
them yourself.

On Linux, pkexec starts a root supervisor that owns the command's process group.
Cancel, the limit, a stop from another device or desktop exit closes its stdin,
and the supervisor stops the group as root the same way (SIGTERM, up to 5
seconds for everything in it to exit, then SIGKILL; exit 137 means it was
killed), and reports only once the whole group is gone. A root-side timer also
stops it shortly after the limit if the desktop loses control. On macOS,
cancelling or timing out can stop the administrator prompt, but handup **cannot
stop the command once it runs as root**; it may continue running.

After a command starts, the desktop sends an **approve** decision with
`run_result`, even for a nonzero exit, cancellation, timeout or a stop from
another device.
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
never run commands** (they can only ask the desktop to stop one), and the
daemon rejects `run_result` submitted by paired devices. Execution exists only
in the local desktop app.

### Stop from another device

Every other client viewing a request that runs on a desktop (a phone, the
browser, another desktop window) shows **Running in the desktop app** with the
elapsed time, the limit and a **Stop** button (hidden on view-only devices).
Stop asks the desktop running it to stop the command; the button then shows
**Stopping…** with **Stop asked from _device_**. The desktop checks every second
and stops it as Cancel does, reporting `stopped from <device>; terminated` (or
`killed`). `handup stop ID` does the same from a terminal.

The API is `POST /v1/requests/{id}/run/stop` with body `{}`. It records
`run.stop` = `{by, at}` (`by` is the paired device's name, or `this computer`),
emits `request.updated` and is audited as `run_stop_requested` (actor
`device:<id>` or `local`). It answers **409** when nothing runs; repeating it
changes nothing. It is available locally, on the remote listener and through
the relay tunnel; paired devices need `decide` scope, checked again when the
stop is recorded: a device disabled, downgraded to view-only or revoked by then
gets **403** and the run is left alone.

## Keys

The `?` sheet and **Settings → Keyboard shortcuts** list the same keys, grouped
as Navigate, Decide, Questions and View, and show only those that work on this
device: a view-only device hides decision keys, the quick window hides list
keys, and in History the sheet shows History's keys. Keys are ignored while you
type in a field, except `Esc` (leaves it) and `Ctrl+Enter` (`⌘+Enter` on macOS).

In the inbox's **Feedback for the agent** or **Reply to the agent** box,
`Ctrl+Enter` (`⌘+Enter` on macOS) sends the primary decision with your text:
**Approve** on an approval request, **OK** on a notice. Plain Enter inserts a
newline. At medium and wider widths, the label shows the focus key (default
`F`) and `Ctrl+Enter approves` or `Ctrl+Enter sends` (`⌘+Enter` on macOS);
the shortcut still works when the hint is hidden on a narrow screen.

The table below shows the defaults. To change a shortcut, open **Settings →
Keyboard shortcuts**, select its key button and press the new key. `Esc` cancels
capture; `Tab` leaves it. A taken key is refused inline, naming the other action;
change that action first or choose another key. **Reset** restores one changed
row (unless its default is now taken); **Reset all** restores every default.
`Esc`, `Enter`, arrows (including Shift+arrows), `g g`, `Home`/`End`,
`Space`, `Tab`, `1`–`9` and `Ctrl+Enter`/`⌘+Enter` are built in and cannot be
remapped. `g` and `Home` stay reserved for the first request; `End` stays
reserved for the last even if you change `Shift+G`. Home/End also move to the
first/last answer while choosing a question's answers.

Shortcuts save to the connected computer's daemon config (`keys:`), not to this
device's preferences. Settings changes apply live to every connected window and
device, including button hints and the shortcut sheet. The editor is available
with a fine pointer on the local app or a `decide` pairing; touch/coarse-pointer
and view-only devices show a read-only list. You can also use
[`handup config set keys.<id>`](cli.md#keyboard-shortcut-configuration).

| Key | Action |
| --- | --- |
| `j` / `k` (or `↓` / `↑`) | Next / previous request (also in History) |
| `g g` (second `g` within 1 second) or `Home` | First request (also in History; built in) |
| `Shift+G` (or `End`) | Last request (also in History; `Shift+G` is remappable) |
| `Shift+J` / `Shift+K` | Extend the selection |
| `Shift+A` | Select the whole session |
| `/` | Open/focus Inbox search or focus History search (not Auto-handled or the quick window) |
| `h` | Switch between Inbox and History |
| `i` | Back to the Inbox |
| `Esc` | Leave a field, the wide preview or the selection; close a sheet |
| `a` | Approve (every selected request); on a notice, OK |
| `d` | Deny; decline a question; dismiss a notice |
| `s` | Allow for session |
| `Shift+P` | Allow in project |
| `1`–`9` | Pick an option (on a question: an answer) |
| `e` | Edit & approve |
| `Ctrl+Enter` (`⌘+Enter` on macOS) | Approve with the typed feedback (OK on a notice), approve the edited input, or submit a question, even while typing |
| `f` | Focus a question's reply box, else the feedback box (`Esc` leaves it; Enter inside it is a newline, `Ctrl+Enter` sends) |
| `r` | Run / Run as admin (desktop app, eligible command requests) |
| `u` | Undo the newest decision still waiting to be sent; press again for the one before |
| `Enter` | On a question, submit once every question is answered (a question's only choice, such as OK, counts as answered, so an OK-or-reply question submits without typing); otherwise step into the first open question's answers (`↑`/`↓` or `j`/`k` move, `Space` or `Enter` chooses, `Tab` goes to the next field, `Esc` returns to the list). Enter never moves into a reply box: press `f`. On a notice, OK; otherwise like `o` |
| `o` | Open the file on screen in its default app (in a file bundle, the file picked in the list) |
| `Ctrl+E` / `Ctrl+Y` | Scroll the request on screen down / up a line (also in History) |
| `Ctrl+D` / `Ctrl+U` | Scroll the request on screen down / up half a screen (also in History) |
| `PageDown` / `PageUp` | Scroll the request on screen down / up a screen (also in History) |
| `p` | Widen the preview (hide the list); `p` or `Esc` to go back |
| `t` | Toggle light/dark theme |
| `m` | Devices (desktop app) |
| `?` | Show the shortcuts (the sheet also links **Report a bug**) |

The scroll keys move the request detail, not the list, and can be remapped.
`Ctrl+F` / `Ctrl+B` are not taken; `Ctrl+F` stays available for browser Find.

Decision buttons show their effective key; the hints change with your shortcuts.
Submit keeps the built-in `Ctrl↵` or `⌘↵`.

While the app stays visible, decisions wait 5 seconds before they reach the
daemon. Hiding or leaving the app sends held decisions immediately, ending
their undo window, and tries every queued decision, even for computers whose
connection looked down. Decisions that cannot reach the daemon stay queued in
the outbox.
Press `u` (or click Undo) within that window and the request stays pending,
with the feedback, answers and edited input you typed still filled in; each
press takes back
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

An info notice (`kind: info`, from MCP `notify` or `handup ask --kind info`)
needs no decision: it shows **OK** on the primary side and **Dismiss** beside
it. `a`, Enter or a right swipe picks OK, `d` or a left swipe picks Dismiss; either
records `status: dismissed`, with `decision.option` `ok` or `dismiss`.
Dismissals use the same Undo window. An optional **Reply to the agent** box
(`f` focuses it) sends its text with OK or Dismiss; the agent receives it on its
own (see [notice replies](agents/mcp.md#notice-replies)), and an empty box
tells the agent nothing. Desktop notifications for a notice show its redacted
summary with **OK** and **Dismiss** actions, which send no reply.

`t` switches to an explicit light or dark theme. The **Settings** button in the
header opens a dialog with collapsible **Appearance**, **Decisions**, **Sync**,
**Read aloud**, [**Dictation**](#dictation), [**Storage**](#storage), [**License**](license.md), **Test**, **Keyboard shortcuts**,
[**Help & feedback**](index.md#report-a-bug-or-request-a-feature), and **About** groups. **Appearance** sets the theme (System,
Light, Dark), color palette, density, and layout. **Decisions** holds the undo
window, approve button side, **Swipe cards** on narrow screens (on by default),
and the desktop-only **Focus on new requests** switch and **Show output after Run**.
**Sync** holds **Resync while open** (Off, 10s, 15s, 30s, 1m, 5m; default
15s): while the window is visible and the daemon is reachable, the inbox
quietly refetches its queue on that timer in case a live update was missed.
**Storage** belongs to the computer's daemon, not the device.
**About** lists the app version, commit, build date, platform, the daemon's
version and commit (or **unreachable**), and the license state; **Copy** puts
all of it on the clipboard as plain text for a bug report.
**Keyboard shortcuts** lets you edit the [keys](#keys) this device can use when
connected locally or with `decide` scope and using a fine pointer. On touch/coarse-pointer
or view-only devices it is read-only; touch screens also list the gestures:
swipe right or left to decide, **Undo**, tap a row, the back gesture, and the
resizable divider. Shortcut overrides belong to the computer's daemon.
**Palette** picks the colors for the whole app and for code in diffs and file
previews: handup (default), Catppuccin, Gruvbox, Solarized, Rosé Pine, GitHub,
Everforest, Tokyo Night, Nord, One, Kanagawa, Ayu, Flexoki, or Dracula. Each has
a light and a dark variant (for example Catppuccin Latte and Mocha), and the
theme picks which one you see. **Density** opens its own page with a live
preview of each choice: **Compact** (default) shows expiry, agent, and location
as small tabs on the preview, **Comfortable** shows them in a roomy header, and
**Ultra-compact** also trims list rows and headers. The risk badge always sits
in the request header. Density applies inside every layout. Theme, palette,
density, layout, pane sizes, undo window, Approve button side and resync timer are saved per device.

**Settings → Appearance → Layout** opens its own page with a preview of each choice:

- **Split** (default): the list sits beside the request in windows at least
  56rem (896px) wide. Narrower windows, such as one tiled to half the screen,
  work like phones: open a request from the list, then go back to the list.
  History works the same way.
- **Stacked**: the list sits above the request, including on phones.
- **Focus**: one request at a time, with **‹ ›**, **N of M**, and a **Queue**
  button that opens the full list in a sheet. Desktop also shows **Next: title**.
- **Rail**: an icon column with risk dots on desktop, or a horizontal chip strip
  on phones, plus **‹ ›** and **Queue**.

Drag the divider in Split or Stacked to resize with a mouse or touch, on
desktop or mobile. Focus the divider and use arrow keys to adjust it;
double-click, double-tap, or press Enter to reset. The Layout page also offers
**Reset sizes** after resizing. Split width is 240–640px (default 380px), and
the list narrows so the request keeps at least 36rem (576px); Stacked height is
15–75% (default 38%).

Previews fit the width of the request pane, not the window: in a narrow pane
request titles wrap to two lines, preview tabs scroll sideways (arrows and edge
fades show when tabs overflow; wheel or drag to scroll), the files and
diff file lists sit above the content, and diffs start unified (switch to split
with the toggle) when the preview is under 768px.

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

When one agent session sends a flood of requests (40 in a minute by default),
a banner at the top of the inbox list says "*agent* · *session* sent *N*
requests in the last minute". **Mute 1h** silences its notifications for an
hour (**Unmute** undoes it), **Dismiss all (N pending)** asks for confirmation,
then dismisses its pending notices and denies its other pending requests, and
**×** hides the banner until the window reloads. See
[floods and mutes](rules.md#floods-and-mutes).

If the daemon stops after the inbox has loaded, the inbox stays up and the
header shows **Syncing…** then **Offline · synced hh:mm** (click to retry, or
**Start daemon**). Decisions made meanwhile wait in the outbox with **Undo** and
are sent in order once the daemon is back. While connected the pill shows
**Live**, and **Syncing…** briefly while it catches up. Every state shows a
sync icon (green on **Live**, spinning while syncing); clicking the pill syncs
now. The inbox also resyncs when its window gains focus, becomes visible, or
the network comes back, plus on the **Sync** timer. A request answered
elsewhere (a phone, the CLI) while open stays a moment with its buttons dimmed
and the footer saying how it ended (**Approved on another device**), then the
inbox moves to the next one. A decision that loses such a race is dropped and
the footer says **Already handled on … · Approved**.

When the daemon's config file is saved ([live reload](cli.md#live-reload)), a
notice beside the pill (on narrow windows, its own row under the header) says
**Config reloaded** for a moment. If a changed key
needs a daemon restart it says **Restart daemon to apply: …** until you dismiss
it or restart (a dismissed notice comes back when the set of restart-only keys
changes); if the file is invalid it says **config.yaml invalid (line N),
kept previous** until a valid save.

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
OS speech backend. Voices come from the device;
online voices send the spoken text to the voice provider.

**Voice provider** chooses who speaks: **This device** (default, free) or a
cloud voice from **OpenAI** or **ElevenLabs**. A cloud provider needs your own
API key (see [cloud speech providers](#cloud-speech-providers)); pick an
**OpenAI voice** or enter an **ElevenLabs voice ID**, and optionally a **Voice
model** (empty uses the provider's default). The voice list and **Pitch** apply
to **This device** only; **Speed** applies to both.

## Dictation

Click the mic (**Dictate**) beside a text field, speak, then click it again
(**Stop dictation**). The words are added to the end of the field and stay
editable; nothing is sent until you submit. The mic appears beside the
free-text answer to a question, **Feedback for the agent** and **Reply to the
agent**, text fields an agent asks you to fill in, and an email draft's
**Subject** and **Body** (not the raw JSON editor). It shows **Listening…**,
then **Transcribing…** after you stop. Starting dictation stops read aloud
first. Each recording keeps at most its first two minutes.

**Settings → Dictation** saves, on this computer:

- **Provider**: **This device** (default, free) transcribes on this computer
  with whisper.cpp; or **OpenAI**, **Groq** or **ElevenLabs** (see
  [cloud speech providers](#cloud-speech-providers)), with an optional
  **Transcription model** (empty uses the provider's default).
- **Language**: **Detect automatically** (default) or a fixed language.
- **Speech model** (This device only): **tiny** (about 78 MB), **base**
  (default, about 148 MB) or **small** (about 488 MB). Larger models are more
  accurate but slower. Select the model to use. No model ships with the app:
  click **Install** beside one to download it from the whisper.cpp model
  repository on Hugging Face (progress shows as **Downloading N%**). handup
  checks its size and SHA-256 before keeping it, and after that dictation works
  offline. **Remove**
  deletes a model. Models are stored in the app's data directory, under
  `stt-models` (for example `~/.local/share/dev.handup.app/stt-models` on
  Linux).
- **Models you already have (Linux):** if another speech tool on this computer
  already downloaded a whisper.cpp model, handup uses it instead of asking you to
  install one, and the model's row in Settings shows **Using base.en from voxtype** (plus
  **English only** for `.en` models). It picks the same size as the selected model
  when one exists, else base, small, tiny, medium, then large. handup only reads
  these files, never changes or deletes them, and a model you install yourself
  always wins. It looks in the default model folders of voxtype (Omarchy's
  dictation), hyprwhspr, Handy, OpenWhispr, Speech Note (also the Flatpak), GNOME
  Speech2Text, whisper-dictation, Buzz and the AUR `whisper.cpp-model-*`
  packages. Tools that use another format, such as nerd-dictation (Vosk), can't
  be reused.
- Dictating with no installed or reusable model shows **Speech model not
  installed. Install one in Settings → Dictation.**

On macOS, the first dictation asks for microphone access for handup; if you
deny it, allow handup under **System Settings → Privacy & Security →
Microphone**. Without a microphone, Settings says **On-device dictation isn't
available here**.

### Cloud speech providers

Cloud dictation and cloud read aloud are optional and off by default. Enter
your own key in **OpenAI API key**, **Groq API key** or **ElevenLabs API key**
and click **Save**; the field then shows **Configured**, and **Clear** removes
the key. A key saved under Read aloud also counts for Dictation and the other
way round. Keys are stored only in the operating system's secure storage
(Keychain on macOS, Credential Manager on Windows, the Secret Service keyring on
Linux), are write-only (never shown again) and are never sent to the daemon,
paired devices or a relay: the app calls the provider directly. Cloud
providers receive your recorded audio (dictation) or the text being read (read
aloud), and may bill your account for it.

## History

The **Inbox | History** switch at the top of the list (or `h`) shows resolved
requests, newest first and grouped by day. Each row shows the outcome
(approved, denied, dismissed, expired, cancelled, or auto for rule, YOLO, and decide hook decisions), the agent,
and when it was resolved. Search matches the title, summary, and folder.
The quick filter row has outcome chips with colored dots; several outcomes
can be selected at once. Nothing selected shows every outcome.

**Filters** opens the same dialog or bottom sheet as Inbox, with **Outcome**,
**Type**, **Agent**, and **Has files** sections. Type means request kind
(Command, Edit, Review, Question, Info, or Custom); **Files** matches file,
bundle, image, PDF, audio, or video previews. Picks within a section combine
with OR; across sections they combine with AND. Type, agent and Files picks
appear after a divider as removable chips, counted by the Filters badge.
The row stays on one line and scrolls sideways with a swipe or mouse wheel.
Tap a selected outcome again to remove it, or use the reset icon at the row
end to clear all chip/sheet filters without clearing search.

Changing filters discards any older page still loading for the previous filters.
`j`/`k` move and `/` focuses search. Inbox remains the default view.

The detail pane is the request as it was asked, read-only, with a summary of
who decided it, the chosen option, feedback, and answers, plus any desktop
Run's exit status and full stored output. Who decided shows as an icon: a
laptop for this computer, a phone for the phone app, a globe for a paired
browser, a generic device for a revoked device or one paired before handup
recorded its kind, a bot for the agent or a [decide hook](integrations/hooks.md#decide-hooks) ("Hook \<name\>"), a scroll for a rule, a bolt for YOLO
mode, and a clock for the timeout. Hover the icon for the name ("Pixel 8 (phone app)"); wide
screens also show the name beside it. **Audit trail** expands every event and
always names who acted, so the name stays readable on touch screens.
Attachments retain their **Open** and **Download** actions in read-only history.

The API is `GET /v1/history` with optional `outcome`, `agent`, `type` (one
preview type), `has=attachments`, `kind`, and `q` (title, summary, folder).
`outcome`, `kind`, and `agent` each accept one value or a comma-separated list.
Values within a parameter combine with OR; different parameters combine with
AND. For example, `GET /v1/history?outcome=approved,denied&kind=command,edit&agent=codex,claude`
matches either outcome, either kind, and either agent. An invalid outcome or
kind member returns HTTP 400 for the whole query; single-value queries are
unchanged. `type` still accepts one preview type, and `has=attachments` matches
the same file previews as **Files**.
`limit` defaults to 50 (maximum 500); pass `next_cursor` as `cursor` with the
same filters to fetch older results without duplicates.
Paired view/decide devices can also read `GET /v1/requests/{id}/audit`;
submission tokens cannot access history or request audit.
History keeps the last `history.keep_days` days and `history.max_requests`
decisions (90 and 2000 by default); older ones are deleted at daemon start and
hourly. Change the age limit in [Settings → Storage](#storage).

## Storage

**Settings → Storage** shows this computer's daemon: total disk use, a stacked
bar and legend (**Request history**, **Files and previews**, **Audit log**,
**Free space in database**, **Database log and other**), pending/resolved/file counts and the age
of the oldest resolved request. On a database created by an older handup, free
space is reused but the file does not shrink; the group says so.

- **Keep request history**: **1 week**, **1 month**, **3 months**, **1 year**
  or **Forever** (`history.keep_days`). Older resolved requests, their audit
  events and files are deleted by the hourly retention. **Forever** removes the
  age limit only; `history.max_requests` still applies.
- **Keep files and previews**: **1 week**, **1 month**, **3 months** or **With
  request** (`history.files_keep_days`). Files go sooner; decisions stay.

Both save to the daemon's config file and apply without a restart. Picking a
shorter period shows what it would delete now and asks to **Save and delete**;
the cleanup then starts at once.

**Clean up this computer now** removes **Requests** (resolved requests with
their audit events and files) or **Files only** (decisions and the audit log
stay). **Older than** offers **1 day**, **1 week**, **1 month** or **3 months**
(counted from when each request was resolved), **Keep newest 100** (requests
only: every resolved request except the newest 100), or **All**. Options that
would delete nothing are disabled with the reason, for example "Nothing was
resolved more than 1 week ago."; **All** always stays. **Review cleanup** shows
an inline estimate that names where it deletes ("Delete on this computer: 12
requests …", approximate size) with **Delete** and **Cancel**. Pending requests
always stay. The cleanup runs in the background on the daemon: a progress bar
shows what was removed, then "Compacting the database…" while freed space
returns to the disk. **Stop** ends it after the current batch; what was removed
stays removed. Keep using handup or close Settings meanwhile. Only one cleanup
runs at a time.

In the web UI on a paired browser, a **Can decide** pairing gets the same
controls; a **View only** pairing sees usage and the retention in force, with a
pointer to the desktop app or `handup storage clean` on that computer. Paired
phones work the same way ([mobile Storage](mobile.md#storage)). The CLI
equivalent is `handup storage`; see
[CLI reference](cli.md#storage-usage-and-cleanup).

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
"Paired: \<name\>". For direct/Tailscale pairing when remote access is off, the
dialog shows **Remote access is off**, tells you to run
`handup remote tailscale`, and links to [Remote access](remote.md).
If the daemon started before Tailscale connected, the dialog instead reports
that remote access is waiting for Tailscale. Local approvals still work;
connect Tailscale, then request a new code once the listener binds automatically.
The button exists only in the desktop app: pairing codes are local-only, so
the web UI and the mobile app never offer it.

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

Web and `mailto:` links always open in your system browser or mail app, never
inside the handup window.

On Linux, audio and video play through GStreamer. If a clip says it could not
be decoded, install `gst-plugins-good`, `gst-plugins-bad`, and `gst-libav`
(package names vary by distro). The Linux and Android apps load the whole clip
before it plays, so they download it only when you tap **Play**; the request
itself opens at once. The clip starts once its metadata loads, and the preview
shows Loading… or Buffering… until it can play.

## macOS

The `handup` CLI and daemon are built for Intel and Apple Silicon; install them
with Homebrew or the install script ([downloads](downloads.md#macos)). The
desktop app is a universal `.dmg` (beta, [downloads](downloads.md#macos)).
Neither is notarized: the Homebrew cask removes the download quarantine flag for
you; for the app, run `xattr -dr com.apple.quarantine /Applications/handup.app`
once. Admin commands use `osascript` with the system administrator prompt.

Daemon notifications appear as banners from the desktop app: click **Allow** on
the handup notifications prompt that macOS shows when the app first opens. With
only the CLI installed, banners are posted as Finder and macOS does not show
them. macOS also hides banners while Screen Sharing is connected.

`handup service install` registers the daemon as a LaunchAgent that names the
desktop app. Until builds are Developer ID signed, **System Settings → General
→ Login Items** lists it as from an unidentified developer.
