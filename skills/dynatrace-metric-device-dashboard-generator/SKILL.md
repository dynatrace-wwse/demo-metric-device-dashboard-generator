---
name: dynatrace-metric-device-dashboard-generator
description: Generate a Dynatrace Gen 3 **KPI dashboard** (15–20 KPIs, optional map tile, branded section dividers), a relevant dynatrace device to map metrics and logs to and a matching 30‑minute data injector for a named technology, then deploy both via `dtctl`. Do not use this skill if a user is triggering the generate-kpi-dashboard generator. Triggers include phrases like "generate a metric dashboard", "build a metrics demo for <technology>", "spin up a metrics dashboard + injector", "/generate-technology-dashboard". Requires `dtctl` authenticated to a Dynatrace Gen 3 tenant.
---

# Metrics & Log Event Generator Agent

Canonical instructions for any agent (Claude Code, GitHub Copilot, Cursor,
etc.) running in this repository. The agent's job: for any technology the user
names, generate a Dynatrace **Gen 3 KPI dashboard** and a **30‑minute
metric and log (if logs are applicable) injector**, and create a dynatrace device the metrics and logs are associated with, deploy them with `dtctl`, and verify ingestion.

---

## Role & Objective

You are a Dynatrace Solutions Engineer. For a given technology:

0. **Always gather inputs before starting — ask all four questions every time.**
   If the user already provided an answer in their prompt, show the value and
   ask them to confirm before proceeding. Do not skip any question even if an
   answer appears obvious from context.

   | # | Input | Required? | Notes |
   |---|-------|-----------|-------|
   | 1 | **Technology** | Required | The technology to build assets for (e.g. Zscaler, NVIDIA DCGM, CrowdStrike). |
   | 2 | **Customer name** | Optional | A specific customer to tailor the dashboard and sales pitch for. If omitted, assets are generic to the technology. |
   | 3 | **Dynatrace Hub or technology metrics link** | Optional | e.g. `https://www.dynatrace.com/hub/detail/<technology>/`. Used to research extensions and official metric names. If omitted, search https://www.dynatrace.com/hub/ yourself. |
   | 4 | **Logo image** | Optional | A local file path or public URL for the technology or customer logo. If omitted, search the web for an official brand logo URL and verify it (see Logo section below). If nothing reliable is found, use a text-only markdown header — never block on a missing logo. |

   After all four questions are answered (or confirmed), also ask:
   - **Workflow duration in days** — how many days the scheduled injector should
     run. Default to `7` for a generated demo; use `0` for no automatic expiry.

   **Confirm rule:** if the user already supplied a value (e.g. named the
   technology in the prompt), display it as the proposed answer and ask
   "Is this correct?" before moving on. Never silently use a value the user
   has not explicitly confirmed in this session.
1. Research technology KPIs relevant to the technology provided (15–20).
2. Include a search of the dynatrace hub - https://www.dynatrace.com/hub/ - for any pre-configured extensions, technology, or application information.
3. Build a **Gen 3 dashboard** with real‑time KPI tiles, charts, and if applicable, a map tile. The metrics used should be the most relevant for the technology, based on research.
4. Create a Dynatrace device to map metrics and logs to.
5. Create a JavaScript injector that streams 3,000–5,000 metric events per
   30‑minute run, and if applicable, 2000 log entries per run.
6. Deploy both to Dynatrace via `dtctl`, creating **a dedicated workflow for
   this technology** (never merging tasks for different technologies into the
   same workflow — each technology's schedule and expiration must stay
   independent).
7. Document patterns in the technology folder for reuse.

### Asset ownership and cleanup

Every generated technology folder must include an `asset-manifest.json` with
`managedBy: dynatrace-metric-device-dashboard-generator`, the event provider,
log source, dashboard IDs, this technology's *owned* OpenPipeline pipeline
setting ID, its routing entry's `description` (see below — never store or
treat the shared routing object's ID as owned by one technology), this
technology's dedicated workflow ID and task names, logo document IDs, and
device type/prefix. Use this manifest as the primary cleanup record; do not
infer ownership from a dashboard title alone.

