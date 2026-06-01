#!/usr/bin/env bash
# arcads_actors.sh — List available Arcads named actors (Douglas, Olivia, ...).
# Filters: --gender male|female --age 20s|30s|... --skin-tone light|medium|dark --free-speech true|false
#
# Use this to pick an actorId for arcads_talking.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a; source "$ROOT/.env"; set +a
fi
BASE="${ARCADS_BASE_URL:-https://external-api.arcads.ai}"
: "${ARCADS_API_KEY:?ARCADS_API_KEY missing — edit $ROOT/.env}"

PAGE="1"
SIZE="50"
GENDER=""
AGE=""
SKIN=""
FREE=""
RAW="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --page) PAGE="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --gender) GENDER="$2"; shift 2 ;;
    --age) AGE="$2"; shift 2 ;;
    --skin-tone) SKIN="$2"; shift 2 ;;
    --free-speech) FREE="$2"; shift 2 ;;
    --raw) RAW="true"; shift ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

query="page=$PAGE&pageSize=$SIZE"
[[ -n "$GENDER" ]] && query+="&gender=$GENDER"
[[ -n "$AGE" ]] && query+="&age=$AGE"
[[ -n "$SKIN" ]] && query+="&skinTone=$SKIN"
[[ -n "$FREE" ]] && query+="&freeSpeech=$FREE"

resp="$(curl -sS -u "$ARCADS_API_KEY:" "$BASE/v1/actors?$query")"

if [[ "$RAW" == "true" ]]; then
  printf '%s\n' "$resp"
  exit 0
fi

# Pretty-print: id, name, gender, age, skinTone
python3 - "$resp" <<'PY'
import json, sys
try:
  data = json.loads(sys.argv[1])
except Exception as e:
  print(f"Failed to parse response: {e}", file=sys.stderr); sys.exit(1)

items = data.get("items") or data.get("actors") or data
if isinstance(items, list):
  rows = items
else:
  rows = []

if not rows:
  print("(no actors returned — check filters or your API plan)", file=sys.stderr)
  print(json.dumps(data, indent=2), file=sys.stderr)
  sys.exit(0)

# Header
print(f"{'ACTOR_ID':<40} {'NAME':<18} {'GENDER':<8} {'AGE':<8} {'SKIN':<8}")
for a in rows:
  aid = (a.get('id') or a.get('actorId') or '')[:38]
  name = (a.get('name') or '')[:16]
  gender = (a.get('gender') or '')[:6]
  age = str(a.get('age') or '')[:6]
  skin = (a.get('skinTone') or '')[:6]
  print(f"{aid:<40} {name:<18} {gender:<8} {age:<8} {skin:<8}")

total = data.get('count')
if total:
  print(f"\n(showing page {data.get('page','?')} — total {total})")
PY
