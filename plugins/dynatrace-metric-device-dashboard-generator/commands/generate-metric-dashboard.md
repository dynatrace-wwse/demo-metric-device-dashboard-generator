---
description: Generate a Dynatrace Gen 3 metric dashboard, Smartscape entities, and a 30-minute injector for a technology.
argument-hint: [technology]
---

Before doing any research or generation work, ask the user all four of the
following questions. If the user already provided an answer in their prompt
(e.g. named the technology as **$ARGUMENTS**), display the proposed value and
ask them to confirm. Do not skip any question, even if the answer seems obvious.

1. **What technology?** _(required)_ — the technology to build assets for.
2. **What customer?** _(optional)_ — a customer name to tailor the dashboard
   title and sales pitch. Leave blank for a generic technology pack.
3. **Dynatrace Hub or technology metrics link?** _(optional)_ — e.g.
   `https://www.dynatrace.com/hub/detail/<technology>/`. Used to research
   extensions and official metric names.
4. **Logo image?** _(optional)_ — a local file path or public URL for the
   technology or customer logo.

After all four are answered, also ask:
- **Workflow duration in days?** — how many days the injector should run.
  Default: `7`. Use `0` for no expiry.

Once all inputs are answered, display a summary table listing every input
(write "none" for any optional input the user left blank) and ask the user
to confirm before starting any research or generation work.

Once inputs are confirmed, follow the canonical generation instructions in
`AGENTS.md` to create and deploy a dashboard pack. Before any tenant mutation,
show the active `dtctl` context and identity and get explicit tenant
confirmation. Use the Zscaler reference pack for lifecycle patterns, adapt the
schema to the requested technology, create an `asset-manifest.json`, use the
shared injector workflow, and run the full live validation before reporting
success.
