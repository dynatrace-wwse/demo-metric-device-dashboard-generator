# Metric-Device Dashboard Generator

An installable **AI agent** that, for any technology you name, generates a
Dynatrace **Gen 3 metric dashboard** plus a **30‑minute MINT metrics injector**,
deploys both with `dtctl`, and verifies metrics and entities are landing.

Works with **Claude Code**, **GitHub Copilot**, **Cursor**, or any agent
runtime that respects `AGENTS.md`.

---

## What you get for each technology

```
dashboards/<Technology>/
  asset-manifest.json                    # generator ownership and tenant resource IDs
  <technology>-dashboard-v1.json          # Gen 3 dashboard (logo, KPIs, charts, map)
  <technology>-injector.js               # 30-min MINT metrics injector
  <technology>-device-creator.js         # Workflow task: MINT ingest for metric-device association
  <technology>-openpipeline.json         # OpenPipeline pipeline (smartscapeNode extraction)
  <technology>-openpipeline-routing.json # OpenPipeline routing rule
  README.md                              # IDs + deploy commands
  LEARNINGS.md                           # DQL/layout notes, device creation findings
  SALES-PITCH.md                         # 1-page value pitch
```

Each technology gets its own `<Technology> | Injector Workflow`, running every
30 minutes in your tenant.

During generation, provide the number of days to run; the default is 7 days,
and `0` means no automatic expiry. Expiry is enforced by an `EXPIRES_AT` guard in
each task script: after that date the schedule still fires but ingests nothing.
Run cleanup to remove the workflow itself.

### Cleanup generated assets

Each generated technology pack records its tenant resource IDs in
`asset-manifest.json`. Use the cleanup tool to inventory packs and preview a
technology-specific cleanup:

```bash
./scripts/cleanup-technology.sh --list
./scripts/cleanup-technology.sh --technology zscaler-internet-access --dry-run
./scripts/cleanup-technology.sh --technology zscaler-internet-access --confirm
./scripts/validate-asset-manifest.sh dashboards/zscaler-internet-access/asset-manifest.json
./scripts/test-asset-manifest.sh
```

Cleanup removes dashboards, technology-specific OpenPipeline settings, this
technology's routing entry, and its dedicated injector workflow (deleted
entirely; cleanup fails if it is still present). Logo documents require manual
cleanup. Historical metrics are retained according to tenant retention.

A technology folder without an `asset-manifest.json` is listed as legacy and
is not eligible for automatic deletion until a manifest is added.

### Reference example: Zscaler Internet Access

The completed [Zscaler Internet Access reference pack](skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/)
is the repository's reference implementation. It shows the full lifecycle:
MINT metric ingest, optional synthetic logs, OpenPipeline Smartscape extraction, shared
workflow tasks, dashboard thresholds, and live validation.

---

## Quick start (macOS / Linux)

```bash
git clone https://github.com/dynatrace-wwse/demo-metric-device-dashboard-generator.git
cd demo-metric-device-dashboard-generator
./scripts/install.sh
```

The installer installs `jq`, `dtctl`, and the agent skills (`dtctl`,
`dynatrace-for-ai`, and `dynatrace-metric-device-dashboard-generator`). If
Claude Code is installed it also adds the plugin so `/generate-metric-dashboard`
works globally.

Then authenticate and verify:

```bash
dtctl auth login --context my-env --environment "https://<env>.apps.dynatrace.com"
./scripts/check-prereqs.sh
```

