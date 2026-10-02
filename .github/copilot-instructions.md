# GitHub Copilot Instructions — Metric-Device Dashboard Generator

This repository is an **agent**: it generates a Dynatrace Gen 3 metric dashboard, metric injector, OpenPipeline device pipeline, and Smartscape device topology for a technology a user names.

> **Read [AGENTS.md](../AGENTS.md) first.** It is the canonical instruction
> set. The notes below are Copilot‑specific reinforcement.

## When the user says "generate a dashboard for <technology>"

1. Confirm `dtctl auth whoami` works. If not, stop and ask the user to run `scripts/check-prereqs.sh`.
2. **Show the active tenant context** (`dtctl ctx current` + `dtctl auth whoami`) and ask the user to confirm before any `apply`/`exec`. Never silently target whatever context is active.
3. Ask how many days the scheduled workflow should run. Default to 7 days for a demo; use 0 for no automatic expiry. Enforce it with an `EXPIRES_AT` guard in every task script — never `latestStart`/`latestStartTime`, which do not stop the schedule (see `skills/dynatrace-metric-device-dashboard-generator/reference/phase-6-workflow.md`).
4. Create `dashboards/<Technology>/` with these files:
   - `<technology>-dashboard-v1.json`
   - `<technology>-injector.js`
   - `<technology>-device-creator.js`
   - `<technology>-openpipeline.json`
   - `<technology>-openpipeline-routing.json`
   - `README.md`, `LEARNINGS.md`, `SALES-PITCH.md`
4. Apply the OpenPipeline settings with `dtctl apply` before running the workflow — entities are created by the pipeline as MINT metrics arrive.
5. Mirror the shape of files in `.example/`.

## Hard rules

- **Gen 3 dashboard JSON only** — match `.example/example_dashboard.json`.
- **Map tile is optional** — `bubbleMap` over geo coordinates emitted by the injector.
- **`bubbleMap` regions** — always set `"regions": { "showRegions": false }`. Never specify region codes; mixed/unknown codes cause "Failed to load map data". The map auto-fits to data points.
- **Inputs — ask upfront if not provided** (all optional, never block): Dynatrace Hub link (`https://www.dynatrace.com/hub/detail/<technology>/`) and logo image/URL. If hub link missing, search the Hub. If logo missing, search the web; fall back to text-only header.
- **Logo + Title** are TWO tiles: `type: image` (`w:6,h:2`) + markdown title (`w:18,h:2`). Upload logo via `bash upload-logo.sh <file> <id> "<desc>"` (no Python — uses `base64`, `fold`, `dtctl apply`), then set `imageSettings.defaultSource: "/platform/document/v1/documents/<id>/content"`.
- **Tile types**: `data` (DQL), `markdown` (text/images), `code` (Dynatrace Functions JS — useful for USQL/metric selectors/external APIs), `image` (native image tile — `imageSettings.defaultSource: "/platform/document/v1/documents/<id>/content"`; sizing: `"fit"` or `"fill"`; image must be uploaded to Dynatrace Documents API first).
- **Charts use `h:4`+, KPIs use `h:2`.**
- **`singleValue` `≥` color rules** — lowest threshold first, highest threshold last. Dynatrace applies the last matching rule; reversing the order causes all values to show the wrong color.
- **`singleValue` `unitsOverrides`** — use `"unitCategory": "unspecified"` + `"baseUnit": "count"` for raw numeric values. `unitCategory: "time"` auto-scales display (1000ms → "1s") but compares colorRule thresholds against raw values → wrong colors. Omitting it with `delimiter: true` abbreviates numbers (1000 → "1k").
- **Dashboard variables** — all query variables with `multiple: true` must include `"defaultSelectAll": true` so the dashboard opens showing all data instead of pre-selecting the first query result.
- **Time charts use `makeTimeseries`** — never `summarize` into a chart.
- All queries filter by `event.provider == "<technology>.event.provider"`.
- Injector emits 3,000–5,000 events/run, batched in 500‑event POSTs.
- **Devices via OpenPipeline only on Gen 3 tenants** — classic device APIs unavailable. `CUSTOM_DEVICE` nodeType is blocked; use `CUSTOM_<TECHNOLOGY>_<DEVICE>`.
- **MINT line format** — commas as dimension separators, NOT semicolons: `metric.key,dim1=val1 value ts`.
- **Device visibility** — OpenPipeline devices appear in Explorer Classic only, not Explorer New.

## Reference implementation and adaptation

Use `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/` as the working example for the
complete lifecycle: dashboard, MINT metrics, optional logs, OpenPipeline device
extraction, its dedicated workflow, and live validation. Copy its structure,
not its domain schema. Before generating, classify the technology as a
device/network, runtime platform, database, application/service, business
system, or security/control-plane use case and design the device, KPIs, event
types, logs, and map decision for that archetype.

## Workflow rule (do not violate)

There is **one injector workflow per tenant**. Always look for it first:

```bash
dtctl get workflows -o json --plain | \
  jq '.[] | select(.title | test("Technology Dashboard Generator|injector"; "i"))'
```

- **Found?** Add a new task `<technology>_v1` to it and `dtctl apply -f`.
- **Not found?** (first‑ever run on this tenant) create from
  `.example/example_data_injector.workflow.json`.

Never create a second injector workflow.

## Tools / skills to prefer

- `dtctl` for all Dynatrace operations.
- `dt-app-dashboards`, `dt-dql-essentials`, `dt-app-notebooks`, `dtctl` skills
  if available in the agent runtime.
