#!/usr/bin/env bash
# Validate synthetic logs for a technology pack are arriving in Dynatrace.
#
# Usage:
#   ./scripts/validate-logs.sh <log.source> [window] [fallback-window]
#
# Examples:
#   ./scripts/validate-logs.sh akamai.synthetic
#   ./scripts/validate-logs.sh zscaler.zia.synthetic 30m 2h

set -euo pipefail

LOG_SOURCE="${1:-}"
WINDOW="${2:-30m}"
FALLBACK_WINDOW="${3:-2h}"

if [ -z "$LOG_SOURCE" ]; then
  echo "Usage: $0 <log.source> [window] [fallback-window]" >&2
  exit 2
fi

if ! command -v dtctl >/dev/null 2>&1; then
  echo "dtctl not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found" >&2
  exit 1
fi

run_query() {
  local window="$1"
  local query
  query="fetch logs, from:now()-${window} | filter log.source == \"${LOG_SOURCE}\" | summarize total = count(), errors = countIf(loglevel == \"ERROR\"), warns = countIf(loglevel == \"WARN\"), sources = countDistinct(log.source), levels = countDistinct(loglevel)"
  dtctl query "$query" -o json --plain
}

OUT="$(run_query "$WINDOW")"
TOTAL="$(printf '%s' "$OUT" | jq -r '.result.records[0].total // 0')"
ERRORS="$(printf '%s' "$OUT" | jq -r '.result.records[0].errors // 0')"
WARNS="$(printf '%s' "$OUT"  | jq -r '.result.records[0].warns // 0')"
LEVELS="$(printf '%s' "$OUT" | jq -r '.result.records[0].levels // 0')"

echo "log.source=${LOG_SOURCE} window=${WINDOW} total=${TOTAL} warns=${WARNS} errors=${ERRORS} levels=${LEVELS}"

if [ "$TOTAL" = "0" ]; then
  OUT="$(run_query "$FALLBACK_WINDOW")"
  TOTAL="$(printf '%s' "$OUT" | jq -r '.result.records[0].total // 0')"
  ERRORS="$(printf '%s' "$OUT" | jq -r '.result.records[0].errors // 0')"
  WARNS="$(printf '%s' "$OUT"  | jq -r '.result.records[0].warns // 0')"
  LEVELS="$(printf '%s' "$OUT" | jq -r '.result.records[0].levels // 0')"
  echo "log.source=${LOG_SOURCE} fallback_window=${FALLBACK_WINDOW} total=${TOTAL} warns=${WARNS} errors=${ERRORS} levels=${LEVELS}"

  if [ "$TOTAL" = "0" ]; then
    echo "Validation failed: no logs found for log.source=${LOG_SOURCE}" >&2
    exit 1
  fi
fi

if [ "$LEVELS" = "0" ]; then
  echo "Validation failed: loglevel field is missing from logs for log.source=${LOG_SOURCE}" >&2
  exit 1
fi

echo "Validation passed: logs present for log.source=${LOG_SOURCE}."
