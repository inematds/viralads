# UGC Ad Copy Formulas

Battle-tested structures for short-form UGC ads (TikTok, Reels, Shorts). Use these as the skeleton for the `prompt` field in any video generation call.

## The 15-second default structure

```
[0-2s   HOOK]   Pattern-interrupt line, eye contact with camera
[2-6s   SHOW]   Hands-on demo of the product
[6-11s  PROOF]  Specific result, number, or before/after
[11-14s CTA]    "Link in bio" / "Get yours at..."
[14-15s LOGO]   Product hero shot, brand wordmark
```

Total spoken words: 30–38. Read aloud — if it doesn't fit comfortably, cut.

## Hook templates (the first line)

Each of these solves a different intent. Pick one, don't blend.

| Intent | Template | Example |
|---|---|---|
| Curiosity | "Wait — I didn't know X did Y" | "Wait, this thing actually fixes [problem] in under 30 seconds?" |
| Authority | "POV: you finally found the [category] that..." | "POV: you found the only mascara that doesn't smudge by 3pm." |
| Contrarian | "Everyone's wrong about [category]." | "Everyone's wrong about which protein powder mixes clean." |
| Result-led | "I tried X for Y days. Here's what happened." | "I used this for two weeks. My skin texture is gone." |
| Direct call | "If you have [problem], stop scrolling." | "If your back hurts at your desk, watch this." |
| Stat | "[Specific number] of people..." | "73 percent of people get this wrong." |

## Demo beats (the middle)

Show the product working. Camera-facing only — the actor should treat the lens like the viewer's eyes.

- Hands enter frame holding the product.
- A single specific action: tap, twist, spray, scoop, scan.
- One quantified result: "in three days," "for nine bucks," "lasts a week."
- Cut to the actor's face for the reaction.

## CTA templates (the close)

Short, low-friction, no "click the link below." Treat the platform's UI as part of the frame.

- "Linked in my bio."
- "It's [brand]. Cheaper than I expected."
- "Run, don't walk."
- "Add to cart before they pull this."
- "I'll link it for you."

## Anti-patterns (do not write)

- Long company-voice intros ("Hi guys, today we're going to talk about...").
- More than one product feature per ad — pick the strongest.
- Generic adjectives: "amazing," "incredible," "game-changing."
- Asking permission: "If you want, you could maybe try..."
- Reading the price like a script ("for the low price of...").

## How this maps to the Arcads prompt

The `prompt` field should describe BOTH the visual direction AND the spoken script. Format:

```
[Visual] 22-year-old woman, soft natural light, holding the product mid-frame, eye contact with camera.

[Audio] She says, with a casual, slightly surprised tone:
1. "Wait — this finally fixed my [problem]."
2. (taps product) "Three days. Three. Days."
3. "It's [brand]. Linked in bio."

[Pacing] Hook holds for 2s, demo at 4s, CTA at 13s. End on product close-up.
```

The dialogue gate in `SKILL.md` will surface the spoken lines for confirmation before generation.
