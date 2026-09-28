---
description: Generate a Dynatrace Gen 3 metric dashboard, metric injector, and device/entity for a technology.
argument-hint: <Technology name> [dynatrace hub link] [industry] [logo-url] [duration-days]
---

Generate a Dynatrace Gen 3 metric dashboard, Smartscape entities (via OpenPipeline), and 30‑minute metric injector for the technology **$ARGUMENTS**.

Follow `AGENTS.md` in this repository exactly. In particular:

1. **Before doing anything else**, if the user has not provided the following items, ask for them explicitly — make clear each is optional and it's fine if they don't have them:
   - **Dynatrace Hub link** (e.g. `https://www.dynatrace.com/hub/detail/<technology>/`) — used to research official metric names and extensions. If not provided, search the Hub yourself.
   - **Logo image or URL** — used for the dashboard header image tile. If not provided, search the web for an official brand logo. If nothing reliable is found, use a text-only header.
   - **Workflow duration in days** — defaults to 7 for a demo; use 0 for no automatic expiry.
2. Verify `dtctl auth whoami` succeeds before doing anything else.
3. **Show the active `dtctl` context to the user** (`dtctl ctx current` + `dtctl auth whoami`) and get explicit confirmation that the tenant is correct before any `dtctl apply` or `dtctl exec`.
4. Mirror the structure of files in `.example/`.
5. Use `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/` as the complete working reference
   for dashboard, injector, optional logs, OpenPipeline, workflow, and live
   validation patterns. Adapt its schema to the requested technology; do not
   copy Zscaler-specific fields or assume every technology needs a map.
6. Output goes into `dashboards/<Technology>/`:
   - `<technology>-dashboard-v1.json`
   - `<technology>-injector.js`
   - `<technology>-device-creator.js`
   - `<technology>-openpipeline.json`
   - `<technology>-openpipeline-routing.json`
   - `<technology>-logo.png` + `<technology>-logo.yaml` + `upload-logo.sh`
   - `README.md`, `LEARNINGS.md`, `SALES-PITCH.md`
6. The dashboard logo tile uses `type: image` (not markdown). Upload the logo first using `upload-logo.sh` from `scripts/` (copy it into the technology folder). The script uses `dtctl exec function` with FormData/Blob — **do NOT use `dtctl apply` with `!!binary` YAML**, which does not correctly transmit binary content and results in a broken image:
   ```bash
   curl -sL "<logo-url>" -o <technology>-logo.png
   bash upload-logo.sh <technology>-logo.png <technology>-logo "Technology Logo"
   ```
   Then reference it in the dashboard tile:
   ```json
   { "type": "image", "imageSettings": { "defaultSource": "/platform/document/v1/documents/<technology>-logo/content", "sizing": "fit", "horizontalAlignment": "center", "verticalAlignment": "center" } }
   ```
7. The dashboard may contain a `bubbleMap` map tile, section dividers, KPI tiles (`h:2`), and charts (`h:4`+).
   - `bubbleMap`: always set `"regions": { "showRegions": false }` — never specify region codes.
   - `singleValue` `≥` color rules: **lowest threshold value first, highest last**. Dynatrace applies the last matching rule; wrong order makes all values show the wrong color.
   - `singleValue` `unitsOverrides`: always use `"unitCategory": "unspecified"` + `"baseUnit": "count"` for raw numeric KPIs. `unitCategory: "time"` auto-scales display (1000ms → "1s") but colorRule thresholds compare against raw values, causing wrong colors.
   - Dashboard variables with `multiple: true` must include `"defaultSelectAll": true`.
8. `dtctl apply` the dashboard JSON.
9. `dtctl apply` the OpenPipeline settings before running the workflow.
10. Look up the existing injector workflow with
   `dtctl get workflows -o json --plain | jq '.[] | select(.title | test("Metrics Dashboard Generator|injector"; "i"))'`.
   - If found: append new tasks `<technology>_v1` and `<technology>_entities_v1` and `dtctl apply` the workflow.
   - If not found: create from `.example/example_data_injector.workflow.json`. Never create a second injector workflow.
11. `dtctl exec workflow <id>` and confirm SUCCESS.
12. Verify MINT metric ingest: `timeseries avg(<technology>.<primary_metric>), from: now()-5m`.
13. Verify entities: `dtctl query "smartscapeNodes \"CUSTOM_<TYPE>\", from:now()-1h | limit 20" --plain`.
14. Report dashboard URL, workflow ID, and task names back to the user.
