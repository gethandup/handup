# End-to-end encrypted relay

Use `handup-relay` when your phone is not on your tailnet. It is a small
server you host yourself. It forwards encrypted envelopes between your handup
daemon and your paired phones. It never sees previews, decisions, device
tokens, pairing codes, or keys, and it never sees request titles unless you
set `push: title`. It can also send content-free FCM/APNs wake-ups.

The relay works alongside any `remote.mode`, including `off`. The phone uses
the same API v1, scopes, biometric gate, and content-hash-bound decisions as
the [remote listener](remote.md).

**Settings → Test** can send a synthetic request or question through the relay
to the selected paired computer. `POST /v1/requests/test` uses the same
[test request contract](cli.md#test-requests) as local and remote HTTP access:
paired `decide` scope is required; `view` devices and submit tokens get 403.
The daemon builds the sample, and deciding it performs no action.

Relay connections never execute command requests. **Run** is local-desktop-only;
the daemon rejects `run_result` from paired devices over the relay just as it
does over the remote listener.

## Run a relay

This requires the compiled `handup-relay` program. handup releases do not
include a relay binary yet; see [downloads and releases](downloads.md) for what
is published. The following commands apply once the relay binary is installed:

```bash
handup-relay --listen 127.0.0.1:8787 --db /var/lib/handup-relay/relay.db
handup-relay --help
```

Settings merge in this order: built-in defaults, then `--config relay.yaml`,
then flags and `HANDUP_RELAY_*` environment variables.

```yaml
listen: 0.0.0.0:8787
db: /var/lib/handup-relay/relay.db
log: /var/log/handup-relay.log      # default: stderr
tls: { cert: /etc/handup-relay/fullchain.pem, key: /etc/handup-relay/key.pem }
trust_forwarded: false               # legacy: true trusts loopback proxies only
trusted_proxies: []                  # explicit CIDRs for your own proxy chain
forwarded_hops: null                 # proxies behind the trusted peer that append X-Forwarded-For
direct_clients: false               # tenant mode without a proxy: clients connect directly
probe_listen: null                   # e.g. 127.0.0.1:9091 moves /healthz and /readyz off the main listener
probe_allow_public: false
no_new_channels: false              # creation kill switch, restart to change
no_wakes: false                     # push kill switch, restart to change
drain_timeout: 10s
metrics_listen: 127.0.0.1:9090       # omit to disable metrics
metrics_allow_public: false
log_format: text                    # text or json
log_ips: true                       # set false for hosted use; forced false in tenant mode
tenants: false                       # true requires a tenant credential to create channels
database:                            # optional: shared Postgres instead of `db`
  url: postgres://relay@db.example.com/handup_relay?sslmode=verify-full  # prefer HANDUP_RELAY_DATABASE_URL
  ca: /etc/handup-relay/db-ca.pem    # extra CA besides the Mozilla roots
  allow_plaintext: false
  pool_size: 16                      # pooled connections per instance
  migrate_url: postgres://owner@…    # optional schema-owning role; prefer HANDUP_RELAY_DATABASE_MIGRATE_URL
  statement_timeout: 10s             # per statement, and per idle open transaction
  acquire_timeout: 5s                # waiting for a pooled connection
limits:
  max_envelope: 65553                # bytes; the protocol maximum is the floor
  max_queue: 64                      # queued envelopes per offline channel end
  queue_ttl: 10m                     # older queued envelopes are dropped, unless being delivered
  channel_ttl: 90d                   # channels idle this long are deleted
  max_connections: 512               # authenticated WebSockets
  tenant:                            # per-tenant defaults (tenant mode)
    channels: 1000                   # default: a quarter of max_channels
    wakes_per_hour: 600              # default: unlimited
push:
  fcm: { service_account: /etc/handup-relay/fcm.json }
  apns: { key: /etc/handup-relay/AuthKey.p8, key_id: ABC123, team_id: TEAM123, topic: dev.handup.app }
```

Other limits guard the relay against abuse:

- A per-IP cap on authentication failures.
- A per-IP cap on channel creations and connections.
- A total byte cap for queued and in-flight ciphertext (`max_queued_bytes`).
- A maximum number of channels.
- A minimum interval between wake-ups, per channel and per push token
  (`wake_interval`), plus a relay-wide cap (`wakes_per_minute`, default 120).
- A write deadline (`write_timeout`, default 30s). A phone or daemon that
  stops reading is disconnected; its traffic waits in the mailbox instead.
- A body-read deadline (`body_timeout`, default 10s) on channel creation,
  push registration, and wake requests. Channel credentials are checked before
  reading push or wake bodies. Timed-out or oversized bodies close the connection;
  creation accepts at most 4 KiB, registration and wake at most 16 KiB.

Channels with a connected end are never swept as idle; others are deleted
after `channel_ttl` (default 90 days) without a connection.

Set `HANDUP_RELAY_REGISTRATION_TOKEN` so only your daemons can create
channels. A non-empty token must be at least 32 characters or the relay refuses
to start; generate a random value with `openssl rand -hex 32`. An empty value
counts as unset. Give the daemon the same value in `HANDUP_RELAY_TOKEN`. You can
rename that variable with `remote.relay.registration_token_env`.
After an IP reaches `auth_failures_per_minute`, channel creation returns HTTP 429
(`too many failed attempts; retry later`) even with the correct registration
token until the current 60-second failure window expires. Rejected requests close
the connection without reading the body.
The relay refuses to start with `push` credentials unless it has a registration
token or runs in tenant mode, because anyone could otherwise send wake-ups
through your FCM/APNs account.

The relay creates its database, SQLite sidecar files, and log with mode 0600.
Clients only ever see `storage error` (HTTP 503) when the database fails; the
log records the SQLSTATE code, never query text or values.

### Instance operations

`GET /healthz` is an empty, unauthenticated liveness response (200).
`GET /readyz` returns 503 while draining or when the database probe fails;
database health is cached for five seconds, and concurrent probes on a cold
cache share one database query. Keep probes internal: set `probe_listen` to
serve both only on that address (it may equal `metrics_listen`, which then
serves `/metrics`, `/healthz` and `/readyz` together); the main listener then
answers them with 404. Like `metrics_listen`, `probe_listen` accepts loopback
and specific private addresses; wildcard or public binds require
`probe_allow_public` (`--probe-allow-public`, `HANDUP_RELAY_PROBE_ALLOW_PUBLIC`).
Tenant mode on a non-loopback listener without
`probe_listen` logs a warning at startup. The probe and metrics listeners stay
up until the drain ends, so readiness reports 503 throughout. The existing
`/v1/health` endpoint remains available for protocol clients.

SIGTERM and SIGINT stop admission and drain for up to `drain_timeout` (10s).
Already-started HTTP writes finish within the deadline; WebSockets close with
1001 (going away), so clients reconnect. Give the supervisor a longer grace.
Setting `no_new_channels` rejects creation with 503 JSON and `Retry-After: 1`;
existing channels are unaffected. `no_wakes` rejects wakes without contacting
FCM/APNs. Both switches are read only at startup, so changing one needs a restart.

Metrics are disabled by default. `metrics_listen` enables Prometheus text at
`/metrics` on a separate, unauthenticated listener. Loopback and specific private
addresses are allowed; wildcard or public binds require `metrics_allow_public`.
Firewall the scrape listener. Labels use only fixed roles, dispositions,
platforms, outcomes and rejection reasons, never channel/tenant ids, tokens or IPs.
Scale on authenticated daemon/device connections, not the HTTP connection gauge.
`handup_relay_db_lookups_total{kind="channel"|"tenant"|"readiness"}` counts
credential and readiness lookups that reached the database.

`log_format` supports `text` (default) or `json`; `log_ips` defaults to true for
self-hosted compatibility but tenant mode forces false. Set false for hosted
use. Logs omit channel identifiers and provider error bodies; channel-creation
lines name the tenant id. Output is capped at 120 lines/minute per instance;
metrics retain counts. Arrange external rotation and retention.
Each of these settings has a matching hyphenated flag and `HANDUP_RELAY_*`
environment variable (for example `--no-wakes`, `HANDUP_RELAY_NO_WAKES`).

`trusted_proxies` accepts CIDRs via YAML, `--trusted-proxies`, or the comma-separated
`HANDUP_RELAY_TRUSTED_PROXIES`. Forwarded headers are ignored unless the TCP peer
is trusted; by default the right-most untrusted hop is the client IP. Repeated
`X-Forwarded-For` headers are read as one list. When more proxies sit behind
the trusted peer (for example a CDN in front of your load balancer), set
`forwarded_hops` (`--forwarded-hops`, `HANDUP_RELAY_FORWARDED_HOPS`) to how many
right-most entries they append; the client is the entry just left of them. A
header shorter than that, or with an unparsable entry, falls back to the TCP
peer. `forwarded_hops` requires `trusted_proxies`. The legacy
`trust_forwarded: true` alias trusts loopback only. IPv6 per-IP counters aggregate
by /64; bounded sharded counters evict rather than locking out new clients.
Valid credentials are not rejected because another caller exhausted failed-auth
limits: past the limit, lookups wait in a small relay-wide slow lane (two at a
time, at least 100ms each) instead of being refused.

Additional YAML controls: `preauth_timeout` (3s), `max_preauth_connections` (64),
`per_ip_connections` (16), `ws_idle_timeout` (120s), `ws_ping_interval` (30s),
`ws_max_lifetime` (24h), `ws_messages_per_second` (120), and
`ws_bytes_per_second` (4194304). Authenticated WebSockets use
`limits.max_connections`; unauthenticated TLS/HTTP uses a separate bounded pool.
An extra pool of at most 16 connections answers overload with 503/Retry-After;
when that pool is full, excess sockets are dropped. Put equivalent admission
limits on the proxy. Trusted proxies also have a TCP-peer concurrent cap, so
size `per_ip_connections` for their legitimate fan-in.
WebSockets ping and close after two unanswered pings; idle/lifetime checks run
at heartbeat ticks. Text frames close with 1003, ingress floods with 1008.
Ping, pong and close frames spend the same `ws_messages_per_second` and
`ws_bytes_per_second` budget as envelopes, so a ping flood also closes with 1008.
Wake titles are limited to 120 characters and control characters are removed.


### Tenant mode

Tenant mode gives each daemon owner a separate channel-creation credential with
its own quotas, which you can rotate, turn off, or remove on its own. Enable it
with `--tenants`, `tenants: true`, or `HANDUP_RELAY_TENANTS=true`. Creating a
channel then needs an enabled tenant credential. The relay refuses to start in
tenant mode when `HANDUP_RELAY_REGISTRATION_TOKEN` is set: a shared token
would create channels that no tenant's quota or revocation reaches. Give your
own daemons a tenant of their own instead.

Per-address limits need the real client address. On a listener that is not
loopback, tenant mode refuses to start unless `trusted_proxies` names your
proxies, or `direct_clients: true` (`--direct-clients`,
`HANDUP_RELAY_DIRECT_CLIENTS`) confirms that clients connect with no proxy in
front. A proxy on the same host can use a loopback listener and needs neither.

Failed tenant credentials count against the same per-address failure budget
as channel credentials. A credential that is not `hrt_` plus 64 hex digits
never reaches the database, and neither does one the database did not know
within the last ten seconds (each instance remembers up to 4096); both fail with
401, or 429 once the address is over its budget. Past the budget, a well-formed
credential this instance has not seen succeed waits in the slow lane. A tenant
enabled, or a token rotated, on another instance works here within ten seconds.

Manage tenants against the relay's database. The commands honor `--config`,
`--db`, `HANDUP_RELAY_DB`, and `HANDUP_RELAY_DATABASE_URL`, and work while the
relay is running:

```bash
handup-relay tenant add "Alice"     # prints id and token (hrt_…); the token is shown once
handup-relay tenant add "Alice" --token-file alice.token  # token to a new 0600 file, only the id on stdout
handup-relay tenant list [--json]   # id, name, enabled, push titles, last use, usage/limit per quota; never tokens
handup-relay tenant rotate <id> [--token-file <path>]  # a new token; the old one stops working at once
handup-relay tenant disable <id>
handup-relay tenant enable <id>
handup-relay tenant set-quota <id> channels 50   # or `default` to clear the override
handup-relay tenant set-push-titles <id> on      # or `off` (the default)
handup-relay tenant remove <id>     # deletes its channels, queued envelopes and push tokens
```

`--token-file` keeps the credential out of terminal scrollback and logs. It
refuses to overwrite an existing file, and removes the file it created if the
change fails. Last use is the last channel creation with the tenant's token,
recorded at most once a minute; a tenant unused for months is a candidate for
removal.

A tenant's daemons send wake-ups with the generic title "Approval requested"
even when they ask for `push: title`, until you run
`tenant set-push-titles <id> on`: a request title then reaches FCM/APNs, which
you, not the tenant, have an agreement with. A wake-up authorized just before
a tenant is disabled or removed is refused rather than sent or counted.

Give the daemon the tenant token in `HANDUP_RELAY_TOKEN`. Each channel it
creates records its tenant. Disabling a tenant rejects its credential and every
one of its channels: new channels, phone and daemon connections, push
registration, and wake-ups. Its open connections close within about a second
(at once on every instance with Postgres). Enabling the tenant restores its
channels. Removing it deletes them for good. Rotation keeps existing channels
and connections; only channel creation uses the tenant token. Channels created
before tenant mode belong to no tenant, so no quota or revocation reaches them:
tenant mode refuses them. Moving a self-hosted relay to tenant mode therefore
means pairing each daemon and phone again (`handup pair --relay`) with a tenant
token.

#### Quotas

Each tenant gets a fair share of the relay so one cannot starve the others.
Over a quota, HTTP requests get `429` with
`{"error": "tenant quota exceeded", "quota": "<name>"}`, and a WebSocket sender
whose envelope does not fit gets a text notice
`{"t": "relay", "error": "tenant quota exceeded", "quota": "queued_bytes"}`.

| Quota | Counts | Default |
|---|---|---|
| `channels` | channels the tenant owns | a quarter of `max_channels` |
| `connections` | open phone and daemon connections, all instances | a quarter of `max_connections` |
| `queued_bytes` | ciphertext waiting for an offline end | a quarter of `max_queued_bytes` |
| `wakes_per_minute` | wake-ups sent | a quarter of `wakes_per_minute` |
| `wakes_per_hour` | wake-ups sent | unlimited |
| `bytes_per_day` | accepted ciphertext, UTC day | unlimited |

Change the defaults under `limits.tenant`, or one tenant's with
`tenant set-quota`. A changed quota applies to connected senders from their
next envelope. Refused envelopes count against nothing.

### Several instances on Postgres

Point every instance at one Postgres database with
`HANDUP_RELAY_DATABASE_URL=postgres://…` (or `database.url`; `db` is then
ignored) and put them behind any load balancer, no sticky sessions needed. They
share channels, mailboxes, push tokens, tenants, quotas, and the relay-wide
channel, queued-byte and wake budgets. A message to a phone connected to
another instance is stored and announced with `NOTIFY` once committed; the
instance holding that phone delivers it in order. Each envelope stays stored,
and counted against the queued-byte budgets, until it is written to the
socket; what a closed or replaced connection did not write goes to the next
connection for that end, in order. A newer connection for a channel end
replaces the older one wherever it is. A lost `NOTIFY` only delays delivery:
every instance also checks for waiting mail each second. `NOTIFY` payloads
carry channel, instance and tenant ids only, never ciphertext or credentials.

TLS to Postgres is required for any host that is not loopback or a Unix
socket. Without `sslmode`, such hosts get verified TLS; `localhost` and Unix
sockets default to plaintext. `sslmode=require`, `verify-ca` and `verify-full`
all verify the certificate chain and host name (against the Mozilla roots plus
`database.ca`). `sslmode=disable` or `prefer` to a remote host is refused
URL, and sessions use a 10s statement timeout.

Every session also ends a transaction left idle longer than
`database.statement_timeout` (default 10s), and waiting for a pooled
connection gives up after `database.acquire_timeout` (default 5s), so a stuck
lock or an exhausted pool fails requests with `storage error` instead of
stalling them. A `statement_timeout` or `idle_in_transaction_session_timeout`
already in the URL's `options` wins. If an instance loses its `LISTEN`
connection it reconnects within about a second, retrying each second, and
re-checks every local socket for mail that arrived meanwhile.

Run the relay as a least-privilege role. Without `database.migrate_url`, the
first start creates the schema and later releases upgrade it, so the serving
role needs to own it. For a serving role with data access only, give the
schema owner's URL as `HANDUP_RELAY_DATABASE_MIGRATE_URL` (or
`database.migrate_url`, or `--database-migrate-url`) and run
`handup-relay migrate` before the first start and after each upgrade. With
a migration URL set, the relay and `tenant` commands run no DDL: they refuse
to start until the schema is at the version they need, and tell you to run
`handup-relay migrate`. Then grant the serving role data access:

