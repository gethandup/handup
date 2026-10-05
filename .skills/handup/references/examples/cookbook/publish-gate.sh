#!/bin/sh
# Publish gate: an agent drafts a social post or announcement; the human edits
# the text and picks Publish now or Schedule. Unanswered posts expire as denied
# after two hours, so nothing goes out while you are away.
#
#   sh examples/cookbook/publish-gate.sh examples/cookbook/post.md
#
# Exit 0 prints {when: "now"|"scheduled", text}; anything else means do not post.
set -eu
post=${1:?Usage: publish-gate.sh POST.md}
# Same text, same pending request: rerunning the agent never queues duplicates.
key=$(sha256sum "$post" | cut -c1-16)

request=$(jq -n --rawfile text "$post" --arg key "$key" '{
  title: "Publish this post?",
  summary: "Announcement draft, \($text | length) characters",
  kind: "review",
  risk: "high",
  tool: "social.publish",
  source: {agent: "launch-agent"},
  dedupe_key: "publish:\($key)",
  timeout: "2h",
  on_timeout: "deny",
  previews: [{type: "markdown", inline: $text}],
  input: {fields: [
    {name: "text", type: "textarea", label: "Post text", default: $text, required: true}
  ]},
  options: [
    {id: "now", label: "Publish now", outcome: "approve", style: "primary"},
    {id: "schedule", label: "Schedule for 9:00", outcome: "approve"},
    {id: "deny", label: "Don'\''t post", outcome: "deny", style: "danger"}
  ]
}')
decision=$(printf '%s' "$request" | handup ask --request - --wait --json) || {
  code=$?
  printf '%s' "$decision" | jq -r '"\(.status): \(.feedback // "no feedback")"' >&2
  exit "$code"
}
# The selected option id says which approve path the human chose.
printf '%s' "$decision" | jq --rawfile text "$post" '
  {when: (if .option == "schedule" then "scheduled" else "now" end),
   text: (.fields.text // $text)}'
