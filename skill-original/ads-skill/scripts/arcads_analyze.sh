#!/usr/bin/env bash
# arcads_analyze.sh — Forensic deconstruction prep for a competitor ad.
# Extracts keyframes + audio + a stub analysis.md template that Claude fills in.
#
# Usage:
#   arcads_analyze.sh <video-path> [--fps N] [--slug NAME]
#
# Defaults:
#   --fps 1   (1 frame per second; bump to 2 for fast-cut ads, drop to 0.5 for >30s)
#   --slug   derived from filename
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIDEO=""
FPS="1"
SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fps) FPS="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *)
      if [[ -z "$VIDEO" ]]; then VIDEO="$1"; shift; else echo "Unknown: $1" >&2; exit 1; fi ;;
  esac
done

if [[ -z "$VIDEO" || ! -f "$VIDEO" ]]; then
  echo "Usage: $0 <video-path> [--fps N] [--slug NAME]" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not installed. Install with: brew install ffmpeg" >&2
  exit 1
fi

# Derive slug from filename if not given
if [[ -z "$SLUG" ]]; then
  base="$(basename "$VIDEO")"
  SLUG="${base%.*}"
  SLUG="$(printf '%s' "$SLUG" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
fi

OUT_DIR="$ROOT/analysis/${SLUG}"
mkdir -p "$OUT_DIR/frames"

echo "Analyzing: $VIDEO" >&2
echo "Output:    $OUT_DIR" >&2

# Get duration and aspect
DURATION="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null || echo "0")"
DURATION_INT="$(printf '%.0f' "$DURATION")"
WIDTH="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$VIDEO" 2>/dev/null || echo "?")"
HEIGHT="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$VIDEO" 2>/dev/null || echo "?")"

# Aspect ratio guess
if [[ "$WIDTH" != "?" && "$HEIGHT" != "?" ]]; then
  if (( WIDTH < HEIGHT )); then ASPECT="9:16"
  elif (( WIDTH > HEIGHT )); then ASPECT="16:9"
  else ASPECT="1:1"
  fi
else
  ASPECT="?"
fi

echo "Duration: ${DURATION_INT}s   Aspect: $ASPECT (${WIDTH}x${HEIGHT})" >&2

# Extract frames at the requested fps
echo "Extracting frames at ${FPS} fps..." >&2
ffmpeg -y -i "$VIDEO" -vf "fps=$FPS" "$OUT_DIR/frames/frame_%03d.png" -hide_banner -loglevel error

# Extract audio as mp3
echo "Extracting audio..." >&2
ffmpeg -y -i "$VIDEO" -vn -acodec libmp3lame -q:a 4 "$OUT_DIR/audio.mp3" -hide_banner -loglevel error

# Count frames
FRAME_COUNT="$(ls "$OUT_DIR/frames" | wc -l | tr -d ' ')"

# Generate stub analysis.md
STUB="$OUT_DIR/analysis.md"
cat > "$STUB" <<EOF
# Analysis: ${SLUG}

Source: ${VIDEO}
Duration: ${DURATION_INT}s
Aspect: ${ASPECT} (${WIDTH}x${HEIGHT})
Frames extracted: ${FRAME_COUNT} at ${FPS} fps
Audio: audio.mp3

> Claude: read every frame in \`frames/\` and fill in the sections below. Transcribe burned-in captions verbatim. If audio dialogue is unclear from captions alone, ask the user to play the clip and paste the spoken script.

## Beats (verbatim transcript + visual)

### [0–?s] HOOK
Spoken: "..."
Visual: ...
Camera: ...
Why it works: ...

### [?–?s] SHOW
Spoken: "..."
Visual: ...

### [?–?s] PROOF
Spoken: "..."
Visual: ...

### [?–?s] CTA
Spoken: "..."
Visual: ...

## Why this ad works (brutal critique)

- Pattern interrupt:
- Concrete claim:
- Emotional payoff:
- Actor moment:
- First-2s test:

## Recreation prompt (target product: __________)

[Visual]

[Audio] Spoken lines (noun-swapped):
1. "..."
2. "..."

[Pacing]

## Arcads input map

- Image: <path or "skip">
- Audio: <path or "let Arcads generate">
- Video: <path or "skip">
- Actor: <actor-id or "custom from image">
- Model: <seedance-2.0 / veo31 / talking-actors>
- Aspect: ${ASPECT}
- Duration: ${DURATION_INT}s
EOF

echo "" >&2
echo "Done. Open these to start the breakdown:" >&2
echo "  $OUT_DIR/frames/         ($FRAME_COUNT PNGs)" >&2
echo "  $OUT_DIR/audio.mp3" >&2
echo "  $STUB" >&2
echo "" >&2
echo "Next: Claude reads the frames and fills in analysis.md." >&2

# Print the output dir so it can be piped
printf '%s\n' "$OUT_DIR"
