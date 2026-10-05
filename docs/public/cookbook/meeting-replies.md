# Meeting replies

![Invites, answered: RSVP with a recommended answer and slots to propose](img/meeting-replies.webp)

Calendar triage needs more than yes or no: accept, decline, or propose other
times, and which times. One `kind: question` request asks both questions in a
single card, recommends an answer based on the conflict the agent found, and
returns structured answers your calendar tool can act on. Script:
[`examples/cookbook/meeting-reply.sh`](../../../examples/cookbook/meeting-reply.sh).

```sh
sh examples/cookbook/meeting-reply.sh examples/cookbook/invite.json
```

## The request

```json
{
  "title": "RSVP: Q4 planning (Thu, 09 Oct 2026 15:00 UTC)",
  "summary": "From Dana Lee <dana@example.org>. Overlaps 'Dentist' (15:30-16:30)",
  "kind": "question",
  "tool": "calendar.rsvp",
  "source": {"agent": "calendar-agent"},
  "timeout": "1d",
  "input": {"questions": [
    {"id": "rsvp", "header": "RSVP", "recommended": 2,
     "question": "Reply to **Q4 planning**, Thu, 09 Oct 2026 15:00 UTC (45m)?",
     "options": [
       {"label": "Accept", "description": "Accept as sent"},
       {"label": "Decline", "description": "Decline with a short note"},
       {"label": "Propose new time", "description": "Offer the slots selected below",
        "preview": "Conflict: Overlaps 'Dentist' (15:30-16:30)"}
     ]},
    {"id": "slots", "header": "Slots", "multi": true, "allow_free_text": true, "recommended": 3,
     "question": "If proposing, which slots should I offer? Type another time if none fit.",
     "options": [
       {"label": "Thu 09 Oct 10:00 UTC"}, {"label": "Fri 10 Oct 14:00 UTC"},
       {"label": "Mon 13 Oct 16:00 UTC"}, {"label": "Not needed"}
     ]}
  ]},
  "options": [
    {"id": "submit", "label": "Send RSVP", "outcome": "approve", "style": "primary"},
    {"id": "decline", "label": "Ignore invite", "outcome": "deny"}
  ]
}
```

Question rules worth knowing:

- Up to 10 questions per request; **every question must be answered** before
  Submit. Give conditional questions an explicit way out (`Not needed`).
- `recommended` is an option index; the agent can compute it (here: propose a
  new time when it found a conflict, otherwise accept).
- `multi: true` allows several selections; `allow_free_text` adds a text box.
- Option `preview` is Markdown shown while the option is focused.
- `options` default to Approve/Deny; label them for the action (`Send RSVP`,
  `Ignore invite`), keeping one `approve` (submit) and one `deny` (decline).

## Reading the answers

Answers arrive in `decision.fields.answers`, keyed by question id, with the
selected **labels**:

```json
{"status": "answered", "option": "submit", "feedback": "Prefer Friday",
 "fields": {"answers": {
   "rsvp": {"selected": ["Propose new time"]},
   "slots": {"selected": ["Fri 10 Oct 14:00 UTC", "Mon 13 Oct 16:00 UTC"], "text": "Tue 14 Oct 09:00 UTC"}}}}
```

```sh
printf '%s' "$decision" | jq '.fields.answers as $a | {
  rsvp: $a.rsvp.selected[0],
  slots: ($a.slots.selected - ["Not needed"] + (if $a.slots.text then [$a.slots.text] else [] end)),
  note: (.feedback // "")}'
```

```json
{"rsvp": "Propose new time",
 "slots": ["Fri 10 Oct 14:00 UTC", "Mon 13 Oct 16:00 UTC", "Tue 14 Oct 09:00 UTC"],
 "note": "Prefer Friday"}
```

From a terminal the same answer is:

```sh
handup answer ID --select "rsvp=Propose new time" \
  --select "slots=Fri 10 Oct 14:00 UTC" --select "slots=Mon 13 Oct 16:00 UTC" \
  --text "slots=Tue 14 Oct 09:00 UTC" -m "Prefer Friday"
```

## Variations

- **Over MCP:** a single question is simpler with `ask_question`
  (`{"question": "…", "choices": [...], "allow_free_text": true}`); use
  `request_approval` with `kind: "question"` for several questions or a timeout.
- **Skip the obvious ones:** an invite from your own domain with no conflict
  needs no question; accept it in the caller and ask only when there is a
  conflict or an external organizer.
- **Same pattern elsewhere:** choose a deploy region, pick which flaky tests to
  quarantine, select PR reviewers, triage a bug's severity and owner.
