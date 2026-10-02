# Inputs — Detailed Handling

## Logo embedding

**Use the `image` tile type — confirmed schema:**
```json
{
  "type": "image",
  "imageSettings": {
    "defaultSource": "/platform/document/v1/documents/<document-id>/content",
    "sizing": "fit",
    "horizontalAlignment": "center",
    "verticalAlignment": "center"
  }
}
```

Images are stored as Dynatrace Documents (`type: image`). They **must** be uploaded
via `dtctl exec function` using a JavaScript `FormData` + `Blob` multipart request.

**DO NOT use `dtctl apply` with `!!binary` YAML** — this does not correctly transmit
binary content to the Document API. It creates the document record but the image
payload is lost, resulting in a broken/unrenderable image tile.

**To upload a logo — use `upload-logo.sh`:**

```bash
# Download the logo first
curl -sL "<logo-url>" -o <technology>-logo.png

# Upload to Dynatrace Document Store via dtctl exec function
bash upload-logo.sh <technology>-logo.png <technology>-logo "Technology Dashboard Logo"
# e.g.
bash upload-logo.sh nvidia-logo.png nvidia-dcgm-logo "NVIDIA DCGM Dashboard Logo"
```

`upload-logo.sh` uses `dtctl exec function` with an inline JS script that:
1. Checks whether the document already exists (`GET /metadata`).
2. If it exists: updates content via `PUT /documents/{id}/content?optimistic-locking-version=<n>`.
3. If it doesn't exist: creates the document via `POST /documents` (JSON metadata), then uploads content via `PUT`.

The script handles both create and update, and is idempotent — safe to re-run.

Copy `upload-logo.sh` from `scripts/` into each `dashboards/<Technology>/` folder.

`sizing`: `"fit"` (letterbox, preserves aspect ratio) or `"fill"` (crops to fill tile).
Document ID convention: `<technology>-logo` (e.g. `nvidia-dcgm-logo`).

---

## Logo URL — VERIFY BEFORE EMBEDDING

Never embed a logo via URL without first confirming the URL serves an image to a
cross-origin browser. Run:

```bash
curl -sIL -A 'Mozilla/5.0' -H 'Referer: https://apps.dynatrace.com' '<URL>' \
  | grep -E '^(HTTP|content-type)'
```

Required: final `HTTP/2 200` AND `content-type: image/(png|svg+xml|jpeg|webp)`.
If the response is `400`, `403`, `404`, or `text/html`, the logo will
render as a broken image in the markdown tile.

Known behavior:
- `upload.wikimedia.org/wikipedia/commons/...` — files frequently get
  renamed (e.g. `Walmart_logo.svg` → `Walmart logo (2008).svg` on a
  hashed path). Plain hot-links return `400` from Varnish for non-wiki
  referers. Resolve current URL via the Commons API:
  `https://commons.wikimedia.org/w/api.php?action=query&titles=File:<Name>.svg&prop=imageinfo&iiprop=url&format=json`.
- `1000logos.net` and `logos-world.net` — allow hot-linking, return
  `image/png`. Reliable fallback for major brands.
- `www.vectorlogo.zone/logos/<vendor>/<vendor>-ar21.svg` — reliable SVG source
  for networking/enterprise vendors (Cisco, Juniper, Palo Alto, etc.) that lack
  good PNG sources. Returns `image/svg+xml`. Use as fallback when the above fail.
- Corporate `*.com` CDNs (e.g. `i5.walmartimages.com`,
  `corporate.<brand>.com`) — usually unstable; require auth or rotate.
  Avoid unless verified.

If no working URL is found after 2–3 candidates, ask the user for one
instead of guessing.

## Dynatrace Hub extension link

When the user provides a link to a Dynatrace Hub extension page:

1. Fetch and read the page.
2. If the page **lists specific metric names or metric keys**, use **only
   those metrics** on the dashboard and in the injector. Do not invent or
   supplement with metrics not listed on the page.
3. If the page **mentions logs** (log ingest, log processing, log events),
   treat log generation as **required**, not optional. Include a log injector
   and log-based tiles on the dashboard.
4. Note the extension version, metric descriptions, and any dimension/field
   names the extension documents — use them verbatim in the event schema.

## Non-Hub technology link

When the user provides a link to a technology vendor page, docs site, or any
non-Hub URL:

1. Fetch and read the page.
2. Extract any metric names, counters, dimensions, or observable signals
   described.
3. From those, choose the subset most relevant for operational monitoring
   (performance, reliability, capacity, errors). Document the selection
   rationale in `LEARNINGS.md`.
4. If the page mentions logs, treat log generation as required.
5. Do not use metrics not derivable from the linked page or the Hub search.
