#!/bin/sh
# Support refund with a form: the agent proposes amount and reason, the human
# adjusts them in typed fields and approves. Prints the refund to execute.
#
#   sh examples/cookbook/refund-form.sh examples/cookbook/order.json
#
# Exit 0 prints {order, amount, reason, notify_customer, note}; anything else
# means issue no refund.
set -eu
order=${1:?Usage: refund-form.sh ORDER.json}

request=$(jq -n --slurpfile o "$order" '$o[0] as $o | {
  title: "Refund \($o.currency) \($o.total) for order \($o.order)?",
  summary: "\($o.customer): \($o.complaint)",
  kind: "review",
  risk: "medium",
  tool: "support.refund",
  source: {agent: "support-agent"},
  dedupe_key: "refund:\($o.order)",
  timeout: "8h",
  previews: [{type: "markdown", inline: "**Customer:** \($o.customer)\n\n**Order:** \($o.order), \($o.item), paid \($o.paid)\n\n**Complaint:** \($o.complaint)\n\nProposed: full refund of \($o.currency) \($o.total)."}],
  input: {
    feedback: "required_on_deny",
    fields: [
      {name: "amount", type: "text", label: "Refund amount (\($o.currency))", default: $o.total, required: true},
      {name: "reason", type: "select", label: "Reason", options: ["Duplicate charge", "Service issue", "Goodwill", "Other"], default: "Duplicate charge", required: true},
      {name: "notify_customer", type: "boolean", label: "Email the customer", default: true},
      {name: "note", type: "textarea", label: "Internal note", description: "Saved on the order, never sent to the customer."}
    ]
  }
}')
decision=$(printf '%s' "$request" | handup ask --request - --wait --json) || {
  code=$?
  printf '%s' "$decision" | jq -r '"\(.status): \(.feedback // "no feedback")"' >&2
  exit "$code"
}
# Form values arrive in decision.fields; fall back to the defaults the human saw.
refund=$(printf '%s' "$decision" | jq --slurpfile o "$order" --argjson req "$request" '
  ($req.input.fields | map({(.name): .default}) | add) as $defaults |
  ($defaults + (.fields // {})) as $f |
  {order: $o[0].order, amount: $f.amount, reason: $f.reason,
   notify_customer: ($f.notify_customer // false), note: ($f.note // "")}')
# The form is human input: check the edited amount before your payment API sees it.
printf '%s' "$refund" | jq -e --slurpfile o "$order" \
  '(.amount | tonumber? // -1) as $a | $a > 0 and $a <= ($o[0].total | tonumber)' >/dev/null || {
  echo "refund amount must be a number between 0 and the order total" >&2
  exit 4
}
printf '%s\n' "$refund"
