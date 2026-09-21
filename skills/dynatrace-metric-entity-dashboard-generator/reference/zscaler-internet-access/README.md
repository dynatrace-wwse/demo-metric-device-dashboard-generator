# Zscaler Internet Access Reference Pack

This folder is a reusable example for the Dynatrace Gen 3 asset generator. It
contains a dashboard, BizEvents injector, optional log injector, OpenPipeline
Smartscape extraction settings, workflow task definition, and validation notes.

Use the structure and validation approach as a pattern. Treat the event names,
fields, entity type, thresholds, and Zscaler terminology as domain-specific.

## Files

- zscaler-internet-access-dashboard-v1.yaml
- zscaler-internet-access-injector.js
- zscaler-internet-access-log-injector.js
- zscaler-internet-access-entity-creator.js
- zscaler-internet-access-openpipeline.yaml
- zscaler-internet-access-openpipeline-routing-entry.json
- zscaler-internet-access-workflow.yaml
- upload-logo.sh
- LEARNINGS.md
- SALES-PITCH.md

## Domain Schema

- Event provider: `zscaler.zia.event.provider`
- Log source: `zscaler.zia.synthetic`
- Entity type: `CUSTOM_ZIA_NODE`
- Example fields: `site`, `zia_node`, `policy_action`, and `loglevel`
- Example volume: 3,600 BizEvents and 1,800 logs per workflow run

These values are examples for Zscaler only. New technology packs should define
their own provider, entity type, fields, KPIs, event volume, and optional log
schema.

## Deployment and Verification

The original pack was deployed and validated in a sprint tenant. Tenant-specific
IDs and URLs belong in a generated technology folder, not in this reusable
reference pack.

Recommended checks when reusing this pack:

- Confirm the workflow execution reaches `SUCCESS`.
- Query `zscaler.zia.event.provider` BizEvents.
- Validate `zscaler.zia.synthetic` logs and required fields.
- Query `CUSTOM_ZIA_NODE` Smartscape entities.
- Inspect the live dashboard payload for persisted thresholds and tile layouts.

## Known Learning

The log ingest endpoint accepts a JSON array body, not an NDJSON string. The
dashboard threshold validator checks the live persisted dashboard payload,
because a successful `dtctl apply` does not guarantee that nested visualization
settings were retained by the tenant.

`builtin:openpipeline.bizevents.routing` is a tenant-wide singleton schema
(`maxObjects: 1`) — there is exactly one such object per environment, shared
by every technology and every hand-built demo route. That's why
`zscaler-internet-access-openpipeline-routing-entry.json` here is a single
routing-entry *fragment*, not a full settings document: it must always be
merged into the existing object via `scripts/apply-openpipeline-routing.sh`,
never applied directly with `dtctl apply -f`. Applying a fresh single-entry
document overwrites the whole list and silently deletes every other rule
that was already there — this broke a real customer demo in production.
