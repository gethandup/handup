#!/bin/sh
# Fails if this repository contains anything outside the public allowlist.
# The application source must never be committed here.
set -eu
cd "$(dirname "$0")/.."

allowed_top='^(README\.md|SECURITY\.md|LICENSE\.md|llms\.txt|llms-full\.txt|assets|docs|examples|\.skills|\.github|scripts)(/|$)'
allowed_scripts='^scripts/check-no-source\.sh$'
denied='(\.(rs|ts|tsx|js|mjs|cjs|kt|kts|java|swift|go|py|c|h|cc|cpp|toml|lock|gradle)$|(^|/)(Cargo\.toml|Cargo\.lock|package\.json|Makefile|Dockerfile)$|^(crates|apps|ui|integrations|site|brag)/)'

files=$(find . -type f ! -path './.git/*' | sed 's|^\./||' | sort)
bad=$(printf '%s\n' "$files" | grep -Ev "$allowed_top" || true)
bad="$bad
$(printf '%s\n' "$files" | grep '^scripts/' | grep -Ev "$allowed_scripts" || true)
$(printf '%s\n' "$files" | grep -E "$denied" || true)"
bad=$(printf '%s\n' "$bad" | sed '/^$/d' | sort -u)

if [ -n "$bad" ]; then
  echo "error: files outside the public allowlist:" >&2
  printf '  %s\n' $bad >&2
  exit 1
fi
echo "ok: $(printf '%s\n' "$files" | wc -l) files, all on the public allowlist"
