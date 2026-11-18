#!/bin/sh
# Handle each email one way by sender: the script tags the proposed action with
# a `tool` name and the `rules:` in config.yaml decide which tags need a human.
# Receipts are archived without asking, no-reply senders are refused, VIPs ask
# at high risk, and everything else asks normally.
#
#   # paste examples/cookbook/email-rules.yaml under `rules:` (handup config edit)
#   HANDUP_VIP='boss@example.com dana@example.org' \
#     sh examples/cookbook/email-route.sh examples/cookbook/receipt-email.json
#
# Exit 0 prints the approved action as JSON; your mail tool performs it.
set -eu
msg=${1:?Usage: email-route.sh MESSAGE.json}
vip=${HANDUP_VIP:-}

addr=$(jq -r '.from | capture("<(?<a>[^>]+)>").a // .' "$msg" | tr '[:upper:]' '[:lower:]')
subject=$(jq -r .subject "$msg")
case "$addr" in
  no-reply@* | noreply@* | donotreply@* | mailer-daemon@*) tool=email.reply.noreply ;;
  *)
    if printf '%s' "$subject" | grep -Eiq 'receipt|invoice paid|payment received'; then
      tool=email.archive.receipt
    elif [ -n "$vip" ] && printf ' %s ' "$vip" | grep -Fiq " $addr "; then
      tool=email.reply.vip
    else
      tool=email.reply.default
    fi
    ;;
esac

# The proposed action. Replies carry an editable draft; archives carry a label.
request=$(jq -n --slurpfile m "$msg" --arg tool "$tool" '$m[0] as $m |
  ($tool | startswith("email.archive.")) as $archive |
  {to: [$m.from], cc: [], bcc: [], subject: "Re: \($m.subject)",
   body: "Thanks, I have this and will reply properly soon."} as $draft | {
  title: (if $archive then "Archive \"\($m.subject)\" as Receipts" else "Reply to \($m.from)" end),
  summary: "From \($m.from): \($m.subject)",
  kind: "review",
  tool: $tool,
  source: {agent: "mail-assistant"},
  dedupe_key: "\($tool):\($m.message_id)",
  timeout: "24h",
  previews: [{type: "email", email: (if $archive
    then {from: $m.from, to: [$m.to], subject: $m.subject, date: $m.date, body: $m.body}
    else $draft + {from: $m.to, in_reply_to: {from: $m.from, date: $m.date, body: $m.body}} end)}]
} + (if $archive then {} else {input: $draft} end)')

decision=$(printf '%s' "$request" | handup ask --request - --wait --json) || {
  code=$?
  printf '%s' "$decision" | jq -r '"\(.status): \(.feedback // "no feedback")"' >&2
  exit "$code"
}
printf '%s' "$decision" | jq --slurpfile m "$msg" --arg tool "$tool" --argjson req "$request" '
  {message_id: $m[0].message_id, tool: $tool, decided_by: (.decided_by // "human")} +
  if ($tool | startswith("email.archive.")) then {action: "archive", label: "Receipts"}
  else {action: "reply", draft: (.fields // $req.input)} end'
