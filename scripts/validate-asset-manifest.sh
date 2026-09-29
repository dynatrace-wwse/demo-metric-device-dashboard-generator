#!/usr/bin/env bash
# Validate a generated technology asset manifest.
set -euo pipefail

MANIFEST="${1:-}"

if [ -z "$MANIFEST" ]; then
  echo "Usage: $0 <asset-manifest.json>" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

jq -e '
  (.schemaVersion | numbers) and
  (.technology | strings | length > 0) and
  (.displayName | strings | length > 0) and
  (.managedBy == "dynatrace-metric-device-dashboard-generator") and
  (.assetVersion | strings | length > 0) and
  (.provider | strings | length > 0) and
  (.workflow.id | strings | length > 0) and
  ((.workflow.tasks | type) == "array") and
  ((.workflow.tasks | length) > 0) and
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
  ([.workflow.tasks[]] | length == (unique | length))
' "$MANIFEST" >/dev/null

echo "Manifest valid: $MANIFEST"
