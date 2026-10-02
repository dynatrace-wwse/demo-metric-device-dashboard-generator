---
description: Generate a Dynatrace Gen 3 metric dashboard, metric injector, and device/entity for a technology.
argument-hint: <Technology name> [dynatrace hub link] [industry] [logo-url] [duration-days]
---

Generate a Dynatrace Gen 3 metric dashboard, Smartscape entities (via OpenPipeline), and 30‑minute metric injector for the technology **$ARGUMENTS**.

Follow `skills/dynatrace-metric-device-dashboard-generator/SKILL.md` exactly (mirrored in `AGENTS.md`). It and its `reference/phase-*.md` files are canonical; if anything below seems to conflict, they win. In particular:

1. **Before doing anything else**, if the user has not provided the following items, ask for them explicitly — make clear each is optional and it's fine if they don't have them:
   - **Dynatrace Hub link** (e.g. `https://www.dynatrace.com/hub/detail/<technology>/`) — used to research official metric names and extensions. If not provided, search the Hub yourself.
   - **Logo image or URL** — used for the dashboard header image tile. If not provided, search the web for an official brand logo. If nothing reliable is found, use a text-only header.
   - **Workflow duration in days** — defaults to 7 for a demo; use 0 for no automatic expiry.
   Then make the log decision and show the pre-work input summary table from `SKILL.md`.
2. Verify `dtctl auth whoami` succeeds before doing anything else.
3. **Show the active `dtctl` context to the user** (`dtctl ctx current` + `dtctl auth whoami`) and get explicit confirmation that the tenant is correct before any `dtctl apply` or `dtctl exec`.
4. Use `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/` as the complete working reference
   for injector, optional logs, OpenPipeline, workflow, manifest, and live
   validation patterns. Adapt its schema to the requested technology; do not
   copy Zscaler-specific fields or assume every technology needs a map. Its
   dashboard YAML predates some rules — where it disagrees with the phase docs
   (threshold schema, units, logo tile), follow the phase docs.
5. Output goes into `dashboards/<technology>/`:
   - `asset-manifest.json` (copy the shape of the reference manifest)
   - `<technology>-dashboard-v1.json`
   - `<technology>-injector.js`, optional `<technology>-log-injector.js`
   - `<technology>-device-creator.js`
   - `<technology>-workflow.yaml`
   - `<technology>-openpipeline.json`
   - `<technology>-openpipeline-routing-entry.json` (one routing entry, never applied directly)
   - `<technology>-logo.png` + `upload-logo.sh`
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
   - `singleValue` thresholds go in `visualizationSettings.coloring.colorRules` with `customColor: { "Default": "#hex" }` and the Unicode `≥` comparator, **lowest threshold value first, highest last**. Dynatrace applies the last matching rule; wrong order makes all values show the wrong color.
   - `singleValue` `unitsOverrides`: always use `"unitCategory": "unspecified"` + `"baseUnit": "count"` for raw numeric KPIs (`percent`/`percent` is fine for percentages). `unitCategory: "time"` auto-scales display (1000ms → "1s") but colorRule thresholds compare against raw values, causing wrong colors.
   - Dashboard variables with `multiple: true` must include `"defaultSelectAll": true`.
8. Run the phase-5 checklist and the fresh-context reviewer (SKILL.md step 6.5) before deploying.
9. Deploy per `reference/phase-6-workflow.md`:
   - `dtctl apply` the dashboard JSON.
   - `dtctl apply` the OpenPipeline pipeline, then merge the routing entry with `scripts/apply-openpipeline-routing.sh` — **never** `dtctl apply -f` a routing file (the routing object is a tenant-wide singleton).
   - Each technology gets its **own** `<Technology> | Injector Workflow`. Create it from the reference workflow YAML on first run; if this technology's workflow already exists, add versioned tasks to it. Never add tasks to another technology's workflow.
   - Enforce the duration with the `EXPIRES_AT` guard in every task script — never `latestStart`/`latestStartTime`, which do not stop the schedule.
   - Write `asset-manifest.json` with the returned IDs and run `scripts/validate-asset-manifest.sh` on it.
10. `dtctl exec workflow <id>` and confirm SUCCESS (`dtctl get wfe-task-result <exec-id> -t <task>` for task output).
11. Verify ingest: BizEvents by `event.provider`, logs by `log.source` (if any), and MINT metrics with `timeseries avg(<technology>.<metric>), from:now()-1h`.
12. Verify entities: `dtctl query 'smartscapeNodes "CUSTOM_<TYPE>" | summarize count()' -o json --plain` (no `from:` — it is invalid in that position). Extraction can take 1–5 minutes.
13. Run `scripts/validate-dashboard-thresholds.sh <dashboard-id> "<exclude-regex>"`.
14. Report dashboard URL, workflow ID, and task names back to the user.
