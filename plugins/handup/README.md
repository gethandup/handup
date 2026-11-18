# handup plugin

handup is an approval inbox for AI agents. With this plugin your agent asks
you before risky actions such as database migrations, releases or emails, asks
you questions when it needs a choice, and tells you when work is done. You
approve, deny or answer from your terminal, the handup desktop app, or your
phone.

## Requirements

The plugin needs the handup app on the same computer. Install it first:

```sh
curl -fsSL https://github.com/gethandup/handup/releases/latest/download/install.sh | sh
```

On a Mac you can use `brew install --cask gethandup/tap/handup`. Other
packages are on the [downloads page](https://gethandup.dev/downloads). Every
install works fully for a 14-day trial, then needs a
[license](https://gethandup.dev/#pricing).

## Install the plugin

- **Claude Code**: `/plugin marketplace add gethandup/handup`, then
  `/plugin install handup@handup`
- **Codex**: `codex plugin marketplace add gethandup/handup`, then
  `codex plugin add handup@handup`
- **Gemini CLI**: `gemini extensions install https://github.com/gethandup/handup --ref main`
- **Any MCP client**: run `handup mcp` as a stdio server, or `handup setup` to
  configure every agent it finds

## What it adds

- **MCP server `handup`**: the tools `request_approval`, `ask_question`,
  `notify`, `check_request`, `wait_requests`, `cancel_request` and
  `list_requests`.
- **Skill `handup`**: when to ask, how to write a request with previews, and
  how to handle a denial.

## What it runs and sends

The plugin starts one program: `handup mcp`, from the handup app you installed.
It talks to the handup background service on this computer over a local
socket and starts that service if it is not running. Requests, previews and
your decisions are stored on this computer. They leave it only through
features you turn on: phone access over your own Tailscale network or the
end-to-end encrypted relay ([remote access](https://github.com/gethandup/handup/blob/main/docs/public/remote.md)),
and notification services you configure, such as phone push or ntfy.
Activating a license key sends that key once to `https://gethandup.dev/api/license`.
The plugin itself contains no programs, only configuration and documentation.

## Permission prompts

The plugin does not change your agent's own permission prompts. To send
Claude Code or Codex permission prompts to handup as well, run `handup setup`
(or `handup integrate claude` / `handup integrate codex`).

## Links

- Website: https://gethandup.dev
- Documentation: https://github.com/gethandup/handup/tree/main/docs/public
- Support: support@gethandup.dev
- License: skill MIT, documentation CC BY 4.0 (see `LICENSE.md`)
