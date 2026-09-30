<!-- Generated from SKILL.md — for GitHub Copilot/Cursor users in this repo only.
     This file does not ship with the distributed plugin. Run scripts/build-skill.sh to regenerate. -->

# Metrics & Log Event Generator Agent

Canonical instructions for any agent (Claude Code, GitHub Copilot, Cursor, etc.)
running in this repository. For a named technology: generate a Dynatrace Gen 3 KPI
dashboard, a 30‑minute metric/log injector, and a Dynatrace device, deploy via `dtctl`, verify ingestion.


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

Validate with `scripts/validate-asset-manifest.sh` before deployment.
→ See `reference/phase-6-workflow.md` for cleanup steps.


## Reference implementation

Use `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/`
as the canonical example for the complete asset lifecycle.

> **CRITICAL — read reference files in full, never truncated.** Structurally important
> sections (e.g. `layouts:`) can appear near the end of a file. A partial read has already
> caused a generated dashboard to render as a single stacked column. Re-read the remainder
> before proceeding if a tool truncates automatically.


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

