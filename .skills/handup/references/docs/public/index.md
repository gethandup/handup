# The approval inbox for AI agents

## Quick start

handup runs on Linux and macOS computers, with an Android app for your phone.
Windows x86-64 is a beta (CLI and desktop installer; see
[downloads](downloads.md#windows)). No iPhone app yet; a [web inbox](web.md)
for iPhone and other browsers is included from v0.1.2 (not in v0.1.1 or
earlier). [Download it](https://gethandup.dev/downloads), or install it from a
terminal:

```sh
curl -fsSL https://github.com/gethandup/handup/releases/latest/download/install.sh | sh
handup setup
```

On a Mac, `brew install --cask gethandup/tap/handup` works too. Packages and
the desktop and Android apps are in [downloads](downloads.md). You never need
Git, Rust or the source.

`handup setup` starts handup in the background (on Windows, see
[downloads](downloads.md#windows) instead), connects every agent it finds
(Claude Code, Codex, Cursor, omp) and installs the handup
[agent skill](agents/skill.md). It is safe to run again, and `--dry-run` shows
what it would change. Restart your agents, then try it:

```sh
handup ask --title "Hello from handup" --wait
```

Approve it in `handup inbox`, in the desktop app (`handup ui`), or on your
phone after [pairing it over Tailscale](remote.md#tailscale-recommended).
Releases work fully for a 14-day trial; `handup license status` shows the days
left. See [License and trial](license.md).

### Set up by hand

`handup setup` runs these steps; run them yourself to pick and choose:

```sh
handup service install   # start handup in the background (not on Windows: run handup serve)
handup integrate all     # connect every detected agent (--list shows what it found)
handup skill install     # teach agents when and how to ask
```

`integrate all` creates missing agent configs (with backups). Claude Code and
Codex get hooks plus MCP; Cursor and omp get MCP only. An existing omp
tool-gating extension is upgraded, but a new one is opt-in with
`handup integrate omp`. Only one agent?

- [`handup integrate claude`](agents/claude-code.md)
- [`handup integrate codex`](agents/codex.md)
- [`handup integrate omp`](agents/omp.md)
- [`handup integrate mcp --client cursor`](agents/cursor.md)

Agents that don't load skills can use `handup prompt`, which prints
instructions to paste into `AGENTS.md` or `CLAUDE.md`
(`--agent claude|codex|cursor|omp` tailors them). Run `handup doctor` if
something doesn't work, and `handup help COMMAND` for every flag.

## How requests work

handup is in beta. Agents submit a request with previews (a command, diff,
file, image, JSON and more), wait, and receive the human decision with the
content hash they must bind execution to. A deny is a normal answer with
feedback, never a transport error and never permission to retry unchanged.

Command requests can also be run explicitly from the desktop app with **Run**
or **Run as admin**. The agent receives `run_result` and must not run the command
again. Phone and web clients never run commands: they review, decide, and can
ask the desktop to stop a running one; see [Desktop](desktop.md).

## Where to go next

- [Agents](agents/mcp.md): Claude Code, Codex, cursor, omp, MCP and shell/CI
  setup, with the approval contract agents must follow.
- [Any agent or custom harness](agents/custom.md): steps to add handup to your
  own agent loop, SDK app or framework over MCP, CLI or HTTP.
- [Email drafts](agents/email.md): ask before sending, let the human edit the
  draft, then send it with your own mail tool.
- [Agent skill](agents/skill.md): print instructions with the installed CLI, or
  run `handup skill install` for the version-matched skill with complete
  offline docs.
- [Integrations](integrations/index.md): let other tools react to requests.
- [Remote access](remote.md), the [relay](relay.md), the
  [mobile app](mobile.md), the [desktop app](desktop.md) and the
  [web inbox](web.md) (included from v0.1.2): approve away from the terminal.
- [Rules](rules.md): scoped allow rules, presence routing and the terminal
  inbox.
- [Cookbook](cookbook/index.md): runnable recipes for canned email replies,
  sender routing, a policy auto-decider, forms, a publish gate and meeting
  replies.
- Machine contracts: the daemon [OpenAPI](openapi.json) and the
  [request](schema/request.schema.json) and
  [decision](schema/decision.schema.json) JSON Schemas.

Agents can read these docs as plain Markdown: append `.md` to any page URL
(without the trailing slash, `/index.md` for this page) or request the page with
`Accept: text/markdown`. [/llms.txt](../../index.md) indexes every page by section and
[/llms-full.txt](../../llms-full.txt) holds the docs in one file (per-operation API
pages are linked from the API overview instead).

## Support

Ask a question or reach us on the
[support page](https://gethandup.dev/support). The product site is
[gethandup.dev](https://gethandup.dev).

### Report a bug or request a feature

Every client opens the support page in your browser with the report kind,
handup version and platform filled in; you add the description and, if you
want a reply, your email.

- Desktop app, phone app and web UI: Settings → **Help & feedback** →
  **Report a bug** or **Request a feature**. The keyboard shortcuts sheet
  (<kbd>?</kbd>) also links **Report a bug**.
- Terminal: `handup report` (add `--feature` or `--question`). Over SSH, with
  `--print` or when output is not a terminal, it prints the URL instead of
  opening a browser.
- To paste exact build details into a report, open Settings → **About** and
  press **Copy**: it copies the app version, commit, build date, platform,
  daemon version and license state as plain text.
