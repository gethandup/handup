#!/bin/sh
# Ask before an agent spends money. Pair with auto-decider.sh: small purchases
# from allowlisted vendors are approved by policy, large ones are refused, and
# the rest wait for a human.
#
#   sh examples/cookbook/spend-request.sh 12 example-cloud "Extra build minutes"
#
# Exit 0 means approved; buy exactly what was approved.
set -eu
amount=${1:?Usage: spend-request.sh AMOUNT_USD VENDOR DESCRIPTION}
vendor=${2:?Usage: spend-request.sh AMOUNT_USD VENDOR DESCRIPTION}
what=${3:?Usage: spend-request.sh AMOUNT_USD VENDOR DESCRIPTION}

request=$(jq -n --arg amount "$amount" --arg vendor "$vendor" --arg what "$what" '{
  title: "Spend $\($amount) at \($vendor)",
  summary: $what,
  kind: "custom",
  risk: (if ($amount | tonumber) > 100 then "high" else "medium" end),
  tool: "spend.purchase",
  source: {agent: "billing-agent"},
  timeout: "1h",
  previews: [{type: "json", inline: ({amount_usd: ($amount | tonumber), vendor: $vendor, description: $what} | tojson)}],
  input: {amount_usd: ($amount | tonumber), vendor: $vendor}
}')
decision=$(printf '%s' "$request" | handup ask --request - --wait --json) || {
  code=$?
  printf '%s' "$decision" | jq -r '"\(.status): \(.feedback // "no feedback")"' >&2
  exit "$code"
}
# A human may edit amount or vendor before approving; buy the edited values.
printf '%s\n' "$decision" | jq -c --argjson req "$request" \
  '{status, decided_by, feedback, purchase: (.fields // $req.input)}'