> [!IMPORTANT]
> **Windows users:** the script above does not run on Windows.
> Skip it and follow the **[Windows install instructions](#windows-install)** section below.

---

## Use it

### Claude Code

```
/generate-metric-dashboard NVIDIA GPU
```

```text
/cleanup-metric-dashboard
/cleanup-metric-dashboard zscaler-internet-access
```

…or just ask in plain English: *"Generate a metric dashboard for NVIDIA GPU."*

### GitHub Copilot Chat (VS Code)

In agent mode:

```
Generate a metric dashboard for NVIDIA
```

If you want a slash command in Copilot, link the prompt file:

```bash
mkdir -p "$HOME/Library/Application Support/Code/User/prompts"   # macOS
ln -sfn "$PWD/.github/prompts/generate-metric-dashboard.prompt.md" \
  "$HOME/Library/Application Support/Code/User/prompts/generate-metric-dashboard.prompt.md"
```

Linux: `~/.config/Code/User/prompts/`. Windows: `%APPDATA%\Code\User\prompts\`.

### Any other agent

Point your agent at `AGENTS.md`. It is fully self‑contained.

---

## What the agent does

The agent confirms your active tenant before touching anything, then asks for
the technology name, an optional Dynatrace Hub link, and logo URL (it
searches if you don't provide one). It researches relevant metrics, writes
the full file set into `dashboards/<Technology>/`,
deploys the dashboard and OpenPipeline settings via `dtctl apply`, adds two
tasks to the shared injector workflow, executes the workflow, and verifies that
MINT metrics and Smartscape entities are landing.

Full spec: [AGENTS.md](AGENTS.md).

---

## Other install paths

### Already have `dtctl` + Dynatrace skills installed?

```bash
npx skills add dynatrace-wwse/demo-metric-device-dashboard-generator
```

Updates: `npx skills update` and `claude plugin update …`.

### Local‑only (developing the skill itself)

```bash
mkdir -p ~/.agents/skills ~/.claude/commands
ln -sfn "$PWD/skills/dynatrace-metric-device-dashboard-generator" \
  ~/.agents/skills/dynatrace-metric-device-dashboard-generator
ln -sfn "$PWD/.claude/commands/generate-metric-dashboard.md" \
  ~/.claude/commands/generate-metric-dashboard.md
ln -sfn "$PWD/.claude/commands/cleanup-metric-dashboard.md" \
  ~/.claude/commands/cleanup-metric-dashboard.md
```

After editing `AGENTS.md` or reference assets, regenerate the skill bundle:

```bash
./scripts/build-skill.sh
```

### Windows install

```powershell
# 1. dtctl + login
irm https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.ps1 | iex
dtctl auth login --context my-env --environment "https://<env>.apps.dynatrace.com"

# 2. jq
winget install jqlang.jq

# 3. Skills
npx skills add dynatrace-oss/dtctl
npx skills add dynatrace/dynatrace-for-ai
npx skills add dynatrace-wwse/demo-metric-device-dashboard-generator

# 4. (Optional) Claude Code plugin
claude plugin marketplace add dynatrace-wwse/demo-metric-device-dashboard-generator
claude plugin install dynatrace-metric-device-dashboard-generator@dynatrace-metric-device-dashboard-generator
```

Verify with `bash scripts/check-prereqs.sh` from Git Bash or WSL.

---

## Prerequisites

| Tool | Why | Check |
|------|-----|-------|
| **`dtctl`** authenticated to a Gen 3 tenant | Deploys dashboards + workflows, runs DQL | `dtctl auth whoami` |
| **`dtctl` agent skill** | Teaches your agent how to operate `dtctl` | folder in `~/.agents/skills/dtctl/` |
| **`dynatrace-for-ai` skills** | DQL, dashboards, notebooks domain knowledge | folders `dt-*` in `~/.agents/skills/` |
| **`dynatrace-metric-device-dashboard-generator` skill** | This agent | folder `~/.agents/skills/dynatrace-metric-device-dashboard-generator/` |
| **`jq`** | Manipulates workflow JSON when adding tasks | `jq --version` |
| **Node.js / `npx`** | Required by `npx skills add` | `node --version` |

> The agent will **not** install or configure `dtctl` for you.

---

## Repository layout

```
.
├── AGENTS.md                              # canonical agent instructions
├── README.md                              # this file
├── .claude-plugin/
│   └── marketplace.json                   # Claude Code plugin manifest
├── plugins/
│   └── dynatrace-metric-device-dashboard-generator/
├── skills/
│   └── dynatrace-metric-device-dashboard-generator/
│       ├── SKILL.md
│       └── reference/
├── .github/
│   ├── copilot-instructions.md
│   └── prompts/generate-metric-dashboard.prompt.md
├── .claude/
│   └── commands/generate-metric-dashboard.md
├── scripts/
│   ├── install.sh
│   ├── build-skill.sh
│   ├── check-prereqs.sh
│   └── cleanup-technology.sh
└── dashboards/<Company>/
```

---

## Troubleshooting

- **`dtctl auth whoami` fails** → run `dtctl auth login` before invoking the agent.
- **400 when applying the workflow** → two tasks share the same `position.{x, y}`; give the new task a unique position.
- **Map tile is empty** → the injector did not populate `geo.location.latitude` / `geo.location.longitude`.
- **Red‑X chart** → query uses `summarize` but the tile is a chart; rewrite with `makeTimeseries`.
- **Dashboard shows "Untitled"** → the JSON was applied without the `name` / `type` wrapper required by `dtctl apply`.
- **MINT 400 "failed to parse metric key"** → dimension separators are semicolons instead of commas. Correct format: `metric.key,dim1=val1,dim2=val2 value timestampMs`.
- **OpenPipeline 400 on routing `requiredDimensions`** → use `$eq(value)` or `$prefix(value)` syntax, not raw strings.
- **OpenPipeline validation error for `CUSTOM_DEVICE` nodeType** → `CUSTOM_DEVICE` is blocked; use `CUSTOM_<TECHNOLOGY>_<ENTITY>` instead.
- **Entities not visible in Explorer New** → OpenPipeline entities appear in Explorer Classic only; Explorer New requires EF2.
- **Smartscape Events API 401 from workflow** → The `/platform/ingest/v1/smartscape.events` endpoint rejects AutomationEngine tokens; use the OpenPipeline approach instead.
