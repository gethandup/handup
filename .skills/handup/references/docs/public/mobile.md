# Mobile app

The handup mobile app is a companion to the daemon on your computer, not a
daemon of its own. It connects through the [remote listener](remote.md), so
turn on remote access first: [Tailscale](remote.md#tailscale-recommended) is
recommended and takes about five minutes to set up.

Android is a beta, sideloaded APK published with each handup release
(`handup-android_<version>_arm64.apk`); there is no Play Store listing or
native iOS app. See [downloads and releases](downloads.md) for availability.

Phone clients never execute command requests and have no **Run** or **Run as
admin** button. Approval grants permission to the agent; it does not start a
desktop run. Paired devices cannot submit `run_result`. A command run locally
in the desktop app can still be reviewed in History with its returned result.
During a desktop run, the phone shows **Running in the desktop app** with the
elapsed time and the run limit, and decisions are blocked with 409 `running in
the desktop app`. With a **Can decide** pairing, **Stop** asks the desktop to
stop the command ([stop from another device](desktop.md#stop-from-another-device));
agent cancellation also stops it. Expiry is paused while the claim lease (the
run limit plus 2 minutes) is active; if the desktop stops responding, the
request shows **Run interrupted** and can be decided again.

## Install (Android)

Download the APK from the release on your phone, open it, and allow your
browser to install unknown apps when Android asks, only if you trust the
release. Verify it against the release checksums first if you can (see
[downloads](downloads.md#verify-a-download)). No Android SDK, Rust toolchain
or application source is needed. The phone app then pairs with your computer.

For automatic updates, install [Obtainium](https://obtainium.imranr.dev) and
open [this link](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22dev.handup.app%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fgethandup%2Fhandup%22%2C%22author%22%3A%22gethandup%22%2C%22name%22%3A%22handup%22%2C%22additionalSettings%22%3A%22%7B%5C%22apkFilterRegEx%5C%22%3A%5C%22%5Ehandup-android_%5C%22%2C%5C%22includePrereleases%5C%22%3Afalse%7D%22%7D)
on the phone. Obtainium tracks the GitHub releases, installs only the
`handup-android_` APK (not the Alpine Linux `.apk` packages in the same
release), skips prereleases, and notifies you when a new version is out.

## Pairing

1. On the computer, run `handup pair` (add `--scope view` for a read-only device),
   or open **Pair a phone** in the desktop app.
2. In the app, tap **Scan QR code** and point the camera at the QR code. Or
   paste the printed link (`http://100.x.y.z:7466/pair#code=…`) into
   **Pairing link** and tap **Pair with link**. If the phone can't run
   Tailscale, use `handup pair --relay` instead: the app then talks to the daemon through
   your [end-to-end encrypted relay](relay.md) (`…/pair#ch=…`).
3. The code works once and expires after two minutes.

The app can pair with several computers (say a laptop, a desktop and a build
server). Their pending requests share one inbox; once two or more are paired,
each row and request shows a chip with its computer's name. Approve, deny,
previews, attachments, history and audit always go to the request's own
computer, and each computer stays the only authority for its requests (they
never sync with each other). Pairing the same computer again replaces just
that pairing.

**Settings** (the gear icon) lists the paired computers with the device name
and scope and the pinned certificate. Rename a computer there (the name
defaults to its hostname), tap **Pair another computer** to add one, or
**Unpair** one. Unpairing only forgets that computer's token on the phone. To
cut the device off, also run `handup devices revoke <id>` on the computer.
When every paired computer has revoked the device, the app shows "This device
was revoked" and offers pairing again; a single revoked computer shows as
offline in the header while the others keep working.

If a computer is asleep or off the tailnet, its name shows as offline in the
header (with one computer: "Can't reach handup") and the app keeps retrying;
the other computers' requests stay usable. **History** shows one computer at a
time, picked above the search box.

## Approval feedback

For ordinary Approve/Deny requests, **Deny** is on the left and **Approve** is
on the right in the bottom action row, above the phone's safe area. Questions
follow the same rule (**Decline** left, **Submit** right), as do custom
choices: the agent's primary option takes the right edge and deny options the
left. Extras such as **Raw JSON** or **Edit & approve** sit in a row above;
the allow scopes (**Allow for session**, **Allow in project**, **Always allow**)
fold behind an **Allow…** toggle there so the footer stays short.
To mirror every decision row (primary on the left, Undo above it), set
`decisions.primary_side: left` in the laptop's config, or choose **Settings →
Decisions → Approve button side → Left** for this phone only. The 48px
feedback slot is always reserved above the controls: showing Undo, replacing
the feedback, or clearing it never moves the decision buttons. Undo has a 44px
touch target and is separated from the decision row.

Swipe the approval card—including its title and preview—right to approve or
left to deny, like dealing a card. The card follows your finger, tilts, and
shows a stamp with the option it picks: **Approve** or **Deny**, **Submit** or
**Decline** on a question, **OK** or **Dismiss** on an info notice, or an
agent's own labels such as **Apply prod** or **Not now**. A short drag (about a
fifth of the card) or a quick flick sends it off; let go earlier and it springs
back. There is no separate swipe strip. Cancelled, edge-started, and
multi-finger gestures do nothing. Turn **Swipe cards** off under
**Settings → Decisions** to use only the buttons. Swipe right always picks the
approve option, also when the buttons are mirrored to the left.
An info notice has an optional **Reply to the agent** box under its summary;
the text goes with **OK** or **Dismiss** (button or swipe), and an empty box
tells the agent nothing.
Vertical scrolling and pinch zoom remain native. A drag locks to an axis after
a few pixels: mostly-vertical drags scroll, mostly-horizontal drags move the
card from anywhere on it, including file lists, diffs and code previews. A
preview that is already scrolled sideways (a long code or diff line) scrolls
back to its edge first; the next drag moves the card. Taps on buttons, file
rows and checkboxes still work. Swipes starting on input fields, sliders,
media controls or an existing text selection do not decide. Interactive HTML
frames keep their own input. Buttons and tabs have 44px touch targets on
narrow screens.
On a question, a right swipe picks the only choice of any unanswered
single-choice question (such as a lone **OK**) and submits; if a question is
still unanswered, the card springs back and shows **Pick an answer**. A request
with no deny option springs back on a left swipe. The buttons remain available;
swipes are not offered for requests with several approve options or several
deny options, multiple selected requests, or view-only devices. Both methods use
the same validation, biometric gate, and held-send/Undo behavior.

After the last decision, **All clear** replaces the card, but Undo remains in
the same bottom slot above the former Approve button—not in the center of the
screen. The last action row's space remains reserved during the Undo window.
Long titles truncate so the countdown and Undo stay visible. Swipe through
several requests quickly and every decision still waiting keeps its own
countdown and 44px **Undo**: the newest stays in the footer slot, older ones
stack above it over the card (up to four, then "+N more"), so you can take
back any one without the buttons moving. Desktop keeps its compact sizing and
shows the `U` shortcut.

While the app stays visible, decisions wait for the undo window (5 seconds by
default). Switching apps or otherwise hiding handup ends that window and hands
held decisions to delivery immediately. On Android, a native outbox keeps
retrying offline decisions in the background; see [Offline](#offline) for limits.

## History

The **History** tab above the request list shows resolved requests grouped by
day, with search and outcome chips; swipe the chip rows sideways to see more.
Tap one for the read-only detail with the
decision summary and audit trail; **History** (or the back gesture) returns to
the list. It uses the same API as the desktop app, so a view-only device sees
it too.

## Security model

- **The token stays out of the webview.** The React UI calls Rust commands.
  Rust attaches `Authorization: Bearer <device token>` and talks to the daemon
  over its own HTTP/WebSocket client. No command returns the token.
- **Secure storage.** On Android the pairing (base URL, fingerprint, token) and
  settings are sealed with AES-256-GCM under a non-exportable Android Keystore
  key (`SecureStorePlugin`, alias `handup-secure-store`). Only the ciphertext
  is written to the app-private `shared_prefs/handup.secure.xml`. App backup is
  disabled (`allowBackup="false"`). On iOS the Keychain would be used through
  the `keyring` crate.
- **TLS pinning.** When the pairing link carries a certificate fingerprint
  (`fp=`, e.g. `direct` mode with its self-signed certificate), the app accepts
  only a server certificate whose SHA-256 matches it. Without a fingerprint,
  HTTPS URLs are checked against the public web roots. In `tailscale` mode the
  daemon listens on plain HTTP inside the tailnet, and WireGuard provides the
  encryption.
- **Relay pairing.** A relay link carries the daemon's Noise static public key
  (`pk=`) and the device's relay bearer credential (`dk=`). The app pins the
  key and runs `Noise_IK_25519_ChaChaPoly_SHA256` with the
  daemon, so the relay sees only ciphertext. The app's per-device Noise key
  and the channel credential live in the same Keystore-sealed pairing.

## Biometric confirmation

Approving a **high-risk** request asks for your fingerprint or face, or falls
back to the screen lock PIN or pattern ("Use PIN"). Denying never asks, and
neither do low- or medium-risk requests. The setting **Confirm high-risk
approvals** is on by default. Turning it off requires the same confirmation
when the device has a lock screen. The gate fails closed. If the device has no
screen lock, high-risk approvals fail with an error until you set one up or turn
the setting off.

Turning on **Hard YOLO** from the header switch ([YOLO mode](rules.md#yolo-mode))
asks for the same confirmation, since it auto-approves high-risk requests.

Rust enforces this gate on the same URI path the daemon routes, even when an
API call includes query parameters. Fragments and malformed request targets
are rejected before forwarding.

The prompt appears when you tap **Approve** or swipe to approve, before the few-second undo window
and before an offline approval is queued. The confirmation covers that request
at that content only: if the request changes before the approval is sent, the
daemon refuses it. On Android, a queued high-risk approval with its tap-time
confirmation can send in the background. Without that confirmation, it waits
for the open app and prompts there; background delivery never bypasses the gate.

## Offline

The header pill shows whether the phone is in sync with your computer:
**Live** (changes arrive as they happen), **Syncing…** (catching up or
reconnecting; you can keep browsing and deciding), or **Offline · synced
14:03** (the time of the last sync). Every state shows a sync icon (green on
**Live**, spinning while syncing and briefly after a tap); tap the pill to sync
now. The app also resyncs the moment it returns to the foreground, the network
comes back, its event stream reconnects, or a push notification arrives, and
while it is on screen it quietly refetches the queue on the **Settings → Sync**
timer (default every 15 seconds). In the background it does not poll: push
notifications cover that, and opening the app resyncs. The daemon pings the event
stream every 25 seconds (through a relay, the relay's own pings every 30
seconds count); a stream that stays silent for 75 seconds (a network change,
or Android dozing) is dropped and reconnected rather than left looking live.
Waking the phone after it slept reconnects any stream not heard from in the
last 35 seconds.

Below the header, the app shows the same config notices as the desktop app
when the computer's config file is saved: **Config reloaded**, **Restart daemon
to apply: …**, or **config.yaml invalid (line N), kept previous** (see
[live reload](cli.md#live-reload)).

A request answered somewhere else (the laptop, the terminal, another phone)
leaves the phone's inbox as soon as the event arrives. If it is the one open on
screen, it stays for a moment with its controls dimmed and the footer saying
how it ended, e.g. **Approved on laptop** or **Denied on another device**, then
moves to the next pending request, or **All clear**. It is in History as usual.

Once the inbox has loaded, losing the connection to your computer never hides
it. The last queue is kept on the phone, so opening the app while offline still
shows it, marked with when it last synced.

Approve, deny, and answers made while offline are queued in **Decisions waiting
to send**, each marked *Sending when connected* with an **Undo** button. When
the connection returns they are sent in the order you made them, bound to the
content you saw. The first decision to reach your computer wins. If one from the
phone loses (the request was already answered elsewhere, expired, or changed
since), it is dropped, never retried and never counted as a second decision,
and its row says what happened, e.g. **Already handled on laptop · Approved**.
The same line appears in the footer when a decision sent while online loses
that race. Nothing is ever sent that you did not tap. Each computer keeps its
own cached queue and outbox: one being offline never holds back decisions for
another.
On Android, queued decisions are also stored in a durable native outbox
(`outbox.db`), separate from the disposable History/file cache. Rust delivers
them without relying on the webview to keep running. Hiding the app ends any
remaining undo windows and tries every queued decision, even for a computer
whose connection looked down. Network failures stay queued and retry in the
background.

When you leave the app with pending work, Android starts a foreground service.
Its silent **Sending 1 decision…** or **Sending N decisions…** notification
shows how many decisions are waiting and disappears when none are waiting.
If Android refuses to start the service, delivery waits for the next open.
Swiping handup away or **Force stop** stops background decision delivery until
you reopen it; queued decisions survive. Android 15 limits `dataSync` foreground
services to about six hours per day. When that allowance runs out, unsent
decisions remain queued for the next open. This native background delivery is
Android-only; desktop and web behavior is unchanged.
Unpairing a computer forgets its cached queue and any unsent decisions for it.

### Offline copy and Downloads autosave

The app keeps a copy of the History pages, request details, audit trails and
files you read or that [auto-download](#auto-download-media) fetched, per paired
computer, in an app-private SQLite database. When that computer is
unreachable, History serves the copy and shows **Offline copy from …** with its
age; online, every read goes to the computer and refreshes the copy. Only these
reads are kept: never the pending queue (it has its own store above), decisions
or other writes, settings, pairing, devices, or any token. Files are checked
against their SHA-256 before they are kept.

Each computer's card in **Settings** has its own controls:

- **History kept on this phone**: **Last 30 days** (default) of what you read,
  **Everything read**, or **Off** (nothing is kept, files included).
- **Space limit**: 256 MB by default (16–4096). Past it, the least recently
  used entries go first; lowering it trims at once.
- **Also save files to Downloads** (off by default, Android 10 and later): new
  requests' named files, and files you open, are copied to `Download/handup`
  once each, up to a per-file limit (25 MB by default). It uses Android's
  MediaStore, so no storage permission is asked. Saved files stay after you
  unpair; delete them in a file manager.
- **Clear cache** deletes that computer's copy only. Unpairing a computer also
  deletes its copy and settings; other computers keep theirs.

The copy holds request content (titles, previews, files), so anyone who can
unlock the phone and open the app can read it offline. Set History to **Off**
on a computer whose requests should not stay on the phone.

### Storage

**Settings → Storage** (shown once a computer is paired) keeps two kinds of
space apart, and never adds them together. The group summary shows both, for
example `80 MB on phone · 162 MB on Laptop`.

**On this phone** comes first: the size of this phone's
[offline copy](#offline-copy-and-downloads-autosave), one row per computer.
**Clear** asks for an inline confirmation (`Clear this phone only: 80 MB.
History on Laptop stays …`), then deletes the copy on the phone only. Your
history on the computer is not deleted; it downloads again when needed.

**On _computer_** (for example **On Laptop**) follows for each paired computer: that computer's own disk
use (a stacked bar and legend: request history, files and previews, audit log,
free database space, database log and other), pending/resolved/file counts and
the retention in force. With a **Can decide** pairing the phone has the same
controls as the [desktop app](desktop.md#storage): **Keep request history**,
**Keep files and previews** and **Clean up _computer_ now**. The confirmation
says where data is deleted, for example `Delete on Laptop and this phone: 120
requests …`: a cleanup on the computer also clears this phone's offline copy of
that computer. A **View only** pairing shows usage and how to clean up on the
computer (Settings › Storage in its desktop app, or
`handup storage clean history --older-than 30d`). It needs a daemon with
storage support; an older one shows an "update it" message.

### Auto-download media

**Settings → Previews** decides whether the files of new pending requests
(images, video, audio, PDFs and other files) download in the background, so
their previews open at once instead of loading while you wait:

- **Auto-download media**: **Always**, **Wi-Fi only** (default; any network
  Android reports as unmetered counts), or **Never** (files load when you open
  them).
- **Per request up to (MB)**: 50 MB by default (1–1024). A request's files
  download in order while they fit; a file that does not fit is skipped and
  loads when you open it.

Downloads start when a request arrives, and again whenever the app reconnects
to a computer (opening the app, network back, or a push notification waking
it), so requests that arrived meanwhile are caught up. The setting applies to
every paired computer and uses that computer's offline copy: with **History
kept on this phone** set to **Off**, nothing downloads. Opening a preview while
its file is still downloading waits for that download instead of starting
another.

Once a request is decided, expires or is cancelled, its downloaded files are
deleted unless you opened them (opened files stay like any file you read) or
another pending request still uses them. The computer's **Space limit** caps
everything kept, oldest-used first.

A download gives up only after 30 seconds without receiving anything, not after
a fixed total time, so large files finish on a slow or relayed connection.

## Display and navigation

**Settings** opens a full-screen page on Android, with a persistent **Back**
button and independently scrolling sections. Android Back also returns to the
inbox. Changes save automatically on this device; there is no separate Save
step and no confirmation when you leave. The header always shows the save
state: **Saving…**, **Saved** with a check, or **Not saved** with **Retry**.
Back during a pending save waits for it to finish, then returns. If a save
failed, Back keeps Settings open and offers **Retry** or **Discard and go
back**; discarding keeps the settings that were actually stored.

Settings has collapsible **Appearance**, **Decisions**, **Sync**, **Previews**, **Read
aloud**, [**Storage**](#storage), [**License**](license.md) (one row per paired computer), **Test**, **Keyboard shortcuts**,
[**Help & feedback**](index.md#report-a-bug-or-request-a-feature), and **About** groups alongside the paired-computer controls.
**About** lists the app version, commit, build date and platform, with **Copy**
for a bug report; the daemon's version is shown in Settings › About on the computer.
**Decisions** contains the undo window, approve button side, and **Swipe
cards**; **Sync** holds **Resync while open** (Off, 10s, 15s, 30s, 1m, 5m;
default 15s), how often the open app re-checks each reachable computer, saved
per device; **Previews** holds [auto-download media](#auto-download-media).
**Keyboard shortcuts** lists the gestures (swipe right or left to decide,
**Undo**, tap a row, back, drag the divider) and the keys a hardware keyboard
can use; when every paired computer is view-only it hides the deciding ones.
The list is read-only on touch/coarse-pointer devices; it shows the connected
computer's configured keys. Change them from that computer's desktop app or a
fine-pointer browser with `decide` scope, or use its
[`keys:` config](cli.md#keyboard-shortcut-configuration). Changes made in
Settings apply live across connected clients; gestures are unchanged.
**Settings → Appearance** sets the theme (System follows the phone's light/dark
setting live, or Light, or Dark), color palette, density, and layout. The mobile
header has no separate theme shortcut. **Density** opens its own page with a live preview of each
choice; Back returns to Settings. **Compact** (the default) puts expiry, agent,
and location in small tabs on top of the preview; tap a tab to show that
detail. **Comfortable** shows them in a roomy header; **Ultra-compact** also
trims list rows and headers. In every density the risk badge sits in the
request header, next to the title.

**Settings → Appearance → Layout** opens a page with a preview of each choice:
**Split** (default) shows the list, then the request you open; **Stacked** keeps
the list above the request; **Focus** shows one request at a time; **Rail**
adds a horizontal chip strip. Focus and Rail have **‹ ›** controls, **N of M**,
and a **Queue** button that opens the full list in a sheet. Density applies
inside every layout. Layout and pane sizes save on this device.

Drag the Split or Stacked divider to resize with touch or a mouse. With the
divider focused, arrow keys adjust it; double-tap, double-click, or Enter
resets it. **Reset sizes** also appears on the Layout page after resizing.
Split width is 240–640px (default 380px); Stacked height is 15–75% (default 38%).

Android Back closes an open dialog or settings, returns from a request
(including one opened from a notification) to the list, and leaves the app
only from the list.
Command and text previews have a **Copy** button. Fenced code blocks in
Markdown previews, summaries and questions have a **Copy code** button in their
top-right corner (shown on hover or focus with a mouse, always on touch).

**Settings → Test** has one row per paired computer, each with **Send test
request** and **Send test question**. Choose the row for the computer whose
inbox and notifications you want to try. It creates a harmless server-built
sample on that computer, not on the phone: **Test request** or **Test question**,
low risk, agent `handup`, session `handup-test`, with a 15-minute timeout.
Approving, denying, or answering performs no action. The pairing needs
`decide` scope; a view-only computer returns an explanatory error. If the
computer runs an older daemon without this route, update it.

### Read aloud

Tap the speaker button (**Read aloud**) in an open pending request's header;
tap **Stop reading** to stop. It reads the agent, title, a shortened summary,
risk, questions and, by default, numbered options—not previews, diffs or tool
input. Changing or deciding the request, returning to the list, or opening
History stops playback. History has no read-aloud button.

**Settings → Read aloud** saves the voice, **Speed**, **Pitch**, **Read options**
and scope on this phone; **Test voice** plays a sample. **This request** is the
default; **Whole queue** continues through the visible pending requests after
the open one, selecting each in turn. **Read new requests** is off by default;
when enabled, it can read a newly arrived request while handup is open and
idle, but does not read the requests already waiting at first load.

The searchable voice picker filters by name, language name or code, and
**Natural** or **Online** labels.

Android uses native TTS through `tauri-plugin-tts`, not the System WebView's
speech APIs. It always reads aloud with the system default text-to-speech
engine. To change the engine or install voices (for example if none appear),
use Android's own text-to-speech settings, then reopen Read aloud in handup.
Online voices send the spoken text to the voice provider.
For a phone browser rather than the native app, see
[Web UI read aloud](remote.md#read-aloud).

## Attachments and Markdown

File attachments offer **Download** and **Open** on Android. Download fetches
the attachment through your authenticated pairing, then opens Android's save
picker. Choose a location on the phone; the suggested name preserves the
original basename, including Unicode. You may rename it, and the selected
storage provider may adjust duplicate names. Cancelling saves nothing and shows
**Download cancelled**. Wait for **Saved** followed by the final file name
before assuming a download finished.
A write failure reports an error and attempts to remove the newly created
partial document; providers that refuse deletion may retain that partial file.

Open passes a temporary, read-only content URI and the file's MIME type to an
installed viewer. Another app receives the attachment, not your pairing token
or the computer's file URL. If no suitable viewer is installed, use Download
and choose a compatible app. The private Open copy remains available until
Android evicts the cache. Open hands over the file's own type first, then plain
text for text-like files (code, JSON, YAML…), then any app that accepts the
file.

Files previews list every file with its size and type. Tap a row to view it
(code is highlighted, Markdown renders, images and media play), or use its
open icon to hand it to another app. Each viewed file has **Open** and
**Download**. Check rows (or the select-all box) to **Download** several at
once; more than one file downloads as a single `.zip` that keeps the folder
layout. On Android the `.zip` goes through the same save picker; on desktop,
downloads land in your Downloads folder without overwriting existing files.
HTML files only open in the sandboxed preview; download them instead.

JSON previews are pretty-printed and syntax-highlighted with the active
palette; switch to **Tree** to fold objects and arrays.

`.md` and `.markdown` attachments (case-insensitive), or attachments marked
`text/markdown`, render in the app with headings, lists, GFM tables and
syntax-highlighted fenced code. Unknown code languages remain readable plain
text. Tables and long code lines scroll inside the reader rather than widening
the page. Raw HTML is not rendered and remote images are blocked. Tapping a
web or `mailto:` link in Markdown, a summary or a plain-text preview opens it
in your browser or mail app, never inside handup; other links do nothing.
Open and Download remain available if reading fails.

These native file actions support Android; iOS attachment delivery is not
implemented. Browser downloads continue to use the browser's own file handling.

## Notifications

Android can receive native Firebase Cloud Messaging (FCM) notifications directly
in handup; the ntfy app is not required. Push is optional at build time.

Queued decision delivery uses a separate silent **Sending decisions** channel
(`outbox`, low importance), not FCM or ntfy. It has no sound, vibration, or badge
and is shown only while the foreground service has work waiting. This does not
require a Firebase-enabled build. Tapping it opens handup.

### Android permissions

The app declares `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_DATA_SYNC` to keep
queued decision delivery running after you leave it. These are manifest
permissions, not extra runtime prompts. Android 13+'s notification permission
controls notification visibility; it is requested after pairing as described
below. The service is still subject to Android's start restrictions and
Android 15's daily `dataSync` limit; reopening the app resumes queued work.

### Owner setup

1. In the [Firebase console](https://console.firebase.google.com/), create a
   project and add an Android app with package name **`dev.handup.app`**.
2. Download its **`google-services.json`** and place it at
   **`apps/handup-app/gen/android/app/google-services.json`** before building
   the APK. This file is gitignored. The Google Services Gradle plugin is applied
   only when the file exists. Without it the release APK still builds, and
   **Settings → Notifications** says **Not available in this build**.
3. Enable the Firebase Cloud Messaging HTTP v1 API for the project. In
   **Project settings → Service accounts**, generate a service-account private
   key (or create a dedicated account with the Firebase Cloud Messaging API
   Admin role). Save the JSON key on the daemon host, outside the repository,
   readable only by its owner (`chmod 600`). Never put this private key in the
   APK or commit it.

Steps 1–3 can be scripted with `gcloud` (logged in as the project owner). The
one manual step is opening the Firebase console once to add Firebase to the new
project, which accepts the Firebase terms; the API returns 403 until then.

```sh
P=handup-push-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')
gcloud projects create "$P" --name="handup push"
gcloud services enable firebase.googleapis.com fcm.googleapis.com iam.googleapis.com --project "$P"
# Console: Add project → choose the existing Google Cloud project "$P".
T=$(gcloud auth print-access-token)
H=(-H "Authorization: Bearer $T" -H "x-goog-user-project: $P" -H 'Content-Type: application/json')
F=https://firebase.googleapis.com/v1beta1/projects/$P
curl -s -X POST "${H[@]}" "$F/androidApps" -d '{"packageName":"dev.handup.app","displayName":"handup"}'
APP=$(curl -s "${H[@]}" "$F/androidApps" | jq -r '.apps[] | select(.packageName=="dev.handup.app") | .appId')
curl -s "${H[@]}" "$F/androidApps/$APP/config" | jq -r .configFileContents | base64 -d \
  > apps/handup-app/gen/android/app/google-services.json
SA=handup-fcm@$P.iam.gserviceaccount.com
gcloud iam service-accounts create handup-fcm --project "$P"
gcloud projects add-iam-policy-binding "$P" --member "serviceAccount:$SA" \
  --role roles/firebasecloudmessaging.admin --condition None
(umask 077; gcloud iam service-accounts keys create ~/.config/handup/firebase-service-account.json --iam-account "$SA")
```

For CI-built APKs, store `google-services.json` as a protected GitLab CI file
variable named `GOOGLE_SERVICES_JSON`; the `android` job copies it into place.

4. Configure the daemon (saves apply live):

   ```yaml
   notifications:
     backends: [desktop, fcm]
     fcm:
       service_account: /absolute/path/to/firebase-service-account.json
       payload: title
   ```

   `handup doctor` checks the account and reports the project id without
   printing credentials. The APK and service account must use the same Firebase
   project.
5. Install the configured APK and pair it with the daemon. Android 13+ asks for
   notification permission **after pairing succeeds**, not on initial launch.
   **Settings → Notifications** shows On or Blocked and opens the system's
   app-notification settings. If the status cannot be read within a few
   seconds, it says **Could not check** with the reason and a **Retry** button.
   Android 12 and earlier use the system setting
   without a runtime permission prompt.

After pairing, the app registers its FCM token with each paired daemon using
device authentication, whether or not notification permission is granted,
over either the tailnet listener or the encrypted relay tunnel. Token refresh is synchronized
while the app is running, and on the next launch after an Android background
refresh. Registration retries when the daemon is offline. Unpairing attempts to
remove push registration; revoking the device always deletes it on the daemon.

FCM uses two system channels: **Approval requests** (`requests`, default
importance) and **High-risk approvals** (`high_risk`, high importance), separate
from the outbox's **Sending decisions** channel.
Android controls sound, lock-screen display, and heads-up eligibility per
channel. Push messages are high-priority, data-only; the app constructs the
notification even when its activity is not running. Swiping the app away is
supported; Android's explicit **Force stop** prevents FCM delivery until the app
is opened again.

`payload: title` (default) sends only the redacted title, request id, and risk;
**preview content is never sent**. `payload: wake` substitutes the generic
“Approval requested” title. Google can see this push metadata; the relay's
end-to-end encryption does not cover the daemon-to-FCM notification. The usual
notification rules and quiet hours apply. Decide, cancel, and expiry send a
`resolved` message to cancel the matching notification, even during quiet hours.
Android can delay that message while the app is closed, so the app also clears
a request's notification as soon as you tap its decision (not after the undo
window or delivery; Undo keeps the request in the inbox but does not bring the
notification back) and, whenever its queue syncs (including when it is opened or
brought back), clears those that are no longer pending.
Tapping a notification opens the request via `handup://r/<id>`. Push contains no
Approve/Deny actions.

## Deep links and ntfy

The app handles `handup://r/<request id>` and opens that request:

```bash
adb shell am start -a android.intent.action.VIEW -d handup://r/01M3S8C6H0CP6R88FFXM4NPFSF
```

The [ntfy backend](remote.md#notification-backends) adds an **Open** action
with this link to every notification, so tapping **Open** in the ntfy Android
app opens the request in handup. When remote access is on, tapping the
notification itself (`click`) opens the [web inbox](web.md) (`<web UI>/#/r/<id>`)
in the browser instead. Releases from v0.1.2 include the web inbox; v0.1.1
and earlier do not, so upgrade before using notification browser links.
ntfy remains an optional alternative; native FCM is Android-only.
Native APNs delivery from the daemon is not implemented.

## iOS

No native iOS app yet, and no TestFlight or App Store download.

The alternative is the daemon's [web inbox](web.md) over Tailscale:
pair from Safari using the `handup pair` QR code and add it to the Home Screen.
It lacks native biometric confirmation and deep links, but has the same inbox.
Releases from v0.1.2 include the web inbox. v0.1.1 and earlier do not,
so upgrade to use an iPhone to approve requests.