```sql
CREATE ROLE handup_relay LOGIN PASSWORD '…';
GRANT CONNECT ON DATABASE handup_relay TO handup_relay;
GRANT USAGE ON SCHEMA public TO handup_relay;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO handup_relay;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO handup_relay;
```

Re-run the grants after a `migrate` that adds tables. The serving role needs
no `CREATE`, superuser, or replication rights. Tenant tokens are stored as
SHA-256 digests; channel credentials as digests too.

### TLS

Use HTTPS for anything that is not loopback or a private network. You can
pass `--tls-cert/--tls-key`, or put the relay behind a reverse proxy (Caddy,
nginx) with a public certificate. The daemon and the app check relay
certificates against the Mozilla roots.

TLS protects the per-channel relay credentials and push tokens in transit.
Request content is end-to-end encrypted either way. The client refuses plain
`http://` except for loopback, private, link-local, and tailnet addresses.

## Configure the daemon

```yaml
remote:
  relay:
    url: https://relay.example.com       # how the daemon reaches the relay
    public_url: ""                       # link URL for phones, when it differs from url
    push: wake                           # wake (generic title), title (request title), or off
```

Restart the daemon, then pair:

```bash
handup pair --relay [--scope view|decide] [--name "Pixel"]
```

Scan the QR code with the handup app, or paste the printed link into it. The
link is `https://relay…/pair#ch=…&dk=…&pk=…&code=…`: `ch` is the channel id,
`dk` is the phone's relay bearer credential for that channel, and `pk` is
your daemon's public key, which the phone pins. Everything after `#` stays
on the phone. The code expires after 2 minutes and works once.

