#!/usr/bin/env bash
# Canonical source: skills/dynatrace-metric-device-dashboard-generator/SKILL.md
# This script generates AGENTS.md (for Copilot/Cursor users in this repo) by
# stripping the Claude Code frontmatter block from SKILL.md.
# Run whenever SKILL.md changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="dynatrace-metric-device-dashboard-generator"
SKILL_DIR="$ROOT/skills/$SKILL_NAME"
REF_DIR="$SKILL_DIR/reference"

if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
	echo "ERROR: canonical source not found: $SKILL_DIR/SKILL.md" >&2
	exit 1
fi

if [ -z "$(find "$REF_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
	echo "ERROR: no reference assets found in $REF_DIR" >&2
	exit 1
fi

# Generate AGENTS.md: strip YAML frontmatter, prepend header comment
{
	echo "<!-- Generated from SKILL.md — for GitHub Copilot/Cursor users in this repo only."
	echo "     This file does not ship with the distributed plugin. Run scripts/build-skill.sh to regenerate. -->"
	echo ""
	# Drop the opening ---, everything up to and including the closing ---, then the blank line after
	awk '/^---$/{if(in_front){in_front=0;next}else{in_front=1;next}} in_front{next} !printed_first && /^$/{next} {printed_first=1; print}' "$SKILL_DIR/SKILL.md"
} > "$ROOT/AGENTS.md"

echo "Generated AGENTS.md from SKILL.md"
echo "---"
echo "Skill bundle: $SKILL_DIR"
ls -la "$SKILL_DIR"