The OpenPipeline pipeline setting is owned exclusively by this technology and
is safe to delete outright. The OpenPipeline **routing** entry is not — it is
one row inside a tenant-wide singleton object shared by every technology and
every hand-built demo route (see Phase 4's CRITICAL note). Track it in the
manifest under `resources.routingEntries` (by `description`, not object ID),
and clean it up by removing just that entry, never the shared object.

Validate it with `scripts/validate-asset-manifest.sh` before deployment. A
generated pack is not cleanup-ready until the manifest passes validation.
Run `scripts/test-asset-manifest.sh` when changing the manifest schema or
cleanup behavior.

The cleanup operation must default to discovery or dry-run. It must display
the active tenant, require typed technology confirmation before deletion,
delete that technology's dedicated workflow and pipeline setting entirely
(neither is shared), and remove only this technology's entry from the shared
OpenPipeline routing object — never delete that object itself. Historical
BizEvents and logs are retained; Smartscape entities may require
tenant-supported lifecycle handling and must not be reported as deleted
without verification.

### Workflow duration

Every generated workflow runs on a 30-minute interval. Unless the user asks
for a different value, set the schedule to expire after 7 days. Calculate the
expiration from the workflow start date in the requested tenant timezone and
write the resulting end date/time into the schedule filter parameters:

```yaml
trigger:
  schedule:
    filterParameters:
      earliestStart: "2026-08-20"
      earliestStartTime: "00:00"
      latestStart: "2026-08-27"
      latestStartTime: "00:00"
```

The interval remains `30` minutes. `0` means omit the end parameters and leave
the workflow running indefinitely. Each technology has its own dedicated
workflow, so its schedule and expiration are independent — setting or
changing this technology's duration never affects any other technology.

After applying a finite-duration workflow, read it back with `dtctl get
workflow` and verify that the persisted schedule contains the intended end
date. If the tenant rejects the end parameters, stop and report that native
schedule expiry is unavailable in that tenant rather than silently deploying
an unlimited workflow.

## Reference implementation: Zscaler Internet Access

Use `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/` as the primary working example for
the complete asset lifecycle. It demonstrates a Gen 3 dashboard, BizEvents
injector, optional synthetic logs, OpenPipeline Smartscape extraction, a
dedicated multi-task workflow, threshold persistence validation, and live
ingestion checks.

Treat Zscaler's fields and event names as technology-specific. Reuse its
structure and validation approach, but redesign the event schema, device type,
KPIs, logs, and layout for the requested technology.

### Technology archetypes

Classify the requested technology before choosing the asset model:

| Archetype | Typical device | Useful signals | Map guidance |
|---|---|---|---|
| Network/device | device, interface, site | availability, errors, throughput, capacity, state | Use for sites or geographic device fleets |
| Runtime platform | cluster, node, process group | CPU, memory, latency, restarts, queue depth, saturation | Use only when nodes or regions matter |
| Database/data platform | database, shard, replica | query latency, connections, locks, replication lag, storage | Usually omit unless instances are geographically distributed |
| Application/service | service, endpoint, workload | rate, errors, duration, dependencies, user impact | Use for service locations or deployment regions |
| Business system | store, venue, account, transaction stream | volume, conversion, revenue, fulfillment, customer impact | Use when location is part of the business model |
| Security/control plane | policy engine, gateway, tenant, site | detections, blocks, risk, policy outcomes, audit activity | Use for sites, regions, or trust boundaries |

The archetype is a design aid, not a restriction. If the technology spans
multiple archetypes, state which device is primary and which signals are
supporting evidence.

---

## Prerequisites

1. **`dtctl`** installed and authenticated to a Dynatrace Gen 3 tenant.
   Verify with `dtctl auth whoami` or `scripts/check-prereqs.sh`. If `dtctl` is
   missing or unauthenticated, **stop and tell the user** — do not try to
   install or configure it. (macOS/Linux can run `scripts/install.sh`;
   Windows users follow https://github.com/dynatrace-oss/dtctl#install.)
2. **`dtctl` agent skill** installed
   (`npx skills add dynatrace-oss/dtctl`) — the agent uses it to operate
   `dtctl` correctly.
3. **`dynatrace-for-ai` skills** installed
   (`npx skills add dynatrace/dynatrace-for-ai`) — supplies
   `dt-dql-essentials`, `dt-app-dashboards`, `dt-app-notebooks`, and the
   `dt-obs-*` domain skills the agent leans on.
4. **`jq`** for workflow JSON manipulation.
5. Network access to fetch the company logo URL.

---

## Tenant confirmation — REQUIRED before any tenant write

Before the agent runs **any** `dtctl apply`, `dtctl exec`, `dtctl create`,
`dtctl edit`, or `dtctl delete` command (anything that mutates the tenant or
executes a workflow), it MUST:

1. Show the active context and iddevice to the user, e.g.:
   ```bash
   dtctl ctx current
   dtctl auth whoami
   ```
   Display the tenant URL / environment, context name, and authenticated
   principal.
2. Ask the user to confirm this is the correct tenant before proceeding.
3. If the user declines or says it is wrong, stop and have them switch
   contexts (`dtctl context use <name>`) before re‑running.

The agent must not silently target whatever context happens to be active.
This check is required on every invocation, even if the agent ran
successfully against the same tenant earlier in the session.

---

## Inputs the agent collects

The agent always asks all four questions on every invocation — even if the user
already supplied an answer. Pre-supplied answers are confirmed, not silently
accepted.

- **Technology** (required) — used for folder name, dashboard title, and
  `event.provider` (e.g. `acme.event.provider`).
- **Customer name** (optional) — when provided, prepend to the dashboard title
  (`<Customer> | <Technology> Operations Dashboard`), tailor `SALES-PITCH.md`
  to that customer, and name the folder `<technology>` (customer context lives
  in the docs, not the folder name).
- **Dynatrace Hub or technology metrics link** (optional) — research hint for
  metrics and extensions. If omitted, search https://www.dynatrace.com/hub/ directly.
- **Logo image** (optional) — a local file path or public URL. If omitted,
  search the web for an official brand logo URL and confirm before using it.

### Pre-work input summary — REQUIRED before any generation

After all inputs are confirmed, display a summary table before starting any
research or file generation:

```
| Input              | Value                                      |
|--------------------|--------------------------------------------|
| Technology         | <value>                                    |
| Customer           | <value or "none">                          |
| Hub / metrics link | <value or "none">                          |
| Logo               | <value or "none">                          |
| Workflow duration  | <N> days                                   |
| Target tenant      | <tenant URL from dtctl context>            |
```

Ask the user to confirm this summary before proceeding. Do not start Phase 1
until the user confirms.

---

## How to use each input

### Customer name

When a customer name is provided:

1. **Research the customer.** Search the web for information about how the
   customer uses or is known to use the named technology. Look for:
   - Scale indicators (fleet size, geography, transaction volume).
   - Business model details that suggest which KPIs matter most (e.g. a
     GPU-rental company cares about utilization % and billing accuracy; a
     retailer cares about checkout latency and inventory sync).
   - Any public case studies, press releases, or product pages that reveal
     operational priorities.
2. Use that research to weight KPI selection and set realistic value ranges
   in the injector. Document the sources and rationale in `LEARNINGS.md`.
3. Tailor `SALES-PITCH.md` to the customer's business context — reference
   their industry, scale, and use case.

### Dynatrace Hub extension link

When the user provides a link to a Dynatrace Hub extension page:

1. Fetch and read the page.
2. If the page **lists specific metric names or metric keys**, use **only
   those metrics** on the dashboard and in the injector. Do not invent or
   supplement with metrics not listed on the page.
3. If the page **mentions logs** (log ingest, log processing, log events),
   treat log generation as **required**, not optional. Include a log injector
   and log-based tiles on the dashboard.
4. Note the extension version, metric descriptions, and any dimension/field
   names the extension documents — use them verbatim in the event schema.

### Non-Dynatrace Hub technology link

When the user provides a link to a technology vendor page, docs site, or any
non-Hub URL:

1. Fetch and read the page.
2. Extract any metric names, counters, dimensions, or observable signals
   described.
3. From those, choose the subset most relevant for operational monitoring
   (performance, reliability, capacity, errors). Document the selection
   rationale in `LEARNINGS.md`.
4. If the page mentions logs, treat log generation as required.
5. Do not use metrics not derivable from the linked page or the Hub search.

### Logo URL — VERIFY BEFORE EMBEDDING

### Logo embedding

**Use the `image` tile type — confirmed schema:**
```json
{
  "type": "image",
  "imageSettings": {
    "defaultSource": "/platform/document/v1/documents/<document-id>/content",
    "sizing": "fit",
    "horizontalAlignment": "center",
    "verticalAlignment": "center"
  }
}
```

Images are stored as Dynatrace Documents (`type: image`). They **must** be uploaded
via `dtctl exec function` using a JavaScript `FormData` + `Blob` multipart request.

**DO NOT use `dtctl apply` with `!!binary` YAML** — this does not correctly transmit
binary content to the Document API. It creates the document record but the image
payload is lost, resulting in a broken/unrenderable image tile.

**To upload a logo — use `upload-logo.sh`:**

```bash
# Download the logo first
curl -sL "<logo-url>" -o <technology>-logo.png

# Upload to Dynatrace Document Store via dtctl exec function
bash upload-logo.sh <technology>-logo.png <technology>-logo "Technology Dashboard Logo"
# e.g.
bash upload-logo.sh nvidia-logo.png nvidia-dcgm-logo "NVIDIA DCGM Dashboard Logo"
```

`upload-logo.sh` uses `dtctl exec function` with an inline JS script that:
1. Checks whether the document already exists (`GET /metadata`).
2. If it exists: updates content via `PUT /documents/{id}/content?optimistic-locking-version=<n>`.
3. If it doesn't exist: creates the document via `POST /documents` (JSON metadata), then uploads content via `PUT`.

The script handles both create and update, and is idempotent — safe to re-run.

Copy `upload-logo.sh` from `scripts/` into each `dashboards/<Technology>/` folder.

`sizing`: `"fit"` (letterbox, preserves aspect ratio) or `"fill"` (crops to fill tile).
Document ID convention: `<technology>-logo` (e.g. `nvidia-dcgm-logo`).

---

Never embed a logo via URL without first confirming the URL serves an image to a
cross-origin browser. Run:

```bash
curl -sIL -A 'Mozilla/5.0' -H 'Referer: https://apps.dynatrace.com' '<URL>' \
  | grep -E '^(HTTP|content-type)'
```

Required: final `HTTP/2 200` AND `content-type: image/(png|svg+xml|jpeg|webp)`.
If the response is `400`, `403`, `404`, or `text/html`, the logo will
render as a broken image in the markdown tile.

Known behavior:
- `upload.wikimedia.org/wikipedia/commons/...` — files frequently get
  renamed (e.g. `Walmart_logo.svg` → `Walmart logo (2008).svg` on a
  hashed path). Plain hot-links return `400` from Varnish for non-wiki
  referers. Resolve current URL via the Commons API:
  `https://commons.wikimedia.org/w/api.php?action=query&titles=File:<Name>.svg&prop=imageinfo&iiprop=url&format=json`.
- `1000logos.net` and `logos-world.net` — allow hot-linking, return
  `image/png`. Reliable fallback for major brands.
- `www.vectorlogo.zone/logos/<vendor>/<vendor>-ar21.svg` — reliable SVG source
  for networking/enterprise vendors (Cisco, Juniper, Palo Alto, etc.) that lack
  good PNG sources. Returns `image/svg+xml`. Use as fallback when the above fail.
- Corporate `*.com` CDNs (e.g. `i5.walmartimages.com`,
  `corporate.<brand>.com`) — usually unstable; require auth or rotate.
  Avoid unless verified.

If no working URL is found after 2–3 candidates, ask the user for one
instead of guessing.

---

## Output layout

For every new technology create a folder under `dashboards/`:

```
dashboards/<Technology>/
  asset-manifest.json                    # generator ownership and tenant resource IDs
  <Technology>-dashboard-v1.json          # Gen 3 dashboard JSON
  <Technology>-injector.js               # 30-min BizEvents metrics/logs injector
  <Technology>-device-creator.js         # Workflow task: MINT ingest to associate metrics with entities
  <Technology>-openpipeline.json         # OpenPipeline pipeline settings (smartscapeNode extraction)
  <Technology>-openpipeline-routing-entry.json # ONE routing entry — never applied directly, only via scripts/apply-openpipeline-routing.sh (see CRITICAL note in "Create Dynatrace entities")
  README.md                              # overview, dashboard ID, workflow ID, device IDs
  LEARNINGS.md                           # DQL patterns, pitfalls, device creation findings
  SALES-PITCH.md                         # 1-page value pitch for sales teams
```

File naming: lower‑case company slug, hyphen‑separated. Versioned dashboards
are `*-dashboard-v2.json` — **never overwrite v1**. In‑workflow task names
mirror the version (e.g. `acme_v1`, `acme_v2`).

---

## Reference assets (read these before generating)

- `reference/zscaler-internet-access/zscaler-internet-access-dashboard-v1.yaml` — Gen 3 dashboard shape: tiles, layouts, variables, map tile, section dividers, category overrides.
- `reference/zscaler-internet-access/zscaler-internet-access-workflow.yaml` — Workflow + JS task shape (schedule, ownerType, action type, position).
- `reference/zscaler-internet-access/zscaler-internet-access-injector.js` — Realistic injector JS template: event helpers, batched ingest, cluster/region weights, geo coords, schema conventions.
- `reference/zscaler-internet-access/zscaler-internet-access-log-injector.js` — Log injector JS template, when the technology warrants one.
- `reference/zscaler-internet-access/zscaler-internet-access-device-creator.js` — Workflow task JS that MINT-ingests entities from BizEvents.
- `reference/zscaler-internet-access/zscaler-internet-access-openpipeline.yaml` — OpenPipeline pipeline settings for Smartscape device extraction (safe to `dtctl apply -f` directly — this schema is multi-object).
- `reference/zscaler-internet-access/zscaler-internet-access-openpipeline-routing-entry.json` — the single routing entry shape expected by `scripts/apply-openpipeline-routing.sh`. This is a *fragment*, not a full settings document — never `dtctl apply -f` it directly (see CRITICAL note in "Create Dynatrace entities").

The agent must **mirror the structure** of these examples.

> **CRITICAL — read reference files in full, never truncated.** These files
> run several hundred lines, and structurally important sections (e.g. the
> `layouts:` mapping) can appear near the end. If your read tool supports a
> line-count cap (`limit`, `maxLines`, or similar), do not set one for these
> files — a partial read has already caused a generated dashboard to come out
> as a single stacked column because the agent never reached the `layouts:`
> section. If a tool truncates automatically, re-read the remainder before
> proceeding — do not generate output from a partial read.

---

## Phase 1 — Planning & Research

Identify primary use cases, common problem, and important metrics. For each, define:

- KPIs (CPU, threads, queue, throttling, etc).
- Event types that map to those KPIs (latency, state changes, service
  requests, telemetry).
- Realistic per‑run volume targets (15–20 event types totaling
  3,000–5,000 events per 30‑minute run).

---

## Phase 2 — Dashboard design (Gen 3 only)

### Header — required split layout

Two side‑by‑side markdown tiles (NOT one combined tile, NOT HTML):

```yaml
tiles:
  "0":  # Logo tile
    type: markdown
    content: "![](https://.../logo.svg)"
  "1":  # Title tile
    type: markdown
    content: "# <Technology> | Operations Dashboard\n\nReal-time KPI monitoring..."
layouts:
  "0":
    x: 0
    "y": 0
    w: 6
    h: 2
  "1":
    x: 6
    "y": 0
    w: 18
    h: 2
```

> **CRITICAL — layout format:** Tile positions are defined in a **separate `layouts:` mapping** at the `content` level — they are NOT embedded inside the tile object itself. `layouts` is a sibling of `tiles`, not a child. Embedding `layout: {x,y,w,h}` inside a tile is silently ignored; the dashboard renders with all tiles stacked in a default grid.

Markdown tiles do not reliably support `<div>`, `<img>`, or other inline
HTML. Use pure markdown image syntax (`![](url)`).

### Section dividers

Use a `singleValue` data tile with `data record(section="...")`, height
`h:1`, full width `w:24`, distinct brand‑appropriate background color per
section.

Suggested palette (override per technology/company brand):
- network: `#D4AF37` (Gold)
- service technology: `#1E90FF` (Blue)
- database: `#FF6347` (Tomato Red)
- AI: `#9B59B6` (Purple)
- Operations/Facilities: `#34495E` (Slate)
- virtualization: `#DAA520` (Dark Gold)

Example divider:

```json
{
  "type": "data",
  "title": "SECTION NAME",
  "query": "data record(section=\"Name\")",
  "visualization": "singleValue",
  "visualizationSettings": {
    "singleValue": {
      "labelMode": "none",
      "isIconVisible": true,
      "prefixIcon": "GridIcon",
      "colorThresholdTarget": "background"
    },
    "thresholds": [
      { "id": 1, "field": "section", "title": "", "isEnabled": true, "rules": [
        { "id": 1, "color": { "Default": "#D4AF37" }, "comparator": "!=", "label": "", "value": "1" }
      ]}
    ]
  }
}
```

> **CRITICAL — threshold color format:** Colors in threshold rules must use the object form `{ "Default": "#hex" }`, **not** a bare hex string `"#hex"`. A bare string is silently accepted but does not apply correctly. This applies to every `color` field inside every threshold rule across all tile types.

### Tile height guidelines

| Height | Use case | Examples |
|--------|----------|----------|
| `h:1` | Section dividers, sparse info | Section headers |
| `h:2` | Single‑value KPIs | Revenue totals, occupancy %, counts |
| `h:3` | Small charts | 2–3 category bar charts |
| `h:4` | **Standard charts (recommended)** | Line, bar, area, donut |
| `h:5+` | Dense tables / multi‑series | Summary tables, complex analyses |

**Rule:** chart tiles need `h:4` minimum. `h:2`–`h:3` truncates legends and
labels.

### Layout & spacing

Minimize vertical gaps for a professional appearance:

- Y‑axis increments: `+1` to `+2` units between rows (not `+3+`).
- Pattern: divider (`h:1`) → KPI row (`h:2`) → chart row (`h:4`) → next
  divider.
- Consistent X columns: `0, 6, 12, 18` (board width is 24).
- Example flow:
  ```
  y:0   header (h:2)
  y:2   divider (h:1)
  y:3   KPI row (h:2)
  y:5   chart row (h:4)
  y:9   next divider (h:1)
  ```

### Map tile — OPTIONAL, WHEN GEOGRAPHICALLY MEANINGFUL

Include a map tile only when the technology has meaningful geographic,
regional, site, store, cluster, or location data that helps the operator make
a decision. Do not add a decorative map or invent coordinates just to satisfy
the template. When appropriate, use a `bubbleMap`,
`dotMap`, `connectionMap`, or `chloropleth` tile, fed by an event type
that emits `geo.location.latitude` and `geo.location.longitude` (cluster,
region, site, or store). The injector must populate these fields for at
least one event type. See the reference dashboard for the tile shape.

When included, place the map immediately under the header when geographic
context is central to the dashboard — full width (`w:24`, `h:8`) at `y:2`,
before the executive summary. Otherwise place it in the most useful section
for the technology. When inserting, bump every following tile's `y` by
exactly the map height; collisions silently break the layout.

**`regions` config — always set `showRegions: false`:**
```json
"regions": { "showRegions": false }
```
Never specify region codes (`"US"`, `"WORLD"`, etc.). Mixed or unknown codes
cause "an error occured: Failed to load map data". With `showRegions: false`
the map auto-fits to the data points regardless of geography.

### Gen 3 tile types

There are three **tile types** (`"type"` field in the tile object):

| Tile type | Purpose | Key fields |
|-----------|---------|-----------|
| `data` | DQL-powered visualization | `query`, `visualization`, `visualizationSettings`, `davis` |
| `markdown` | Text, headers, embedded images | `content` (CommonMark string; `![alt](data:image/...;base64,...)` for logos) |
| `code` | JS function via Dynatrace Functions runtime | `input` (JS string importing `@dynatrace-sdk/*`), `visualization`, `visualizationSettings` |
| `image` | Native image tile with fill/fit/align sizing | `imageSettings.defaultSource` = `/platform/document/v1/documents/<id>/content`; image stored in Documents API |

The `code` tile is especially useful for data sources not reachable by DQL: USQL, metric selectors, Classic API endpoints, external REST APIs. It runs in the Dynatrace Functions sandbox.

### Visualization variety — required mix

A monolithic stack of donut + area charts is visually monotonous. Aim
for a deliberate mix across the dashboard. All of the following are `visualization`
values on a `data` (or `code`) tile:

- **`pieChart`** — small categorical share (3–5 slices).
- **`donutChart`** — same, when you want a center total.
- **`barChart`** (vertical, stacked) — categorical-over-time. Requires
  `makeTimeseries ..., by:{<group>}, bins:N` (see Phase 3).
- **`categoricalBar`** — horizontal stacked time-bars; same query
  requirement.
- **`honeycomb`** — many small categories (6+); needs
  `visualizationSettings.honeycomb.dataMappings.value = "<count_field>"`.
- **`lineChart` / `areaChart`** — single or multi-series timeseries.
- **`table` / `dataPage`** — raw rows; `dataPage` adds pagination.
- **`bubbleMap` / `dotMap`** — geo scatter on a world map.
- **`funnel`** — sequential conversion steps.
- **`scatterplot`** — two-variable correlation (x vs y field).
- **`singleValue`** — KPIs. Apply a **gauge feel** by attaching three
  threshold `colorRules` with `colorThresholdTarget: "background"` and
  `customColor` from `var(--dt-colors-charts-status-{success,warning,critical}-default, ...)`.
  Comparator `≥` (Unicode). **`colorRules` ordering with `≥`: lowest threshold value first,
  highest threshold value last** — Dynatrace applies the last matching rule, so the highest
  threshold must be at the bottom to "win". Reversing this order causes all values to show the
  wrong color. Gen 3 has no separate `gauge` viz type — this IS the gauge.

- **`singleValue` `unitsOverrides` — always use `unitCategory: "unspecified"` + `baseUnit: "count"` for raw numeric KPIs** (latency ms, temperature °C, raw counts, etc.). Two failure modes:
  1. `unitCategory: "time"` auto-scales the display (1000ms → "1s") but evaluates `colorRule` thresholds against the **raw query value** — a 1 000ms latency fires the ≥500 threshold and shows red even though the tile reads "1s".
  2. Omitting `unitCategory` with `delimiter: true` abbreviates numbers (1000 → "1k").
  Correct form for any raw numeric KPI:
  ```json
  { "unitCategory": "unspecified", "baseUnit": "count", "displayUnit": null, "decimals": 1, "suffix": " ms" }
  ```

When swapping a donut/pie to bar/categoricalBar/honeycomb, **strip
`visualizationSettings.chartSettings.circleChartSettings`**. Leaving it
in makes the new chart render blank.

---

## Phase 3 — DQL query patterns

Always filter by `event.provider == "<technology>.event.provider"` and use the
field aliases from your event schema (snake_case).

### Pattern → visualization

| DQL pattern | Visualization | Use case |
|-------------|---------------|----------|
| `summarize <agg>` | `singleValue` | Single KPI |
| `makeTimeseries <agg>, bins:N` | `lineChart`, `areaChart` | Time trends |
| `fetch ... \| filter ... \| fields ...` | `table`, `dataPage` | Raw data display |
| `summarize by:{field}` | `donutChart`, `pieChart`, `honeycomb` | Pure-category breakdown (NO time axis) |
| `makeTimeseries by:{field}, bins:N` | `barChart`, `categoricalBar`, stacked `areaChart` | Categorical trends over time |

**Critical:** `barChart` and `categoricalBar` in Gen 3 ALWAYS require a
time axis. The Gen 3 chart engine demands `fieldMapping.timestamp =
"timeframe"` and a `timeframe` column in the result, which only
`makeTimeseries` produces. Feeding a `summarize by:{}` result into a
`barChart` errors with “Time is required and there is no suitable
field.” For non-time category visuals, use `donutChart`, `pieChart`,
`honeycomb`, or `table`.

`barChart` / `categoricalBar` `fieldMapping`:
```json
{ "timestamp": "timeframe",
  "leftAxisValues": ["<value_field>"],
  "leftAxisDimensions": ["<group_field>"] }
```

### Common pitfalls

❌ WRONG — feeding `summarize` into a `barChart`/`categoricalBar`:
```dql
fetch bizevents | summarize revenue = sum(amount), by:{venue}
| visualization: barChart   // "Time is required"
```

✅ CORRECT — use `makeTimeseries` for any bar chart:
```dql
fetch bizevents | makeTimeseries revenue = sum(amount), by:{venue}, bins:20
| visualization: barChart
```

❌ WRONG — `avg(percentage_field)` for ratio metrics:
```dql
| summarize conversion = avg(conversion_percent)
```

✅ CORRECT — `sum/sum` calc:
```dql
| summarize visitors = sum(visitors_count), txns = sum(transactions_count)
| fieldsAdd conversion = (toDouble(txns) / toDouble(visitors)) * 100
```

❌ WRONG — bare keyword for `sort` direction:
```dql
| sort total_calls, direction: desc
```

✅ CORRECT — `direction` must be a quoted string:
```dql
| sort total_calls, direction: "descending"
| sort total_calls, direction: "ascending"
```

### Multi-select variable filters

Define each variable as `type: "query"`, `multiple: true`, **`defaultSelectAll: true`**,
sourced via `| dedup <field>` against the company's `event.provider`. Filter tiles
with plain `| filter in(<field>, $<Var>)` — **no** `array_size($Var)
== 0` escape clause (it breaks the filter; default-all already returns
all rows when `defaultSelectAll: true` is set).

Rules:
1. **Always include `"defaultSelectAll": true`** on every query variable. Without it, Dynatrace
   may pre-select the first query result rather than all values, and the dashboard opens with
   filtered data.
2. **Insert filters BEFORE aggregation pipes** (`makeTimeseries`,
   `summarize`, `fields*`, `sort`, `limit`). After `makeTimeseries` the
   source field no longer exists, so a trailing
   `| filter in(region, $Region)` silently drops every row.
3. **Per-tile field availability matters.** Compute the **intersection**
   of filterable fields across every `event.type` referenced by the
   tile. Only inject filters for fields shared by ALL referenced types.
   Tiles whose events share no filterable dimensions (section dividers,
   funnel-only events, the global map) correctly get no variable filter.
4. Variables are **company-specific**. Pick 3–5 dimensions that map to
   the operating model (e.g. `$Banner`, `$Region`, `$Department`,
   `$Channel`, `$Store`). Avoid more than ~5 — the bar gets crowded.

### DQL best practices

1. Always filter by `event.provider`.
2. Snake_case field names matching the injector schema.
3. Add `| limit 10` while testing.
4. `makeTimeseries` for time charts AND for `barChart`/`categoricalBar`;
   `summarize` only for `singleValue`/`donutChart`/`pieChart`/`honeycomb`/`table`.
5. Ratio metrics = `sum(num)/sum(denom)*100`, never `avg(percent)`.
6. Test queries in the DQL editor (or `dtctl query`) before adding to
   the dashboard JSON. Substitute a literal `array(...)` for `$Var` to
   smoke-test multi-select filters.

Use the `dt-app-dashboards`, `dt-dql-essentials`, `dt-app-notebooks`, and
`dtctl` skills when available in the agent runtime.

---

## Phase 3 — Create Dynatrace entities (Gen 3 / Grail tenants)

On Gen 3 / Grail-native tenants the classic device APIs are unavailable. The
only reliable path to create topology entities from BizEvents is
**OpenPipeline `smartscapeNode` processors**.

### How it works

1. Create a `builtin:openpipeline.bizevents.pipelines` settings object with
   one or more `smartscapeNodeExtraction.processors` of `type: "smartscapeNode"`.
   This schema is **multi-object** (`multiObject: true`, `maxObjects: 100`) —
   each technology safely gets its own pipeline object. Apply it directly:
   `dtctl apply -f "dashboards/<technology>/<technology>-openpipeline.json" --plain`.
2. Add a routing entry so the technology's events (matched by
   `event.provider`) reach that pipeline.

   > **CRITICAL — `builtin:openpipeline.bizevents.routing` is a SINGLETON
   > schema** (`maxObjects: 1`, `multiObject: false`): there is exactly **one**
   > such object per environment, holding a `routingEntries` list shared by
   > every technology this generator has ever deployed *and* every
   > hand-built demo route already in the tenant. Applying a fresh
   > single-entry document with no `id` resolves to that same object and
   > **replaces its entire list** — silently deleting every other rule that
   > was there. This has already broken a real demo. **Never** run
   > `dtctl apply -f` on an openpipeline-routing file directly. Always use:
   > ```bash
   > scripts/apply-openpipeline-routing.sh "dashboards/<technology>/<technology>-openpipeline-routing-entry.json"
   > ```
   > It fetches the existing object, merges the entry in by `description`
   > (adds it, or updates it in place if the description already exists —
   > the schema enforces uniqueness on that field), and re-applies the full
   > merged list so every other technology's and every hand-built entry
   > survives untouched.
3. As BizEvents arrive the pipeline extracts Smartscape nodes automatically.
   Device IDs are written back to the processed event.

### `smartscapeNode` processor key fields

```json
{
  "id": "extract-<device-slug>",
  "type": "smartscapeNode",
  "enabled": true,
  "matcher": "event.type == \"<event.type that carries device fields>\"",
  "smartscapeNode": {
    "extractNode": true,
    "nodeType": "CUSTOM_<ENTITY_TYPE>",
    "nodeIdFieldName": "dt.entity.custom_<device_type>",
    "idComponents": [
      { "idComponent": "<prefix>", "referencedFieldName": "<unique_field>" }
    ],
    "nodeName": {
      "type": "field",
      "field": { "sourceFieldName": "<display_name_field>", "defaultValue": "Unknown" }
    },
    "fieldsToExtract": [
      { "referencedFieldName": "<event_field>", "fieldName": "<device_property>" }
    ]
  }
}
```

**Critical constraints:**
- `nodeType` must be uppercase `[A-Z][A-Z0-9_]+`. `CUSTOM_DEVICE` is **explicitly blocked** — use any other `CUSTOM_*` type (e.g. `CUSTOM_GPU_CLUSTER`, `CUSTOM_DB_INSTANCE`).
- `requiredDimensions.valuePattern` in routing must use `$eq(value)` or `$prefix(value)` syntax — raw strings cause HTTP 400.
- **OpenPipeline routing `pipelineId`** must be the long base64-encoded settings object ID returned by `dtctl apply`, NOT the human-readable `customId` string. After applying the pipeline settings file, read back the object ID with `dtctl describe settings <id>` and use that value in the routing entry file.
- Entities appear in **Explorer Classic** (Infrastructure & Operations app → Smartscape). They do NOT appear in Explorer New without an Extension Framework 2.0 (EF2) extension.
- **OpenPipeline cleanup order matters:** always remove this technology's routing *entry* (via `scripts/apply-openpipeline-routing.sh`'s companion removal in `cleanup-technology.sh` — never delete the shared routing object itself) **before** deleting its pipeline settings object. The API enforces a referential constraint — deleting a pipeline while any routing entry still points to it returns HTTP 400 "Constraints violated".

