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
