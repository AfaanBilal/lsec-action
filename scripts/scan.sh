#!/usr/bin/env bash
# Run lsec, write JSON report, set step outputs.
# Inputs (env): LSEC_BIN, INPUT_PATH, INPUT_FAIL_ON, INPUT_MIN_CONFIDENCE,
#               INPUT_BASELINE, INPUT_ONLY, INPUT_SKIP, JSON_OUTPUT.
# Outputs (GITHUB_OUTPUT): findings-count, critical-count, high-count,
#                          medium-count, low-count, info-count, result, exit-code.
set -uo pipefail

: "${LSEC_BIN:?LSEC_BIN is required}"
: "${INPUT_PATH:?INPUT_PATH is required}"
: "${INPUT_FAIL_ON:?INPUT_FAIL_ON is required}"
: "${INPUT_MIN_CONFIDENCE:?INPUT_MIN_CONFIDENCE is required}"
: "${JSON_OUTPUT:=lsec-report.json}"

args=(
  scan "$INPUT_PATH"
  --ci
  --fail-on "$INPUT_FAIL_ON"
  --min-confidence "$INPUT_MIN_CONFIDENCE"
  --format json
  --output "$JSON_OUTPUT"
)

[ -n "${INPUT_BASELINE:-}" ] && args+=(--baseline "$INPUT_BASELINE")
[ -n "${INPUT_ONLY:-}" ]     && args+=(--only "$INPUT_ONLY")
[ -n "${INPUT_SKIP:-}" ]     && args+=(--skip "$INPUT_SKIP")

set +e
"$LSEC_BIN" "${args[@]}"
code=$?
set -e

# 0 = clean, 1 = CI threshold breached, 2 = lsec runtime error.
if [ "$code" -ge 2 ]; then
  echo "::error::lsec exited with $code (runtime error)"
  exit "$code"
fi

if [ ! -f "$JSON_OUTPUT" ]; then
  echo "::error::lsec did not produce $JSON_OUTPUT"
  exit 2
fi

read_count() { jq -r ".counts.${1} // 0" "$JSON_OUTPUT"; }

critical=$(read_count critical)
high=$(read_count high)
medium=$(read_count medium)
low=$(read_count low)
info=$(read_count info)
total=$(jq -r '.counts.total // (.findings | length)' "$JSON_OUTPUT")

result=$([ "$code" -eq 0 ] && echo pass || echo fail)

{
  echo "critical-count=$critical"
  echo "high-count=$high"
  echo "medium-count=$medium"
  echo "low-count=$low"
  echo "info-count=$info"
  echo "findings-count=$total"
  echo "result=$result"
  echo "exit-code=$code"
} >> "$GITHUB_OUTPUT"

echo "lsec scan complete: result=$result, total=$total (C:$critical H:$high M:$medium L:$low I:$info)"
exit 0