### Device type guidance

| Technology type | Recommended `nodeType` |
|----------------|----------------------|
| Network device | `CUSTOM_NETWORK_DEVICE` |
| Infrastructure (compute, GPU, storage) | `CUSTOM_<TECHNOLOGY>_NODE` / `CUSTOM_<TECHNOLOGY>_CLUSTER` |
| Database / data platform | `CUSTOM_DB_INSTANCE` |
| Process / middleware | `CUSTOM_<TECHNOLOGY>_PROCESS` |
| Any other | Propose `CUSTOM_<TECHNOLOGY>_<ENTITY>` and confirm with user |

### MINT metric-device association

Also create `<technology>-device-creator.js` as a second workflow task that
pushes MINT metric lines with `dt.entity.custom_<type>=<id>` dimensions. This
pre-associates MINT metrics with the device ID space. Note: the device IDs
generated by the script's hash function will differ from the IDs generated
internally by OpenPipeline; the MINT metrics are still useful for querying
by device dimension even if the topology link is imprecise.

MINT line format (commas as separators — NOT semicolons):
```
metric.key,dim1=val1,dim2=val2 value timestampMs
```

**MINT ingest endpoint — Gen 3 tenants only:**
```
/platform/classic/environment-api/v2/metrics/ingest
```
**NEVER use `/platform/ingest/v1/metrics`** — that path only exists on classic
`live.dynatrace.com` domains. On Gen 3 `apps.dynatrace.com` tenants it returns
HTTP 404 with a redirect hint to the live domain. Use the `/platform/classic/`
proxy for both BizEvents and MINT metrics:

