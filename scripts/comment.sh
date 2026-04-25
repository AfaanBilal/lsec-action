#!/usr/bin/env bash
# Post (or update) a PR comment summarising lsec results.
# Inputs (env): GH_TOKEN, REPO, PR_NUMBER, RESULT, FAIL_ON, JSON_REPORT.
set -euo pipefail

: "${JSON_REPORT:=lsec-report.json}"

if [ ! -f "$JSON_REPORT" ]; then
  echo "::warning::$JSON_REPORT missing; skipping PR comment"
  exit 0
fi

: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${RESULT:?RESULT is required}"
: "${FAIL_ON:?FAIL_ON is required}"

BADGE_PASS="![pass](https://img.shields.io/badge/lsec-pass-4CAF50?style=flat-square&logo=shield)"
BADGE_FAIL="![fail](https://img.shields.io/badge/lsec-fail-E53935?style=flat-square&logo=shield)"
BADGE=$([ "$RESULT" = "pass" ] && echo "$BADGE_PASS" || echo "$BADGE_FAIL")

CRITICAL=$(jq -r '.counts.critical // 0' "$JSON_REPORT")
HIGH=$(jq -r    '.counts.high     // 0' "$JSON_REPORT")
MEDIUM=$(jq -r  '.counts.medium   // 0' "$JSON_REPORT")
LOW=$(jq -r     '.counts.low      // 0' "$JSON_REPORT")
INFO=$(jq -r    '.counts.info     // 0' "$JSON_REPORT")
TOTAL=$(jq -r   '.counts.total // (.findings | length)' "$JSON_REPORT")

# Top 10 findings, location-safe, message truncated.
FINDINGS_TABLE=$(jq -r '
  .findings[:10][]? |
  "| `\(.rule_id)` | \(.severity) | \((.file // "-")):\((.line // "-")) | \((.message // "")[:80] | gsub("\\|"; "\\\\|") | gsub("\n"; " ")) |"
' "$JSON_REPORT" 2>/dev/null || true)

BODY="<!-- lsec-action-comment -->
## $BADGE lsec security scan

| Severity | Count |
|----------|-------|
| 🔴 Critical | $CRITICAL |
| 🟠 High     | $HIGH     |
| 🟡 Medium   | $MEDIUM   |
| 🔵 Low      | $LOW      |
| ⚪ Info     | $INFO     |
| **Total**   | **$TOTAL** |

**Fail threshold:** \`$FAIL_ON\` and above
"

if [ -n "$FINDINGS_TABLE" ]; then
  BODY="$BODY
### Top findings

| Rule | Severity | Location | Message |
|------|----------|----------|---------|
$FINDINGS_TABLE

_See the **Security** tab for the full annotated report._
"
fi

EXISTING_ID=$(gh api --paginate \
  "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq '.[] | select(.body | startswith("<!-- lsec-action-comment -->")) | .id' \
  | head -n1)

if [ -n "$EXISTING_ID" ]; then
  gh api --method PATCH \
    "repos/$REPO/issues/comments/$EXISTING_ID" \
    -f body="$BODY" >/dev/null
  echo "Updated lsec PR comment ($EXISTING_ID)"
else
  gh api --method POST \
    "repos/$REPO/issues/$PR_NUMBER/comments" \
    -f body="$BODY" >/dev/null
  echo "Posted lsec PR comment"
fi
