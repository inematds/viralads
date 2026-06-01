# Arcads External API — Endpoint Reference

Authoritative reference for every Arcads endpoint this skill talks to. When in doubt, trust this file over the bash scripts.

## Base URL

```
https://external-api.arcads.ai
```

Override with `ARCADS_BASE_URL` if Arcads moves the endpoint.

## Authentication

HTTP Basic — **API key as username, empty password.**

```bash
curl -u "$ARCADS_API_KEY:" "$ARCADS_BASE_URL/v1/products"
```

Equivalent header form:

```
Authorization: Basic <base64(API_KEY + ":")>
```

If you see `401`/`403`, the key is wrong or unset. Do NOT print the key when debugging.

---

## Video generation (unified v2 — preferred)

`POST /v2/videos/generate`

Required body:
- `model` — one of `seedance-2.0`, `sora2`, `sora2-pro`, `veo31`, `kling-2.6`, `kling-3.0`, `grok-video`
- `productId` — UUID (from `POST /v1/products` or list)
- `prompt` — string

Optional body:
- `aspectRatio` — `"9:16"` | `"16:9"` | `"1:1"`
- `duration` — integer seconds (see per-model limits below)
- `resolution` — `"720p"` | `"1080p"`
- `referenceImages` — array of `filePath` strings from presigned upload
- `referenceVideos` — array (Seedance only, mutually exclusive with `referenceImages`)
- `referenceAudios` — array
- `audioEnabled` — boolean (default `false`; set `true` for spoken UGC)
- `startFrame` — `filePath` (Veo / Kling — locks first frame)
- `endFrame` — `filePath` (Veo only — locks last frame)
- `projectId` — UUID
- `nbGenerations` — integer (variants per call)

Example:

```bash
curl -sS -X POST -u "$ARCADS_API_KEY:" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "seedance-2.0",
    "productId": "...",
    "prompt": "15-second UGC review: woman holds the skincare bottle...",
    "aspectRatio": "9:16",
    "duration": 15,
    "resolution": "720p",
    "audioEnabled": true,
    "referenceImages": ["/uploads/abc.jpg"]
  }' \
  "$ARCADS_BASE_URL/v2/videos/generate"
```

Response includes the job `id` to poll.

---

## Image generation

`POST /V2/images/generate` (note capital V)

Required body: `productId`, `prompt`, `model` (`nano-banana-2` or `nano-banana`), `aspectRatio`.
Optional: `referenceImages`, `projectId`, `nbGenerations`.

Use this to produce a still of an actor holding the product before animating it.

---

## Legacy video endpoints (per-model)

Still functional, but the v2 unified endpoint should be your default.

- `POST /v1/sora2/generate/video` — `productId`, `prompt`, `aspectRatio`, `duration` ∈ {4,8,12,16,20}, optional `resolution`, `refImageAsBase64`.
- `POST /v1/veo31/generate/video` — `productId`, `prompt`, `resolution`, `aspectRatio`, optional `referenceImages`, `startFrame`, `endFrame`.

---

## B-roll & scene

- `POST /v1/b-roll` — silent product/scene clips. `duration` ∈ {5, 10}. Takes `refImageAsBase64`, `startFrameAsBase64`, `endFrameAsBase64`.
- `POST /v1/scene` — narrative scene. Takes optional `script`, `contextScript`, `contextPrompt`.

Both poll at `/v1/assets/{id}`.

---

## File upload (presigned URL)

`POST /v1/file-upload/get-presigned-url`

Body:
```json
{ "fileType": "image/jpeg" }
```

Also accepts `image/png`, `video/mp4`, `audio/mp3`, `audio/mpeg`, `audio/wav`.

Response:
- `presignedUrl` — one-time PUT target
- `filePath` — use this in generation calls
- `expiresIn` — TTL seconds
- `maxFileSize` — bytes

Upload the file:
```bash
curl -X PUT -H "Content-Type: image/jpeg" --data-binary @file.jpg "$presignedUrl"
```

**Presigned URLs are single-use.** Re-fetch a new presigned URL every generation call.

---

## Status polling

Two endpoints — which one depends on the model.

| Model | Poll at |
|---|---|
| `sora2`, `sora2-pro`, `veo31`, `kling-2.6`, `kling-3.0`, `grok-video` | `GET /v1/videos/{id}` |
| `seedance-2.0`, b-roll, scene, Nano Banana images | `GET /v1/assets/{id}` |

**Trap:** Seedance is a video model but polls at `/v1/assets/{id}`. The job type returned is `seedance_20`.

Response fields:
- `status` — `created` | `pending` | `generated` | `failed` | `uploaded`
- `videoUrl` / `url` — final download (when ready)
- `creditsCharged` — actual cost
- `videoStatus` — for `/v1/videos/{id}` style

Poll every ~5–10 seconds. Most jobs finish in 30s–3min.

---

## Product, folder, project

These organize your generations. The skill auto-creates a default product on first run.

- `POST /v1/products` — `name`, `description`, `targetAudience`, `mainFeatures[]`, `painPoint`, `perceived`.
- `GET /v1/products` — list.
- `POST /v1/folders` — `productId`, `name`.
- `GET /v1/products/:productId/folders` — list folders.
- `POST /v1/projects` — `productId`, `folderId`, `name`.
- `POST /v1/assets/add-to-project` — `assetId`, `projectId`.

