# Model Routing Guide

When to pick which Arcads model. Default is Seedance 2.0 — only deviate when the brief gives you a reason.

## Quick chooser

```
Talking actor + product, 4–15s, audio matters → SEEDANCE 2.0
Single still you want to animate with dialogue, ~8s → VEO 3.1
Style transfer / cinematic / 16–20s long form → SORA 2
Silent B-roll or scene under 15s → KLING 3.0 or /v1/b-roll
Just need a still image first → NANO BANANA 2 (then animate)
```

## Seedance 2.0 — the default UGC model

- **Strengths:** Best lip sync. Takes reference images OR a reference video. Native audio. Flexible 4–15s.
- **Weaknesses:** Poll lives at `/v1/assets/{id}` instead of `/v1/videos/{id}` — don't forget.
- **Use when:** Most UGC ads. Talking actor holding a product. Reaction-style content.
- **Don't use when:** You need >15s, or you want to lock the first frame exactly (use Veo).

## Veo 3.1 — the locked-frame storyteller

- **Strengths:** Sharp motion. Locks to a `startFrame` (and optionally `endFrame`). Speech-capable.
- **Weaknesses:** Auto-clamps to ~8s. Less freedom on the duration knob.
- **Use when:** The user wants a specific still to come alive, or you need a polished hero clip with predictable framing.
- **Don't use when:** The brief is >10s or you want generative style transfer.

## Sora 2 — the long-form / style model

- **Strengths:** Discrete durations of 4/8/12/16/20s. Strong with style-reference images. Speech-capable.
- **Weaknesses:** Less precise on product fidelity than Seedance.
- **Use when:** Cinematic ads, brand-film aesthetic, the user wants longer narrative arcs.
- **Don't use when:** Tight product accuracy matters — Seedance reads reference images more faithfully.

## Kling 3.0 — silent motion

- **Strengths:** Cheap, fast, decent motion. Takes `startFrame`.
- **Weaknesses:** No audio. No lip sync.
- **Use when:** B-roll, product spin, atmospheric shots that will be voiced over in post.

## Grok Video — utility

- **Strengths:** 1–15s, fast.
- **Weaknesses:** No audio.
- **Use when:** Quick filler clips. Rarely the right call for a final UGC ad.

## Nano Banana 2 — image, not video

- Cheap (~0.03 credits). Use to generate the still of the actor holding the product, then animate with Seedance or Veo.
- Required when the user hasn't provided a usable hero image of the product on a person.

## The decision in code

The `arcads_generate.sh` script accepts `--model` and defaults to `seedance-2.0`. The override matrix:

```
--model seedance-2.0  → /v2/videos/generate, poll /v1/assets/{id}, audioEnabled=true
--model veo31         → /v2/videos/generate, poll /v1/videos/{id}, uses startFrame
--model sora2         → /v2/videos/generate, poll /v1/videos/{id}, duration must be {4,8,12,16,20}
--model kling-3.0     → /v2/videos/generate, poll /v1/videos/{id}, no audio
```

## Credit awareness

Models cost different amounts and the user pays per generation. Before running an expensive variant (e.g., Sora 2 at 20s, 1080p), confirm with the user. Save `creditsCharged` from the poll response in the JSON log next to the output file.
