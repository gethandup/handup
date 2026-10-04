# Downloads and installation

handup ships as compiled binaries and packages from its public release host,
[github.com/gethandup/handup](https://github.com/gethandup/handup/releases).
Downloads are public; you never need the application source, Git, Rust, Make or
an Android SDK.

A handup Personal license is $30 USD one-time, sold through Polar (merchant of
record): one person on their own machines, perpetual use and all future released
updates. The license key arrives by email after checkout. No hosted service,
unlimited personal support or indefinite development is promised.

> **No public release has been published yet.** The commands below work once
> the first release is out; until then the release page has no files.

## Platforms

| Platform | Package | Status |
| --- | --- | --- |
| Linux x86-64 / ARM64 | install script, AUR, .deb, .rpm, Alpine .apk, tar.gz | Primary platform. ARM64 builds are not runtime-tested. |
| Linux desktop app, x86-64 | AppImage, .deb, .rpm | Pre-alpha; needs the CLI daemon installed too. |
| macOS Intel / Apple Silicon | Homebrew cask, tar.gz | Built but **untested**; not notarized. |
| Android | APK (sideload) | Pre-alpha companion app for the daemon on your computer. |
| iPhone / iPad | — | No native app. Use the daemon's web inbox over Tailscale. |
| Windows | — | Not available. The Linux build in WSL is untested. |

## Linux

### Any distribution (install script)

```sh
curl -fsSL https://github.com/gethandup/handup/releases/latest/download/install.sh | sh
```

The script detects your OS and CPU (x86-64 or ARM64), downloads the matching
`handup_<version>_<os>_<arch>.tar.gz`, verifies it against the release
`checksums.txt` (SHA-256) and installs `handup` to `~/.local/bin`. It never
uses sudo and refuses to install if the checksum is missing or wrong.

| Variable | Default | Purpose |
| --- | --- | --- |
| `HANDUP_INSTALL_DIR` | `~/.local/bin` | Install directory (must be writable). |
| `HANDUP_VERSION` | latest | Release tag to install, e.g. `v0.1.0`. |

### Arch Linux (AUR)

```sh
yay -S handup-bin
```

`handup-bin` repackages the released x86-64/ARM64 binary into `/usr/bin/handup`.

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

## macOS (untested)

```sh
brew install --cask gethandup/tap/handup
```

The install script above also works on macOS. Builds exist for Intel and Apple
Silicon but have not been tested, and the binary is not notarized: the cask
removes the download quarantine flag for you.

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

Every release publishes `checksums.txt` with SHA-256 sums for all files. Put it
next to your download and check:

```sh
curl -fsSLO https://github.com/gethandup/handup/releases/latest/download/checksums.txt
sha256sum --ignore-missing -c checksums.txt          # Linux
shasum -a 256 --ignore-missing -c checksums.txt      # macOS
```

For an older release, replace `latest/download` with `download/<tag>`. The
install script, AUR package and Homebrew cask verify checksums for you.

## After installing

```sh
handup service install
handup doctor --json
handup integrate claude
```

See [agent setup](agents/mcp.md) for other agents.

## Updates

Every update is a new binary release; see the [changelog](https://github.com/gethandup/handup/releases).

- Install script: re-run the same one-liner. It upgrades only when the release is
  newer, keeps the previous binary as `handup.backup.<date>` (newest three kept)
  and restores it if the new binary fails to start.
- AUR: `yay -Syu`. Debian/Fedora/Alpine: install the newer package file the same way.
- Homebrew: `brew upgrade --cask handup`.
- Android: install the newer APK over the old one.

## Uninstall

Install script:

```sh
handup uninstall
```

or, without a working binary,
`curl -fsSL https://github.com/gethandup/handup/releases/latest/download/uninstall.sh | sh -s -- --yes`.
Both remove the binary from `~/.local/bin` (or `HANDUP_INSTALL_DIR`) plus
installer backups. Configuration and data are kept.

Packages: `yay -R handup-bin`, `sudo apt remove handup`, `sudo dnf remove handup`,
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
applicable source-offer requirements.
