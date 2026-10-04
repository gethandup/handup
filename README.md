<div align="center">

<img src="assets/icon.png" width="96" alt="handup">

# handup

**Approve your AI agents from anywhere.**

</div>

Your agent wants to run a migration, push a release or send an email. Instead of
a yes/no prompt buried in a terminal, it asks handup. You see exactly what it
wants to do (the command, the diff, the file, the email), approve or deny with
feedback from your terminal, desktop or phone, and the agent gets your answer.

> **Pre-alpha.** Linux is the primary platform; macOS and iOS builds are untested.
> Binaries are not published yet; releases will appear on this repository's
> Releases page.

This repository holds handup's documentation, agent skill and examples. The
application source is not here.

## What you get

- **Real previews**: commands, diffs, code, Markdown, JSON, HTML, email, images,
  video, audio, PDFs and file bundles, snapshotted so what you approve is what runs.
- **Any agent that speaks MCP**: Claude Code, Codex, Cursor, omp, opencode and any
  other MCP client, plus the CLI and a local HTTP API for scripts and CI.
- **Decide anywhere**: terminal inbox, desktop app, or your phone over Tailscale
  or an end-to-end encrypted relay.
- **Feedback, not errors**: deny with a note and the agent revises and asks again.
- **Fewer taps**: scoped allow rules, presence routing and a timed YOLO mode,
  with every auto-handled request still in the history.

## Connect an agent

```sh
handup service install                  # run the daemon as a user service
handup integrate claude                 # or codex, omp: hook/extension plus MCP
handup integrate mcp --client cursor    # MCP only, for any other MCP client
```

## Agent skill

Teach your agent when and how to ask:

```sh
npx skills add gethandup/handup --skill handup
```

See [docs/public/agents/skill.md](docs/public/agents/skill.md) for agent targets
and global installs.

## Docs

- [Getting started](docs/public/index.md)
- [Agent setup](docs/public/agents/mcp.md): [Claude Code](docs/public/agents/claude-code.md),
  [Codex](docs/public/agents/codex.md), [Cursor](docs/public/agents/cursor.md),
  [omp](docs/public/agents/omp.md), [shell/CI](docs/public/agents/shell-ci.md),
  [any agent or custom harness](docs/public/agents/custom.md)
- [Desktop](docs/public/desktop.md), [mobile](docs/public/mobile.md),
  [remote access](docs/public/remote.md), [relay](docs/public/relay.md)
- [Rules, presence and YOLO](docs/public/rules.md)
- [CLI and daemon reference](docs/public/cli.md)
- [Integrations](docs/public/integrations/index.md): event hooks, submit tokens, callbacks
- [Examples](examples/README.md) and the [LLM-readable guide](llms.txt)

## Issues

Bug reports and feature requests are welcome in
[Issues](https://github.com/gethandup/handup/issues). Report security problems
privately; see [SECURITY.md](SECURITY.md).
