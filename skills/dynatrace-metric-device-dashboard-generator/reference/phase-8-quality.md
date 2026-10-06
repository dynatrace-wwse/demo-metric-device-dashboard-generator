# Phase 8 — Quality Gate (run before declaring done)

- [ ] Logo renders.
- [ ] All section dividers show correct colors.
- [ ] No red‑X tiles.
- [ ] Every KPI tile has data.
- [ ] Every chart shows legends/labels.
- [ ] If a map is included, it is populated with cluster/region/site coordinates.
- [ ] Layout is compact (no excessive whitespace).
- [ ] Workflow execution finished SUCCESS.
- [ ] 3,000+ events ingested per run.
- [ ] OpenPipeline settings applied; entities visible in Explorer Classic.
- [ ] `README.md`, `LEARNINGS.md`, `SALES-PITCH.md` all present.
- [ ] `<technology>-openpipeline.json` and `<technology>-openpipeline-routing-entry.json` present.
- [ ] Routing entry was applied via `scripts/apply-openpipeline-routing.sh`, never a direct `dtctl apply -f` — confirm every pre-existing entry in `builtin:openpipeline.bizevents.routing` is still present after deployment.

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
8. **Variables default to `*` (all values)** — set `"defaultSelectAll": true` on every query variable.
