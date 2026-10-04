# Shell and CI

Ask before destructive/irreversible actions, external publication or messages, costly resource use, credential changes/access, or ambiguous intent. Include the exact proposed action and its effects. Do not execute while pending. Only approved/answered permits the approved action; bind execution to content_hash and re-request if the action changes. A deny is a normal human answer, not a transport error. Read feedback, stop, and revise only when requested. Never retry the same request or treat expired, cancelled, or error as permission.

```sh
handup ask --request - --wait --json < examples/command.json
```

Exit codes of blocking `ask --wait` and `wait`. Nonblocking `ask`, `status` and
`show` also exit 0 while pending, so read `status` there.

| Exit | Meaning |
| --- | --- |
| 0 | approved/answered |
| 1 | denied |
| 2 | expired/timeout |
| 3 | cancelled |
| 4 | error |
| 5 | ran in the desktop app |

Exit 0 permits the reviewed action; it is not the command's own exit status.
Desktop **Run** returns an approved decision with `run_result` and CLI exit
**5**, even on failure (`ask --wait`, `wait`, `status` and `show`). Consume its
`exit_code`, `error` and output tails and **do not run again**. Wait JSON puts
it at the top level; status/show JSON puts it under `decision.run_result`.
See [the result contract](mcp.md#desktop-run-results).
`examples/deploy-gate.sh` skips its own execution on exit 5 and returns the
desktop command's `run_result.exit_code`, or 1 when no exit code is available.

Capture JSON even when exit is nonzero so human feedback is not lost. Do not use `|| true` before the execution gate. Ask auto-starts the local daemon unless daemon.autostart is false; wait/status do not. CI needs a reachable local daemon and a human able to decide (CLI, desktop app, terminal inbox, or a paired phone/browser when `remote.mode` is on; see [remote access](../remote.md)); unattended timeout is denial, not approval.

Agent shell tools often kill commands after a default timeout (omp: 300s), long before a human decides. Run `handup ask --wait` and `handup wait <id>` with the tool's timeout disabled or raised (omp: `timeout: 0`), or ask without waiting and keep the request id. A killed waiter is not an answer: the request stays pending. Reattach with `handup wait <id>` or read it with `handup status <id> --json`, and never act until the decision is approved.

See [examples](../../../examples/README.md) and [request schema](../schema/request.schema.json). Approval-gated shell flows must require exit 0 **and no `run_result`** before executing a command themselves. For HTTP-only runners use [submit tokens](../integrations/tokens.md); for wiring a custom harness see [any agent or custom harness](custom.md).
