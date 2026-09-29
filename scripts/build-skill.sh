#!/usr/bin/env bash
# Build the redistributable skill bundle at
# skills/dynatrace-metric-device-dashboard-generator/ from AGENTS.md and the
# checked-in reference assets. Run this whenever the agent instructions or
# reference assets change.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="dynatrace-metric-device-dashboard-generator"
SKILL_DIR="$ROOT/skills/$SKILL_NAME"
REF_DIR="$SKILL_DIR/reference"

mkdir -p "$REF_DIR"

if [ ! -f "$ROOT/AGENTS.md" ]; then
	echo "ERROR: canonical instructions not found: $ROOT/AGENTS.md" >&2
	exit 1
fi

if [ -z "$(find "$REF_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
	echo "ERROR: no reference assets found in $REF_DIR" >&2
	exit 1
fi

# --- SKILL.md = frontmatter + AGENTS.md (with .example/ -> reference/ rewrites)
cat > "$SKILL_DIR/SKILL.md" <<'FRONTMATTER'
---
name: dynatrace-metric-device-dashboard-generator
description: Generate a Dynatrace Gen 3 **metric dashboard** (relevant metrics, optional map tile, branded section dividers), a relevant Dynatrace device to map metrics and logs to, and a matching 30‑minute MINT metrics injector for a named technology, then deploy both via `dtctl`. Triggers include phrases like "generate a metric dashboard", "build a metrics demo for <technology>", "spin up a metrics dashboard + injector", "/generate-technology-dashboard". Requires `dtctl` authenticated to a Dynatrace Gen 3 tenant.
---

FRONTMATTER

# Append AGENTS.md, rewriting legacy `.example/` references to the bundled
# `reference/` path. Reference assets are already checked into REF_DIR and are
# intentionally preserved rather than deleted and recopied from a missing
# source directory.
sed 's|\.example/|reference/|g' "$ROOT/AGENTS.md" >> "$SKILL_DIR/SKILL.md"

echo "Built skill bundle at: $SKILL_DIR"
ls -la "$SKILL_DIR"
echo "---"
ls -la "$REF_DIR"
