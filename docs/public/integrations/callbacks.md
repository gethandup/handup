# Per-request callbacks

Use a callback when the submitting system cannot keep a connection open. Unlike
[event hooks](hooks.md), the destination belongs to one request, and receives only
its `request.decided`, `request.expired`, or `request.cancelled` transition.

## Enable permitted hosts

Callbacks are disabled by default. Configure the daemon; saves apply live, but
the secret environment variable must be set when the daemon starts:

```yaml
callbacks:
  allowlist: [automation.example.com, '*.workflows.example.com', '127.0.0.1']
  secret_env: HANDUP_CALLBACK_SECRET
```

Exact host matching is case-insensitive; `*.workflows.example.com` permits
subdomains, not the bare `workflows.example.com` or lookalike suffixes. Entries
are hosts only, without schemes, ports, paths, or credentials. Ports and paths
on an allowed host are not restricted. Keep the list narrow and only permit
hosts you trust: this authorizes submitters to cause outbound requests to them,
including any private addresses those hosts resolve to. It is not an IP-level
network firewall. An empty allowlist rejects all callbacks with HTTP 400.

URLs require HTTPS, except `http://127.0.0.1` and `http://localhost` for local
tools. Embedded credentials and fragments are rejected. The daemon checks the
allowlist when creating the request and again before delivery; redirects are
not followed. Callback URLs are persisted with the request and included in its
content hash, so treat path/query tokens as sensitive request metadata.

`secret_env` is optional. Set the named variable in the daemon's environment,
not in YAML. If configured but unset or empty, delivery fails rather than sending
unsigned. Without it the callback is unsigned. Config CLI keys are
`callbacks.allowlist` (YAML list) and `callbacks.secret_env` (variable name).

## Submit

```sh
handup ask --title 'Deploy production' \
  --callback-url https://automation.example.com/handup/result --json
```

The daemon API accepts the optional `callback_url` string in `POST /v1/requests`.
`handup ask --request -` also accepts it in full request JSON; an explicit
`--callback-url` overrides that JSON field. MCP tool arguments are unchanged.

## Receive and verify

The POST uses the same [versioned event envelope and signing contract](hooks.md)
as hooks: `v: 1`, `type`, event `id`, `time`, and `data.request` metadata plus
`data.decision` when present. Summary and previews are excluded; decision
feedback is included and credential-like text is redacted, as for hooks.

Desktop Run also includes `data.decision.run_result`: redacted stdout/stderr
tails and execution metadata are decision data, so excluding previews does
not exclude this output. Treat receivers as trusted. An approve outcome with
this field means the command was already attempted, even on nonzero exit or
error: consume the [result](../agents/mcp.md#desktop-run-results) and **do not
execute it again**.

```text
x-handup-timestamp: <Unix seconds>
x-handup-signature: sha256=<hex HMAC-SHA256(secret, "<timestamp>.<raw body>")>
```

Verify raw bytes with constant-time comparison, reject stale timestamps, and
deduplicate by event `id`. Respond with a 2xx status after safely accepting the
notification. There is one delivery scheduled per terminal transition, but
network errors, 10-second timeouts, and HTTP 5xx can cause three retries with
100/200/400ms backoff. Retries retain the body/event id; HTTP 4xx and redirects
are not retried. An expired event may contain the configured timeout decision:
inspect the event type and decision rather than treating every terminal status
as approval.

Delivery is asynchronous and best-effort, not a durable outbox or exactly-once
transport. Daemon shutdown can lose pending delivery; it is not replayed on
restart. Failures never undo or delay the human decision. Final outcomes append
`callback.delivered` or `callback.failed` to request audit; failures are logged
without the destination URL or provider response. Use polling to reconcile
missing notifications when reliability is essential.

## GitHub deployment protection outline

A GitHub App integration can receive a deployment protection webhook, verify
GitHub's signature, persist the deployment/environment correlation, and create a
handup request with the integration's own allowlisted HTTPS callback URL. On a
verified `request.decided` callback, the integration looks up that correlation
and uses its GitHub App installation credentials to submit the corresponding
approved/rejected deployment protection review. Expiration/cancellation should
fail closed, never approve. Deduplicate event ids and GitHub review submissions.

Do not use GitHub's review API as `callback_url`: handup sends its own event
schema and does not attach GitHub App authentication. The adapter must translate
and authenticate the review. Keep installation credentials out of request data.

## n8n Wait node

Use a Wait node configured to resume on a webhook call. Before waiting, submit a
handup request whose `callback_url` is that execution's resume URL (n8n exposes
`$execution.resumeUrl`). Allowlist the n8n production host, not a broad wildcard
covering unrelated tenants. Configure the Wait node to accept POST.

After resume, inspect `body.type` and `body.data.decision.outcome`, using deny,
expired, and cancelled branches to stop the workflow. Verify HMAC before running
privileged actions; if the Wait node cannot verify raw bytes itself, place a
verifying proxy in front of its resume endpoint. Account for an immediate
rule-based decision racing the Wait node: ensure the resume endpoint is ready
before submitting or use a proxy that durably holds verified callbacks until
n8n is waiting. Use polling/reconciliation for callbacks lost during restarts.