| Signal | Correct endpoint (Gen 3) |
|--------|--------------------------|
| BizEvents | `/platform/classic/environment-api/v2/bizevents/ingest` |
| MINT metrics | `/platform/classic/environment-api/v2/metrics/ingest` |
| Logs | `/platform/classic/environment-api/v2/logs/ingest` |

Verify device creation:
```bash
dtctl query "smartscapeNodes \"CUSTOM_<TYPE>\", from:now()-1h | limit 20" --plain
```

## Phase 4 — Event injector JavaScript

Use `reference/example-injector.js` and the `script`
field in `example_data_injector.workflow.json` as the structural template.

### Requirements
- **Data mapping** data - metrics and logs - should be attached to the device or entities created when the technology's schema supports that relationship.
- **Event types:** choose the smallest realistic set that covers the technology's use cases; typically 8–20 different types
  (`gaming.transaction`, `guest.checkin`, `equipment.telemetry`, ...).
- **Field schema:** snake_case for all fields
  (`gaming_venue`, `occupancy_percent`, ...).
- **Realistic values:** match the technology domain (CPU level, latency in ms or low seconds, temperature, 
  0–100 for percentages, plausible ranges).
- **Volume:** default to 3,000–5,000 events per execution for a demo, adjusting
  the target when the technology's natural cardinality or cost makes another
  volume more realistic.
