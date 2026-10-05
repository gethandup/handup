# The approval inbox for AI agents

handup is in beta. Agents submit a request with previews (a command, diff,
file, image, JSON and more), wait, and receive the human decision with the
content hash they must bind execution to. A deny is a normal answer with
feedback, never a transport error and never permission to retry unchanged.

Command requests can also be run explicitly from the desktop app with **Run**
or **Run as admin**. The agent receives `run_result` and must not run the command
again. Phone and web clients never run commands: they review, decide, and can
ask the desktop to stop a running one; see [Desktop](desktop.md).

## Install

Install compiled handup software from [downloads and releases](downloads.md).
You do not need Git, Rust, Make or application source access. No public release
has been published yet; platform availability is listed in the downloads guide.

After installing a supported release:

```sh
handup service install  # run the daemon as a user service
handup doctor --json
```

Releases work fully for a 14-day trial, then need a license:
`handup license status` shows the days left. See [License and trial](license.md).

## Set up an agent in 60 seconds

```sh
handup integrate all   # every detected agent: Claude Code, Codex, Cursor, omp
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add gethandup/handup --skill handup
handup prompt          # paste into your project instructions
handup ask --title "Review action" --command "echo hello" --wait --json
```

The [agent skill](agents/skill.md) gives your agent setup instructions, the
approval contract and offline reference docs. `handup prompt` uses generic
instructions; `--agent claude|codex|cursor|omp` tailors them.

`all` detects agent homes (see [`--list`](cli.md#agent-integration)), so it can
create missing configs. Claude Code and Codex get hooks plus MCP; Cursor and
omp get MCP only. An existing omp tool-gating extension is upgraded, but a
new one is opt-in with `handup integrate omp`.

Only one agent?

- [`handup integrate claude`](agents/claude-code.md)
- [`handup integrate codex`](agents/codex.md)
- [`handup integrate omp`](agents/omp.md)
- [`handup integrate mcp --client cursor`](agents/cursor.md)

Decide from another terminal with `handup approve ID` or
`handup deny ID -m "feedback"`, from the desktop inbox (`handup ui`), or from a
paired phone. Every flag is described by `handup help COMMAND`.

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
  [mobile app](mobile.md) and the [desktop app](desktop.md): approve away from
  the terminal.
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
