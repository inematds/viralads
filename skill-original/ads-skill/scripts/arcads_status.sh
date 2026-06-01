#!/usr/bin/env bash
# Poll an Arcads job status. Auto-routes to /v1/videos/{id} or /v1/assets/{id}.
# Usage: arcads_status.sh <job-id> [--model <model>]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a; source "$ROOT/.env"; set +a
fi
BASE="${ARCADS_BASE_URL:-https://external-api.arcads.ai}"
: "${ARCADS_API_KEY:?ARCADS_API_KEY missing}"

ID="${1:-}"
MODEL=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$ID" ]]; then
  echo "Usage: $0 <job-id> [--model <model>]" >&2
  exit 1
fi

# Route to the right endpoint based on model
case "$MODEL" in
  seedance-2.0|seedance|b-roll|scene|nano-banana|nano-banana-2)
    endpoint="/v1/assets/$ID"
    ;;
  sora2|sora2-pro|veo31|kling-2.6|kling-3.0|grok-video|"")
    endpoint="/v1/videos/$ID"
    ;;
  *)
    endpoint="/v1/videos/$ID"
    ;;
esac

curl -sS -u "$ARCADS_API_KEY:" "$BASE$endpoint"
echo
