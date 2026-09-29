export default async function () {
  const TOTAL_LOGS = 1800;
  const BATCH_SIZE = 300;
  const now = Date.now();

  const sites = [
    { site: "us-west", region: "na-west", nodePrefix: "usw" },
    { site: "us-east", region: "na-east", nodePrefix: "use" },
    { site: "eu-central", region: "eu-central", nodePrefix: "euc" },
    { site: "ap-south", region: "ap-south", nodePrefix: "aps" },
    { site: "ap-southeast", region: "ap-southeast", nodePrefix: "apse" }
  ];

  const severities = ["INFO", "INFO", "INFO", "WARN", "ERROR"];
  const actions = ["allow", "allow", "allow", "block", "challenge"];
  const categories = ["dns", "policy", "tunnel", "threat", "ssl", "auth"];

  const rand = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const int = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

  const logs = [];
  for (let i = 0; i < TOTAL_LOGS; i++) {
    const loc = rand(sites);
    const level = rand(severities);
    const action = rand(actions);
    const category = rand(categories);
    const node = `${loc.nodePrefix}-node-${int(1, 12)}`;
    const ts = new Date(now - int(0, 30 * 60 * 1000)).toISOString();
    const latency = int(8, 220);
    const dns = int(6, 240);
    const threatScore = int(0, 100);

    const message = `[ZIA] ${category} event at ${loc.site}; action=${action}; node=${node}; latency_ms=${latency}; dns_ms=${dns}; threat_score=${threatScore}`;

    logs.push({
      timestamp: ts,
      content: message,
      severity: level,
      loglevel: level,
      "log.source": "zscaler.zia.synthetic",
      "event.provider": "zscaler.zia.event.provider",
      site: loc.site,
      pop_region: loc.region,
      zia_node: node,
      policy_action: action,
      event_category: category,
      tunnel_latency_ms: latency,
      dns_lookup_ms: dns,
      threat_score: threatScore
    });
  }

  let sent = 0;
  for (let i = 0; i < logs.length; i += BATCH_SIZE) {
    const batch = logs.slice(i, i + BATCH_SIZE);
    const body = JSON.stringify(batch);
    const res = await fetch("/platform/classic/environment-api/v2/logs/ingest", {
      method: "POST",
      headers: { "content-type": "application/json; charset=utf-8" },
      body
    });
    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Log ingest failed: ${res.status} ${err}`);
    }
    sent += batch.length;
  }

  return { status: "ok", sent, source: "zscaler.zia.synthetic" };
}
