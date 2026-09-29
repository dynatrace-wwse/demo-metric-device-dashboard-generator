export default async function () {
  const EVENT_PROVIDER = "zscaler.zia.event.provider";
  const TOTAL_EVENTS = 3600;
  const BATCH_SIZE = 500;
  const now = Date.now();
  const sites = [
    { site: "us-west", region: "na-west", lat: 37.7749, lon: -122.4194 },
    { site: "us-east", region: "na-east", lat: 40.7128, lon: -74.0060 },
    { site: "eu-central", region: "eu-central", lat: 50.1109, lon: 8.6821 },
    { site: "ap-south", region: "ap-south", lat: 19.0760, lon: 72.8777 },
    { site: "ap-southeast", region: "ap-southeast", lat: 1.3521, lon: 103.8198 }
  ];
  const userSegments = ["engineering", "finance", "sales", "support", "exec"];
  const appCategories = ["saas", "web", "collaboration", "development", "file-sharing"];
  const actions = ["allow", "allow", "allow", "block", "challenge"];
  const severities = ["low", "medium", "high", "critical"];
  const outcomes = ["ok", "ok", "ok", "degraded", "failed"];
  const eventTypes = [
    "zia.tunnel.health",
    "zia.web.transaction",
    "zia.security.threat",
    "zia.policy.decision",
    "zia.dns.lookup",
    "zia.user.experience",
    "zia.ssl.inspection",
    "zia.bandwidth.anomaly",
    "zia.app.performance",
    "zia.auth.posture",
    "zia.location.load",
    "zia.policy.hit",
    "zia.ipsec.status",
    "zia.private.app.access",
    "zia.sandbox.verdict",
    "zia.edge.health"
  ];

  const rand = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const rnd = (min, max) => Math.random() * (max - min) + min;
  const int = (min, max) => Math.floor(rnd(min, max + 1));

  const events = [];
  for (let i = 0; i < TOTAL_EVENTS; i++) {
    const loc = rand(sites);
    const et = eventTypes[i % eventTypes.length];
    const ts = new Date(now - int(0, 30 * 60 * 1000)).toISOString();
    const base = {
      "event.provider": EVENT_PROVIDER,
      "event.type": et,
      timestamp: ts,
      site: loc.site,
      pop_region: loc.region,
      zia_node: `${loc.site}-node-${int(1, 12)}`,
      user_segment: rand(userSegments),
      app_category: rand(appCategories),
      outcome: rand(outcomes),
      throughput_mbps: Number(rnd(40, 2500).toFixed(2)),
      tunnel_latency_ms: Number(rnd(8, 180).toFixed(2)),
      packet_loss_pct: Number(rnd(0.01, 3.2).toFixed(2)),
      dns_lookup_ms: Number(rnd(8, 220).toFixed(2)),
      user_experience_score: Number(rnd(58, 99.8).toFixed(1)),
      policy_action: rand(actions),
      threat_severity: rand(severities),
      threat_count: int(0, 7),
      "geo.location.latitude": loc.lat,
      "geo.location.longitude": loc.lon
    };
    events.push(base);
  }

  let sent = 0;
  for (let i = 0; i < events.length; i += BATCH_SIZE) {
    const batch = events.slice(i, i + BATCH_SIZE);
    const res = await fetch("/platform/classic/environment-api/v2/bizevents/ingest", {
      method: "POST",
      headers: { "content-type": "application/json; charset=utf-8" },
      body: JSON.stringify(batch)
    });
    if (!res.ok) {
      const body = await res.text();
      throw new Error(`BizEvents ingest failed: ${res.status} ${body}`);
    }
    sent += batch.length;
  }

  return { status: "ok", sent };
}