---

## Health check

`GET /health` — no auth required. Use to confirm the API is up before debugging auth.

---

## Per-model capability matrix

| Model | Duration | Audio | Image input | Poll at |
|---|---|---|---|---|
| Seedance 2.0 | 4–15s | yes | `referenceImages` or `referenceVideos` (XOR) | `/v1/assets/{id}` |
| Sora 2 | 4, 8, 12, 16, 20s | yes | `referenceImages` (max 1) | `/v1/videos/{id}` |
| Veo 3.1 | ~8s auto | yes | `startFrame` + up to 3 refs | `/v1/videos/{id}` |
| Kling 3.0 | 3–15s | no | `startFrame` only | `/v1/videos/{id}` |
| Grok Video | 1–15s | no | — | `/v1/videos/{id}` |
| B-roll | 5 or 10s | no | base64 frames | `/v1/assets/{id}` |
| Nano Banana 2 | image | n/a | `referenceImages` | `/v1/assets/{id}` |

## Talking Actors flow (legacy, named-actor)

This is the flow behind the standard Arcads UI — pick a named actor (Douglas, Olivia, …), optionally a situation, and either supply your own audio for lip-sync or let Arcads generate the voice from your script.

### List actors
`GET /v1/actors`

Query params: `page`, `pageSize`, `freeSpeech` (bool), `age`, `gender`, `skinTone`.

Response: paginated list with `items[]`. Each item has `id` (the `actorId`), `name`, `gender`, `age`, `skinTone`, and capability flags.

### List situations
`GET /v1/situations`

Query params include: `page`, `pageSize`, `isPro`, `talkingActorEnabled`, `showYourAppEnabled`, `unboxingPovEnabled`, `brollSora2Enabled`, `fashionTryOnEnabled`, `productShowcaseEnabled`, `gesturesEnabled`, `cameraMovementEnabled`, `actorGender`, `actorAge`, `actorName`, `actorFreeSpeech`.

### Get an actor's available situations
`GET /v1/actors/{actorId}/situations` — useful for picking a situation guaranteed to work with a given actor.

### Create a script (with videos[])
`POST /v1/scripts`

Body (`ScriptCreationDto`):
- `name` (required)
- `text` (required) — the spoken script
- `productId` (typically required)
- `folderId` (optional)
- `projectId` (optional)
- `videos[]` (optional) — each video object specifies generation params:
  - `actorId` — UUID from `/v1/actors`
  - `aspectRatio` — `"9:16"` / `"16:9"` / `"1:1"`
  - `situationId` — UUID from `/v1/situations` (optional)
  - `audioUrl` — `filePath` from a presigned upload, if supplying custom voiceover

Response (`ScriptDto`): `id`, `version`, `isActiveVersion`, `videos[]`.

### Generate
`POST /v1/scripts/{scriptId}/generate` — triggers generation for every video in the script. Returns boolean.

`POST /v1/scripts/{scriptId}/generate-omnihuman` — Omnihuman variant (advanced lip-sync). Returns `{ created[], failed[], summary }`.

### Poll
`GET /v1/scripts/{scriptId}/videos` — returns the array of videos with `status` and `videoUrl` once ready.

### Update / delete
- `PUT /v1/scripts/{scriptId}` — body `ScriptUpdateDto` with `name`, `text`, `folderId`.
- `DELETE /v1/scripts/{scriptId}`.

### Example curl — Talking Actor with custom audio

```bash
# 1. Upload audio first
AUDIO_PATH="$(arcads_upload.sh ~/Desktop/voiceover.mp3)"

# 2. Create the script
curl -sS -X POST -u "$ARCADS_API_KEY:" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "fresca-recreation-v1",
    "text": "This Pepsi is beautiful, it'\''s refreshing...",
    "productId": "PRODUCT_UUID",
    "videos": [{
      "actorId": "ACTOR_UUID_FROM_LIST",
      "aspectRatio": "9:16",
      "audioUrl": "'$AUDIO_PATH'"
    }]
  }' \
  "$ARCADS_BASE_URL/v1/scripts"

# 3. Trigger generation with the returned scriptId
curl -sS -X POST -u "$ARCADS_API_KEY:" \
  "$ARCADS_BASE_URL/v1/scripts/SCRIPT_ID/generate"

# 4. Poll
curl -sS -u "$ARCADS_API_KEY:" \
  "$ARCADS_BASE_URL/v1/scripts/SCRIPT_ID/videos"
```

`arcads_talking.sh` wraps all four steps.

### When audio "verification" hangs in the UI

The UI transcribes uploaded audio and compares it against the typed script. Mismatches stall verification. Via the API, the same applies — keep `text` close to what's actually spoken in the `audioUrl` file. If you just want lip-sync to your audio without script-matching, omit `text` and supply only `audioUrl`.

---

## Common errors

- `401` — bad or missing API key. Re-check `.env`.
- `403` — key is valid but plan doesn't include API access (need Pro).
- `400` with `aspectRatio` — typo, must be the exact string `"9:16"` / `"16:9"` / `"1:1"`.
- `400` with `referenceImages` — you passed a URL instead of the `filePath` from presigned upload.
- Stuck `pending` >5min — re-poll; if still stuck, the job may have failed silently. Check `status` for `failed`.
