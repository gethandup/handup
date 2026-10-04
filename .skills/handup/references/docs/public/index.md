# Approval queue for AI agents

handup is pre-alpha. Agents submit a request with previews (a command, diff,
file, image, JSON and more), wait, and receive the human decision with the
content hash they must bind execution to. A deny is a normal answer with
feedback, never a transport error and never permission to retry unchanged.

Command requests can also be run explicitly from the desktop app with **Run**
or **Run as admin**. The agent receives `run_result` and must not run the command
again. Phone and web clients only review and decide; see [Desktop](desktop.md).

## Install

Build from source. You need stable Rust and Make; `mise install` selects the
repository's tool versions.

```sh
git clone https://gitlab.com/ariel-frischer/handup.git
cd handup
make install
make install-global  # ~/.local/bin/handup; add ~/.local/bin to PATH
handup service install  # run the daemon as a user service
handup doctor --json
```

## Set up an agent in 60 seconds

```sh
handup integrate mcp --client claude-code  # also codex, cursor, omp
handup prompt --agent claude              # paste into your project instructions
handup ask --title "Review action" --command "echo hello" --wait --json
```

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
- [Agent skill](agents/skill.md): private GitLab npx installation with complete
  offline docs; supported agents and the future public URL cutover.
- [Integrations](integrations/index.md): let other tools react to requests.
- [Remote access](remote.md), the [relay](relay.md), the
  [mobile app](mobile.md) and the [desktop app](desktop.md): approve away from
  the terminal.
- [Rules](rules.md): scoped allow rules, presence routing and the terminal
  inbox.
- Machine contracts: the daemon [OpenAPI](openapi.json) and the
  [request](schema/request.schema.json) and
  [decision](schema/decision.schema.json) JSON Schemas.

Agents can read these docs as plain Markdown: [/llms.txt](../../index.md) indexes
every page and [/llms-full.txt](../../llms-full.txt) is the whole set in one file.
