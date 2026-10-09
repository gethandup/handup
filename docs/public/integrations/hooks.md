# Event hooks

Use top-level `hooks:` in `config.yaml` to send request lifecycle events to any
HTTP receiver or local program, or to let a local policy program decide new
requests. Restart `handup serve` after changing config. Hooks are independent of
desktop/ntfy/FCM/licensed push notifications, quiet hours, and `notifications.enabled`.
`webhook:` and `exec:` delivery never changes an approval decision; only a
[`decide:` hook](#decide-hooks) can.

```yaml
hooks:
  - name: automation
    webhook: http://127.0.0.1:8080/handup
    events: [request.created, request.decided]
    format: json
    secret_env: HANDUP_AUTOMATION_SECRET
    include_content: false
  - exec: [~/bin/on-decision.py, --production]   # name: on-decision
    events: [request.decided]
    timeout: 30s
  - decide: ~/bin/spend-policy                    # name: spend-policy
    tool: spend.purchase
```

Each entry has exactly one of `webhook:` (URL), `exec:`, or `decide:`. A program
is a string (one path) or an argv list; a leading `~` in the program is expanded
and nothing is interpreted by a shell. `name` is optional: it defaults to the
program's file stem or the URL host, lowercased with other characters replaced
by `-`. Names must be unique and match `[a-z0-9-]+`; set `name` explicitly when
two derived names collide. `format`, `template`, and `secret_env` are
webhook-only; `timeout` is for `exec` (default 30s) and `decide` (default 10s);
`tool`, `kind`, and `agent` filters are decide-only.

For webhook and exec hooks, omit `events` for all events;
`events: []` disables lifecycle delivery to that hook. Supported types:
`request.created`, `request.decided`, `request.expired`, `request.cancelled`,
`request.reminder`, and `request.expiring`. Reminder/expiring timing comes from
`notifications.remind_every` / `notifications.on_expiring`, even when notification
backends are disabled. Requests without deadlines never emit expiring events.
A [muted](../rules.md#floods-and-mutes) source emits neither, and a reminder or
expiry skipped by the per-source `notifications.burst` limit skips its event too.
Decide hooks run only on `request.created`; setting `events` on one is a config
error.

## Envelope and privacy

JSON bodies, exec stdin, and template context share the
[generated event schema](../schema/event.schema.json):

```json
{"v":1,"type":"request.created","id":"01J00000000000000000000000","time":"2026-09-30T12:00:00Z","data":{"request":{"id":"01J00000000000000000000001","title":"Deploy staging","risk":"low","agent":"codex","source":{"agent":"codex"},"status":"pending","url":"handup://r/01J00000000000000000000001","deep_link":"handup://r/01J00000000000000000000001"}}}
```

The event ULID is distinct from the request id. `data.decision` is present when
there is a decision, including timeout decisions. Request content is absent by
default. Opting into `include_content: true` adds `data.request.content.summary`
and `.previews` (snapshot descriptors; blob data is not fetched). Known credential
patterns are redacted in metadata and content. Source metadata and decision
feedback can still contain sensitive information; choose trusted receivers.
`url` uses the configured remote web origin when available, otherwise the native
`deep_link`. Custom templates render with strict undefined-variable handling.

Desktop Run decisions include `data.decision.run_result` even when
`include_content` is false: output tails are part of the decision, not preview
content. They are redacted, but may still contain sensitive command output;
choose receivers accordingly. The outcome is approve even if the command
failed. Consumers must inspect the [result](../agents/mcp.md#desktop-run-results)
and **not execute the command again** when it is present. Lifecycle event
hooks are distinct from native permission hooks, which block the original
tool call with the run summary to prevent duplicate execution.

## Slack, Discord, and Teams

Create an incoming webhook in the provider and keep its URL in private config:

```yaml
hooks:
  - name: slack
    webhook: https://hooks.slack.com/services/YOUR/WEBHOOK/PATH
    format: slack
    events: [request.created, request.decided]
  - name: discord
    webhook: https://discord.com/api/webhooks/YOUR/WEBHOOK
    format: discord
  - name: teams
    webhook: https://YOUR-TEAMS-WEBHOOK
    format: teams
```

Presets are minijinja templates producing Slack `text`, Discord `content`, and
Teams MessageCard `summary`/`text`. They JSON-escape title and links. Provider
length limits and Teams endpoint compatibility still apply; use a custom template
for a Teams Workflow endpoint that expects a different JSON shape. No signing
secret is required when the receiver does not implement handup HMAC verification.

```yaml
hooks:
  - name: custom
    webhook: https://example.com/events
    format: template
    template: '{"message": {{ (type ~ ": " ~ data.request.title)|tojson }}}'
```

Invalid template syntax is rejected at config load. A runtime missing variable
fails that delivery, not the request decision. Use `tojson` for JSON strings.

## n8n webhook node

Create a Webhook node accepting POST, activate the workflow, and copy its
production URL (test URLs only listen during n8n's test mode):

```yaml
hooks:
  - name: n8n
    webhook: https://n8n.example.com/webhook/handup
    events: [request.decided]
```

In the workflow, branch on `{{$json.body.type}}` and inspect
`{{$json.body.data.decision.outcome}}`. Deduplicate by `body.id` if an action is
not safe to repeat. A hook delivery is a notification, not permission to rerun a
denied operation. Add HMAC verification before processing if you use `secret_env`.
For command automation, also check `body.data.decision.run_result`: consume
an existing run result instead of running the approved command a second time.

## Home Assistant webhook automation

Create a local-only automation with an unguessable webhook id:

```yaml
alias: handup decision
triggers:
  - trigger: webhook
    webhook_id: YOUR_RANDOM_WEBHOOK_ID
    allowed_methods: [POST]
    local_only: true
conditions:
  - condition: template
    value_template: "{{ trigger.json.type == 'request.decided' }}"
actions:
  - action: persistent_notification.create
    data:
      title: handup
      message: "{{ trigger.json.data.request.title }}: {{ trigger.json.data.request.status }}"
```

Point handup at `http://HOME_ASSISTANT_LAN_IP:8123/api/webhook/YOUR_RANDOM_WEBHOOK_ID`
with `format: json`. Do not set a signing secret on non-loopback plaintext HTTP;
use HTTPS for signed delivery. Home Assistant's webhook trigger does not itself
verify handup signatures; use a verifying proxy if required.

## Exec script

Make this Python script executable and configure its path in `exec:`:

```python
#!/usr/bin/env python3
import json
import os
import sys

event = json.load(sys.stdin)
assert event["type"] == os.environ["HANDUP_EVENT"]
assert event["data"]["request"]["id"] == os.environ["HANDUP_REQUEST_ID"]
if event["type"] == "request.decided":
    decision = event["data"].get("decision", {})
    print(event["data"]["request"]["id"], decision.get("outcome"))
```

Commands are argv, never implicitly interpreted by a shell. They inherit the
daemon environment plus `HANDUP_EVENT` and `HANDUP_REQUEST_ID`. Stdin is JSON;
stdout/stderr are discarded. Nonzero exits fail delivery. The configured timeout
covers both stdin writing and process completion; the direct child is killed and
reaped on timeout. Hooks run with the daemon user's privileges. Avoid scripts
that spawn detached descendants: timeout does not kill an entire process tree.

## Decide hooks

A `decide:` hook runs a local policy program on `request.created` for each
request that is still pending (no rule, scoped allow, or YOLO decided it) and
matches the optional `tool`, `kind`, and `agent` filters. It gets the full
request JSON on stdin (the `GET /v1/requests/{id}` shape, including `tool`,
`input`, and previews) and the daemon environment plus `HANDUP_EVENT`,
`HANDUP_REQUEST_ID`, and `HANDUP_HOOK`. Stderr is discarded.

Empty or whitespace stdout leaves the request pending. Otherwise stdout must be
one JSON object `{"option": "...", "feedback": "...", "fields": {...}}`
(`feedback` and `fields` optional, no other keys, at most 64 KiB). handup applies
it through the normal decision path bound to the `content_hash` of the request it
sent, with `decided_by: hook:<name>`, and emits `request.decided` as for any
decider. A nonzero exit, timeout (default 10s), invalid JSON, unknown option, or
rejected decision logs a warning without payloads and leaves the request pending;
there is no fail-open path. If a human or rule decided first, the answer is
silently ignored. Each hook handles one request at a time.

`GET /v1/requests?decided_by=hook:` lists requests decided by any hook. History
labels them "Hook \<name\>" and counts them as `auto`; **N auto-handled · View**
above the Inbox list opens their read-only view. **← Inbox** returns to pending
requests; **Mark read** leaves them in History and syncs the read state across
devices connected to the same daemon. See the [read-state API](../cli.md#auto-handled-read-state).
See the [policy auto-decider](../cookbook/auto-decider.md) recipe.

## Signing, retries, and testing

Optional `secret_env` names an environment variable available to the daemon and
CLI test command. Unset/empty secrets skip signed delivery (never silently send
unsigned). Signed destinations must use HTTPS or loopback HTTP.

```text
x-handup-timestamp: <Unix seconds>
x-handup-signature: sha256=<hex HMAC-SHA256(secret, "<timestamp>.<raw body>")>
```

Verify raw bytes with a constant-time comparison, reject stale timestamps (for
example older than five minutes), and deduplicate event ids. Each retry uses the
same body/event id with a fresh signature timestamp. There are up to three
retries after the initial attempt, with 100/200/400ms backoff, for network errors,
10-second network timeouts, and HTTP 5xx only. HTTP 4xx and redirects do not retry.
Exec and decide hooks are not retried. Each hook has its own asynchronous task;
the bounded bus can lose events if a receiver remains slow (a lost
`request.created` leaves the request pending for a human). This is best-effort
delivery, not a durable queue. Failures are logged through tracing to daemon stderr.

```sh
handup hooks list
handup hooks test automation
handup hooks test automation --event request.decided
```

`list` validates the config and prints names/types/event filters (decide hooks
show `request.created`), never URLs or secrets. `test` sends a synthetic event
directly even if its type is excluded by the lifecycle filter; it does not create
or decide a real request. For a decide hook, `test` is a dry run: it runs the
program on a sample pending request (ignoring filters and `--event`) and prints
the returned decision, or that it left the request pending, without applying it.
A failed test returns the normal error exit code.

## Migration

`notifications.webhook` and `notifications.backends: [webhook]` are removed.
Loading either fails with a hint to use `hooks:`. Move URL and `secret_env` into a
named `webhook:` hook, select lifecycle `events`, and update the receiver
from the old `{event,id,title,...}` body to the versioned envelope above. Keep
`ntfy`, `desktop`, `fcm`, and `push` in `notifications.backends` unchanged.

The `type:`, `url:`, and `command:` hook keys are removed with no alias: write
`webhook: <url>` or `exec: <program>` instead (unknown keys fail config load).
