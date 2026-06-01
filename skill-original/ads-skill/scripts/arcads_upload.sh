#!/usr/bin/env bash
# Upload a local file to Arcads via presigned URL. Prints the filePath to stdout.
# Usage: arcads_upload.sh <local-file>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a; source "$ROOT/.env"; set +a
fi
BASE="${ARCADS_BASE_URL:-https://external-api.arcads.ai}"
: "${ARCADS_API_KEY:?ARCADS_API_KEY missing — edit .env}"

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: $0 <local-file>" >&2
  exit 1
fi

# Detect MIME type (lowercase ext for case match — bash 3.2 compatible)
ext="$(printf '%s' "${FILE##*.}" | tr '[:upper:]' '[:lower:]')"
case "$ext" in
  jpg|jpeg) mime="image/jpeg" ;;
  png)      mime="image/png" ;;
  mp4)      mime="video/mp4" ;;
  mp3)      mime="audio/mpeg" ;;
  wav)      mime="audio/wav" ;;
  *) echo "Unsupported extension: $ext (use jpg/png/mp4/mp3/wav)" >&2; exit 1 ;;
esac

# Step 1: get presigned URL
resp="$(curl -sS -X POST -u "$ARCADS_API_KEY:" \
  -H "Content-Type: application/json" \
  -d "{\"fileType\": \"$mime\"}" \
  "$BASE/v1/file-upload/get-presigned-url")"

presigned_url="$(printf '%s' "$resp" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("presignedUrl",""))')"
file_path="$(printf '%s' "$resp" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("filePath",""))')"

if [[ -z "$presigned_url" || -z "$file_path" ]]; then
  echo "Failed to get presigned URL. Response: $resp" >&2
  exit 1
fi

# Step 2: PUT the file
http_code="$(curl -sS -o /dev/null -w "%{http_code}" -X PUT -H "Content-Type: $mime" --data-binary "@$FILE" "$presigned_url")"
if [[ "$http_code" != "200" && "$http_code" != "204" ]]; then
  echo "Upload failed (HTTP $http_code)" >&2
  exit 1
fi

# Step 3: emit the filePath for the next stage
printf '%s\n' "$file_path"
