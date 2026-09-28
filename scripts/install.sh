#!/usr/bin/env bash
# One-shot installer for Metric-Device Dashboard Generator agent prerequisites.
# macOS / Linux only. Windows users: see README.md.
set -eu

OS=$(uname -s)
case "$OS" in
  Darwin|Linux) ;;
  *)
    echo "This installer supports macOS and Linux only."
    echo "Windows users: install dtctl with PowerShell"
    echo "  irm https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.ps1 | iex"
    echo "Then install skills:  npx skills add dynatrace-oss/dtctl && npx skills add dynatrace/dynatrace-for-ai && npx skills add SudoSmitty/dynatrace-kpi-dashboard-generator"
    exit 1
    ;;
esac

green(){ printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

# ---------- jq ----------
if ! have jq; then
  yellow "==> Installing jq..."
  if have brew; then
    brew install jq
  elif have apt-get; then
    sudo apt-get update && sudo apt-get install -y jq
  elif have dnf; then
    sudo dnf install -y jq
  elif have yum; then
    sudo yum install -y jq
  else
    red "Could not auto-install jq. Install it manually: https://jqlang.github.io/jq/"
    exit 1
  fi
else
  green "==> jq already installed: $(jq --version)"
fi

# ---------- dtctl ----------
dtctl_latest() {
  # Prints the latest dtctl release tag (without leading "v"), e.g. "0.27.0".
  curl -fsSL "https://api.github.com/repos/dynatrace-oss/dtctl/releases/latest" 2>/dev/null \
    | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' \
    | head -n1
}

dtctl_current() {
  # Best-effort version extraction from `dtctl version` output.
  dtctl version 2>/dev/null | sed -n 's/.*[vV]\{0,1\}\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1
}

if ! have dtctl; then
  yellow "==> Installing dtctl..."
  if have brew; then
    brew install dynatrace-oss/tap/dtctl
  else
    curl -fsSL https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.sh | sh
  fi
else
  CURRENT="$(dtctl_current || true)"
  LATEST="$(dtctl_latest || true)"
  if [ -n "$CURRENT" ] && [ -n "$LATEST" ] && [ "$CURRENT" != "$LATEST" ]; then
    yellow "==> Updating dtctl: ${CURRENT} -> ${LATEST}"
    if have brew && brew list dynatrace-oss/tap/dtctl >/dev/null 2>&1; then
      brew update && brew upgrade dynatrace-oss/tap/dtctl
    else
      curl -fsSL https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.sh | sh
    fi
    green "==> dtctl now: $(dtctl_current || echo unknown)"
  else
    green "==> dtctl up to date: ${CURRENT:-unknown}${LATEST:+ (latest ${LATEST})}"
  fi
fi

# ---------- npx (Node) ----------
if ! have npx; then
  red "npx (Node.js) is required to install agent skills."
  yellow "Install Node.js (>=18):"
  yellow "  macOS:  brew install node"
  yellow "  Linux:  https://nodejs.org/  (or your distro's package manager)"
  yellow "Then re-run this installer to add the skills."
else
  yellow "==> Installing dtctl agent skill..."
  npx --yes skills add dynatrace-oss/dtctl || yellow "  (skip if already present)"

  yellow "==> Installing dynatrace-for-ai agent skills..."
  npx --yes skills add dynatrace/dynatrace-for-ai || yellow "  (skip if already present)"

  yellow "==> Installing dynatrace-metric-device-dashboard-generator skill..."
  npx --yes skills add dynatrace-wwse/demo-metric-device-dashboard-generator || yellow "  (skip if already present)"
fi

# ---------- Claude Code plugin (skill + /generate-kpi-dashboard slash command) ----------
if have claude; then
  yellow "==> Claude Code detected — installing plugin (skill + slash command)..."
  claude plugin marketplace add dynatrace-wwse/demo-metric-device-dashboard-generator 2>/dev/null \
    || yellow "  (marketplace already added)"
  claude plugin install dynatrace-metric-device-dashboard-generator@dynatrace-metric-device-dashboard-generator 2>/dev/null \
    || yellow "  (plugin already installed)"
  green "  /generate-metric-dashboard is now available in Claude Code from any cwd."
else
  yellow "==> Claude Code (\`claude\`) not found — skipping plugin install."
  yellow "    Install Claude Code (https://docs.anthropic.com/claude/claude-code) and re-run"
  yellow "    this script to enable /generate-metric-dashboard globally."
fi

# ---------- Authenticate ----------
echo
green "Prerequisite tools installed."
if ! dtctl auth whoami >/dev/null 2>&1; then
  yellow "Next: authenticate dtctl to your Dynatrace tenant, e.g.:"
  yellow "  dtctl auth login --context my-env --environment \"https://<env>.apps.dynatrace.com\""
else
  green "dtctl is authenticated as: $(dtctl auth whoami 2>/dev/null | head -n1)"
fi

echo
green "Run ./scripts/check-prereqs.sh to verify everything is ready."
