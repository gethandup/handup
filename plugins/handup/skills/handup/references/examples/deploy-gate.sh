#!/bin/sh
set -eu
: "${1:?Usage: deploy-gate.sh DEPLOY_EXECUTABLE [args...]}"
request=$(jq -n --args '$ARGS.positional as $argv | {title:"Approve deployment",kind:"command",risk:"high",summary:"Review target and rollback before deployment",previews:[{type:"command",command:{argv:$argv}}]}' -- "$@")
if decision=$(printf '%s' "$request" | handup ask --request - --wait --json); then
  printf '%s\n' "$decision"
  exec "$@"
else
  code=$?; printf '%s\n' "$decision"
  # 5: the human already ran it from the handup desktop app; never run it
  # again. Exit with the deployment's own status (1 if it did not finish).
  if [ "$code" -eq 5 ]; then
    exit "$(printf '%s' "$decision" | jq -r '.run_result.exit_code // 1')"
  fi
  exit "$code"
fi
