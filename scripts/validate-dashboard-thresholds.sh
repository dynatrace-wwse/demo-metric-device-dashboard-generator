#!/usr/bin/env bash
# Validate singleValue tiles in a live Dynatrace Gen 3 dashboard.
#
# Checks coloring.colorRules (Gen 3 schema).
# NOTE: Do NOT check visualizationSettings.thresholds — that is the old schema.
# Gen 3 dashboards store thresholds in coloring.colorRules after dtctl apply.
#
# Usage:
#   ./scripts/validate-dashboard-thresholds.sh <dashboard-id> [exclude-title-regex]
#
# exclude-title-regex (ERE, optional): skip singleValue tiles whose title matches.
# Use it for intentionally threshold-free count tiles.
#
# Example:
#   ./scripts/validate-dashboard-thresholds.sh abc-123
#   ./scripts/validate-dashboard-thresholds.sh abc-123 "Total.*Requests|DDoS|WAF|Bot|Ingested"

set -euo pipefail

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

if ! command -v dtctl >/dev/null 2>&1; then
  red "dtctl not found in PATH"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  red "jq not found in PATH"
  exit 1
fi

if [ $# -lt 1 ]; then
  red "Usage: $0 <dashboard-id> [exclude-title-regex]"
  exit 2
fi

DASHBOARD_ID="$1"
EXCLUDE_REGEX="${2:-}"   # empty = all singleValue tiles are required; caller supplies exclusions

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

echo "==> Fetching dashboard ${DASHBOARD_ID} from Dynatrace..."
dtctl get dashboard "$DASHBOARD_ID" -o json --plain > "$TMP_JSON"

DASHBOARD_NAME="$(jq -r '.result.name // "<unknown>"' "$TMP_JSON")"
echo "Dashboard: ${DASHBOARD_NAME}"
echo "Exclude title regex: ${EXCLUDE_REGEX:-<none — all singleValue tiles required>}"
echo

# Build rows: tileId, title, colorRuleCount, requiredFlag
# coloring.colorRules is the Gen 3 path for threshold rules.
REPORT="$(jq -r --arg ex "$EXCLUDE_REGEX" '
  .result.content.tiles
  | to_entries[]
  | select(.value.visualization == "singleValue")
  | {
      tile: .key,
      title: (.value.title // ""),
      colorRuleCount: (
        (.value.visualizationSettings.coloring.colorRules // []) | length
      ),
      required: (
        if ($ex == "") then true
        else ((.value.title // "") | test($ex) | not)
        end
      )
    }
  | [.tile, .title, (.colorRuleCount|tostring), (if .required then "required" else "excluded" end)]
  | @tsv
' "$TMP_JSON")"

if [ -z "$REPORT" ]; then
  yellow "No singleValue tiles found in this dashboard."
  exit 0
fi

printf "%s\n" "tile	title	coloring_rule_count	status"
printf "%s\n" "$REPORT"

MISSING_COUNT="$(printf "%s\n" "$REPORT" | awk -F'\t' '$4=="required" && $3=="0" {c++} END {print c+0}')"
REQUIRED_COUNT="$(printf "%s\n" "$REPORT" | awk -F'\t' '$4=="required" {c++} END {print c+0}')"

if [ "$MISSING_COUNT" -gt 0 ]; then
  echo
  red "Validation failed: ${MISSING_COUNT} of ${REQUIRED_COUNT} required singleValue tiles have no coloring rules."
  red "Missing tiles:"
  printf "%s\n" "$REPORT" | awk -F'\t' '$4=="required" && $3=="0" {printf "- tile %s: %s\n", $1, $2}'
  echo
  yellow "Tip: pass an exclude-title-regex as \$2 for tiles that are intentionally threshold-free (plain counts)."
  yellow "Example: $0 ${DASHBOARD_ID} \"Total.*Requests|DDoS|WAF|Bot|Ingested\""
  exit 1
fi

# Check for ASCII >= comparators in coloring.colorRules — Dynatrace silently ignores them.
ASCII_GE="$(jq -r '
  .result.content.tiles | to_entries[]
  | select(.value.visualization == "singleValue")
  | . as $tile
  | (.value.visualizationSettings.coloring.colorRules // [])[]
  | select(.comparator == ">=")
  | "  tile \($tile.key) (\($tile.value.title // "untitled")): comparator is ASCII >= — must be Unicode ≥"
' "$TMP_JSON" 2>/dev/null)"

if [ -n "$ASCII_GE" ]; then
  echo
  red "Validation failed: ASCII >= comparator detected. Dynatrace silently ignores it — thresholds will never fire."
  red "Fix: replace every \">=\" with the Unicode character ≥ (U+2265)."
  printf "%s\n" "$ASCII_GE"
  exit 1
fi

echo
green "Validation passed: all ${REQUIRED_COUNT} required singleValue tiles have coloring rules with valid comparators."