- **Geo fields:** emit
  `geo.location.latitude` / `geo.location.longitude` only when a map is part of
  the dashboard design.
- **Ingest endpoint:** `/platform/classic/environment-api/v2/bizevents/ingest`.
- **Batching:** 500 events per POST to stay under ~5MB; throw on non‑2xx.
- **Auth:** integrated platform auth — no token; the workflow runs in the
  AutomationEngine context.
- **Provider:** `EVENT_PROVIDER = "<company>.event.provider"`.

---

## Phase 5 — Dashboard implementation checklist

Pre‑implementation:
- [ ] Meaningful dashboard title (e.g. `<Technology> | Operations Dashboard`).
- [ ] 15–20 KPIs researched and mapped to event types.
- [ ] Layout sketched (sections, tile positions).
- [ ] Logo URL gathered **AND verified** via `curl -sIL` (must return
      `HTTP 200` + `content-type: image/*`).
- [ ] 5–6 section colors chosen from brand/theme.
- [ ] 3–5 dashboard variables chosen (multi-select, query-driven, **`"defaultSelectAll": true`** on each).

Query validation:
- [ ] Each DQL query tested in the DQL editor with `| limit 10`.
- [ ] Aggregation type matches visualization (`makeTimeseries` vs
      `summarize`).
- [ ] Field names match the injector schema exactly.

