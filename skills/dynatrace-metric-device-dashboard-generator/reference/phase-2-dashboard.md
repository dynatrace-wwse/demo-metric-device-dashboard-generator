# Phase 2 — Dashboard Design (Gen 3 only)

## Header — required split layout

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

## Section dividers

Use a `singleValue` data tile with `data record(section="...")`, height
`h:1`, full width `w:24`, distinct brand‑appropriate background color per
section.

**Color rule for section dividers — NEVER use red, green, or yellow (any shade).**
Those colors are reserved exclusively for KPI health indicators on `singleValue`
tiles that display real metric values. Using them on structural chrome trains
users to look for health meaning where there is none.

Forbidden families for dividers:
- Red: `#c62239`, `#FF6347`, `#e53935`, `#d32f2f`, or any red/crimson/tomato
- Green: `#2a7452`, `#4caf50`, `#43a047`, or any green/emerald/teal-green
- Yellow/Gold: `#DAA520`, `#D4AF37`, `#eea53c`, `#FFD700`, `#f9a825`, or any gold/amber/yellow

Safe palette for section dividers:
- `#1E90FF` — Dodger Blue (service, cloud)
- `#2980B9` — Steel Blue (infrastructure, network)
- `#9B59B6` — Amethyst Purple (AI, security)
- `#34495E` — Wet Asphalt / Slate (operations, general)
- `#2C3E50` — Dark Slate (heavy infrastructure)
- `#1ABC9C` — Turquoise Teal (data, storage)
- `#E67E22` — Carrot Orange (backup, tasks — clearly orange, not yellow)
- `#3F51B5` — Indigo (virtualization, platform)
- `#546E7A` — Blue Grey (neutral, system)

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
        { "id": 1, "color": { "Default": "#2980B9" }, "comparator": "!=", "label": "", "value": "1" }
      ]}
    ]
  }
}
```

> **CRITICAL — threshold color format:** Colors in threshold rules must use the object form `{ "Default": "#hex" }`, **not** a bare hex string `"#hex"`. A bare string is silently accepted but does not apply correctly. This applies to every `color` field inside every threshold rule across all tile types.

## Tile height guidelines

| Height | Use case | Examples |
|--------|----------|----------|
| `h:1` | Section dividers, sparse info | Section headers |
| `h:2` | Single‑value KPIs | Revenue totals, occupancy %, counts |
| `h:3` | Small charts | 2–3 category bar charts |
| `h:4` | **Standard charts (recommended)** | Line, bar, area, donut |
| `h:5+` | Dense tables / multi‑series | Summary tables, complex analyses |

**Rule:** chart tiles need `h:4` minimum. `h:2`–`h:3` truncates legends and labels.

## Layout & spacing

Minimize vertical gaps for a professional appearance:

- Y‑axis increments: `+1` to `+2` units between rows (not `+3+`).
- Pattern: divider (`h:1`) → KPI row (`h:2`) → chart row (`h:4`) → next divider.
- Consistent X columns: `0, 6, 12, 18` (board width is 24).
- Example flow:
  ```
  y:0   header (h:2)
  y:2   divider (h:1)
  y:3   KPI row (h:2)
  y:5   chart row (h:4)
  y:9   next divider (h:1)
  ```

## Map tile — OPTIONAL, WHEN GEOGRAPHICALLY MEANINGFUL

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

## Gen 3 tile types

There are four **tile types** (`"type"` field in the tile object):

| Tile type | Purpose | Key fields |
|-----------|---------|-----------|
| `data` | DQL-powered visualization | `query`, `visualization`, `visualizationSettings`, `davis` |
| `markdown` | Text, headers, embedded images | `content` (CommonMark string; `![alt](data:image/...;base64,...)` for logos) |
| `code` | JS function via Dynatrace Functions runtime | `input` (JS string importing `@dynatrace-sdk/*`), `visualization`, `visualizationSettings` |
| `image` | Native image tile with fill/fit/align sizing | `imageSettings.defaultSource` = `/platform/document/v1/documents/<id>/content`; image stored in Documents API |

The `code` tile is especially useful for data sources not reachable by DQL: USQL, metric selectors, Classic API endpoints, external REST APIs. It runs in the Dynatrace Functions sandbox.

## Visualization variety — required mix

A monolithic stack of donut + area charts is visually monotonous. Aim
for a deliberate mix across the dashboard. All of the following are `visualization`
values on a `data` (or `code`) tile:

- **`pieChart`** — small categorical share (3–5 slices).
- **`donutChart`** — same, when you want a center total.
- **`barChart`** (vertical, stacked) — categorical-over-time. Requires
  `makeTimeseries ..., by:{<group>}, bins:N` (see phase-3-dql.md).
- **`categoricalBar`** — horizontal stacked time-bars; same query requirement.
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
