export default async function () {
  // Smartscape entities are created from BizEvents via OpenPipeline. This task is informational.
  return { status: "ok", message: "Entity extraction handled by OpenPipeline smartscapeNode processor." };
}
