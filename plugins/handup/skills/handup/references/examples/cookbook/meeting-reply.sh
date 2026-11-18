#!/bin/sh
# Calendar invite triage: two questions in one card. RSVP (with a recommended
# answer based on the conflict the agent found) and, when proposing a new time,
# which alternative slots to offer.
#
#   sh examples/cookbook/meeting-reply.sh examples/cookbook/invite.json
#
# Exit 0 prints {rsvp, slots, note}; denied (Decline to answer) prints nothing.
set -eu
invite=${1:?Usage: meeting-reply.sh INVITE.json}

request=$(jq -n --slurpfile i "$invite" '$i[0] as $i | {
  title: "RSVP: \($i.title) (\($i.when))",
  summary: "From \($i.organizer). \($i.conflict // "No conflicts.")",
  kind: "question",
  tool: "calendar.rsvp",
  source: {agent: "calendar-agent"},
  timeout: "1d",
  input: {questions: [
    {id: "rsvp", header: "RSVP", question: "Reply to **\($i.title)**, \($i.when) (\($i.duration))?",
     recommended: (if $i.conflict then 2 else 0 end),
     options: [
       {label: "Accept", description: "Accept as sent"},
       {label: "Decline", description: "Decline with a short note"},
       {label: "Propose new time", description: "Offer the slots selected below",
        preview: "Conflict: \($i.conflict // "none")"}
     ]},
    # Every question needs an answer, so Accept/Decline get an explicit way out.
    {id: "slots", header: "Slots", multi: true, allow_free_text: true,
     question: "If proposing, which slots should I offer? Type another time if none fit.",
     recommended: ($i.alternatives | length),
     options: ([$i.alternatives[] | {label: .}] + [{label: "Not needed"}])}
  ]},
  options: [
    {id: "submit", label: "Send RSVP", outcome: "approve", style: "primary"},
    {id: "decline", label: "Ignore invite", outcome: "deny"}
  ]
}')
decision=$(printf '%s' "$request" | handup ask --request - --wait --json) || exit $?
printf '%s' "$decision" | jq '.fields.answers as $a | {
  rsvp: $a.rsvp.selected[0],
  slots: ($a.slots.selected - ["Not needed"] + (if $a.slots.text then [$a.slots.text] else [] end)),
  note: (.feedback // "")}'
