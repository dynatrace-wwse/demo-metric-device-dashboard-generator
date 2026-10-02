---
mode: agent
description: Generate a Dynatrace Gen 3 metric dashboard, metric injector, and device/entity for a technology.
---

You are operating in the **Metric Event Generator** repository. Follow the
instructions in [AGENTS.md](../../AGENTS.md) exactly.

Inputs you need from the user — **ask for these explicitly before starting** if not already provided. All are optional; never block on a missing item:

- **Technology name** (required)
- **Dynatrace Hub link** — e.g. `https://www.dynatrace.com/hub/detail/<technology>/`. If not provided, search the Hub yourself at https://www.dynatrace.com/hub/.
- **Logo image or URL** — used for the dashboard header image tile. If not provided, search the web for an official brand logo. If nothing reliable is found, use a text-only markdown header — do not block.
- **Workflow duration in days** (optional; defaults to `7`, or use `0` for no automatic expiry)

Then:

1. Run `dtctl auth whoami` to confirm tenant access.
2. **Display the active `dtctl` context** (`dtctl ctx current` + `dtctl auth whoami`) and ask the user to confirm the tenant before applying or executing anything.
3. Research relevant metrics for the technology.
4. Create `dashboards/<technology>/` with these files — using `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/` as the structural template:
   - `asset-manifest.json`
   - `<technology>-dashboard-v1.json`
   - `<technology>-injector.js`, optional `<technology>-log-injector.js`
   - `<technology>-device-creator.js`
   - `<technology>-workflow.yaml`
   - `<technology>-openpipeline.json`
   - `<technology>-openpipeline-routing-entry.json`
   - `README.md`, `LEARNINGS.md`, `SALES-PITCH.md`
5. The dashboard may include a `bubbleMap` tile fed by geo coordinates from the injector.
   - `bubbleMap`: always set `"regions": { "showRegions": false }` — never specify region codes; they cause "Failed to load map data".
   - `singleValue` thresholds go in `visualizationSettings.coloring.colorRules` (`customColor: { "Default": "#hex" }`, Unicode `≥`), **lowest threshold value first, highest last**. Dynatrace applies the last matching rule; wrong order makes all values show the wrong color.
   - `singleValue` `unitsOverrides`: always use `"unitCategory": "unspecified"` + `"baseUnit": "count"` for raw numeric values. Never use `unitCategory: "time"` — it auto-scales display (1000ms → "1s") but colorRule thresholds compare against raw values, causing wrong colors.
   - Query variables with `multiple: true` must include `"defaultSelectAll": true` so the dashboard opens with all values selected.
   - Logo tile uses `type: image` (not markdown). Upload with `bash upload-logo.sh <file> <id> "<desc>"` then reference `/platform/document/v1/documents/<id>/content` in `imageSettings.defaultSource`.
6. `dtctl apply` the dashboard.
7. `dtctl apply` the OpenPipeline pipeline, then merge the routing entry with `scripts/apply-openpipeline-routing.sh` — never `dtctl apply -f` a routing file (it is a tenant-wide singleton).
8. Create this technology's own `<Technology> | Injector Workflow` (or add versioned tasks to its existing one — never to another technology's workflow). Enforce duration with the `EXPIRES_AT` guard in every task, never `latestStart`. Write and validate `asset-manifest.json`, then `dtctl exec workflow`.
9. Verify MINT metric ingest: `timeseries avg(<technology>.<metric>), from:now()-1h`.
10. Verify entities: `dtctl query 'smartscapeNodes "CUSTOM_<TYPE>" | summarize count()' -o json --plain` (no `from:` — invalid in that position).
11. Report the dashboard URL, workflow ID, and task names back to the user.
