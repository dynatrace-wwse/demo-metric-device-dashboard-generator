#!/usr/bin/env bash
# Discover and safely clean up assets generated for one technology.
# Configuration is removed; historical logs and metrics are retained.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_ROOT="$ROOT/dashboards"
MODE="list"
TECHNOLOGY=""
YES=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/cleanup-technology.sh --list
  scripts/cleanup-technology.sh --technology <slug> --dry-run
  scripts/cleanup-technology.sh --technology <slug> --confirm
  scripts/cleanup-technology.sh --technology <slug> --confirm --yes   # skip interactive prompt (for non-interactive/agentic use)

The command is dry-run unless --confirm is supplied. Each technology owns its
workflow exclusively, so cleanup deletes it entirely. Historical metrics and
historical logs are never deleted.
USAGE
}

fail() { echo "ERROR: $*" >&2; exit 1; }

delete_resource() {
  local resource_type="$1"
  local resource_id="$2"
  # builtin: schema IDs are settings objects — map to the dtctl resource name
  local dtctl_type="$resource_type"
  [[ "$resource_type" == builtin:* ]] && dtctl_type="settings"
  local output
  if output="$(dtctl delete "$dtctl_type" "$resource_id" --plain 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi
  if printf '%s' "$output" | grep -qiE '404|not found'; then
    echo "Already absent: $resource_type $resource_id"
    return 0
  fi
  printf '%s\n' "$output" >&2
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --list) MODE="list" ;;
    --technology|-t) [ "$#" -ge 2 ] || fail "--technology requires a slug"; TECHNOLOGY="$2"; MODE="plan"; shift ;;
    --dry-run) MODE="plan" ;;
    --confirm) MODE="cleanup" ;;
    --yes|-y) YES=1 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v dtctl >/dev/null 2>&1 || fail "dtctl is required"
VALIDATOR="$ROOT/scripts/validate-asset-manifest.sh"
[ -x "$VALIDATOR" ] || fail "manifest validator is missing or not executable: $VALIDATOR"

manifest_for() {
  find "$MANIFEST_ROOT" -path '*/asset-manifest.json' -type f -print | while IFS= read -r file; do
    if [ "$(jq -r '.technology // empty' "$file")" = "$1" ]; then
      printf '%s\n' "$file"
      return 0
    fi
  done
}

if [ "$MODE" = "list" ]; then
  found=0
  echo "Generated technology packs:"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    found=1
    jq -r '"\(.technology)\t\(.displayName)\t\(.workflow.id // "no-workflow")\t\((.resources.dashboard // []) | length) dashboard(s)\t\((.resources.settings // []) | length) setting(s)"' "$file"
  done < <(find "$MANIFEST_ROOT" -path '*/asset-manifest.json' -type f -print | sort)
  [ "$found" -eq 1 ] || echo "No asset manifests found. Existing packs need a manifest before automated cleanup."
  echo
  echo "Technology folders without manifests:"
  legacy=0
  while IFS= read -r folder; do
    [ -f "$folder/asset-manifest.json" ] && continue
    legacy=1
    printf '%s\n' "- ${folder#"$MANIFEST_ROOT"/}"
  done < <(find "$MANIFEST_ROOT" -mindepth 1 -maxdepth 1 -type d -print | sort)
  [ "$legacy" -eq 1 ] || echo "- none"
  exit 0
fi

[ -n "$TECHNOLOGY" ] || { usage >&2; exit 2; }
MANIFEST="$(manifest_for "$TECHNOLOGY" || true)"
[ -n "$MANIFEST" ] || fail "no asset manifest found for '$TECHNOLOGY'"
"$VALIDATOR" "$MANIFEST" >/dev/null

DISPLAY_NAME="$(jq -r '.displayName // .technology' "$MANIFEST")"
WORKFLOW_ID="$(jq -r '.workflow.id // empty' "$MANIFEST")"

echo "Technology: $DISPLAY_NAME ($TECHNOLOGY)"
echo "Manifest: $MANIFEST"
echo
echo "Configuration candidates:"
jq -r '
  (.resources.dashboard[]? | "- dashboard \(.id) \(.name // "")"),
  (.resources.settings[]? | "- setting \(.id) [\(.role // "")] (owned exclusively by this technology)") ,
  (.resources.routingEntries[]? | "- routing entry \"\(.description)\" (removed from the shared tenant-wide routing object; the object itself is never deleted)"),
  (.resources.documents[]? | "- document \(.id) [\(.role // "")] (manual/platform-supported cleanup)"),
  (.workflow.tasks[]? | "- workflow task \(. )")
' "$MANIFEST"
echo
echo "Workflow: ${WORKFLOW_ID:-none} (owned exclusively by this technology — will be deleted entirely)"
echo "Retained telemetry: metrics and logs for this technology"
echo "Smartscape entities: reported for follow-up; not assumed deletable"

[ "$MODE" = "plan" ] && exit 0

[ "$MODE" = "cleanup" ] || fail "internal mode error"

