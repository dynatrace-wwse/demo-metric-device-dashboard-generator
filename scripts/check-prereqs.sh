#!/usr/bin/env bash
# Verify prerequisites for the Metric-Device Dashboard Generator agent.
set -u

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

fail=0
SKILLS_HOME="${HOME}/.agents/skills"

echo "==> Checking dtctl..."
if ! command -v dtctl >/dev/null 2>&1; then
  red "  dtctl is NOT installed."
  yellow "  Install:"
  yellow "    macOS/Linux:  ./scripts/install.sh    (or: brew install dynatrace-oss/tap/dtctl)"
  yellow "    Windows:      irm https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.ps1 | iex"
  fail=1
else
  green "  dtctl found: $(dtctl version 2>/dev/null | head -n1 || echo 'unknown version')"
fi

echo "==> Checking dtctl authentication..."
if ! dtctl auth whoami >/dev/null 2>&1; then
  red "  dtctl is not authenticated to a Dynatrace tenant."
  yellow "  Run: dtctl auth login --context my-env --environment \"https://<env>.apps.dynatrace.com\""
  fail=1
else
  green "  Authenticated as: $(dtctl auth whoami 2>/dev/null | head -n1)"
  CTX=$(dtctl ctx current 2>/dev/null | head -n1 || echo unknown)
  green "  Active context: ${CTX}"
fi

echo "==> Checking jq..."
if ! command -v jq >/dev/null 2>&1; then
  yellow "  jq not found. Install with: brew install jq   (or apt-get install jq)"
  fail=1
else
  green "  jq found: $(jq --version)"
fi

echo "==> Checking dtctl agent skill..."
if [ -d "${SKILLS_HOME}/dtctl" ] || [ -d "./.claude/skills/dtctl" ] || [ -d "./.cursor/skills/dtctl" ]; then
  green "  dtctl skill installed"
else
  yellow "  dtctl skill not detected. Install with:  npx skills add dynatrace-oss/dtctl"
  fail=1
fi

echo "==> Checking dynatrace-for-ai skills..."
if ls "${SKILLS_HOME}"/dt-* >/dev/null 2>&1 \
   || ls ./.claude/skills/dt-* >/dev/null 2>&1 \
   || ls ./.cursor/skills/dt-* >/dev/null 2>&1; then
  green "  dynatrace-for-ai skills installed"
else
  yellow "  dynatrace-for-ai skills not detected. Install with:  npx skills add dynatrace/dynatrace-for-ai"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  green "All prerequisites satisfied. You can run the agent."
  exit 0
else
  red "One or more prerequisites are missing. Fix the items above and re-run."
  exit 1
fi