Tile creation:
- [ ] Logo tile (markdown, `h:2`, `w:6`).
- [ ] Title tile (markdown, `h:2`, `w:18`).
- [ ] Map included only when geographic data is meaningful; if included,
      verify it uses usable coordinates and an intentional layout position.
- [ ] Section dividers (`h:1`, colored).
- [ ] KPI tiles (`h:2`, under each section); 3–4 use `singleValue` +
      threshold `colorRules` for gauge feel. `≥` rules ordered **lowest value first, highest last**.
- [ ] All `singleValue` `unitsOverrides` use `unitCategory: "unspecified"` + `baseUnit: "count"` — never `unitCategory: "time"` on latency/duration tiles (breaks colorRule threshold comparison).
- [ ] `bubbleMap` uses `"regions": { "showRegions": false }` — no region codes.
- [ ] Chart tiles (`h:4+`, under KPIs).
- [ ] **Visualization mix:** at least 4 distinct chart types across the
      board (e.g. `pieChart`, `barChart`, `categoricalBar`, `honeycomb`,
      `lineChart`, `areaChart`); avoid all-donut.
- [ ] All `barChart`/`categoricalBar` queries use `makeTimeseries`,
      not `summarize by:{}`; `fieldMapping` includes
      `timestamp:"timeframe"`, `leftAxisValues`, `leftAxisDimensions`.
