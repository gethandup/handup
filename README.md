<div align="center">

<img src="assets/icon.png" width="96" alt="handup">

# handup

**The approval inbox for AI agents.**

</div>

Your agents ask before risky actions like migrations, releases and emails. You
see exactly what they want to do and approve or deny from your terminal, desktop
or phone.

https://github.com/user-attachments/assets/cc0aa659-68e8-47e8-8d35-bafb793d742c

> **Beta.** Runs on Linux and macOS (Intel and Apple Silicon), with an
> Android companion app; no native iOS app yet. Get it from this repository's
> [Releases](https://github.com/gethandup/handup/releases) page or see
> [downloads](docs/public/downloads.md).
> Releases work fully for a 14-day trial, then need a paid license; see
> [License and trial](docs/public/license.md).

This repository holds handup's documentation, agent skill and examples. The
application source is not here.

## What you get

- **Real previews**: commands, diffs, code, Markdown, JSON, HTML, email, images,
  video, audio, PDFs and file bundles, snapshotted so what you approve is what runs.
- **Any agent that speaks MCP**: Claude Code, Codex, Cursor, omp, opencode and any
  other MCP client, plus the CLI and a local HTTP API for scripts and CI.
- **Decide anywhere**: terminal inbox, desktop app, or your phone over
  [Tailscale](docs/public/remote.md#tailscale-recommended) (five-minute setup)
  or an end-to-end encrypted relay.
- **Feedback, not errors**: deny with a note and the agent revises and asks again.
- **Fewer taps**: scoped allow rules, presence routing and a timed YOLO mode,
  with every auto-handled request still in the history.

## Connect an agent

```sh
handup service install                  # run the daemon as a user service
handup integrate all   # every detected agent: Claude Code, Codex, Cursor, omp
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add gethandup/handup --skill handup
handup prompt          # generic instructions; --agent claude|codex|cursor|omp tailors them
handup ask --title "Review action" --command "echo hello" --wait --json
```

The [agent skill](docs/public/agents/skill.md) gives the agent setup instructions,
the approval contract and offline docs. Only one agent? Use
[`handup integrate claude`](docs/public/agents/claude-code.md),
[`handup integrate codex`](docs/public/agents/codex.md),
[`handup integrate omp`](docs/public/agents/omp.md), or
[`handup integrate mcp --client cursor`](docs/public/agents/cursor.md).

`all` detects agent home directories and creates missing configs. omp gets MCP
only unless its tool-gating extension is already installed; add that optional
gate explicitly with `handup integrate omp`.

## Agent skill

Teach your agent when and how to ask. With handup installed, use the
version-matched copy bundled with it:

```sh
handup skill install                    # or --agent claude, --agent codex, --project
```

Without handup, install from this repository:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add gethandup/handup --skill handup
```

See [docs/public/agents/skill.md](docs/public/agents/skill.md) for agent targets
and global installs.

## Docs

Read them on [docs.gethandup.dev](https://docs.gethandup.dev); the product site
is [gethandup.dev](https://gethandup.dev).

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
- [Cookbook](docs/public/cookbook/index.md): advanced recipes for automated decisions
- [Examples](examples/README.md) and the [LLM-readable guide](llms.txt)

## Cookbook

[![handup cookbook: recipes for automated decisions](docs/public/cookbook/img/index.webp)](docs/public/cookbook/index.md)

Advanced recipes with runnable scripts in [examples/cookbook](examples/cookbook/):

- [Canned email replies](docs/public/cookbook/email-canned-replies.md): pick a template, edit, send what you approved
- [Route email by sender](docs/public/cookbook/email-routing.md): rules archive receipts, refuse no-reply senders, flag VIPs
- [Policy auto-decider](docs/public/cookbook/auto-decider.md): a hook that decides thresholds and allowlists in code
- [Form approvals](docs/public/cookbook/form-approvals.md): adjust amount, reason and flags before approving
- [Publish gate](docs/public/cookbook/publish-gate.md): edit, then Publish now or Schedule; silence fails closed
- [Meeting replies](docs/public/cookbook/meeting-replies.md): RSVP and slot questions in one card

## Issues

Bug reports and feature requests are welcome in
[Issues](https://github.com/gethandup/handup/issues). For anything else, email
[support@gethandup.dev](mailto:support@gethandup.dev). Report security problems
privately; see [SECURITY.md](SECURITY.md).

## License

Documentation is [CC BY 4.0](LICENSE.md#documentation-cc-by-40); the agent
skill, examples and code snippets are [MIT](LICENSE.md#skill-examples-and-code-snippets-mit).
The handup application is licensed separately and is not in this repository.
