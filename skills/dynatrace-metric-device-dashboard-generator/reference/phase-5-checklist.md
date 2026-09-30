# Phase 5 — Dashboard Implementation Checklist

## Pre‑implementation

- [ ] Meaningful dashboard title (e.g. `<Technology> | Operations Dashboard`).
- [ ] 15–20 KPIs researched and mapped to event types.
- [ ] Layout sketched (sections, tile positions).
- [ ] Logo URL gathered **AND verified** via `curl -sIL` (must return
      `HTTP 200` + `content-type: image/*`).
- [ ] 5–6 section colors chosen from brand/theme.
- [ ] 3–5 dashboard variables chosen (multi-select, query-driven, **`"defaultSelectAll": true`** on each).

## Query validation

- [ ] Each DQL query tested in the DQL editor with `| limit 10`.
- [ ] Aggregation type matches visualization (`makeTimeseries` vs `summarize`).
- [ ] Field names match the injector schema exactly.

## Tile creation

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
- [ ] Any `honeycomb` tile sets `visualizationSettings.honeycomb.dataMappings.value`.
- [ ] Any non-circular chart has `chartSettings.circleChartSettings` removed.
- [ ] Consistent X positions (`0, 6, 12, 18`).
- [ ] Y gaps minimized (`+1` to `+2`).
- [ ] **All tile positions are in the `content.layouts` section** (sibling of `content.tiles`), NOT embedded inside individual tile objects.
- [ ] All threshold `color` values use `{ "Default": "#hex" }` object form, not bare `"#hex"` strings.

## Styling & validation

- [ ] Section colors applied.
- [ ] Chart `legend.ratio` 20–30.
- [ ] `categoryOverrides` for semantic colors.
- [ ] No red‑X tiles in preview.
- [ ] Logo renders correctly; if a map is included, it renders correctly.
