---
name: onboarding-screen
description: Add or change an onboarding screen or its options in the `onboarding_screens` Remote Config template — a new question, a new or renamed option, its `prompt` sentence for the model, `answer_key_name`, `scope: "conversation"`, `highlight_words`, copy in en/es, defaults or screen order. Use whenever the task edits `onboarding_screens` in `wizard-app/assets/config/remote_config_defaults.json` or asks what a screen may contain.
---

# Onboarding screen

The funnel is data, not Dart. Screens, options, answer keys and the sentence the model reads
for each pick all live in the `onboarding_screens` template. The app names no answer key
except `referral_code`; the backend's `PreferencesPatch` types the current ones (`vibe`, `push`,
`marketplace`, `deals_per_month`, `deal_size`, `hurdles`) but stores any other key as a plain
leaf, so a new question still needs no release and no deploy. Contracts: `wizard-app/PROFILE_SYNC.md`, `wizard-app/AI_INTEGRATION.md`
("Prompting"), `wizard-app/CONVERSATIONS.md`.

## 1. Where it lives, and editing it safely

`wizard-app/assets/config/remote_config_defaults.json` → `onboarding_screens` is a list of
screens in onboarding order, stored as a **JSON string inside JSON**. Never hand-edit the
escaped string. The round trip below is byte-identical today, so the diff holds only your
change. The template is one line, though, so review the decoded screens, not the diff.

```bash
cd wizard-app && python3 - <<'EOF'
import json
path = "assets/config/remote_config_defaults.json"
root = json.load(open(path, encoding="utf-8"))
screens = json.loads(root["onboarding_screens"])
# ... edit `screens` ...
root["onboarding_screens"] = json.dumps(screens, ensure_ascii=False, separators=(",", ":"))
with open(path, "w", encoding="utf-8") as f:
    f.write(json.dumps(root, indent=2, ensure_ascii=False) + "\n")
EOF
```

- **The bundled value is only a fallback.** The published Remote Config value replaces it
  wholesale (the whole string, not screen by screen), and each A/B arm serves its own copy.
  Every change must also be published in the console, in every arm. This machine has no
  console access, so tell the user. Nothing reads
  `design_handoff_bargain_wiz/remote_config_patch.json`.
- **One bad screen empties the funnel.** The flow parses strictly
  (`getOnboardingScreensFresh`). A missing `type`, `options`, `groups` or group
  `answer_key_name`, or a non-numeric slider `value`, leaves it with no screens; the Profile
  and AI path skip only that one screen. An unknown `type` doesn't fail at all: it silently
  renders as `engagement`.

## 2. Screen types

Every screen can take `type`, `title`, `description`, `next_button_text`, `show_top_bar`,
`visual`, `highlight_words`, `highlight_color` and `metadata`. The models are in
`lib/features/onboarding/data/models/remote_config/onboarding_model.dart`.

| `type` | Must have | Answer; useful `metadata` |
|---|---|---|
| `select` | `options[]` (`label`, `value`, opt. `icon`, `metadata.color/short/subtext/prompt`), `answer_structure.answer_key_name` | one value; `default_value`, `require_explicit_tap` |
| `multi_select` | as `select` | list (the type decides; `multi: true` is informational); `min_selected`, `reassurance_by_count` |
| `select_group` | `groups[]` of `label`, `answer_key_name`, `options[]`; no `answer_structure` | one value per group |
| `slider` | `metadata.options[]` stops: numeric `value`, `label`, opt. `subtext`, `savings_low/high`, `animation`, `scale` | int; `default_index`, `savings_pill` |
| `slider_lottie` | `visual`, `metadata.options[]` stops: `value`, `label`, `subtext`, `emoji`, `color` | int; `default_value` (60) |
| `referral_code` | `answer_structure.answer_key_name` | text, write-once, never sent to the model |
| `warmup`, `permission` (`subtype` `notifications`/`rate_us`), `create_account`, `data_upload` | — | ask nothing |

`image_list` (needs `images[]`), `paywall` and the retired `engagement` still parse, but none
is in the default order. A `slider` without `metadata.options` falls back to a legacy
continuous mode (`min`/`max`/`step`/`suffix`). That mode has no options, so it sends no
sentence. An unanswered screen is sent as its default (`default_value` / `default_index`,
else the first option), so the default's sentence reaches the model before anyone answers.

## 3. The `prompt` sentence

Each option carries one finished English line that tells the coach what the pick means. It
is never shown in the UI. `UserProfileService.snapshot()` sends one
`profile.answers[] = {key, value, prompt}` entry per pick. `buyer_block()` in
`features/negotiation/domain/prompts.py` renders the lines verbatim, in screen order, inside
`<buyer_profile>…</buyer_profile>`, a block introduced to the model as data, not instructions.