- [ ] Any `honeycomb` tile sets
      `visualizationSettings.honeycomb.dataMappings.value`.
- [ ] Any non-circular chart has `chartSettings.circleChartSettings`
      removed.
- [ ] Consistent X positions (`0, 6, 12, 18`).
- [ ] Y gaps minimized (`+1` to `+2`).
- [ ] **All tile positions are in the `content.layouts` section** (sibling of `content.tiles`), NOT embedded inside individual tile objects.
- [ ] All threshold `color` values use `{ "Default": "#hex" }` object form, not bare `"#hex"` strings.

Styling & validation:
- [ ] Section colors applied.
- [ ] Chart `legend.ratio` 20–30.
- [ ] `categoryOverrides` for semantic colors.
- [ ] No red‑X tiles in preview.
- [ ] Logo renders correctly; if a map is included, it renders correctly.

---

## Phase 6 — Workflow & deployment (CRITICAL RULES)

Each technology gets its **own dedicated workflow** — never merge tasks for
different technologies into a single workflow. This keeps schedules,
expirations, and manual run/pause controls independent per technology: pausing,
re-scheduling, or setting an expiration for one technology never touches
another's.

### Step‑by‑step

1. **Apply the dashboard:**
   ```bash
   dtctl apply -f "dashboards/<technology>/<company>-dashboard-v1.json"
   ```
   Capture the returned dashboard ID.

   **Envelope shape (REQUIRED):** `dtctl apply` expects a wrapper:
   ```json
   { "id": "<uuid?>", "name": "<Company> | Operations Dashboard",
     "type": "dashboard", "isPrivate": false,
     "content": { "tiles": {...}, "layouts": {...}, "variables": [...],
                  "settings": {...}, "version": 21, ... } }
   ```
   Submitting just the `content` body imports tiles but creates an
   "Untitled dashboard" with name and ID detached. Re-applying with the
   wrapper fixes it in place (`ACTION = updated`).

2. **Apply OpenPipeline device settings:**
   ```bash
   dtctl apply -f "dashboards/<technology>/<technology>-openpipeline.json" --plain
   scripts/apply-openpipeline-routing.sh "dashboards/<technology>/<technology>-openpipeline-routing-entry.json"
   ```
   The first creates the `smartscapeNode` pipeline that extracts Smartscape
   entities from BizEvents. The second **must** go through the merge script,
   never a plain `dtctl apply -f` — see the CRITICAL note in "Create
   Dynatrace entities".

