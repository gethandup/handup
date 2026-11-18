
# Cookbook: automated decisions

Advanced recipes for wiring handup into everyday automation: email, money,
publishing and calendars. Each one has a runnable script in
[`examples/cookbook/`](../../../examples/cookbook), the request it sends, and
how it reads the decision. They assume you know the basics from
[Getting started](../index.md) and [Custom agents](../agents/custom.md).

| Recipe | What it shows |
| --- | --- |
| [Canned email replies](email-canned-replies.md) | Pick a reply template from option previews, edit the filled draft, send exactly what you approved |
| [Route email by sender](email-routing.md) | Tag each proposed action with a `tool` name; `rules:` in config.yaml archive receipts, refuse no-reply senders, flag VIPs |
| [Policy auto-decider](auto-decider.md) | A `decide:` hook that decides what rules cannot express (thresholds, allowlists) and leaves the rest to you |
| [Form approvals](form-approvals.md) | Typed form fields (amount, reason, flags) the human adjusts before the agent acts |
| [Publish gate](publish-gate.md) | Editable post text, Publish now vs Schedule options, timeout that fails closed, dedupe |
| [Meeting replies](meeting-replies.md) | Two questions in one card: RSVP with a recommended answer and multi-select slots |

## Who decides what

A request can be decided at four layers. Put each decision at the lowest layer
that can make it safely:

1. **Your caller** decides whether to ask at all. Anything it can do without
   side effects needs no request.
2. **[Rules](../rules.md)** match fields you set on the request (`agent`,
   `kind`, `tool`, `risk`, `session`, `command`, `cwd`, `repo`) and approve,
   deny, or ask, optionally overriding the risk. First match wins.
3. **A policy hook** ([auto-decider](auto-decider.md)) inspects pending request
   content and decides with code when a rule is too coarse.
4. **You** decide everything left, on the desktop, phone, or `handup inbox`.

The `tool` field is the bridge between your script and your rules: give every
kind of action a stable, specific name (`email.archive.receipt`,
`spend.purchase`, `social.publish`) and rules can treat each one differently.

## Running the recipes

Every script submits through `handup ask --request - --wait --json`, so it
works against your normal daemon. To try them without touching your real
queue, run an isolated daemon as in [Runnable requests](../../../examples/README.md)
and decide from a second terminal (`handup ls --json`, `handup approve ID`,
`handup deny ID -m why`, `handup answer ID --select LABEL`), or from the app.

All scripts need `jq`. They print the approved action as JSON and exit 0 only
when it is approved or answered; every other exit (1 denied, 2 expired, 3
cancelled, 4 error) means **do not act**. None of them performs the action
itself: you pipe the output into your mail tool, payment API, or scheduler.

## Safety rules for automated decisions

- **Only `approved` or `answered` permits the action.** Denied, expired,
  cancelled, pending and errors never do. A nonblocking submit's exit 0 is
  not an approval.
- **Act on what was approved.** Apply `decision.fields` (the human's edits)
  and the selected `option`; never re-read the source and act on newer data.
- **Bind automated decisions to the content you inspected.** Send the
  `content_hash` you read; handup rejects a decision for different content.
- **Rules and policy never execute anything.** They only decide; your script
  still performs the action, once.
- **Agents never grant themselves scopes or turn on YOLO.** Those are human
  decisions.