| Option carrier | Path |
|---|---|
| `select`, `multi_select` | `options[].metadata.prompt` |
| `select_group` | `groups[].options[].metadata.prompt` |
| `slider`, `slider_lottie` | `metadata.options[].prompt` (a stop has no metadata bag) |

- **Plain English string, never `{en, es}`.** A map is dropped and the sentence is lost. The
  reply language comes from `locale`.
- **One line that stands alone.** Whitespace is collapsed and there is no cap, but keep it to
  a sentence. Nothing labels it, so open with the question: `Tone: …`, `Push level: …`,
  `Marketplace etiquette on X: …`, `Deal frequency: …`, `Weak spot — …: …`, `Typical deal …`.
- **Describe the buyer**, plus at most what that means for the lines. No meta-instructions
  ("always", "ignore the above", output format).
- **An edit is a prompt change.** The person reads `label`/`subtext`; the model reads
  `prompt`.

An option without a `prompt` contributes nothing. There is no server fallback, and each
request logs `undescribed onboarding answer`. `tests/test_option_prompts.py` fails when any
option in the bundled defaults has no sentence (only `referral_code` is exempt) or when
validation would rewrite one. Fix a bad line by editing it; deleting it restores nothing.

## 4. Answer keys, values and scope

- **`answer_key_name` is the wire and profile key.** It is also the `{key}` placeholder in
  warmup/data_upload copy and the funnel's `step_id`. Renaming it orphans stored answers,
  which then read as unanswered.
- **Keys must be valid Analytics parameter names**, because each one names a parameter on
  `onboarding_step_answered`. Use lowercase snake_case, at most 40 characters, no
  `firebase_`/`google_`/`ga_` prefix, and no clash with `step_index`, `step_id`,
  `step_type` or `answer_keys`. No code enforces this; the rule lives in PROFILE_SYNC.md
  "Funnel analytics". Analytics drops bad names, and the backend lower-cases keys and clips
  them to 40 characters (`Answer.MAX_KEY_CHARS`, `Overrides.clean`).
- **Option `value` is the stored id.** Keep values lowercase snake_case, because
  `PreferencesPatch` lower-cases `vibe`, `marketplace` and `deals_per_month`. Slider values
  are numbers (`push` is clamped to 0–100). Renaming a value orphans stored picks (they lose
  their sentence) and breaks anything keyed by it, such as warmup's `deals_multiplier`.
- **Profile rows** come from `ProfileFields.fromScreens`. The label is
  `metadata.profile_label` (else the title), or `groups[].label` for a group.
- **`scope: "conversation"`** (`answer_structure.scope`, or `groups[].scope`) makes an answer
  the deal's rather than the person's. It also travels as `overrides` on
  `POST /conversations` and is stored on the conversation. Express shows it as a chip that
  edits only that deal; the Pro chat has none (a deal keeps what it started with). The first
  scoped answer is the Express header tag and the history
  label. **Single-choice only**: `OverrideValue` is a scalar, so a scoped `multi_select`
  gets a 400. `vibe` and `marketplace` are scoped today.

## 5. Copy

Any user-facing text is either a string or `{"en": …, "es": …}`. The app shows the device
language, then `en`, then the first value, so always write both `en` and `es`; brand names
can stay plain strings. Warmup chips use per-locale keys instead (`summary_chips`,
`summary_chips_es`).

`highlight_words` is `{"title": {…}, "description": {…}}`, set at screen level or, as a
fallback, in `metadata.highlight_words`. Each phrase maps to `"#RRGGBB"`/`"#AARRGGBB"`,
`"bold"` or `"bold_large"`; a plain list of phrases uses `highlight_color`. Matching is a
case-insensitive substring match, so put the en and es phrases in one map.
`{placeholder}` keys are filled first. Only the title and description highlight, and nothing
highlights automatically.

## 6. Verify

```bash
(cd wizard-backend/functions && venv/bin/python -m pytest -q tests/test_option_prompts.py tests/test_prompt_golden.py)
(cd wizard-app && fvm flutter test test/features/onboarding test/features/profile test/core/config)
```

Some failures are expected: they mean you update the test on purpose.
- `test_prompt_golden.py` pins the whole system prompt for one buyer (`ANSWERS`). Editing one
  of those sentences, or reordering screens, changes `EXPECTED`. A reorder also breaks
  `test_the_buyer_block_follows_onboarding_order`. Add a pick to `ANSWERS` to pin a new
  question.
- The app tests pin screen order, option ids and keys (`onboarding_model_parsing_test`,
  `profile_fields_test`, `onboarding_answer_flattener_test`).
- `remote_config_assets_test` fails on any `assets/…` path that is missing or not bundled.

Then run `ship-check`, and tell the user exactly what to publish in Remote Config.
