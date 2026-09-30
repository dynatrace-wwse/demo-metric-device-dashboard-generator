# Phase 4 — Event Injector JavaScript

Use `reference/zscaler-internet-access/zscaler-internet-access-injector.js` and the
`script` field in `zscaler-internet-access-workflow.yaml` as the structural template.

## Requirements

- **Data mapping** — metrics and logs should be attached to the device or entities created
  when the technology's schema supports that relationship.
- **Event types:** choose the smallest realistic set that covers the technology's use cases;
  typically 8–20 different types (`gaming.transaction`, `guest.checkin`, `equipment.telemetry`, ...).
- **Field schema:** snake_case for all fields (`gaming_venue`, `occupancy_percent`, ...).
- **Realistic values:** match the technology domain (CPU level, latency in ms or low seconds,
  temperature, 0–100 for percentages, plausible ranges).
- **Volume:** default to 3,000–5,000 events per execution for a demo, adjusting
  the target when the technology's natural cardinality or cost makes another
  volume more realistic.
- **Geo fields:** emit `geo.location.latitude` / `geo.location.longitude` only when a map
  is part of the dashboard design.
- **Ingest endpoint:** `/platform/classic/environment-api/v2/bizevents/ingest`.
- **Batching:** 500 events per POST to stay under ~5MB; throw on non‑2xx.
- **Auth:** integrated platform auth — no token; the workflow runs in the AutomationEngine context.
- **Provider:** `EVENT_PROVIDER = "<company>.event.provider"`.
