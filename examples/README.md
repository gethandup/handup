# Runnable requests

Each TYPE.json is a complete request for one preview type. From the repository root:

```sh
export HANDUP_SOCKET="$PWD/.example-state/handup.sock"
HANDUP_DATA_DIR="$PWD/.example-state/data" HANDUP_STATE_DIR="$PWD/.example-state/state" handup serve --foreground
# In another terminal with the same HANDUP_SOCKET:
sh examples/upload-assets.sh
handup ask --request - --wait --json < examples/image.json
# A human in a third terminal: handup ls --json; handup approve ID
```

The upload step is required for files, image, video, audio, file and pdf JSONs; committed hashes bind the bundled actual assets. Text, markdown, code, diff, command, json and html JSONs are immediately runnable without asset uploads. Files are snapshots, not live links. Media samples are a blue one-second video, a one-second silent WAV, a one-pixel PNG, ZIP and a tiny PDF.

Flows (run with sh; jq required): deploy-gate.sh executes its supplied executable/arguments only after approval; pr-review.sh snapshots the current git diff without publishing; html-mockup/review.sh submits a self-contained HTML preview; voiceover-audio.sh uploads and asks about the sample audio. They all submit through `handup ask --request -`. On deny/expiry/cancellation/error they exit without executing the gated action. Never put credential values in previews.

Cookbook flows in `cookbook/` (see the [Cookbook](../docs/public/cookbook/index.md)): email-canned-reply.sh, email-route.sh with email-rules.yaml, auto-decider.sh (exec hook) with spend-request.sh, refund-form.sh, publish-gate.sh and meeting-reply.sh, plus sample inputs (inbound-email.json, receipt-email.json, noreply-email.json, order.json, post.md, invite.json). Each prints the approved action as JSON and exits 0 only when approved or answered; none performs the action itself.

For command approvals, desktop **Run** returns approval with `run_result` and
CLI **exit 5**, even if execution failed. Consume its exit code/error/output
and do not execute again. `deploy-gate.sh` skips its supplied command on exit 5
and returns `run_result.exit_code`, or 1 when absent. Only ordinary approved
decisions without a result permit the script to execute the reviewed command
itself. See [Shell and CI](../docs/public/agents/shell-ci.md) for result paths.
