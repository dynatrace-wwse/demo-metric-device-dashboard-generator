---
name: dynatrace-metric-device-dashboard-generator
description: Generate a Dynatrace Gen 3 **metric dashboard** (relevant metrics, optional map tile, branded section dividers), a relevant Dynatrace device to map metrics and logs to, and a matching 30‑minute MINT metrics injector for a named technology, then deploy both via `dtctl`. Triggers include phrases like "generate a metric dashboard", "build a metrics demo for <technology>", "spin up a metrics dashboard + injector", "/generate-technology-dashboard". Requires `dtctl` authenticated to a Dynatrace Gen 3 tenant.
---

# Metrics & Log Event Generator Agent

Canonical instructions for any agent (Claude Code, GitHub Copilot, Cursor, etc.)
running in this repository. For a named technology: generate a Dynatrace Gen 3 KPI
dashboard, a 30‑minute metric/log injector, and a Dynatrace device, deploy via `dtctl`, verify ingestion.

---

## Role & Objective

You are a Dynatrace Solutions Engineer. For a given technology:

0. **Gather inputs before starting** — ask for Hub link, logo, workflow duration, and whether logs are needed. Confirm any value the user already supplied.
1. Research 15–20 technology KPIs; search https://www.dynatrace.com/hub/.
   → Read `reference/phase-1-planning.md` for archetype guidance.
2. Build a Gen 3 dashboard with KPI tiles, charts, and (if appropriate) a map tile.
   → Read `reference/phase-2-dashboard.md` for layout, tile types, and visualization rules.
3. Write DQL queries for each tile; validate before embedding.
   → Read `reference/phase-3-dql.md` for pattern→visualization table and pitfall examples.
4. Create a Dynatrace device via OpenPipeline `smartscapeNode` processors.
   → Read `reference/phase-3-entities.md` for the CRITICAL routing singleton rule and MINT endpoint.
5. Create a JavaScript injector (3,000–5,000 events/run; log injector if applicable).
   → Read `reference/phase-4-injector.md` for requirements and schema conventions.
6. Run the dashboard implementation checklist before deploying.
   → Read `reference/phase-5-checklist.md`.
6.5. **Fork a sub-agent reviewer before deploying.** Spawn a fresh sub-agent with no prior context and ask it to verify:
   - Every `barChart`/`categoricalBar` tile feeds from `makeTimeseries`, not `summarize`
   - Every threshold comparator is Unicode `≥` (U+2265), not ASCII `>=`
   - `layouts:` is a top-level sibling of `tiles:` in `content:`, not nested inside any tile object
   - All threshold `color` values use `{ "Default": "#hex" }` object form, not a bare string
   - Variable filter conditions appear before any `|` aggregation pipe in every DQL query
   Incorporate any findings before proceeding to deploy.
7. Deploy dashboard, OpenPipeline settings, and dedicated workflow via `dtctl`.
   → Read `reference/phase-6-workflow.md` for step-by-step deployment and production fallback.
8. Write README.md, LEARNINGS.md, SALES-PITCH.md; run the quality gate.
   → Read `reference/phase-7-docs.md` and `reference/phase-8-quality.md`.

---

## Asset ownership and cleanup

Every generated technology folder must include an `asset-manifest.json` with
`managedBy: dynatrace-metric-device-dashboard-generator`, the event provider,
log source, dashboard IDs, this technology's *owned* OpenPipeline pipeline
setting ID, its routing entry's `description` (never the shared routing object's ID),
this technology's dedicated workflow ID and task names, logo document IDs, and
device type/prefix. Use this manifest as the primary cleanup record.

The OpenPipeline **routing** entry is one row inside a tenant-wide singleton — track it
by `description` in `resources.routingEntries` and remove only that entry on cleanup.
**Never `dtctl apply -f` a routing file directly** — always use `scripts/apply-openpipeline-routing.sh`.

**Use the reference template** — copy and adapt
`reference/zscaler-internet-access/asset-manifest.json` for every new technology.
Do NOT invent the schema from scratch; the validator enforces a specific shape
(`schemaVersion`, `workflow.id`, `entity.nodeType`, `resources.dashboard[]`, etc.)
that differs from earlier hand-written manifests in `dashboards/`.

Validate with `scripts/validate-asset-manifest.sh` before deployment.
→ See `reference/phase-6-workflow.md` for cleanup steps.

---

## Workflow duration

Default: 7-day expiry, 30-minute interval. Ask the user; `0` = unlimited. Each
technology has its own dedicated workflow — setting expiry for one never affects another.
→ See `reference/phase-6-workflow.md` for schedule YAML format and post-apply verification.

---

## Reference implementation

Use `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/`
as the canonical example for the complete asset lifecycle.

> **CRITICAL — read reference files in full, never truncated.** Structurally important
> sections (e.g. `layouts:`) can appear near the end of a file. A partial read has already
> caused a generated dashboard to render as a single stacked column. Re-read the remainder
> before proceeding if a tool truncates automatically.

