# Email drafts

Sending email is external publication: ask before every send. handup shows the
human a rendered email preview, lets them edit the draft and leave feedback, and
records the decision. **handup never sends mail** and has no Gmail, IMAP or SMTP
access. After approval you send the message with your own tool (for example
`gog gmail send`, himalaya, or an MCP mail tool).

## Flow

1. Draft the email.
2. Ask with an `email` preview and the editable draft as `input`
   (`{to, cc, bcc, subject, body}`). Do not send while the request is pending.
3. **Approved**: send `decision.fields` if present (the human edited the draft;
   it is the complete edited draft, not a patch), otherwise send your original
   draft. Send exactly that content once. Read `feedback` either way.
4. **Denied**: do not send. Read the feedback, revise the draft and ask again
   with the revision. A denial is not permission to retry the same draft.
5. Expired, cancelled or error: do not send.

Without `input` the request is review-only: the human can approve or deny and
leave feedback, but not edit.

Recipes: [canned email replies](../cookbook/email-canned-replies.md) (pick a
template, then review the draft) and [route email by
sender](../cookbook/email-routing.md) (rules per sender class).

**Open in mail app.** Email previews in the inbox and History have an "Open in
mail app" button that hands the shown draft (the human's edit while editing)
to their own mail client as a `mailto:` link with To, Cc, Bcc, subject and
the plain-text body prefilled. The human may send it from there. Opening the
mail app changes nothing about the request: it stays pending until the human
approves or denies it here, and handup still never sends mail.

## Preview shape

```json
{
  "type": "email",
  "email": {
    "from": "Ari <ari@example.com>",
    "to": ["Dana Lee <dana@example.org>"],
    "cc": ["ops@example.org"],
    "bcc": [],
    "reply_to": "billing@example.com",
    "subject": "Re: Q3 invoice",
    "date": "Tue, 30 Sep 2026 16:05:00 +0000",
    "body": "Hi Dana,\n\nThe signed invoice is attached.\n\nBest,\nAri",
    "attachments": [{"name": "invoice-q3.pdf", "mime": "application/pdf", "size": 48213, "blob": "sha256:…"}],
    "in_reply_to": {"from": "Dana Lee <dana@example.org>", "date": "Tue, 30 Sep 2026 09:12:00 +0000", "body": "Could you send the signed invoice?"}
  }
}
```

- `body` is Markdown (plain text renders as written, line breaks kept).
- `body_html` is optional; it renders only in the sandboxed HTML preview frame
  (network blocked), never inline. Edits change `body` only: if the human
  edited the draft, regenerate or drop your HTML alternative.
- Addresses are `address` or `Name <address>` (the name may be quoted). Each
  address is `local@domain` with exactly one `@`; the local part is ASCII
  letters, digits and ``!#$%&'*+-/=?^_`{|}~.`` (at most 64, no leading,
  trailing or doubled dots); the domain has at least two labels and ends in a
  letters-only TLD of two or more letters or an `xn--` label (`a@b`,
  `ops@example.org2` are rejected; Unicode domains are fine). At least one of
  `to`/`cc`/`bcc` is set, and the subject or body is non-empty.
- An approval's `decision.fields` on an email request must be a complete draft
  `{to, cc, bcc, subject, body}` meeting the same rules; the API and CLI
  reject anything else with HTTP 400, so an approved edit is always sendable.
- Attachments are shown as chips the human can open or download. `blob` is a
  hash from `POST /v1/blobs`; the CLI and MCP also accept a local `path` and
  upload it for you. Without either, the chip shows the name only.
- `in_reply_to` is the earlier message, shown collapsed under the body.

## MCP

```json
{"name": "request_approval", "arguments": {
  "title": "Send reply to Dana",
  "kind": "review",
  "risk": "medium",
  "previews": [{"type": "email", "email": {
    "from": "ari@example.com", "to": ["dana@example.org"],
    "subject": "Re: Q3 invoice", "body": "Hi Dana,\n\nInvoice attached.\n\nAri",
    "attachments": [{"path": "out/invoice-q3.pdf"}]}}],
  "input": {"to": ["dana@example.org"], "cc": [], "bcc": [],
            "subject": "Re: Q3 invoice", "body": "Hi Dana,\n\nInvoice attached.\n\nAri"},
  "wait": false
}}
```

Wait with `wait_requests`. An approved reply looks like
`{"status":"approved","option":"approve","feedback":null,"fields":{"to":[…],"cc":[],"bcc":[],"subject":"…","body":"…"}}`;
`fields` is absent or null when the human approved without editing.

## CLI

`--preview email:FILE` (or `email:-` for stdin) reads the email JSON object
above. The CLI also uses the draft as `input`, so the human can always edit it;
for a review-only request send the full request with `handup ask --request -`
and omit `input`.

```sh
handup ask --title "Send reply to Dana" --risk medium \
  --preview email:draft.json --wait --json > decision.json
case $? in
  0) jq -e '.fields' decision.json >/dev/null && jq '.fields' decision.json > send.json \
       || jq '{to, cc, bcc, subject, body}' draft.json > send.json
     # send send.json with your own mail tool, e.g. gog gmail send
     ;;
  1) jq -r '.feedback // empty' decision.json  # revise, then ask again
     ;;
  *) echo "not approved; do not send" ;;
esac
```

Without `--json`, `--wait` prints the request, then any feedback, then
`Edited input:` followed by the edited draft when the human changed it. Exit
codes are the usual ones: 0 approved, 1 denied, 2 expired, 3 cancelled, 4 error.

`handup demo` seeds an editable email reply with an attachment to try the
review and Edit & approve flow.
