# Codex

## Quickstart

```sh
handup serve --foreground                 # or install the handup service
handup integrate codex --dry-run
handup integrate codex
handup prompt --agent codex
codex --sandbox workspace-write --ask-for-approval on-request
```

The reversible installer merges `handup hook codex` into `$CODEX_HOME/hooks.json` (default `~/.codex/hooks.json`) and the handup MCP server into `$CODEX_HOME/config.toml` (below); `--no-mcp` installs only the hook. It preserves other handlers, shows the config diffs, checks every file before writing any, and backs up changed configuration. Reapply is idempotent. Remove both with `handup integrate codex --uninstall`. Codex requires hook trust review; approve the reviewed hook in Codex before use. Requests have no deadline by default. The installed host hook timeout is still 660 seconds: increase it for longer human waits. If Codex kills the hook, the request remains pending and no approval is returned.

## Behavior and fallback

The `PermissionRequest` hook runs only when Codex requests permission, not on commands already allowed by its sandbox or rules. Bash becomes a command preview; other tools show tool-input JSON. Requests carry `source.agent=codex`, the session ID, and cwd. A human can deny with `handup deny ID -m 'Use staging instead'`, and Codex receives that feedback as `decision.message`. Approval returns only `behavior: allow`; denial, cancellation, and expiration return `behavior: deny` with feedback or a safe default. Codex never receives `updatedInput` or `updatedPermissions`: this hook cannot revise the tool call or grant Codex-native persistent permissions.

Exception: desktop **Run** approves the handup request with `run_result`, but
the hook returns `behavior: "deny"` and `decision.message` contains the run
summary and **do not run again** instruction. The original command is blocked
to avoid duplicate execution, including after a failed run; consume the result
rather than retrying. See [result fields](mcp.md#desktop-run-results).

`handup approve ID --scope session` creates a handup rule for matching repeat requests in that session; the daemon handles these repeats automatically, with rule audit metadata. Agents must not grant themselves a scope. If the daemon is unreachable or presence routes to the keyboard, the hook prints no decision, leaving Codex's native permission handling in place. It never grants fallback approval and does not auto-start a missing daemon.

## MCP and limitations

```sh
handup integrate mcp --client codex --dry-run
handup integrate mcp --client codex
```

`handup integrate codex` already includes this; the commands above install the MCP server alone. It uses `$CODEX_HOME/config.toml`, preserving comments and other servers. Codex defaults to a 60-second MCP tool timeout: prefer `wait=false` then `wait_requests`, or configure `tool_timeout_sec`. Read [MCP](mcp.md) for arguments and polling. Preview paths resolve from the MCP server cwd.

This adapter targets the Codex 0.159.2 `PermissionRequest` contract, not an app-server proxy. It gates only permission requests and does not enforce a separate pre-tool policy. In 0.159.2, `codex exec` forces approval policy `never`, even with `-c 'approval_policy="on-request"'`, so use the interactive CLI for native approval round-trips. A command must actually need escalation to invoke this hook. Native headless behavior depends on Codex's approval policy; a no-decision fallback is not permission.

Sources: https://developers.openai.com/codex/hooks#permissionrequest and https://developers.openai.com/codex/mcp
