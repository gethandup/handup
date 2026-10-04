# Claude Code

```sh
handup integrate claude --dry-run
handup integrate claude
handup prompt --agent claude
```

The installer merges a PermissionRequest command hook (`handup hook claude`, timeout 660 seconds) into ~/.claude/settings.json and the handup MCP server into ~/.claude.json (below); `--no-mcp` installs only the hook. Existing keys and other hooks survive; a unique handup.bak backup is created before every changed write, and every file is checked before any is written. Reapply is idempotent. Remove with `handup integrate claude --uninstall`. Hooks apply only when Claude requests permission, not every tool call or actions already allowed by rules. Only PermissionRequest is supported; PreToolUse has a different decision contract and is deliberately not registered.

Input includes hook_event_name, tool_name, tool_input, session_id, cwd. Bash shows command and description. Edit/MultiEdit reads current content and computes a unified diff in sequential edit order; ambiguous/missing matches fail closed to the configured fallback. Write shows a diff or code for a new file. Other tools (including WebFetch) show tool-input JSON. Handup never edits the file itself.

Allow output: `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`. Approved edited fields merge into the original tool_input and return a complete `decision.updatedInput`. Deny output uses `behavior:"deny"` and `message` equal to human feedback (or `Denied in handup`). No persistent updatedPermissions are granted.

When the human uses desktop **Run**, the request is approved with `run_result`,
but the hook returns `behavior: "deny"` with the run summary and **do not run
again** instruction. This blocks the original Bash call because execution was
already attempted, not because the human denied it. Nonzero exits, timeouts,
Cancel and launch/authentication errors follow the same path. Consume the
summary; do not retry. [Result fields](mcp.md#desktop-run-results).

Unreachable daemon or expiration defaults to exit 0 with no stdout decision, so Claude uses its native prompt (or denies when no permission host exists). Set `handup config set integrations.claude.fallback deny` for explicit denial. Neither fallback ever allows. The hook does not autostart a missing daemon; run handup serve or install its service. Requests have no deadline by default. The installed host hook timeout is still 660 seconds: increase it for longer human waits. If Claude kills the hook, the request remains pending and no approval is returned.

For agent-initiated requests, the same install merges a user-scope stdio entry in ~/.claude.json, equivalent to `claude mcp add --scope user --transport stdio handup -- handup mcp`, and adds the `mcp__handup` rule to `permissions.allow` in settings.json. handup's MCP tools only ask the human, so the rule keeps the hook from asking a second time about the request itself. `handup integrate mcp --client claude-code` installs the MCP server alone, without the hook or the rule. Restart Claude and check /mcp.

Sources: https://code.claude.com/docs/en/hooks#permissionrequest and https://code.claude.com/docs/en/mcp
