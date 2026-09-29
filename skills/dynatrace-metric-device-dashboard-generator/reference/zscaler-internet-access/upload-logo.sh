#!/usr/bin/env bash
# Upload a logo image to Dynatrace Document Store via dtctl exec function.
#
# Uses FormData + Blob (multipart/form-data) — the only format the Document API
# accepts for binary content. dtctl apply with !!binary YAML does NOT correctly
# transmit binary image data and results in a broken document.
#
# Usage:
#   ./upload-logo.sh                                      # nvidia-logo.png -> nvidia-dcgm-logo
#   ./upload-logo.sh logo.png my-tech-logo "My Logo"
#
# Arguments:
#   $1  Image file  (default: nvidia-logo.png)
#   $2  Document ID (default: nvidia-dcgm-logo)
#   $3  Description (default: Dashboard logo)

set -euo pipefail

FILE="${1:-$(dirname "$0")/nvidia-logo.png}"
DOC_ID="${2:-nvidia-dcgm-logo}"
DESCRIPTION="${3:-Dashboard logo}"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: Image file not found: $FILE" >&2
  exit 1
fi

# Detect MIME type from extension
MIME_TYPE="image/png"
case "${FILE##*.}" in
  jpg|jpeg) MIME_TYPE="image/jpeg" ;;
  svg)      MIME_TYPE="image/svg+xml" ;;
  webp)     MIME_TYPE="image/webp" ;;
esac

FILENAME=$(basename "$FILE")
BASE64=$(base64 < "$FILE" | tr -d '\n')

TMP_JS=$(mktemp /tmp/dtlogo.XXXXXX.js)
trap 'rm -f "$TMP_JS"' EXIT

cat > "$TMP_JS" << 'JSEOF'
export default async function({ docId, name, description, mimeType, filename, base64 }) {
  const binaryStr = atob(base64);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }
  const blob = new Blob([bytes], { type: mimeType });

  // Check if document already exists
  const metaRes = await fetch(`/platform/document/v1/documents/${docId}/metadata`);

  if (metaRes.ok) {
    // Document exists — update content only (PUT requires optimistic-locking-version)
    const meta = await metaRes.json();
    const version = meta.version;
    const formData = new FormData();
    formData.append('content', blob, filename);
    const res = await fetch(
      `/platform/document/v1/documents/${docId}/content?optimistic-locking-version=${version}`,
      { method: 'PUT', body: formData }
    );
    const body = await res.text();
    return { action: 'updated', status: res.status, body };
  } else {
    // Document does not exist — create it, then upload content
    const createRes = await fetch('/platform/document/v1/documents', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: docId, name, type: 'image', isPrivate: false, description }),
    });
    if (!createRes.ok) {
      const err = await createRes.text();
      return { action: 'create_failed', status: createRes.status, body: err };
    }
    const created = await createRes.json();
    const version = created.version;
    const formData = new FormData();
    formData.append('content', blob, filename);
    const res = await fetch(
      `/platform/document/v1/documents/${docId}/content?optimistic-locking-version=${version}`,
      { method: 'PUT', body: formData }
    );
    const body = await res.text();
    return { action: 'created', status: res.status, body };
  }
}
JSEOF

echo "Uploading $FILE as document '$DOC_ID'..."
dtctl exec function -f "$TMP_JS" \
  --payload "{\"docId\":\"$DOC_ID\",\"name\":\"$DOC_ID\",\"description\":\"$DESCRIPTION\",\"mimeType\":\"$MIME_TYPE\",\"filename\":\"$FILENAME\",\"base64\":\"$BASE64\"}" \
  --plain

echo "defaultSource: /platform/document/v1/documents/$DOC_ID/content"
