---
name: ads-skill
description: Forensically deconstruct viral UGC ads and rebuild them with Arcads — extract frames + transcript from a competitor video, identify the hook/show/proof/CTA structure, then recreate it for a new product via image / audio / video / actor inputs. Supports Seedance 2.0, Veo 3.1, Sora 2, Kling, and the legacy Talking Actors flow with named actors (Douglas, Olivia, etc.) and custom voiceovers. Trigger when the user says "analyze this ad", "break down this video", "recreate this competitor ad", "make me an ad like this", "Arcads", "talking actor ad", "UGC video ad", or hands over a competitor MP4 to copy. Backend handles ffmpeg extraction, presigned upload, model routing, polling, and download — never freehand the API.
---

# Ads Skill — Arcads + Viral Ad Deconstruction

This skill does two things:

1. **Reverse-engineers** a viral UGC ad — frame by frame, line by line — and produces a recreation prompt that swaps only the brand-specific nouns.
2. **Generates** the recreated ad through the Arcads API, accepting any combination of four inputs: **image, audio, video, actor**.

The whole concept: don't generate blind. Copy proven structure. Swap the variables.

---

## The two modes

### Mode A — Analyze first, then generate (default for competitor recreation)

```
1. User hands over a competitor video (MP4 or Meta Ad Library URL).
2. scripts/arcads_analyze.sh extracts frames (1/sec PNGs) + audio (MP3).
3. Claude reads the frames, transcribes the audio (use burned-in captions
   if visible; else ask user to play it and paste), fills in analysis.md.
4. Claude presents the breakdown:
   - Verbatim transcript per beat
   - Visual notes per beat
   - Why-it-works brutal critique
5. Claude proposes the recreation prompt with noun-swap (Fanta → Pepsi).
6. User approves via the dialogue gate.
7. Claude maps inputs (image / audio / video / actor) and runs the right
   generation script.
```

### Mode B — Direct generation (no source to deconstruct)

```
1. User describes the ad and provides at least an image (or actor + script).
2. Claude proposes a recreation prompt + input map.
3. Dialogue gate.
4. Generate.
```

---

## The four inputs

Arcads accepts four distinct input slots. Map them deliberately.

| Slot | What it does | Endpoint family | When to use |
|---|---|---|---|
| **Image** | Reference still for actor / product / style | `/v2/videos/generate` with `referenceImages` or `startFrame` | Default — always supply a product or actor still if you have one |
| **Audio** | Custom voiceover Arcads lip-syncs to | `/v1/scripts` with `audioUrl` (Talking Actors flow) | When you have a specific voice, accent, or recorded line |
| **Video** | Motion / style reference (Seedance 2.0 only) | `/v2/videos/generate` with `referenceVideos` | When the source has a distinctive motion you want copied. XOR with image refs |
| **Actor** | Pre-built named persona (Douglas, Olivia, …) | `/v1/actors` + `/v1/scripts` | When no custom actor image — use a polished pre-trained face |

### How to choose

```
Do you have an existing actor / product photo?
├── YES → IMAGE slot, v2 flow (arcads_generate.sh)
└── NO  → pick an ACTOR via arcads_actors.sh, use legacy flow (arcads_talking.sh)

Do you already have a recorded voiceover?
├── YES → AUDIO slot via arcads_talking.sh --audio voice.mp3
└── NO  → let Arcads generate voice from the --script text

Does the source have a distinctive camera move worth copying?
├── YES → VIDEO slot, Seedance only (arcads_generate.sh --video ref.mp4)
└── NO  → skip
```

---

## The scripts

| Script | What it does |
|---|---|
| `arcads_check.sh` | Verify the API key works |
| `arcads_analyze.sh <video>` | **Forensic prep** — extract frames + audio + analysis stub |
| `arcads_actors.sh [filters]` | List named actors with filters (gender / age / skin tone) |
| `arcads_upload.sh <file>` | Presigned-URL upload, returns the filePath |
| `arcads_generate.sh ...` | v2 unified flow — image / video reference, Seedance / Veo / Sora / Kling |
| `arcads_talking.sh ...` | Legacy Talking Actors — named actor + script + optional audio |
| `arcads_status.sh <id>` | Poll a job by ID |

