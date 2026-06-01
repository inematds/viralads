#!/usr/bin/env bash
# Verify Arcads API connectivity. Does not print the API key.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT/.env"
  set +a
fi

BASE="${ARCADS_BASE_URL:-https://external-api.arcads.ai}"

if [[ -z "${ARCADS_API_KEY:-}" ]] || [[ "$ARCADS_API_KEY" == "your_key_here" ]]; then
  echo "No ARCADS_API_KEY set. Edit $ROOT/.env (copy from .env.example) and paste your key." >&2
  echo "Get a key at: https://app.arcads.ai/settings/api" >&2
  exit 1
fi

code="$(curl -sS -o /dev/null -w "%{http_code}" -u "$ARCADS_API_KEY:" "$BASE/v1/products")"
echo "GET /v1/products -> HTTP $code"

if [[ "$code" != "200" ]]; then
  echo "Auth failed (HTTP $code). Re-check your key in .env. The key is HTTP Basic username, empty password." >&2
  exit 1
fi

echo "OK - connection verified."
