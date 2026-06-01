#!/usr/bin/env bash
# arcads_talking.sh — Legacy Talking Actors flow: named actor + script (+ optional custom audio).
#
# This is the flow that powers the Arcads UI you see in the browser (Douglas, Olivia, etc.).
# Use when you want a polished pre-trained face rather than supplying your own actor image.
#
# Usage:
#   arcads_talking.sh --actor-id <uuid> --script "..." [options]
#
# Options:
#   --actor-id UUID       Pick via arcads_actors.sh.
#   --script TEXT         What the actor says.
#   --audio PATH          Optional: your own voiceover (lip-sync to it). Skip = Arcads generates voice.
#   --situation-id UUID   Optional: pre-built scene from /v1/situations.
#   --aspect 9:16|16:9|1:1   Default 9:16.
#   --product-id UUID     Override default product.
#   --slug NAME           Output filename slug.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a; source "$ROOT/.env"; set +a
fi
BASE="${ARCADS_BASE_URL:-https://external-api.arcads.ai}"
: "${ARCADS_API_KEY:?ARCADS_API_KEY missing — edit $ROOT/.env}"

ACTOR_ID=""
SCRIPT_TEXT=""
AUDIO=""
SITUATION_ID=""
ASPECT="9:16"
PRODUCT_ID="${ARCADS_DEFAULT_PRODUCT_ID:-}"
SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --actor-id) ACTOR_ID="$2"; shift 2 ;;
    --script) SCRIPT_TEXT="$2"; shift 2 ;;
    --audio) AUDIO="$2"; shift 2 ;;
    --situation-id) SITUATION_ID="$2"; shift 2 ;;
    --aspect) ASPECT="$2"; shift 2 ;;
    --product-id) PRODUCT_ID="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$ACTOR_ID" ]]; then
  echo "--actor-id required. List actors: arcads_actors.sh" >&2; exit 1
fi
if [[ -z "$SCRIPT_TEXT" ]]; then
  echo "--script required." >&2; exit 1
fi

# Upload audio if provided
AUDIO_PATH=""
if [[ -n "$AUDIO" ]]; then
  if [[ ! -f "$AUDIO" ]]; then echo "Audio file not found: $AUDIO" >&2; exit 1; fi
  echo "Uploading audio..." >&2
  AUDIO_PATH="$("$ROOT/scripts/arcads_upload.sh" "$AUDIO")"
  echo "Audio uploaded -> $AUDIO_PATH" >&2
fi

# Auto-create product if needed
if [[ -z "$PRODUCT_ID" ]]; then
  echo "No product ID set. Creating default..." >&2
  prod_resp="$(curl -sS -X POST -u "$ARCADS_API_KEY:" \
    -H "Content-Type: application/json" \
    -d '{"name":"ads-skill default","description":"Auto-created","targetAudience":"general","mainFeatures":["UGC ads"],"painPoint":"none","perceived":"trusted"}' \
    "$BASE/v1/products")"
  PRODUCT_ID="$(printf '%s' "$prod_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("id") or d.get("productId") or "")')"
  [[ -z "$PRODUCT_ID" ]] && { echo "Failed to create product: $prod_resp" >&2; exit 1; }
fi

# Build the script body. videos[] structure: each video specifies actor + optional audio + situation.
SLUG="${SLUG:-talking-$(date +%s)}"
BODY="$(python3 - "$SLUG" "$SCRIPT_TEXT" "$ACTOR_ID" "$AUDIO_PATH" "$SITUATION_ID" "$ASPECT" "$PRODUCT_ID" <<'PY'
import json, sys
slug, text, actor_id, audio_path, situation_id, aspect, product_id = sys.argv[1:8]
video = {"actorId": actor_id, "aspectRatio": aspect}
if audio_path: video["audioUrl"] = audio_path
if situation_id: video["situationId"] = situation_id
body = {"name": slug, "text": text, "productId": product_id, "videos": [video]}
print(json.dumps(body))
PY
)"

echo "Creating script..." >&2
script_resp="$(curl -sS -X POST -u "$ARCADS_API_KEY:" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$BASE/v1/scripts")"

SCRIPT_ID="$(printf '%s' "$script_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("id") or "")')"
if [[ -z "$SCRIPT_ID" ]]; then
  echo "Failed to create script. Response:" >&2; echo "$script_resp" >&2; exit 1
fi
echo "Script $SCRIPT_ID created." >&2

echo "Triggering generation..." >&2
curl -sS -X POST -u "$ARCADS_API_KEY:" "$BASE/v1/scripts/$SCRIPT_ID/generate" >/dev/null

# Poll videos endpoint
URL=""
for i in $(seq 1 120); do
  vids_resp="$(curl -sS -u "$ARCADS_API_KEY:" "$BASE/v1/scripts/$SCRIPT_ID/videos")"
  status="$(printf '%s' "$vids_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); items=d if isinstance(d,list) else d.get("items") or []; print((items[0] or {}).get("status","") if items else "")' )"
  URL="$(printf '%s' "$vids_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); items=d if isinstance(d,list) else d.get("items") or []; print((items[0] or {}).get("videoUrl") or (items[0] or {}).get("url","") if items else "")')"
  printf '[%02d] status=%s\n' "$i" "$status" >&2
  case "$status" in
    generated|uploaded|completed|ready) [[ -n "$URL" ]] && break ;;
    failed|error) echo "Failed: $vids_resp" >&2; exit 1 ;;
  esac
  sleep 5
done

[[ -z "$URL" ]] && { echo "Timed out." >&2; exit 1; }

OUT_DIR="$ROOT/output"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/$(date +%Y-%m-%d_%H%M%S)_${SLUG}.mp4"
curl -sSL "$URL" -o "$OUT_FILE"
echo "$OUT_FILE"
