# Phase 6 — Workflow & Deployment (CRITICAL RULES)

Each technology gets its **own dedicated workflow** — never merge tasks for
different technologies into a single workflow. This keeps schedules,
expirations, and manual run/pause controls independent per technology: pausing,
re-scheduling, or setting an expiration for one technology never touches
another's.

## Workflow duration schedule YAML

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
the workflow running indefinitely. After applying a finite-duration workflow,
read it back with `dtctl get workflow` and verify that the persisted schedule
contains the intended end date. If the tenant rejects the end parameters, stop
and report that native schedule expiry is unavailable in that tenant rather than
silently deploying an unlimited workflow.

## Step‑by‑step

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
   never a plain `dtctl apply -f` — see the CRITICAL note in phase-3-entities.md.

3. **Check whether this technology already has its own workflow (only relevant
   when updating an existing pack, not on a first run):**
   ```bash
   dtctl get workflows -o json --plain | \
     jq --arg t "<technology>" '.[] | select(.title | test($t; "i"))'
   ```
   Never search for or reuse a workflow that belongs to a different
   technology — each technology's workflow is independent, never shared.

4. **If this technology's own workflow already exists (updating an existing pack):**
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
   - Use `skills/dynatrace-metric-device-dashboard-generator/reference/zscaler-internet-access/zscaler-internet-access-workflow.yaml`
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
   This does **not** trigger the workflow tasks (device-creator, log injector); run
   those separately if needed:
   ```bash
   dtctl exec function -f "dashboards/<technology>/<technology>-device-creator.js" --plain
   ```
   The workflow itself still exists for scheduled 30-minute runs if/when Automation
   authorization is later configured. Do not delete it.

7. **Verify ingestion — account for fresh-tenant indexing delay:**
   On a production tenant seeing BizEvents for the first time, the Grail index may
   lag several seconds. Always use an explicit short window for the first check:
   ```dql
   fetch bizevents, from:now()-30m
   | filter event.provider == "<company>.event.provider"
   | summarize total = count(), types = countDistinct(event.type)
   ```
   If that also returns 0, wait 15–30 seconds and retry before concluding ingest failed.

**Never merge this technology's tasks into another technology's workflow**,
and never create a second workflow for the *same* technology when one already
exists — update it instead.

## Versioning

- First iteration: `<company>-dashboard-v1.json`, task `<company>_v1`.
- Updates: `<company>-dashboard-v2.json`, task `<company>_v2`.
- Never overwrite v1 files.