CURRENT_CONTEXT="$(dtctl config current-context 2>/dev/null || true)"
IDENTITY="$(dtctl auth whoami --plain 2>/dev/null || true)"
[ -n "$CURRENT_CONTEXT" ] || fail "unable to determine active dtctl context"
[ -n "$IDENTITY" ] || fail "unable to determine authenticated identity"
dtctl auth can-i delete dashboards --plain >/dev/null 2>&1 || fail "missing permission to delete dashboards"
echo
echo "Active context: ${CURRENT_CONTEXT:-unknown}"
echo "Authenticated identity: ${IDENTITY:-unknown}"
echo
echo "This will remove the listed configuration for '$TECHNOLOGY'."
if [ "$YES" = "1" ]; then
  echo "(confirmation skipped via --yes)"
else
  printf "Type the technology slug to confirm: "
  read -r confirmation < /dev/tty
  [ "$confirmation" = "$TECHNOLOGY" ] || fail "confirmation did not match; nothing was changed"
fi

echo

if [ -n "$WORKFLOW_ID" ]; then
  echo "Deleting workflow $WORKFLOW_ID (owned exclusively by '$TECHNOLOGY')..."
  delete_resource "workflow" "$WORKFLOW_ID"
fi

# Routing entries live inside a tenant-wide SINGLETON settings object
# (builtin:openpipeline.bizevents.routing, maxObjects=1) shared by every
# technology and every hand-built demo route. Remove only this technology's
# entries from that object's list; never delete the object itself. This must
# happen before the pipeline settings object below is deleted, or the API
# rejects the pipeline delete with a referential-constraint 400.
ROUTING_DESCRIPTIONS=()
while IFS= read -r d; do
  [ -n "$d" ] && ROUTING_DESCRIPTIONS+=("$d")
done < <(jq -r '.resources.routingEntries[]?.description' "$MANIFEST")

if [ "${#ROUTING_DESCRIPTIONS[@]}" -gt 0 ]; then
  ROUTING_SCHEMA="builtin:openpipeline.bizevents.routing"
  routing_tmp="$(mktemp)"
  trap 'rm -f "$routing_tmp"' EXIT
  dtctl get settings --schema "$ROUTING_SCHEMA" -o json --plain > "$routing_tmp"
  ROUTING_OBJECT_ID="$(jq -r '.result[0].objectId // empty' "$routing_tmp")"
  if [ -n "$ROUTING_OBJECT_ID" ]; then
    echo "Removing ${#ROUTING_DESCRIPTIONS[@]} routing entr$([ "${#ROUTING_DESCRIPTIONS[@]}" = 1 ] && echo y || echo ies) from the shared routing object $ROUTING_OBJECT_ID (every other entry is preserved)..."
    jq --argjson names "$(printf '%s\n' "${ROUTING_DESCRIPTIONS[@]}" | jq -R . | jq -s .)" '
      .result[0] as $existing
      | {
          id: $existing.objectId,
          schemaid: $existing.schemaId,
          scope: $existing.scope,
          value: { routingEntries: [ $existing.value.routingEntries[]? | select(.description | IN($names[]) | not) ] }
        }
    ' "$routing_tmp" > "${routing_tmp}.resource"
    dtctl apply -f "${routing_tmp}.resource" -o json --plain
    rm -f "${routing_tmp}.resource"
  else
    echo "No shared routing object exists — nothing to remove for: ${ROUTING_DESCRIPTIONS[*]}"
  fi
fi

while IFS=$'\t' read -r resource_type resource_id; do
  [ -n "$resource_type" ] || continue
  echo "Deleting $resource_type $resource_id..."
  delete_resource "$resource_type" "$resource_id"
done < <(jq -r '
  (.resources.dashboard[]? | [.type, .id]),
  (.resources.settings[]?  | [.type, .id])
  | @tsv
' "$MANIFEST")

jq -r '.resources.documents[]? | "Document retained for manual/platform-supported cleanup: \(.id)"' "$MANIFEST"

echo
echo "Verifying deleted configuration..."
while IFS=$'\t' read -r resource_type resource_id; do
  [ -n "$resource_type" ] || continue
  verify_type="$resource_type"
  [[ "$resource_type" == builtin:* ]] && verify_type="settings"
  if dtctl get "$verify_type" "$resource_id" -o json --plain >/dev/null 2>&1; then
    echo "WARNING: $resource_type $resource_id is still readable" >&2
  else
    echo "Verified absent: $resource_type $resource_id"
  fi
done < <(jq -r '
  (.resources.dashboard[]?, .resources.settings[]?) | [.type, .id],
  (if (.workflow.id // empty) != "" then [ "workflow", .workflow.id ] else empty end)
  | @tsv
' "$MANIFEST")

if [ "${#ROUTING_DESCRIPTIONS[@]}" -gt 0 ]; then
  remaining="$(dtctl get settings --schema "builtin:openpipeline.bizevents.routing" -o json --plain 2>/dev/null \
    | jq -r --argjson names "$(printf '%s\n' "${ROUTING_DESCRIPTIONS[@]}" | jq -R . | jq -s .)" \
      '[.result[0].value.routingEntries[]? | select(.description | IN($names[]))] | length')"
  if [ "${remaining:-0}" = "0" ]; then
    echo "Verified absent: routing entries ${ROUTING_DESCRIPTIONS[*]}"
  else
    echo "WARNING: $remaining routing entry/entries for '$TECHNOLOGY' still present in the shared routing object" >&2
  fi
fi

echo
echo "Cleanup complete for configuration assets belonging to $TECHNOLOGY."
echo "Historical metrics and logs were retained. Smartscape entities require separate tenant-supported lifecycle handling."
