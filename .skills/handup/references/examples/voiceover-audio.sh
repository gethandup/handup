#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Upload the bundled one-second silence before submitting its immutable audio JSON.
: "${HANDUP_SOCKET:?Set HANDUP_SOCKET to the running daemon Unix socket}"
curl --fail --silent --show-error --unix-socket "$HANDUP_SOCKET" -H 'Content-Type: audio/wav' --data-binary "@$base/assets/audio.wav" http://localhost/v1/blobs >&2
handup ask --request - --wait --json < "$base/audio.json"
