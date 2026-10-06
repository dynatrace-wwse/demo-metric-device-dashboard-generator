#!/usr/bin/env bash
# Validate a generated technology asset manifest.
set -euo pipefail

MANIFEST="${1:-}"
# --for-cleanup: a missing workflow.id must not block cleanup; the cleanup
# script falls back to an exact-title lookup instead.
FOR_CLEANUP=false
[ "${2:-}" = "--for-cleanup" ] && FOR_CLEANUP=true

if [ -z "$MANIFEST" ]; then
  echo "Usage: $0 <asset-manifest.json> [--for-cleanup]" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

jq -e --argjson cleanup "$FOR_CLEANUP" '
  (.schemaVersion | numbers) and
  (.technology | strings | length > 0) and
  (.displayName | strings | length > 0) and
  (.managedBy == "dynatrace-metric-device-dashboard-generator") and
  (.assetVersion | strings | length > 0) and
  (.provider | strings | length > 0) and
  ($cleanup or (
    (.workflow.id | strings | length > 0) and
    ((.workflow.tasks | type) == "array") and
    ((.workflow.tasks | length) > 0)
  )) and
  ((.resources.dashboard | type) == "array") and
  ((.resources.settings | type) == "array") and
  ((.resources.documents | type) == "array") and
  ((.resources.routingEntries | type) == "array") and
  (.entity.nodeType | strings | test("^[A-Z][A-Z0-9_]+$")) and
  (.entity.idPrefix | strings | length > 0) and
  ([(.resources.dashboard // [])[], (.resources.settings // [])[], (.resources.documents // [])[]]
    | all(.[]; ((.type | strings | length > 0) and (.id | strings | length > 0)))) and
  ((.resources.routingEntries // [])
    | all(.[]; (.description | strings | length > 0))) and
  ([.workflow.tasks[]?] | length == (unique | length))
' "$MANIFEST" >/dev/null || {
  echo "ERROR: manifest does not match the required schema (compare with skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/asset-manifest.json): $MANIFEST" >&2
  exit 4
}

if [ "$FOR_CLEANUP" = false ]; then
  WORKFLOW_FILE="$(dirname "$MANIFEST")/$(jq -r '.workflow.file // empty' "$MANIFEST")"
  if [ -f "$WORKFLOW_FILE" ]; then
    # latestStart does not stop a Dynatrace workflow; expiry must be enforced in each task script.
    if grep -qE 'latestStart(Time)?:' "$WORKFLOW_FILE"; then
      echo "ERROR: $WORKFLOW_FILE uses latestStart/latestStartTime, which does not stop the schedule — use the EXPIRES_AT guard instead (see reference/phase-6-workflow.md)" >&2
      exit 5
    fi
    task_count="$(grep -c 'export default async function' "$WORKFLOW_FILE" || true)"
    guard_count="$(grep -c 'const EXPIRES_AT' "$WORKFLOW_FILE" || true)"
    if [ "$guard_count" -lt "$task_count" ]; then
      echo "ERROR: $WORKFLOW_FILE has $task_count task script(s) but only $guard_count EXPIRES_AT guard(s) — every task needs one" >&2
      exit 5
    fi
  fi
fi

echo "Manifest valid: $MANIFEST"