Paired relay devices show up in `handup devices list`. Revoke one with
`handup devices revoke <id>`. Revocation deletes the device's channel on the
relay, ends its sessions, and makes its token useless.

## What the relay can and cannot see

The relay **can** see:

- Channel ids.
- Connection times, IP addresses, and envelope sizes and counts.
- Which end of a channel is online.
- Push tokens and their platform.
- When wake-ups are sent. With `push: title`, it also sees the request title
  sent in the notification.

The relay stores:

- Channel ids, and the tenant id of channels created with a tenant credential.
- Hashes of the two per-channel credentials. Each end still sends its
  bearer credential on every request, so the relay sees it in transit (it
  only lets that end use its own channel).
- Timestamps.
- Queued ciphertext, up to the TTL.
- Push tokens.
- Tenants: id, name, enabled flag, creation time, a SHA-256 hash of the
  credential, quota overrides, and usage counters.

The relay **cannot**:

- Read requests, previews, decisions, device tokens, or pairing codes. They
  travel only inside Noise sessions.
- Pair a device of its own. The code is encrypted to your daemon's static
  key, which the phone pins from the QR code.
- Pose as your daemon or your phone. Both static keys are pinned, and the
  daemon still checks the device token on every call.
- Replay, reorder, or alter envelopes. Any of these ends the session.
- Post to or read a channel without that channel's credential.

A malicious relay can still drop or delay traffic, or refuse service.

## Push notifications

Phones register an FCM or APNs token with the relay. The registration is
scoped to their channel. When a request arrives, the daemon posts a
content-free wake hint. The relay then sends one of these requests:

- FCM HTTP v1 with a service-account OAuth JWT.
- APNs HTTP/2 with a token-based ES256 JWT.

The notification carries only a title: "Approval requested" by default, or
the credential-redacted request title with `push: title`. Redaction happens in
the daemon before sending the title to the relay. It has no request id and never
includes preview content. Tapping it opens the app, which fetches the queue
through the encrypted channel.

Push registration and removal (`PUT`/`DELETE /v1/devices/self/push`) also
travel through the encrypted session, with the same paired-device scope checks
as direct remote access.

If the provider reports an invalid or unregistered token, the relay removes
it. The Android app registers an FCM token only when built with your own
Firebase configuration (see [mobile.md](mobile.md)); builds without it receive
no push.
