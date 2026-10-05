# Claude Code

```sh
handup integrate claude --dry-run
handup integrate claude
handup prompt --agent claude
```

To include every detected agent instead, use `handup integrate all`; it uses
this same full Claude integration when `~/.claude/` or `~/.claude.json` exists.
Preview with `--dry-run`, or remove installed integrations with `--uninstall`.

The installer merges command hooks into ~/.claude/settings.json: PermissionRequest (`handup hook claude`, timeout 660 seconds) plus UserPromptSubmit (same command, timeout 10 seconds) and Stop (same command, `"asyncRewake": true`, timeout 86400 seconds), both for [notice replies](#notice-replies), and the handup MCP server into ~/.claude.json (below); `--no-mcp` installs only the hooks. An older handup Stop hook without `asyncRewake` is upgraded in place on reinstall. Existing keys and other hooks survive; a unique handup.bak backup is created before every changed write, and every file is checked before any is written. Reapply is idempotent. Remove all three with `handup integrate claude --uninstall`. Permission hooks apply only when Claude requests permission, not every tool call or actions already allowed by rules. PreToolUse has a different decision contract and is deliberately not registered.

Input includes hook_event_name, tool_name, tool_input, session_id, cwd. Bash shows command and description. Edit/MultiEdit reads current content and computes a unified diff in sequential edit order; ambiguous/missing matches fail closed to the configured fallback. Write shows a diff or code for a new file. Other tools (including WebFetch) show tool-input JSON. Handup never edits the file itself.

Allow output: `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`. Approved edited fields merge into the original tool_input and return a complete `decision.updatedInput`. Deny output uses `behavior:"deny"` and `message` equal to human feedback (or `Denied in handup`). No persistent updatedPermissions are granted.

When the human uses desktop **Run**, the request is approved with `run_result`,
but the hook returns `behavior: "deny"` with the run summary and **do not run
again** instruction. This blocks the original Bash call because execution was
already attempted, not because the human denied it. Nonzero exits, timeouts,
Cancel and launch/authentication errors follow the same path. Consume the
summary; do not retry. [Result fields](mcp.md#desktop-run-results).

Unreachable daemon or expiration defaults to exit 0 with no stdout decision, so Claude uses its native prompt (or denies when no permission host exists). Set `handup config set integrations.claude.fallback deny` for explicit denial. Neither fallback ever allows. The hook does not autostart a missing daemon; run handup serve or install its service. Requests have no deadline by default. The installed host hook timeout is still 660 seconds: increase it for longer human waits. If Claude kills the hook, the request remains pending and no approval is returned.

For agent-initiated requests, the same install merges a user-scope stdio entry in ~/.claude.json, equivalent to `claude mcp add --scope user --transport stdio handup -- handup mcp`, and adds the `mcp__handup` rule to `permissions.allow` in settings.json. handup's MCP tools only ask the human, so the rule keeps the hook from asking a second time about the request itself. `handup integrate mcp --client claude-code` installs the MCP server alone, without the hooks or the rule. Restart Claude and check /mcp.

## Notice replies

A human may type an optional reply under an info notice before choosing **OK** or **Dismiss**. The UserPromptSubmit and Stop hooks claim unread non-empty replies to notices whose `session` equals Claude's `session_id` (the same id permission requests carry). Agents need not pass it: when Claude Code runs `handup mcp`, requests created without a `session` argument default to `CLAUDE_CODE_SESSION_ID`, which Claude sets to that id. An MCP server keeps the id it was spawned with, so after `/clear` or `--continue` it can differ from the hook's; an explicit `session` argument wins. On UserPromptSubmit, replies are added as `hookSpecificOutput.additionalContext`. Stop runs as a background `asyncRewake` waiter: unread replies print on stderr with exit 2, which Claude shows as a system reminder and wakes on, even when idle; otherwise, while the session has pending notices, it waits for them and wakes on the first reply. It exits 0 silently when no notice is pending, when Claude exits, when a newer Stop waiter for the session takes over, or on error. Each reply is one line, `Reply from the human to your notice TITLE: FEEDBACK`, and is delivered once, to whichever consumer claims it first (these hooks or the MCP server's [own delivery](mcp.md#notice-replies)). Without replies, or if the daemon is unreachable, the hooks print nothing and exit 0 (fail open).

Sources: https://code.claude.com/docs/en/hooks#permissionrequest, https://code.claude.com/docs/en/hooks#userpromptsubmit, https://code.claude.com/docs/en/hooks#stop and https://code.claude.com/docs/en/mcp
