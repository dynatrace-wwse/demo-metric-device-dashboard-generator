# Phase 1 — Planning & Research

Identify primary use cases, common problem, and important metrics. For each, define:

- KPIs (CPU, threads, queue, throttling, etc).
- Event types that map to those KPIs (latency, state changes, service
  requests, telemetry).
- Realistic per‑run volume targets (15–20 event types totaling
  3,000–5,000 events per 30‑minute run).

## Technology archetypes

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

## Log decision

Determine whether to include a log injector **before** generating any files. This decision must be based on the technology itself — never on what other technologies in this repository did or did not include.

### Research steps

1. **Fetch the Hub page** and check for log-related extensions, mention of log sources, or audit/access references.
2. **Identify the log sources the technology natively produces.** Name them. If you cannot name at least one concrete log source, the technology probably does not warrant a log injector.
3. **Apply the heuristic below**, state the log sources you identified, and explain why they belong (or don't) on a Dynatrace dashboard.

### Heuristic by archetype

| Archetype | Log verdict | Examples of log sources to look for |
|---|---|---|
| Artifact / package repository | **Yes — logs are primary signals.** Access logs capture every artifact request: who downloaded what, HTTP status, response time. These are critical for CI/CD reliability and supply chain security. | access.log, request.log, audit.log, Xray policy decisions |
| Security / control plane | **Yes.** Policy enforcement, detections, and audit events are most naturally represented as logs. | threat logs, policy decision logs, auth audit |
| CI/CD / build platform | **Yes.** Build logs, pipeline run outcomes, and step-level errors matter for developer productivity stories. | pipeline run logs, step logs, test result logs |
| Database / data platform | **Usually yes** if query errors and slow-query logs are available; otherwise no. | slow query log, error log, replication log |
| Network / device | **Usually no** — metrics (availability, throughput, errors) tell the story; syslog is rarely demo-worthy unless there is a specific security angle. | syslog (only if security story is central) |
| Runtime platform / infrastructure | **Sometimes** — if there is a meaningful error or event log beyond what metrics already capture. | event log, crash log, audit log |
| Business system | **Rarely** — unless transaction failures produce structured log data worth showing. | transaction error log |

### What to include when logs are warranted

- A `<technology>-log-injector.js` (or a log block inside the main injector) writing to `fetch logs | filter log.source == "<technology>.synthetic"`
- 2–4 log tiles on the dashboard: error rate, top noisy sources, log-level distribution, and a sample log record table
- `logSource` populated in `asset-manifest.json`

### Anti-pattern to avoid

Do not look at the existing `dashboards/` folder and reason "Dell EMC had no logs, so this technology probably doesn't need them either." Each technology is independent. The only valid inputs to the log decision are the technology's own nature, its Hub page, and your knowledge of what it produces.
