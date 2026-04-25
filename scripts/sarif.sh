#!/usr/bin/env bash
# Run lsec a second time to produce a SARIF report for Code Scanning upload.
# Inputs (env): LSEC_BIN, INPUT_PATH, INPUT_MIN_CONFIDENCE, INPUT_BASELINE,
#               INPUT_ONLY, INPUT_SKIP, SARIF_OUTPUT.
set -uo pipefail

: "${LSEC_BIN:?LSEC_BIN is required}"
: "${INPUT_PATH:?INPUT_PATH is required}"
: "${INPUT_MIN_CONFIDENCE:?INPUT_MIN_CONFIDENCE is required}"
: "${SARIF_OUTPUT:?SARIF_OUTPUT is required}"

args=(
  scan "$INPUT_PATH"
  --min-confidence "$INPUT_MIN_CONFIDENCE"
  --format sarif
  --output "$SARIF_OUTPUT"
)

[ -n "${INPUT_BASELINE:-}" ] && args+=(--baseline "$INPUT_BASELINE")
[ -n "${INPUT_ONLY:-}" ]     && args+=(--only "$INPUT_ONLY")
[ -n "${INPUT_SKIP:-}" ]     && args+=(--skip "$INPUT_SKIP")

# Without --ci, lsec exits 0 on success regardless of severity. Exit 2 still
# indicates a runtime error and should surface.
set +e
"$LSEC_BIN" "${args[@]}"
code=$?
set -e

if [ "$code" -ge 2 ]; then
  echo "::error::lsec SARIF run exited with $code"
  exit "$code"
fi

if [ ! -f "$SARIF_OUTPUT" ]; then
  echo "::error::SARIF report not generated at $SARIF_OUTPUT"
  exit 1
fi
