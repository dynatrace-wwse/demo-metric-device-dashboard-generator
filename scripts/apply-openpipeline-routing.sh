#!/usr/bin/env bash
# Safely add or update one routing entry in the tenant-wide OpenPipeline
# bizevents routing object.
#
# builtin:openpipeline.bizevents.routing is a SINGLETON settings schema
# (maxObjects=1, multiObject=false): there is exactly one such object per
# environment, holding a list of routing entries for every technology and
# every hand-built demo route that already exists in the tenant. Applying a
# fresh single-entry document with no id resolves to that same object and
# REPLACES its entire routingEntries list — silently deleting every other
# rule that was there before, including ones this generator never created.
# Always go through this script instead of `dtctl apply -f <routing-file>`.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/apply-openpipeline-routing.sh <entry.json>

<entry.json> is a single RoutingEntry object, e.g.:
{
  "description": "<Technology> topology extraction pipeline",
  "enabled": true,
  "matcher": "event.provider == \"<technology>.event.provider\"",
  "pipelineType": "custom",
  "pipelineId": "<pipeline-settings-object-id>"
}

Fetches the existing tenant-wide routing object (if any), replaces or adds
the entry keyed by "description" (the schema enforces uniqueness on that
field, so re-running with the same description updates that entry in place
instead of duplicating it), and applies the full merged list back to the
same object id. Every other technology's entries are preserved untouched.
USAGE
}

[ "$#" -eq 1 ] || { usage >&2; exit 2; }
ENTRY_FILE="$1"
[ -f "$ENTRY_FILE" ] || { echo "ERROR: not found: $ENTRY_FILE" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }
command -v dtctl >/dev/null 2>&1 || { echo "ERROR: dtctl is required" >&2; exit 1; }

SCHEMA="builtin:openpipeline.bizevents.routing"
DESCRIPTION="$(jq -r '.description // empty' "$ENTRY_FILE")"
[ -n "$DESCRIPTION" ] || { echo "ERROR: entry file must set a non-empty 'description'" >&2; exit 1; }

tmp_existing="$(mktemp)"
tmp_resource="$(mktemp)"
trap 'rm -f "$tmp_existing" "$tmp_resource"' EXIT

dtctl get settings --schema "$SCHEMA" -o json --plain > "$tmp_existing"
OBJECT_ID="$(jq -r '.result[0].objectId // empty' "$tmp_existing")"

if [ -n "$OBJECT_ID" ]; then
  PRIOR_COUNT="$(jq '.result[0].value.routingEntries | length' "$tmp_existing")"
  jq --slurpfile entry "$ENTRY_FILE" '
    .result[0] as $existing
    | {
        id: $existing.objectId,
        schemaid: $existing.schemaId,
        scope: $existing.scope,
        value: {
          routingEntries: (
            [ $existing.value.routingEntries[]? | select(.description != $entry[0].description) ]
            + $entry
          )
        }
      }
  ' "$tmp_existing" > "$tmp_resource"
  NEW_COUNT="$(jq '.value.routingEntries | length' "$tmp_resource")"
  echo "Existing routing object $OBJECT_ID has $PRIOR_COUNT entr$([ "$PRIOR_COUNT" = 1 ] && echo y || echo ies)."
  echo "Merging entry \"$DESCRIPTION\" -> $NEW_COUNT total entr$([ "$NEW_COUNT" = 1 ] && echo y || echo ies) after merge (every other entry preserved)."
else
  echo "No tenant-wide routing object exists yet — creating it with this one entry."
  jq --slurpfile entry "$ENTRY_FILE" -n '
    { schemaid: "builtin:openpipeline.bizevents.routing",
      scope: "environment",
      value: { routingEntries: $entry } }
  ' > "$tmp_resource"
fi

dtctl apply -f "$tmp_resource" -o json --plain