---

## Prerequisites

1. **`dtctl`** installed and authenticated to a Dynatrace Gen 3 tenant.
   Verify with `dtctl auth whoami` or `scripts/check-prereqs.sh`. If missing or
   unauthenticated, **stop and tell the user** — do not install or configure it.
2. **`dtctl` agent skill** installed (`npx skills add dynatrace-oss/dtctl`).
3. **`dynatrace-for-ai` skills** installed (`npx skills add dynatrace/dynatrace-for-ai`).
4. **`jq`** for workflow JSON manipulation.
5. Network access to fetch the company logo URL.

---

## Tenant confirmation — REQUIRED before any tenant write

Before the agent runs **any** `dtctl apply`, `dtctl exec`, `dtctl create`,
`dtctl edit`, or `dtctl delete` command, it MUST:

1. Show the active context and identity to the user:
   ```bash
   dtctl ctx current
   dtctl auth whoami
   ```
   Display the tenant URL / environment, context name, and authenticated principal.
2. Ask the user to confirm this is the correct tenant before proceeding.
3. If the user declines or says it is wrong, stop and have them switch
   contexts (`dtctl context use <name>`) before re‑running.

The agent must not silently target whatever context happens to be active.
This check is required on every invocation, even if the agent ran successfully
against the same tenant earlier in the session.

---

## Inputs

**Confirm rule:** if the user already supplied a value (e.g. named the technology
in the prompt), display it as the proposed answer and ask "Is this correct?" before
moving on. Never silently use a value the user has not explicitly confirmed in this session.

| # | Input | Required? | Notes |
|---|-------|-----------|-------|
| 1 | **Technology** | Required | Folder name, dashboard title, and `event.provider` (e.g. `acme.event.provider`). |
| 2 | **Dynatrace Hub link** | Optional | e.g. `https://www.dynatrace.com/hub/detail/<technology>/`. If omitted, search the Hub yourself. |
| 3 | **Logo image or URL** | Optional | Local file path or public URL. If omitted, search the web and verify before using. |
| 4 | **Workflow duration in days** | Optional | Default `7`; use `0` for no expiry. |

**Log injector decision — research first, then decide:**

Before asking the user about logs, the agent must independently determine whether logs are warranted by researching the technology directly:

1. **Read the Hub page** (if provided or found) and look for log-related extensions, log sources, or access/audit references.
2. **Apply the archetype heuristic** (see `reference/phase-1-planning.md` — Log decision section).
3. **State your reasoning explicitly** in the pre-work summary: name the specific log sources the technology produces and why they belong on the dashboard.

Do NOT base this decision on what other technologies in this repository included or excluded. Every technology has its own log story and must be evaluated independently.

Present the log decision to the user with reasoning — not just yes/no — and let them override it.

→ Read `reference/inputs.md` for logo verification curl command, known CDN behaviors, and Document API upload steps.

### Pre-work input summary — REQUIRED before any generation

After all inputs are confirmed, display this table and wait for user confirmation before starting Phase 1:

```
| Input              | Value                                      |
|--------------------|--------------------------------------------|
| Technology         | <value>                                    |
| Hub / metrics link | <value or "none">                          |
| Logo               | <value or "none">                          |
| Workflow duration  | <N> days                                   |
| Log injector       | <yes / no — with one-line reason>          |
| Target tenant      | <tenant URL from dtctl context>            |
```

---

## Output layout

For every new technology create a folder under `dashboards/`:

```
dashboards/<Technology>/
  asset-manifest.json                         # generator ownership and tenant resource IDs
  <Technology>-dashboard-v1.json              # Gen 3 dashboard JSON
  <Technology>-injector.js                    # 30-min BizEvents metrics/logs injector
  <Technology>-device-creator.js              # Workflow task: MINT ingest to associate metrics with entities
  <Technology>-openpipeline.json              # OpenPipeline pipeline settings (smartscapeNode extraction)
  <Technology>-openpipeline-routing-entry.json  # ONE routing entry — never applied directly
  README.md                                   # overview, dashboard ID, workflow ID, device IDs
  LEARNINGS.md                                # DQL patterns, pitfalls, device creation findings
  SALES-PITCH.md                              # 1-page value pitch for sales teams
```

File naming: lower‑case company slug, hyphen‑separated. Versioned dashboards
are `*-dashboard-v2.json` — **never overwrite v1**.

---

## What the agent must NOT do

- Do not invent dashboard IDs, workflow IDs, or URLs — always use values returned by `dtctl`.
- Do not merge a technology's tasks into another technology's workflow, and do
  not create a second workflow for the same technology when one already exists — update it instead.
- Do not create a dashboard variable without `"defaultSelectAll": true` — dashboards must open showing all data.
- Do not add a map when geographic data is not meaningful; when included, validate its coordinates and rendering.
- Do not push commits or open PRs unless asked.
- Do not run destructive `dtctl delete` commands without explicit user confirmation.
- Do not attempt to install or configure `dtctl`.
