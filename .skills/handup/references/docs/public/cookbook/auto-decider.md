# Policy auto-decider

[Rules](../rules.md) match fixed fields. When the decision depends on the
request's content (an amount, a vendor allowlist, a time window, which files a
diff touches) write a small policy handler instead. A `decide:`
[hook](../integrations/hooks.md) reads the full request JSON on stdin and prints
a decision JSON object, or nothing to leave it pending for you.
Handler:
[`examples/cookbook/auto-decider.sh`](../../../examples/cookbook/auto-decider.sh);
requests: [`examples/cookbook/spend-request.sh`](../../../examples/cookbook/spend-request.sh).

The example policy covers agent purchases (`tool: spend.purchase`):

| Condition | Decision |
| --- | --- |
| Vendor allowlisted and amount ≤ `AUTO_APPROVE_USD` (20) | approve, with the reason as feedback |
| Amount > `AUTO_DENY_USD` (500) | deny: "purchases over $500 need a budget request" |
| Anything else | no decision: stays pending for a human |

## Hook it up

Add the hook to `config.yaml`; it applies when you save:

```yaml
hooks:
  - name: spend-policy
    decide: /abs/path/examples/cookbook/auto-decider.sh
    tool: spend.purchase
```

The hook inherits the daemon's environment plus `HANDUP_EVENT`,
`HANDUP_REQUEST_ID`, and `HANDUP_HOOK`. The default timeout is 10 seconds.
No socket, API credentials, or HTTP calls are needed.

## The handler

```sh
request=$(cat)
[ "$(printf '%s' "$request" | jq -r '.tool // empty')" = spend.purchase ] || exit 0

printf '%s' "$request" | jq -c --arg vendors "$vendors" \
  --argjson max "$approve_max" --argjson over "$deny_over" '
  (.input.amount_usd | tonumber? // null) as $amount |
  (.input.vendor // "") as $vendor |
  if $amount == null then empty
  elif $amount > $over then
    {option: "deny", feedback: "Policy: purchases over $\($over) need a budget request, not an agent."}
  elif $amount <= $max and ($vendors | split(" ") | index($vendor)) != null then
    {option: "approve", feedback: "Policy: $\($amount) at \($vendor) is under the $\($max) auto-approve limit."}
  else empty end'
```


Why it is shaped this way:

- **Full request on stdin.** The JSON has the same shape as
  `GET /v1/requests/{id}`, including `tool`, `input`, and previews.
- **Hash-bound automatically.** handup binds the returned decision to the
  snapshot sent to the policy. Changed content cannot be approved by a stale answer.
- **Silence is the default.** Anything the policy does not recognize exits 0
  without printing a decision, so a human sees it. Never write a fallback approve.
- **Races are harmless.** A rule, YOLO or a fast human may decide first;
  handup ignores the hook's answer if the request is no longer pending.
- **Feedback explains the decision.** It is shown in History and returned to
  the agent, so the reason travels with the result.

## The request side

```sh
$ sh examples/cookbook/spend-request.sh 12 example-cloud "Extra build minutes"
{"status":"approved","decided_by":"hook:spend-policy","feedback":"Policy: $12 at example-cloud is under the $20 auto-approve limit.","purchase":{"amount_usd":12,"vendor":"example-cloud"}}

$ sh examples/cookbook/spend-request.sh 900 example-cloud "GPU reservation"
denied: Policy: purchases over $500 need a budget request, not an agent.   # exit 1

$ sh examples/cookbook/spend-request.sh 60 example-cloud "Bigger runner"
# pending: waits for you
```

The request puts the amount and vendor in `input` so the policy can read them
and a human can edit them before approving; the script buys `decision.fields`
when present. Its `risk` is `high` above $100, so those purchases alert
loudly when they reach you.

## Limits

- Decisions are attributed to `hook:spend-policy` in History, Auto-handled,
  and the audit log.
- Decide hooks are best effort and not durable: if the daemon restarts before
  the hook runs, the request simply stays pending for a human. That is the
  safe failure.
- Hooks run with the daemon user's privileges. Keep the handler small,
  avoid detached child processes, and keep its timeout short.
- For decisions that are pure field matches (agent, tool, risk, command
  regex, paths), use [rules](../rules.md): they are declarative, tested with
  `handup rules test`, and decide before any hook runs.