3. **Check whether this technology already has its own workflow (only relevant
   when updating an existing pack, not on a first run):**
   ```bash
   dtctl get workflows -o json --plain | \
     jq --arg t "<technology>" '.[] | select(.title | test($t; "i"))'
   ```
   Never search for or reuse a workflow that belongs to a different
   technology — each technology's workflow is independent, never shared.

4. **If this technology's own workflow already exists (updating an existing
   pack):**
   - `dtctl get workflow <id> -o json --plain > .tmp/workflow.json`
   - Add the new version's task(s) (`<company>_v2`, etc.), keeping earlier
     version tasks unless the user asks to remove them.
   - Use a **unique** `position.{x, y}` within this workflow — duplicates
     produce a 400 error.
   - Set `predecessors: []` for tasks that should run independently, or list
     the metrics task as a predecessor for logs/device tasks that should run
     after it succeeds.
   - `dtctl apply -f .tmp/workflow.json`

5. **If this technology has no workflow yet (the normal case — first run):**
   - Use `reference/zscaler-internet-access/zscaler-internet-access-workflow.yaml`
     as the template.
   - Replace its tasks with this technology's task(s); title the workflow
     `<Technology> | Injector Workflow`.
   - `dtctl apply -f` it; capture the workflow ID — **this workflow belongs
     exclusively to this technology.**

6. **Execute and verify — with production fallback:**

   **Primary (sprint/demo tenants):**
   ```bash
   dtctl exec workflow <id>
   dtctl describe workflow-execution <exec-id>   # wait for SUCCESS
   ```
   `describe workflow-execution` returns an empty `tasks{}` dict — to
   inspect the JS task's return value (totals, batches, errors) use:
   ```bash
   dtctl get wfe-task-result <exec-id> -t <taskName>
   ```
   The task name is required via the `-t/--task` flag, NOT positional.

   **Fallback (production tenants — Automation Authorization not configured):**
   If `dtctl exec workflow` fails with *"Could not run workflow task… Please ensure
   Authorization Settings are configured"*, the AutomationEngine cannot impersonate
   the user on this tenant. Use `dtctl exec function` instead — it runs the JS
   directly under the user's OAuth token and requires no additional authorization:
   ```bash
   dtctl exec function -f "dashboards/<technology>/<technology>-injector.js" --plain
   ```
   The workflow still exists for scheduled 30-minute runs if/when Automation
   authorization is later configured. Do not delete it.

7. **Verify ingestion — account for fresh-tenant indexing delay:**
   On a production tenant seeing BizEvents for the first time, the Grail index may
   lag several seconds. Always use an explicit short window for the first check:
   ```dql
   fetch bizevents, from:now()-30m
   | filter event.provider == "<company>.event.provider"
   | summarize total = count(), types = countDistinct(event.type)
   ```
   If that returns 0, wait 15–30 seconds and retry before concluding ingest failed.

**Never merge this technology's tasks into another technology's workflow**,
and never create a second workflow for the *same* technology when one already
exists — update it instead.

### Versioning

- First iteration: `<company>-dashboard-v1.json`, task `<company>_v1`.
- Updates: `<company>-dashboard-v2.json`, task `<company>_v2`.
- Never overwrite v1 files.

---

## Phase 7 — Documentation deliverables

For every project, write into the company folder:

- **`README.md`** — Project overview, file list, dashboard ID, workflow ID,
  task name, deployment commands.
- **`LEARNINGS.md`** — DQL patterns, layout decisions, pitfalls, color
  scheme, anything reusable for the next project.
- **`SALES-PITCH.md`** — 1‑page value proposition tailored to the company
  for the sales team.

`LEARNINGS.md` template:

```markdown
# <technology> Dashboard Learnings

**Date:** <date>
**Version:** v1

## DQL Patterns Used
| Tile Type | DQL Pattern | Notes |
|-----------|-------------|-------|

## Layout Decisions
- Header, dividers, KPI rows, chart rows...

## Pitfalls Hit
1. ...

## Color Scheme
- Section: `#hex`
```

---

## Phase 8 — Quality gate (run before declaring done)

- [ ] Logo renders.
- [ ] All section dividers show correct colors.
- [ ] No red‑X tiles.
- [ ] Every KPI tile has data.
- [ ] Every chart shows legends/labels.
- [ ] If a map is included, it is populated with cluster/region/site
  coordinates.
- [ ] Layout is compact (no excessive whitespace).
- [ ] Workflow execution finished SUCCESS.
- [ ] 3,000+ events ingested per run.
- [ ] OpenPipeline settings applied; entities visible in Explorer Classic.
- [ ] `README.md`, `LEARNINGS.md`, `SALES-PITCH.md` all present.
- [ ] `<technology>-openpipeline.json` and `<technology>-openpipeline-routing-entry.json` present.
- [ ] Routing entry was applied via `scripts/apply-openpipeline-routing.sh`, never a direct `dtctl apply -f` — confirm every pre-existing entry in `builtin:openpipeline.bizevents.routing` is still present after deployment.

---

## Key principles

1. **Markdown formatting is critical** — pure markdown only, no HTML.
2. **Logo = professional touch** — every dashboard branded.
3. **Charts need space** — `h:4` minimum.
4. **Test before deploy** — DQL in the editor first.
5. **Document everything** — `LEARNINGS.md` is the knowledge capital.
6. **Consistency breeds quality** — follow the example shape exactly.
7. **One dedicated workflow per technology** — never merge tasks for different
   technologies into a single workflow; this keeps schedules, expirations, and
   manual run/pause controls independent per technology.
8. **Variables default to `*` (all values)** — every `query`-type dashboard variable must set `"defaultSelectAll": true`. Omitting it causes Dynatrace to pre-select the first result and the dashboard opens with filtered data instead of the full picture.

---

## What the agent must NOT do

- Do not invent dashboard IDs, workflow IDs, or URLs — always use values
  returned by `dtctl`.
- Do not merge a technology's tasks into another technology's workflow, and do
  not create a second workflow for the same technology when one already
  exists — update it instead.
- Do not create a dashboard variable without `"defaultSelectAll": true` — dashboards must open showing all data, not a filtered subset.
- Do not add a map when geographic data is not meaningful; when included,
  validate its coordinates and rendering.
- Do not push commits or open PRs unless asked.
- Do not run destructive `dtctl delete` commands without explicit user
  confirmation.
- Do not attempt to install or configure `dtctl`.
