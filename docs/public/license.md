# License and trial

Downloads are public. A new install works fully for **14 days**; after that the
daemon needs a handup Personal license (one person, their own machines,
perpetual). [Buy a license](https://gethandup.dev/#pricing).

## Find your key

1. After checkout, Polar emails "Thank you for your purchase!" with your invoice
   attached. Under **Included benefits** it lists **handup license key**.
2. Click **handup license key** in that email. It opens Polar's customer portal
   at **Benefit Grants**, where the key is shown under **License keys**.
3. Copy the key and activate it as below.

Lost the email? Open the [customer portal](https://polar.sh/handup/portal) and
sign in with your purchase email; Polar sends a one-time code.

## Activate

```sh
handup license activate HANDUP-XXXX-XXXX     # or: echo "$KEY" | handup license activate
handup license status                        # License: licensed (****-XXXXXX, you@example.com)
```

In the desktop, web and phone apps open **Settings → License**, paste the key and
choose **Activate**. On a phone, each paired computer has its own row; activating
there needs the device's decide scope.

Activation sends the key once to `https://gethandup.dev/api/license`, which checks
it with Polar and returns a license signed by gethandup.dev. The daemon verifies the
signature with a public key built into handup and stores the signed license as
`license` and the key as `license-state.json` in the data directory (both 0600).
After that the license works offline.

## Offline machines

A machine that cannot reach gethandup.dev can use the signed license file from
an activated machine:

```sh
handup license import ~/license       # a copy of <data dir>/license from another machine
```

**Settings → License → Import license file** does the same. An imported license
carries no key, so it is never rechecked online.

## Trial

The trial starts when the daemon first runs and is recorded in the data and state
directories; reinstalling does not restart it. `handup license status` shows the
days left. The apps show an inline banner above the inbox in the last 3 trial
days and while a license is required; it never covers the decision buttons.

## When a license is required

After the trial ends without a license (or after the key is revoked):

- New requests are refused. `handup ask` exits **6** with `license required: …`;
  the daemon API answers HTTP **402** with `{"error": "license required: …",
  "code": "license_required"}`; MCP tools return the same message and code.
- Claude and Codex permission hooks and the omp extension fall back to the
  agent's own permission prompt, as when the daemon is not running (omp without
  a UI blocks). They never allow anything on handup's behalf.
- Pending requests can still be approved, denied or answered. History, settings,
  storage cleanup, `handup uninstall` and the license commands keep working.

Activate or import a license and new requests work again immediately, without a
restart.

## Rechecks and revocation

While the daemon runs it rechecks an activated key with Polar about every 3 days.
Only a definite answer locks the license: the key is revoked, disabled, unknown, or
for another product. Being offline, a Polar outage, rate limits or a malformed
reply never lock it; the daemon retries an hour later. A refunded order's key is
revoked by Polar, so the next recheck requires a new license.

## Commands and API

| Command | API | Effect |
| --- | --- | --- |
| `handup license status [--json]` | `GET /v1/license` | State, days left, masked key |
| `handup license activate [KEY] [--json]` | `PUT /v1/license` `{"key": "…"}` | Exchange the key for a signed license |
| `handup license import FILE [--json]` | `PUT /v1/license` `{"license": "HANDUP-LICENSE-1.…"}` | Install a signed license file |
| `handup license deactivate [--json]` | `DELETE /v1/license` | Remove the license and key from this machine |

`state` is one of `trial`, `expired`, `licensed`, `revoked` or `not_enforced`
(development builds, which never refuse requests); `locked` is true for `expired`
and `revoked`. A rejected key answers HTTP 400 and an unreachable license server
502; the CLI exits 4 for both. Remote devices need the view scope to read the
license and the decide scope to change it. See the
[OpenAPI reference](openapi.json) for every field.
