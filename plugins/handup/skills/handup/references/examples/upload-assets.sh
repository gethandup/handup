#!/bin/sh
set -eu
: "${HANDUP_SOCKET:?Set HANDUP_SOCKET to the running daemon Unix socket}"
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
for spec in image.png:image/png audio.wav:audio/wav video.mp4:video/mp4 file.zip:application/zip pdf.pdf:application/pdf notes.txt:text/plain; do
  file=${spec%%:*}; mime=${spec#*:}
  curl --fail --silent --show-error --unix-socket "$HANDUP_SOCKET" -H "Content-Type: $mime" --data-binary "@$base/assets/$file" http://localhost/v1/blobs
  printf '\n'
done
