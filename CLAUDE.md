# demo-metric-device-dashboard-generator

Dynatrace Pre-Sales tool: given a technology name, generate a Gen 3 KPI dashboard, a matching metric/log injector, and a Dynatrace device — then deploy via `dtctl`.

## Primary skill

`skills/dynatrace-metric-device-dashboard-generator/SKILL.md` — canonical instructions for all agents.

## Key commands

| Command | Purpose |
|---------|---------|
| `/generate-metric-dashboard` | Start a new dashboard + injector |
| `/dynatrace-metric-device-dashboard-generator` | Full skill entrypoint |
| `/cleanup-metric-dashboard` | Remove a deployed technology pack |

## Constraints

- Always confirm the active tenant before any `dtctl apply` or delete
- Validate `asset-manifest.json` with `scripts/validate-asset-manifest.sh` before deployment
- Never delete the shared OpenPipeline routing object — remove only this technology's entry

## Environment

Inherited from parent `CLAUDE.md` — see `../CLAUDE.md` for tenant URLs and tooling preferences.
