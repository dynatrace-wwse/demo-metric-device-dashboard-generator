# Phase 3 — DQL Query Patterns

Always filter by `event.provider == "<technology>.event.provider"` and use the
field aliases from your event schema (snake_case).

## Pattern → visualization

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
`barChart` errors with "Time is required and there is no suitable
field." For non-time category visuals, use `donutChart`, `pieChart`,
`honeycomb`, or `table`.

`barChart` / `categoricalBar` `fieldMapping`:
```json
{ "timestamp": "timeframe",
  "leftAxisValues": ["<value_field>"],
  "leftAxisDimensions": ["<group_field>"] }
```

## Common pitfalls

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

✅ CORRECT — `direction` must be a quoted string, or use the short `asc`/`desc` suffix:
```dql
| sort total_calls, direction: "descending"
| sort total_calls, direction: "ascending"
| sort total_calls desc, other_field asc
```

## Multi-select variable filters

Define each variable as `type: "query"`, `multiple: true`, **`defaultSelectAll: true`**,
sourced via `| dedup <field>` against the company's `event.provider`. Filter tiles
with plain `| filter in(<field>, $<Var>)` — **no** `array_size($Var)
== 0` escape clause (it breaks the filter; default-all already returns
all rows when `defaultSelectAll: true` is set).

**CRITICAL — Gen 3 variable JSON schema is flat, not nested.** The `type`, `defaultSelectAll`,
`multiple`, `editable`, and `version` fields belong at the top level of each variable object.
`input` is a plain DQL string — NOT a nested object. Using a nested `input: { type: "query", ... }`
structure causes "Missing required property 'type'" on every variable.

Correct form (copy this exactly):

```json
{
  "key": "Region",
  "name": "Region",
  "type": "query",
  "visible": true,
  "editable": true,
  "multiple": true,
  "defaultSelectAll": true,
  "version": 3,
  "input": "fetch bizevents | filter event.provider == \"<company>.event.provider\" | fields <field> | dedup <field>"
}
```

❌ WRONG — nested input object (causes validation error):
```json
{ "key": "Region", "visible": true, "input": { "type": "query", "defaultSelectAll": true, "multiple": true, "query": "..." } }
```

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

## DQL best practices

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
