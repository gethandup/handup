# Use handup in a browser

The web inbox lets you review and decide agent requests from a web browser on
another computer, a phone or an iPhone, served by the handup daemon on your
computer.

> **Not in released packages yet.** Releases up to v0.1.1 do not include the
> web inbox files. Opening the address shows `handup web UI is not installed`
> (HTTP 503) and there is nothing to pair. The web inbox ships in the next
> release. Until then, use the [desktop app](desktop.md) on the computer and the
> [Android app](mobile.md) elsewhere.

## What the web inbox does

A paired browser shows the same inbox as the desktop app: pending requests with
their previews, history, and Settings. With **decide** access it can approve,
deny, edit and approve, answer questions, cancel, and stop a command that the
desktop app is running. **View** access is read-only.

A browser never runs commands. **Run** and **Run as admin** exist only in the
desktop app. Scoped allow rules, pairing, device management and the audit log
also stay on the computer itself. See [Web UI](remote.md#web-ui) for every
setting and the browser protections.

There is no native iPhone app. On an iPhone, use the web inbox in Safari.

## Choose a setup

| Where the browser is | Setup | Notes |
| --- | --- | --- |
| Phone, iPhone or another computer, anywhere | [Tailscale](#tailscale-recommended) | **Recommended.** Only your own devices can connect |
| The computer that runs handup | [Desktop app](#on-the-same-computer) | A browser here needs Tailscale or a self-signed certificate |
| Another device on the same network, without Tailscale | [Direct mode](#on-your-network-without-tailscale) | **Not recommended.** Self-signed TLS and a permanent risk banner |
| Anywhere, through the [relay](relay.md) | Not supported | Relay pairing links pair only in the Android app |

Every setup uses two ports on the computer: `remote.port` (default 7466) for
the inbox and API, and `remote.preview_port` (default 7467) for HTML and file
previews. `remote.*` changes apply when the daemon restarts:

```sh
systemctl --user restart handup.service                  # Linux
launchctl kickstart -k gui/$(id -u)/com.handup.daemon   # macOS
```

If you run `handup serve --foreground` yourself, stop it and start it again.

## Tailscale (recommended)

Tailscale connects your computer and your other devices on a private network
that only you can join. Set it up once by following
[Tailscale setup](remote.md#tailscale-recommended): install Tailscale on the
computer and on the device with the browser, and sign in to the same account
on both.

1. Turn on remote access and restart the daemon:

   ```sh
   handup config set remote.mode tailscale
   systemctl --user restart handup.service   # macOS: see above
   ```

   handup reads the computer's tailnet address with `tailscale ip -4` and
   listens there. It never changes your Tailscale configuration.
2. Pair the browser:

   ```sh
   handup pair                 # approve and deny
   handup pair --scope view    # read-only
   ```

   It prints a QR code and a link like
   `http://100.x.y.z:7466/pair#code=…&scope=decide`. Scan the code with the
   phone's camera, or open the link on the other device. The link works once
   and expires after 2 minutes.
3. The **Pair this device** page shows the access you are granting and an
   optional device name. Press **Pair**. The browser opens the inbox and stays
   paired.

Bookmark `http://100.x.y.z:7466/` (the address from your pairing link) to come
back later. On an iPhone, Safari's **Share → Add to Home Screen** gives it an
icon.

Traffic between tailnet devices is encrypted by WireGuard, so the address uses
plain `http://`. Use the IP address from the pairing link: handup refuses other
host names, such as your MagicDNS name, with `host not allowed`. For an HTTPS
name, run `tailscale serve` yourself and set `remote.public_url`; see
[Tailscale](remote.md#tailscale-recommended). Never use `tailscale funnel`.

## On the same computer

Use the [desktop app](desktop.md) (`handup ui`) on the computer that runs
handup. It is the only client that can run commands and create allow rules.

The daemon's local API (`127.0.0.1:7465`) does not serve the web inbox. To use a
browser on the same computer anyway:

- **With Tailscale**, follow [Tailscale](#tailscale-recommended) and open the
  pairing link in a browser on this computer.
- **Without Tailscale**, run direct mode on `127.0.0.1`. handup requires TLS
  and the risk acknowledgement even on loopback, so the browser warns about a
  self-signed certificate and the inbox always shows a red risk banner:

  ```sh
  handup config set remote.direct.accept_risk true
  handup config set remote.tls.enabled true
  handup config set remote.bind 127.0.0.1
  handup config set remote.mode direct
  systemctl --user restart handup.service   # macOS: see above
  handup pair
  ```

  Open the `https://127.0.0.1:7466/pair#code=…` link, check the certificate
  fingerprint as described in [direct mode](#on-your-network-without-tailscale),
  accept the browser's warning, and press **Pair**.

## On your network without Tailscale

Direct mode listens on a network address over TLS. Anyone who can reach the
port and gets a device token can approve what your agents do, including
running commands on your computer. Prefer [Tailscale](#tailscale-recommended).
Never forward this port from your router to the internet.

1. Find the computer's network address (for example `192.168.1.20`) and set
   these keys in this order. handup rejects `remote.mode direct` before
   `accept_risk` and TLS are on, and a network `remote.bind` before TLS is on:

   ```sh
   handup config set remote.direct.accept_risk true
   handup config set remote.tls.enabled true
   handup config set remote.bind 192.168.1.20
   handup config set remote.mode direct
   systemctl --user restart handup.service   # macOS: see above
   ```

   With no `remote.tls.cert` and `remote.tls.key`, handup creates a self-signed
   certificate for `localhost`, `127.0.0.1` and the bind address, and reuses it
   after restarts. At start the daemon prints the listening address, the
   certificate's SHA-256 fingerprint and a risk warning; `handup doctor`
   reports the same warning.
2. Pair with `handup pair` (or `--scope view` for read-only). The link looks
   like `https://192.168.1.20:7466/pair#code=…&fp=…`.
3. Open the link on the other device. The browser warns that the certificate
   is not trusted. Compare its SHA-256 fingerprint (in the browser's certificate
   details) with **Expected certificate fingerprint** on the handup page and
   with the fingerprint the daemon printed. Continue only if they match, then
   press **Pair**.

The other device must reach ports 7466 and 7467 on the computer; allow them in
the computer's firewall for your local network only. Every handup screen shows
the risk warning as a red banner while direct mode is on. To use your own
certificate, set `remote.tls.cert` and `remote.tls.key`; see
[Direct mode](remote.md#direct-mode-not-recommended).

## Relay

The [relay](relay.md) does not serve the web inbox. `handup pair --relay`
links pair only in the Android app; a browser that opens one does not pair.

## Manage paired browsers

```sh
handup devices list               # every paired browser and phone
handup devices scope ID view      # make one read-only
handup devices disable ID         # pause it without unpairing
handup devices revoke ID          # unpair it now
```

A revoked browser shows **Device not paired** and needs a new `handup pair`.
To stop serving the web inbox, run `handup config set remote.mode off` and
restart the daemon. See [Managing devices](remote.md#managing-devices).

## Troubleshooting

| You see | Fix |
| --- | --- |
| `handup web UI is not installed` | Your release does not include the web inbox yet; see the note at the top |
| `host not allowed` | Open the address from the pairing link, or set `remote.public_url` for your own host name |
| **Device not paired** | Run `handup pair` again: each link works once, for 2 minutes |
| The page does not load | Check that Tailscale is connected on both devices (`tailscale status`), or that the firewall allows ports 7466 and 7467 in direct mode |
| `handup pair` answers that remote access is off | Set `remote.mode` and restart the daemon |
