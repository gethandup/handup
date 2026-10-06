# Downloads and installation

handup ships as compiled binaries and packages from its public release host,
[github.com/gethandup/handup](https://github.com/gethandup/handup/releases).
Downloads are public; you never need the application source, Git, Rust, Make or
an Android SDK.

A handup Personal license is $30 USD one-time plus tax where applicable, sold through Polar (merchant of
record): one person on their own machines, perpetual use and all future released
updates. Polar emails the order confirmation; the license key is in Polar's
customer portal. Refunds are available within 30 days of purchase; see the
[Terms](https://gethandup.dev/terms) and [Privacy Policy](https://gethandup.dev/privacy).
No hosted service, unlimited personal support or indefinite development is promised.

Every release works fully for a 14-day trial; then activate your key with
`handup license activate KEY` or **Settings → License**. Activation contacts
gethandup.dev once, after which the license works offline. See
[License and trial](license.md).

If checkout reports too many attempts, wait about a minute before trying again.
The server rejects the attempt before contacting Polar; nothing was charged.

> **No public release has been published yet.** The commands below work once
> the first release is out; until then the release page has no files.

## Platforms

| Platform | Package | Status |
| --- | --- | --- |
| Linux x86-64 / ARM64 | install script, Arch package, .deb, .rpm, Alpine .apk, tar.gz | Primary platform. |
| Linux desktop app, x86-64 | AppImage, .deb, .rpm | Beta; needs the CLI daemon installed too. |
| macOS Intel / Apple Silicon | Homebrew cask, tar.gz | Beta; not notarized. |
| macOS desktop app (universal) | .dmg | Beta; not notarized; needs the CLI daemon installed too. |
| Android | APK (sideload) | Beta companion app for the daemon on your computer. |
| iPhone / iPad | — | No native app. Use the daemon's web inbox over Tailscale. |
| Windows | — | Not available. Use the Linux build in WSL. |

## Linux

### Any distribution (install script)

```sh
curl -fsSL https://github.com/gethandup/handup/releases/latest/download/install.sh | sh
```

The script detects your OS and CPU (x86-64 or ARM64), downloads the matching
`handup_<version>_<os>_<arch>.tar.gz`, verifies it against the release
`checksums.txt` (SHA-256) and installs `handup` to `~/.local/bin`. When minisign
is installed and the release has a signature, it verifies that signature first
and refuses to install if it is invalid. Without minisign, or for older releases
without a signature, it prints a note and still checks SHA-256. It never uses
sudo and refuses to install if the checksum is missing or wrong.

| Variable | Default | Purpose |
| --- | --- | --- |
| `HANDUP_INSTALL_DIR` | `~/.local/bin` | Install directory (must be writable). |
| `HANDUP_VERSION` | latest | Release tag to install, e.g. `v0.1.0`. |

### Arch Linux

Download `handup-<version>-1-x86_64.pkg.tar.zst` (or `-aarch64`), then:

```sh
sudo pacman -U ./handup-*.pkg.tar.zst
```

It installs the released binary as `/usr/bin/handup`. There is no AUR package.

### Debian and Ubuntu

Download `handup_<version>_amd64.deb` (or `_arm64.deb`) from the release, then:

```sh
sudo apt install ./handup_*.deb
```

### Fedora and RHEL

Download `handup-<version>-1.x86_64.rpm` (or `.aarch64.rpm`), then:

```sh
sudo dnf install ./handup-*.rpm
```

### Alpine

The Alpine package contains a musl build. It is not signed with an Alpine
key, so verify its checksum first (below), then:

```sh
sudo apk add --allow-untrusted ./handup_*.apk
```

### Desktop app

Download `handup-desktop_<version>_amd64.AppImage` (or the desktop `.deb`/`.rpm`
bundle), then:

```sh
chmod +x ./handup-desktop_*.AppImage && ./handup-desktop_*.AppImage
```

The desktop app is an inbox for the `handup` daemon; install the CLI with one
of the methods above as well. See [desktop](desktop.md).

## macOS

```sh
brew install --cask gethandup/tap/handup
```

The install script above also works on macOS. Builds exist for Intel and Apple
Silicon. The binary is not notarized: the cask removes the download quarantine
flag for you.

### Desktop app

Download `handup-desktop_<version>_universal.dmg` (Intel and Apple Silicon),
open it and drag **handup** to Applications. The app is not notarized, so macOS
blocks the first open: remove the download quarantine flag once, then open it
normally:

```sh
xattr -dr com.apple.quarantine /Applications/handup.app
```

Install the CLI as well (above); daemon notification banners on macOS need the
desktop app. See [desktop app on macOS](desktop.md#macos).

## Android

Download `handup-android_<version>_arm64.apk` on the phone, allow your browser
to install unknown apps when Android asks, and open it. Pair it with
`handup pair` on the computer. See [mobile](mobile.md).

## iPhone and iPad

There is no native iOS app. Enable Tailscale mode and pair; then open the
pairing link in Safari and add it to the Home Screen:

```sh
handup config set remote.mode tailscale
handup pair
```

See [remote access](remote.md).

## Verify a download

Every release publishes `checksums.txt` with SHA-256 sums for the downloads.
Signed releases also publish `checksums.txt.minisig`. Install
[minisign](https://jedisct1.github.io/minisign/), put both files next to your
download, and verify the signature before checking the checksum:

```sh
curl -fsSLO https://github.com/gethandup/handup/releases/latest/download/checksums.txt
curl -fsSLO https://github.com/gethandup/handup/releases/latest/download/checksums.txt.minisig
minisign -Vm checksums.txt -P RWRmxfwgJLzyYHvZKxoWSd44lp0rN3pUKD4HVPJIfwntmiIFFWDPW8V/
sha256sum -c --ignore-missing checksums.txt          # Linux
shasum -a 256 --ignore-missing -c checksums.txt      # macOS
```

For an older release, replace `latest/download` with `download/<tag>`. The
install script and Homebrew cask verify checksums for you.

## After installing

```sh
handup service install
handup doctor --json
handup integrate all   # every detected agent: Claude Code, Codex, Cursor, omp
```

See [agent setup](agents/mcp.md) to configure one agent at a time.

## Updates

Every update is a new binary release; see the [changelog](https://github.com/gethandup/handup/releases).

- Install script: re-run the same one-liner. It upgrades only when the release is
  newer by SemVer precedence (a prerelease such as `v1.2.0-rc.1` is older than
  `v1.2.0`), keeps the previous binary as `handup.backup.<date>` (newest three kept)
  and restores it if the new binary fails to start.
- Debian/Fedora/Alpine/Arch: install the newer package file the same way.
- Desktop app: install the newer AppImage, package or `.dmg` over the old one.
- Homebrew: `brew upgrade --cask handup`.
- Android: install the newer APK over the old one.

After updating the binary:

1. Restart the daemon so it loads the new executable:
   `systemctl --user restart handup.service` on Linux, or
   `launchctl kickstart -k "gui/$(id -u)/com.handup.daemon"` on macOS.
   For a manually started daemon, stop it and run `handup serve --foreground`
   again. There is no `handup service restart` command.
2. Reapply the current integration with `handup integrate all` (or your chosen
   agent target) and refresh the bundled skill with `handup skill install`.
3. Restart your agent sessions and their handup MCP servers so they load the
   new binary and integration configuration; close and reopen the desktop app.
4. Run `handup doctor --json` and `handup version` to check the updated setup.


## Uninstall

Install script:

```sh
handup uninstall
```

or, without a working binary,
`curl -fsSL https://github.com/gethandup/handup/releases/latest/download/uninstall.sh | sh -s -- --yes`.
Both remove the binary from `~/.local/bin` (or `HANDUP_INSTALL_DIR`) plus
installer backups. Configuration and data are kept.

Packages: `sudo pacman -R handup`, `sudo apt remove handup`, `sudo dnf remove handup`,
`sudo apk del handup`, `brew uninstall --cask handup`. Run `handup service uninstall`
first if you installed the user service.

## Source and documentation

The application source stays private. Buying a personal license does not grant
repository access or application-source modification rights. Public usage
documentation, machine contracts and [agent instructions](agents/skill.md) are
distributed separately from the application repository.

Some integrations and web assets necessarily include readable scripts; that is
not publication of the complete application source. Third-party components
retain their licenses, and distribution must satisfy their notice and any
applicable source-offer requirements. Their license texts ship as
`THIRD_PARTY_NOTICES.md`: in every CLI archive, at
`/usr/share/doc/handup/THIRD_PARTY_NOTICES.md` from the Linux packages, and as a
bundled resource of the desktop app.
