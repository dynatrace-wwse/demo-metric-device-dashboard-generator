#!/usr/bin/env bash
# Fixture tests for asset-manifest validation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALID="$(mktemp)"
INVALID="$(mktemp)"
trap 'rm -f "$VALID" "$INVALID"' EXIT

cat > "$VALID" <<'JSON'
{
  "schemaVersion": 1,
  "technology": "example-runtime",
  "displayName": "Example Runtime",
  "managedBy": "dynatrace-metric-entity-dashboard-generator",
  "assetVersion": "v1",
  "provider": "example.runtime.event.provider",
  "workflow": { "id": "workflow-1", "tasks": ["example_runtime_v1"] },
  "resources": {
    "dashboard": [{ "type": "dashboard", "id": "dashboard-1" }],
    "settings": [{ "type": "setting", "id": "setting-1" }],
    "documents": [],
    "routingEntries": [{ "description": "Example Runtime topology extraction pipeline" }]
  },
  "entity": { "nodeType": "CUSTOM_RUNTIME_NODE", "idPrefix": "runtime" }
}
JSON

cat > "$INVALID" <<'JSON'
{
  "schemaVersion": 1,
  "technology": "example-runtime",
  "managedBy": "someone-else",
  "workflow": { "id": "workflow-1", "tasks": [] },
  "resources": { "dashboard": [], "settings": [], "documents": [] },
  "entity": { "nodeType": "CUSTOM_RUNTIME_NODE", "idPrefix": "runtime" }
}
JSON

"$ROOT/scripts/validate-asset-manifest.sh" "$VALID"
if "$ROOT/scripts/validate-asset-manifest.sh" "$INVALID" >/dev/null 2>&1; then
  echo "ERROR: invalid fixture unexpectedly passed" >&2
  exit 1
fi

echo "Manifest fixtures passed."
