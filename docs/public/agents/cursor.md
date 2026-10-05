# cursor

```sh
handup integrate mcp --client cursor --dry-run
handup integrate mcp --client cursor
handup prompt --agent cursor
```

`handup integrate all` includes this MCP-only integration when
`~/.cursor/` exists, creating `mcp.json` if absent. `--no-mcp` skips Cursor;
`--uninstall` removes handup from every installed agent.

The installer safely merges the handup stdio server (command handup, args ["mcp"]) into ~/.cursor/mcp.json, backing up before changes. Other servers and keys remain. Reapplying is idempotent; `handup integrate mcp --client cursor --uninstall` removes only handup. Existing conflicting handup entries are not overwritten.

Restart Cursor and enable handup under Customize. Cursor may ask before MCP calls.

Ask before destructive/irreversible actions, external publication or messages, costly resource use, credential changes/access, or ambiguous intent. Include the exact proposed action and its effects. Do not execute while pending. Only approved/answered permits the approved action; bind execution to content_hash and re-request if the action changes. A deny is a normal human answer, not a transport error. Read feedback, stop, and revise only when requested. Never retry the same request or treat expired, cancelled, or error as permission.

An approved command with `run_result` was already attempted by desktop **Run**.
Read its exit code/error and output; **do not run again**, even on failure.
Without `run_result`, approval still permits the reviewed action.

Read [MCP](mcp.md) for tool arguments and polling. Paths resolve from the server process cwd; use absolute paths if your client starts servers outside the project.

Source: https://cursor.com/docs/mcp
