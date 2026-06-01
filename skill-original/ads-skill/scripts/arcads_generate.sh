#!/usr/bin/env bash
# arcads_generate.sh — One-shot Arcads ad generator.
# Uploads a reference image, calls /v2/videos/generate, polls until ready,
# and downloads the finished MP4 into ~/Desktop/ads-skill/output/.
#
# Usage:
#   arcads_generate.sh --prompt "..." [options]
#
# Options:
#   --image PATH          Reference image (product or actor still). Recommended.
#   --prompt TEXT         Full prompt with visuals + dialogue. Required.
#   --model NAME          seedance-2.0 (default) | veo31 | sora2 | kling-3.0 | ...
#   --aspect RATIO        9:16 (default) | 16:9 | 1:1
#   --duration N          Seconds. Default 15 (seedance), 8 (veo), 12 (sora).
#   --resolution R        720p (default) | 1080p
#   --product-id UUID     Override the default product. Reads ARCADS_DEFAULT_PRODUCT_ID otherwise.
#   --no-audio            Disable audio (default: audio on for seedance/veo/sora).
#   --slug NAME           Short name for the output file. Default: timestamp.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a; source "$ROOT/.env"; set +a
fi
BASE="${ARCADS_BASE_URL:-https://external-api.arcads.ai}"
: "${ARCADS_API_KEY:?ARCADS_API_KEY missing — edit $ROOT/.env}"

IMAGE=""
PROMPT=""
MODEL="seedance-2.0"
ASPECT="9:16"
DURATION=""
RESOLUTION="720p"
PRODUCT_ID="${ARCADS_DEFAULT_PRODUCT_ID:-}"
AUDIO="true"
SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --aspect) ASPECT="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --resolution) RESOLUTION="$2"; shift 2 ;;
    --product-id) PRODUCT_ID="$2"; shift 2 ;;
    --no-audio) AUDIO="false"; shift ;;
    --slug) SLUG="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  echo "--prompt is required." >&2
  exit 1
fi

# Model-aware duration defaults
if [[ -z "$DURATION" ]]; then
  case "$MODEL" in
    veo31) DURATION=8 ;;
    sora2|sora2-pro) DURATION=12 ;;
    seedance-2.0) DURATION=15 ;;
    *) DURATION=10 ;;
  esac
fi

# Auto-create a product if none given
if [[ -z "$PRODUCT_ID" ]]; then
  echo "No product ID set. Creating a default 'ads-skill' product..." >&2
  prod_resp="$(curl -sS -X POST -u "$ARCADS_API_KEY:" \
    -H "Content-Type: application/json" \
    -d '{"name":"ads-skill default","description":"Auto-created by ads-skill","targetAudience":"general","mainFeatures":["UGC ads"],"painPoint":"none","perceived":"trusted"}' \
    "$BASE/v1/products")"
  PRODUCT_ID="$(printf '%s' "$prod_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("id") or d.get("productId") or "")')"
  if [[ -z "$PRODUCT_ID" ]]; then
    echo "Failed to create product. Response: $prod_resp" >&2; exit 1
  fi
  echo "Created product $PRODUCT_ID. Add ARCADS_DEFAULT_PRODUCT_ID=$PRODUCT_ID to .env to skip this next time." >&2
fi

# Optional image upload via presigned URL
REF_PATH=""
if [[ -n "$IMAGE" ]]; then
  if [[ ! -f "$IMAGE" ]]; then
    echo "Image not found: $IMAGE" >&2; exit 1
  fi
  echo "Uploading $IMAGE ..." >&2
  REF_PATH="$("$ROOT/scripts/arcads_upload.sh" "$IMAGE")"
  if [[ -z "$REF_PATH" ]]; then
    echo "Upload returned empty filePath." >&2; exit 1
  fi
  echo "Uploaded -> $REF_PATH" >&2
fi

# Build the generation body. Veo/Kling use startFrame; Seedance/Sora use referenceImages.
case "$MODEL" in
  veo31|kling-3.0|kling-2.6)
    ref_key="startFrame"; ref_value_is_array=false ;;
  *)
    ref_key="referenceImages"; ref_value_is_array=true ;;
esac

# Compose JSON with Python so we don't fight quoting
GEN_JSON="$(python3 - "$MODEL" "$PRODUCT_ID" "$PROMPT" "$ASPECT" "$DURATION" "$RESOLUTION" "$AUDIO" "$REF_PATH" "$ref_key" "$ref_value_is_array" <<'PY'
import json, sys
model, pid, prompt, aspect, duration, resolution, audio, ref, ref_key, is_array = sys.argv[1:11]
body = {
  "model": model,
  "productId": pid,
  "prompt": prompt,
  "aspectRatio": aspect,
  "duration": int(duration),
  "resolution": resolution,
  "audioEnabled": audio == "true",
}
if ref:
  body[ref_key] = [ref] if is_array == "true" else ref
print(json.dumps(body))
PY
)"

echo "Submitting generation (model=$MODEL, duration=${DURATION}s, aspect=$ASPECT)..." >&2
gen_resp="$(curl -sS -X POST -u "$ARCADS_API_KEY:" \
  -H "Content-Type: application/json" \
  -d "$GEN_JSON" \
  "$BASE/v2/videos/generate")"

JOB_ID="$(printf '%s' "$gen_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("id") or d.get("videoId") or d.get("assetId") or "")')"
if [[ -z "$JOB_ID" ]]; then
  echo "No job ID returned. Response:" >&2
  echo "$gen_resp" >&2
  exit 1
fi
echo "Job $JOB_ID queued. Polling..." >&2

# Route polling endpoint by model
case "$MODEL" in
  seedance-2.0|seedance) poll_path="/v1/assets/$JOB_ID" ;;
  *) poll_path="/v1/videos/$JOB_ID" ;;
esac

URL=""
for i in $(seq 1 120); do
  status_resp="$(curl -sS -u "$ARCADS_API_KEY:" "$BASE$poll_path")"
  status="$(printf '%s' "$status_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("status") or d.get("videoStatus") or "")')"
  URL="$(printf '%s' "$status_resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("url") or d.get("videoUrl") or "")')"
  printf '[%02d] status=%s\n' "$i" "$status" >&2
  case "$status" in
    generated|uploaded|completed|ready)
      [[ -n "$URL" ]] && break ;;
    failed|error)
      echo "Job failed. Response: $status_resp" >&2; exit 1 ;;
  esac
  sleep 5
done

if [[ -z "$URL" ]]; then
  echo "Timed out waiting for video. Last response above." >&2
  exit 1
fi

# Download
OUT_DIR="$ROOT/output"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
SLUG="${SLUG:-$MODEL}"
OUT_FILE="$OUT_DIR/${STAMP}_${SLUG}.mp4"

echo "Downloading -> $OUT_FILE" >&2
curl -sSL "$URL" -o "$OUT_FILE"

# Log a sidecar JSON with the job metadata + credits charged
META_FILE="${OUT_FILE%.mp4}.json"
printf '%s' "$status_resp" > "$META_FILE"

echo "$OUT_FILE"
