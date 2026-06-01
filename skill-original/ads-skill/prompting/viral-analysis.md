# Viral Ad Deconstruction Framework

The whole point of this skill is to **reverse-engineer what makes a UGC ad work**, then rebuild it for your own product. We don't generate blind — we copy proven structure and swap the variables.

## The deconstruction loop

```
Competitor video → Frame-by-frame breakdown → Transcript (verbatim) → 
  Beat-by-beat structure → Why-it-works analysis → Recreation prompt 
    with noun-swap → Arcads inputs (image / audio / video / actor) → 
      Generate
```

## Step 1 — Extract assets

Run the analyze script on the saved competitor MP4:

```bash
~/Desktop/ads-skill/scripts/arcads_analyze.sh ~/Desktop/competitor.mp4
```

It produces `~/Desktop/ads-skill/analysis/<slug>/`:
- `frames/` — one PNG per second (or every 0.5s for short clips)
- `audio.mp3` — extracted speech track
- `analysis.md` — empty template to fill in

## Step 2 — Read the frames (Claude does this)

Claude reads every PNG in `frames/` and fills in the analysis template with:

### Visuals (per beat)
- Shot type: close-up, mid, wide, POV, over-shoulder
- Subject framing: actor centered, off-axis, holding product
- Hand positions: where the product enters/exits
- Lighting: natural window, ring light, golden hour, harsh, soft
- Background: bedroom, kitchen, gym, car, outdoor, studio white
- Wardrobe: outfit style, accessories, anything brand-relevant
- B-roll cuts: when the camera leaves the actor's face
- Captions/text on screen: verbatim, with timestamp
- Motion: static talking head, slow pan, handheld shake, jump cut

### Audio (verbatim)
- **Quote every spoken line verbatim** — these become the swap targets
- Mark silent beats explicitly
- Note tone: casual, conspiratorial, urgent, deadpan, hyped
- Pace: words per second (count words, divide by audio length)
- Background sound: silent, ambient room tone, music bed, sfx

### Pacing (timestamps)
| Beat | Time | What |
|---|---|---|
| Hook | 0–2s | "..." (verbatim) + visual note |
| Show | 2–5s | "..." + product enters frame |
| Proof | 5–10s | "..." + specific number / demo |
| Twist | 10–13s | (optional) reversal beat |
| CTA | 13–15s | "..." + product close-up |

## Step 3 — Why it works (the brutal critique)

Force yourself to answer in one sentence each:

- **What is the pattern interrupt in the first 1.5 seconds?** (If you can't name it, the ad isn't going viral.)
- **What is the specific, concrete claim?** ("3 days," "$9," "a week.")
- **What is the emotional payoff?** (Relief, surprise, vindication, status, belonging.)
- **What does the actor's face do at the key beat?** (Eye contact break, smile, deadpan, eyebrow raise.)
- **What would happen if you cut the first 2 seconds?** (If nothing — the hook is weak.)

## Step 4 — Recreation prompt (the noun-swap)

The recreation rule:

> **Keep the structure verbatim. Swap only the brand-specific nouns.**

If the hook is *"I've always found drinking Fanta is the best way to go forward,"* and you sell Pepsi, the recreation hook is *"I've always found drinking Pepsi is the best way to go forward."* Same cadence, same syntax, same eye contact — different word.

What you swap:
- Brand name
- Product category (if needed)
- Specific claim (your $9, your 3 days)
- Setting (only if your category demands it — usually keep it)

What you DO NOT swap:
- Sentence structure
- Hook syntax
- Pacing
- Camera angles
- Wardrobe vibe
- Tone

## Step 5 — Map to Arcads inputs

The four input slots, and what to put in each:

| Slot | What it does | When to use it |
|---|---|---|
| **Image** | Reference still for actor likeness, product, or style | Always — product photo or actor still. Best signal Arcads gets. |
| **Audio** | Custom voiceover Arcads lip-syncs to | When you want a specific voice / accent / pace. Otherwise let Arcads generate from the script. |
| **Video** | Motion reference (Seedance 2.0 only) | When the source has a distinctive motion / camera move you want to copy. Mutually exclusive with image refs in one call. |
| **Actor** | Pre-built named persona (Douglas, Olivia, etc.) | When you don't have a custom actor still and want a polished pre-trained face. Uses the legacy `/v1/scripts` flow. |

### Decision tree for which to use

```
Do you have an existing actor photo / face you want to use?
├── YES → use IMAGE slot + v2 unified flow (Seedance/Veo)
└── NO → pick a built-in ACTOR via /v1/actors + legacy /v1/scripts flow

Do you have a specific voiceover you've already recorded?
├── YES → use AUDIO slot (legacy flow, Talking Actors)
└── NO → let Arcads generate voice from script text

Does the competitor have a distinctive motion (whip pan, zoom, etc.)?
├── YES → use VIDEO slot as referenceVideos (Seedance 2.0)
└── NO → skip
```

## Step 6 — Generate

Once the recreation prompt + input map is ready, fire the right script:

- **Custom actor still + product** → `arcads_generate.sh --image actor.jpg --prompt "..."`
- **Named actor + custom audio** → `arcads_talking.sh --actor-id <uuid> --audio voiceover.mp3 --script "..."`
- **Motion reference from competitor** → `arcads_generate.sh --video competitor.mp4 --prompt "..."` (Seedance only)

## The analysis template (auto-generated)

The analyze script creates this stub at `analysis/<slug>/analysis.md` — Claude fills it in after reading frames:

```markdown
# Analysis: <competitor-name>

Source: <path>
Duration: <Xs>
Aspect: <9:16 / 16:9 / 1:1>

## Beats (verbatim transcript + visual)

### [0–2s] HOOK
Spoken: "..."
Visual: ...
Camera: ...
Why it works: ...

### [2–5s] SHOW
...

### [5–10s] PROOF
...

### [10–15s] CTA
...

## Why this ad works (brutal critique)

- Pattern interrupt: ...
- Concrete claim: ...
- Emotional payoff: ...
- Actor moment: ...
- First-2s test: ...

## Recreation prompt (for our product: <product-name>)

[Visual] ...
[Audio] Spoken lines (noun-swapped):
1. "..."
2. "..."
3. "..."
[Pacing] ...

## Arcads input map

- Image: <path or "skip">
- Audio: <path or "let Arcads generate">
- Video: <path or "skip">
- Actor: <actor-id or "custom from image">
- Model: <seedance-2.0 / veo31 / talking-actors>
- Aspect: 9:16
- Duration: 15s
```

## Hard rules

- **Always transcribe verbatim.** If the source has burned-in captions, copy them character-for-character. If you can't make out a word, mark it `[unclear]` — never paraphrase.
- **Never invent visual details.** Only describe what's in the frame.
- **Mark silent beats explicitly.** A 2-second pause is a structural choice, not an omission.
- **Stop before generating** and ask the user to approve the recreation prompt. This is the dialogue confirmation gate from the main SKILL.md — it applies here too.
