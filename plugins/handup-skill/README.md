# handup skill plugin

handup is an approval inbox for AI agents. With this plugin your agent asks
you before risky actions such as database migrations, releases or emails, asks
you questions when it needs a choice, and tells you when work is done. You
approve, deny or answer from your terminal, the handup desktop app, or your
phone.

This is the skill-only edition listed in the Claude and OpenAI plugin
directories. It holds documentation only: the agent runs the `handup` command
you installed. The full plugin in `plugins/handup` also adds the handup MCP
server.

## Requirements

Install the handup app on the same computer first; the
[downloads page](https://gethandup.dev/downloads) lists every package. Every
install works fully for a 14-day trial, then needs a
[license](https://gethandup.dev/#pricing). Run `handup setup` once to connect
the agents it finds, including their MCP configuration.

## What it adds

- **Skill `handup`**: when to ask, how to send a request with previews through
  the `handup` command, and how to handle a denial.

## What it runs and sends

The plugin contains no programs. The agent runs `handup` commands, which talk
to the handup background service on this computer over a local socket.
Requests, previews and your decisions are stored on this computer. They leave
it only through features you turn on: phone access over your own Tailscale
network or the end-to-end encrypted relay
([remote access](https://github.com/gethandup/handup/blob/main/docs/public/remote.md)),
and notification services you configure, such as phone push or ntfy.
Activating a license key sends that key once to `https://gethandup.dev/api/license`.

## Links

- Website: https://gethandup.dev
- Documentation: https://github.com/gethandup/handup/tree/main/docs/public
- Example scripts: https://github.com/gethandup/handup/tree/main/examples
- Support: support@gethandup.dev
- License: skill MIT, documentation CC BY 4.0 (see `LICENSE.md`)
