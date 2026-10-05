#!/bin/sh
# Canned email replies: the human picks a template (or types a reply), reviews
# and edits the filled draft, and the approved draft is printed as JSON for your
# own mail tool. handup never sends mail; neither does this script.
#
#   sh examples/cookbook/email-canned-reply.sh examples/cookbook/inbound-email.json > send.json
#
# Exit 0 prints {to, cc, bcc, subject, body}; any other exit means do not send.
set -eu
msg=${1:?Usage: email-canned-reply.sh MESSAGE.json}
sign=${HANDUP_MAIL_SIGNATURE:-Ari}

# 1. Pick a reply. Each template is an option whose preview is the filled body.
first=$(jq -r '.from | sub(" *<.*"; "") | split(" ")[0]' "$msg")
templates=$(jq -n --arg n "$first" --arg s "$sign" '{
  "Thanks, received": "Hi \($n),\n\nThanks, got it. I will take a look and come back to you if anything is missing.\n\nBest,\n\($s)",
  "Reply by Friday": "Hi \($n),\n\nThanks for the note. I will get you a full answer by Friday.\n\nBest,\n\($s)",
  "Decline politely": "Hi \($n),\n\nThanks for thinking of me. I have to pass on this one, but I appreciate the ask.\n\nBest,\n\($s)",
  "Book a call": "Hi \($n),\n\nThis is easier to sort out live. Could you pick a 20-minute slot that works for you this week?\n\nBest,\n\($s)"
}')
pick=$(jq -n --slurpfile m "$msg" --argjson t "$templates" '$m[0] as $m | {
  title: "Reply to \($m.from)?",
  summary: $m.subject,
  kind: "question",
  tool: "email.reply.pick",
  source: {agent: "mail-assistant"},
  previews: [{type: "email", email: {from: $m.from, to: [$m.to], subject: $m.subject, date: $m.date, body: $m.body}}],
  input: {questions: [{
    id: "reply", header: "Reply", recommended: 0, allow_free_text: true,
    question: "Which reply should I draft? Type your own text to use it as the body.",
    options: [$t | to_entries[] | {label: .key, preview: .value}]
  }]},
  options: [
    {id: "draft", label: "Draft it", outcome: "approve", style: "primary"},
    {id: "skip", label: "No reply", outcome: "deny"}
  ]
}')
answer=$(printf '%s' "$pick" | handup ask --request - --wait --json) || exit $?

# Typed text wins; otherwise the chosen template's body.
body=$(printf '%s' "$answer" | jq -r --argjson t "$templates" \
  '.fields.answers.reply as $a | ($a.text // $t[$a.selected[0]]) // empty')
[ -n "$body" ] || { echo "no reply chosen; nothing to send" >&2; exit 1; }

# 2. Review the filled draft. The human may edit any field before approving.
draft=$(jq -n --slurpfile m "$msg" --arg body "$body" '$m[0] as $m | {
  to: [$m.from], cc: [], bcc: [],
  subject: (if ($m.subject | test("^re:"; "i")) then $m.subject else "Re: \($m.subject)" end),
  body: $body
}')
review=$(jq -n --slurpfile m "$msg" --argjson d "$draft" '$m[0] as $m | {
  title: "Send reply to \($m.from)",
  kind: "review",
  risk: "medium",
  tool: "email.reply.send",
  source: {agent: "mail-assistant"},
  dedupe_key: "reply:\($m.message_id)",
  timeout: "24h",
  previews: [{type: "email", email: ($d + {from: $m.to,
    in_reply_to: {from: $m.from, date: $m.date, body: $m.body}})}],
  input: $d
}')
decision=$(printf '%s' "$review" | handup ask --request - --wait --json) || {
  code=$?
  printf '%s' "$decision" | jq -r '.feedback // empty' >&2
  exit "$code"
}

# Approved: the human's edit is the complete draft; without one, send ours.
printf '%s' "$decision" | jq --argjson d "$draft" '.fields // $d'
