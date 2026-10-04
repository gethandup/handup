#!/bin/sh
set -eu
# Review only; never creates or publishes a PR automatically.
diff=$(git diff)
jq -n --arg diff "$diff" '{title:"Review proposed PR",kind:"review",previews:[{type:"diff",inline:$diff}]}' | handup ask --request - --wait --json
