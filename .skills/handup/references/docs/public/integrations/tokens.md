# Integration submission tokens

A named `submit` token lets CI, n8n, Home Assistant, or a remote script submit a request and wait for a human. It cannot approve, deny, list the queue, receive events, or read another token's requests.

## Create and manage locally

```sh
handup tokens create github-ci --expires 90d
handup tokens list
handup tokens revoke github-ci
```

Names match `[a-z0-9-]{1,40}` and are unique. The secret is printed **once**; store it in your automation's secret manager. `--json` returns the secret and metadata on create, and only metadata on list. Without `--expires` a token does not expire. Expired names remain reserved until revoked. Revocation and expiry reject subsequent calls with 401. Recreating a revoked name does not grant access to its old requests.

Only SHA-256 token hashes are stored. List shows name, creation time, last use and expiry, never the secret or hash. Token management is local-only (Unix socket or the privileged loopback bearer).

## HTTP contract

Use the existing [remote listener](../remote.md) or loopback HTTP. Prefer Tailscale HTTPS; direct mode still requires TLS and explicit risk acceptance. Submit credentials are bearer tokens, not browser sessions. Host/Origin protections still apply.

| Allowed method/path | Access |
| --- | --- |
| `POST /v1/requests` | Create (60 attempts per token per rolling minute; excess returns 429) |
| `POST /v1/blobs` | Upload (remote body limit: 1 MiB) |
| `GET /v1/requests/{id}` | Own requests only |
| `GET /v1/requests/{id}/wait` | Own requests only; long poll, default 25s, maximum 60s |
| `POST /v1/requests/{id}/cancel` | Own pending requests only |

Other API routes return 403; other tokens' and nonexistent request IDs return 404. The server overwrites `source.integration` with the verified token name, while keeping caller-supplied agent/session/host fields self-declared. Local requests cannot forge a verified integration. UI source labels show `via <name> · verified`; this verifies the submitting credential, not the truth or safety of its content.

`POST /v1/requests/test` is not a submit-token route: it returns 403, even
though this token may create arbitrary requests through `POST /v1/requests`.
Synthetic tests from remote Settings require a paired device with `decide` scope.

## curl

Set `HANDUP_URL` to your listener URL and `HANDUP_TOKEN` from your secret manager. Do not enable shell tracing.

```sh
request=$(curl --fail-with-body -sS "$HANDUP_URL/v1/requests" \
  -H "Authorization: Bearer $HANDUP_TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Deploy production?","source":{"agent":"release-runner"},"timeout":"10m"}')
id=$(printf '%s' "$request" | jq -r .id)
while :; do
  result=$(curl --fail-with-body -sS "$HANDUP_URL/v1/requests/$id/wait?timeout=60s" \
    -H "Authorization: Bearer $HANDUP_TOKEN")
  [ "$(printf '%s' "$result" | jq -r .status)" != pending ] && break
done
# Only explicit approval permits the next action; denial/cancellation/expiry do not.
printf '%s' "$result" | jq -e '.status == "approved"' >/dev/null
```

A wait response can still be pending: repeat it rather than assuming permission. Human denial feedback is in `decision.feedback`.

For command requests, also inspect `decision.run_result` in the returned
Request. Desktop Run records approval even when execution fails; if a result
is present, consume its exit code/error and output instead of executing again.
Submit credentials cannot run commands or submit decisions/results themselves.
See [the result contract](../agents/mcp.md#desktop-run-results).

## GitHub Actions

Create a token locally, add it as repository secret `HANDUP_SUBMIT_TOKEN`, and set repository variable `HANDUP_URL` to a reachable HTTPS listener. The runner needs network access (for example a self-hosted runner on your tailnet).

```yaml
- name: Human deploy approval
  env:
    HANDUP_TOKEN: ${{ secrets.HANDUP_SUBMIT_TOKEN }}
    HANDUP_URL: ${{ vars.HANDUP_URL }}
  shell: bash
  run: |
    set -euo pipefail
    id=$(curl --fail-with-body -sS "$HANDUP_URL/v1/requests" \
      -H "Authorization: Bearer $HANDUP_TOKEN" -H 'Content-Type: application/json' \
      -d '{"title":"Approve production deployment?","timeout":"10m","source":{"agent":"github-actions"}}' | jq -r .id)
    while :; do
      result=$(curl --fail-with-body -sS "$HANDUP_URL/v1/requests/$id/wait?timeout=60s" \
        -H "Authorization: Bearer $HANDUP_TOKEN")
      status=$(jq -r .status <<< "$result")
      [ "$status" != pending ] && break
    done
    test "$status" = approved
- name: Deploy
  run: ./deploy.sh
```

## n8n

1. Create a named `n8n` token and save it in an n8n Header Auth credential (`Authorization: Bearer <token>`), not in workflow JSON.
2. HTTP Request node: `POST <listener>/v1/requests`, JSON body `{"title":"Run maintenance?","timeout":"10m","source":{"agent":"n8n"}}`.
3. Retain the response `id`; HTTP Request node: `GET <listener>/v1/requests/<id>/wait?timeout=60s` using the same credential. Set the node's request timeout above 60 seconds.
4. If status is `pending`, loop back to wait. Only an `approved` status takes the action branch; route all other terminal statuses to a stop/feedback branch. Surface `decision.feedback` on denial.

Rotate by revoking the old name and creating a replacement; save any pending request decisions first because the replacement cannot read the old credential's requests.
