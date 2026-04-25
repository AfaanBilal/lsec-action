#!/usr/bin/env bash
set -euo pipefail

BADGE_PASS="![pass](https://img.shields.io/badge/lsec-pass-4CAF50?style=flat-square&logo=shield)"
BADGE_FAIL="![fail](https://img.shields.io/badge/lsec-fail-E53935?style=flat-square&logo=shield)"

BADGE="$( [ "$RESULT" = "pass" ] && echo "$BADGE_PASS" || echo "$BADGE_FAIL" )"

# Build the severity table from the JSON report
CRITICAL=$(jq '.severity_counts.critical // 0' lsec-report.json)
HIGH=$(jq '.severity_counts.high     // 0' lsec-report.json)
MEDIUM=$(jq '.severity_counts.medium // 0' lsec-report.json)
LOW=$(jq '.severity_counts.low       // 0' lsec-report.json)
INFO=$(jq '.severity_counts.info     // 0' lsec-report.json)
TOTAL=$(jq '.findings | length'           lsec-report.json)

# Top 5 findings for the detail section
FINDINGS_TABLE=$(jq -r '
  .findings[:5][] |
  "| `\(.rule_id)` | \(.severity) | \(.file):\(.line) | \(.message[:60]) |"
' lsec-report.json 2>/dev/null || echo "")

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

$(if [ -n "$FINDINGS_TABLE" ]; then
  echo "### Top findings"
  echo ""
  echo "| Rule | Severity | Location | Message |"
  echo "|------|----------|----------|---------|"
  echo "$FINDINGS_TABLE"
  echo ""
  echo "_See the Security tab for the full annotated report._"
fi)
"

# Find existing lsec comment on this PR
EXISTING_ID=$(gh api \
  "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq '.[] | select(.body | startswith("<!-- lsec-action-comment -->")) | .id' \
  | head -1)

if [ -n "$EXISTING_ID" ]; then
  # Update existing comment
  gh api \
    --method PATCH \
    "repos/$REPO/issues/comments/$EXISTING_ID" \
    -f body="$BODY"
else
  # Create new comment
  gh api \
    --method POST \
    "repos/$REPO/issues/$PR_NUMBER/comments" \
    -f body="$BODY"
fi
