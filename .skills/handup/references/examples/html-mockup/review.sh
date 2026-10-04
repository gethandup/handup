#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
jq -n --rawfile html "$base/index.html" '{title:"Review HTML mockup",kind:"review",previews:[{type:"html",inline:$html}]}' | handup ask --request - --wait --json
