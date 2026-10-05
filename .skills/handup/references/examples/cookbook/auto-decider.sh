#!/bin/sh
# Policy decide hook for spend thresholds and a vendor allowlist.
# Reads the full request on stdin and prints a decision or nothing.
# Everything it does not decide stays pending for a human.
#
# config.yaml:
#   hooks:
#     - name: spend-policy
#       decide: /abs/path/examples/cookbook/auto-decider.sh
#       tool: spend.purchase
#
# Policy for requests with tool "spend.purchase" and input {amount_usd, vendor}:
#   allowlisted vendor and amount <= AUTO_APPROVE_USD -> approve
#   amount > AUTO_DENY_USD                             -> deny with feedback
#   anything else                                      -> leave for a human
set -eu
vendors=${SPEND_VENDORS:-"example-cloud registrar.example"}
approve_max=${AUTO_APPROVE_USD:-20}
deny_over=${AUTO_DENY_USD:-500}

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