---

## Analyze-first workflow (the main use case)

### Step 1 — Get the source video

If from Meta Ad Library: open the ad, DevTools Console:
```js
[...document.querySelectorAll('video')].filter(v => !v.paused).map(v => v.currentSrc)
```
Then `curl -o competitor.mp4 "URL"`.

### Step 2 — Run the analyzer

```bash
~/Desktop/ads-skill/scripts/arcads_analyze.sh ~/Desktop/competitor.mp4
```

Produces `~/Desktop/ads-skill/analysis/<slug>/`:
- `frames/frame_001.png` … (one per second)
- `audio.mp3`
- `analysis.md` (empty template)

### Step 3 — Claude fills in `analysis.md`

Read every frame. Fill in:
- **Beats** with verbatim transcript + visual description per second range
- **Why-it-works** — pattern interrupt, concrete claim, emotional payoff, actor moment, first-2s test
- **Recreation prompt** — noun-swapped version for the user's product
- **Arcads input map** — which slot gets what

If the source has burned-in captions, transcribe them verbatim. If audio dialogue is unclear from captions, ask the user to play `audio.mp3` and paste what's said. **Never paraphrase.**

### Step 4 — Dialogue gate

Show the user the recreated dialogue beat-by-beat:

```
Recreation script (please confirm before I generate)

  1. [HOOK]  "..." (noun-swapped from "...")
  2. [SHOW]  "..."
  3. [DEMO]  (silent beat — same as source)
  4. [CTA]   "..."

Spoken words: 32  |  Target duration: 15s  |  Fits: yes

Approve? (yes / edit / rewrite)
```

Wait for explicit `yes`.

### Step 5 — Generate

Pick the right script based on the input map:

```bash
# Custom actor image + product, Seedance default
arcads_generate.sh --image ~/Desktop/my-actor.jpg --prompt "..." \
  --model seedance-2.0 --aspect 9:16 --duration 15

# Named actor + custom voiceover
arcads_talking.sh --actor-id <uuid-from-arcads_actors.sh> \
  --audio ~/Desktop/voiceover.mp3 \
  --script "..." --aspect 9:16

# Motion reference from competitor (Seedance only, XOR with image)
arcads_generate.sh --video ~/Desktop/competitor.mp4 --prompt "..." \
  --model seedance-2.0 --aspect 9:16
```

---

## Setup (first run only)

1. Pro plan at `https://app.arcads.ai/settings/api`.
2. `cp .env.example .env`, paste `ARCADS_API_KEY=...`, save.
3. `scripts/arcads_check.sh` → expect `OK - connection verified.`
4. (Optional) Save a default `ARCADS_DEFAULT_PRODUCT_ID` in `.env` to skip product creation on each run.

---

## Hard rules

- **Never paraphrase the source transcript.** Verbatim or `[unclear]`. The whole skill is built on faithful copying.
- **Always run the dialogue gate** before generation. Wrong dialogue = wasted credits.
- **Presigned URLs are one-time-use.** The scripts re-upload per call — don't cache.
- **Seedance polls at `/v1/assets/{id}`**, every other video model polls at `/v1/videos/{id}`. The scripts already route this correctly.
- **`referenceImages` and `referenceVideos` are mutually exclusive** on Seedance in one call. Pick one.
- **Never print or log the API key.** If the user pastes it in chat, write to `.env` silently and warn them about chat history.
- **No "Skills Fleet" anywhere** — that's another creator's brand.

---

## Files in this skill

- **[reference.md](reference.md)** — every endpoint, body shape, polling rule, and quirk.
- **[prompting/viral-analysis.md](prompting/viral-analysis.md)** — the deconstruction framework + recreation rules.
- **[prompting/ugc-formulas.md](prompting/ugc-formulas.md)** — hook / demo / CTA templates.
- **[prompting/model-routing.md](prompting/model-routing.md)** — which model for which brief.
- **`scripts/arcads_*.sh`** — the runtime.
- **`analysis/<slug>/`** — per-source deconstruction outputs.
- **`output/<date>_<slug>.mp4`** — final generated videos + sidecar `.json` metadata.
