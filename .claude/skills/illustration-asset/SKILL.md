---
name: illustration-asset
description: Produce, cut out or wire in a character illustration — new or replaced paywall plan-card art (`option_visuals`), paywall explainer-step art (`steps[].visual`), a mascot variant, or an image or Lottie the user hands over to drop into the app. Use whenever the task writes a file into `wizard-app/assets/images/` or `assets/lottie/` for a template to name, or asks for generation prompts for the wizard.
---

# Illustration asset

Every illustration is the same wizard, named by a Remote Config template and drawn as given by
`VisualAssetWidget` (image, Lottie or SVG, bundled or `https://`). How the paywall takes and
sizes art — keys, render sizes, URL caveats, the step rules — is in `wizard-app/PAYWALL.md`
("Plan art", "The explainer steps"). This skill is making the file and dropping it in.

## 0. Never overwrite what the user supplied

Before writing anything into `wizard-app/assets/`, check whether that name already exists
(`ls wizard-app/assets/images/<name> wizard-app/assets/lottie/<name>`). If it does and you did
not make it this session, pick a new name or ask. **Never overwrite a user-supplied asset with
a placeholder or a generated stand-in** — this has happened once, and a supplied file that is
not yet in git has no other copy (a test run leaves one in `build/unit_test_assets/`, until the
next clean). Work in the scratchpad, copy into `assets/` only once the result is checked, and
keep the original until the cutout is confirmed.

## 1. The character, shared

Only pose, prop and palette change between images.

- Bearded wizard, shoulders-up or waist-up, facing the viewer.
- Purple pointed hat carrying a `%` symbol. Dark sunglasses. Ginger beard and hair.
- Flat vector cartoon. Thick dark outline, uniform weight. Flat fills, minimal shading, no
  gradients, no texture, no drop shadows.
- Same crop and same eye line across a set, so a pair sits level side by side.
- **No baked-in background.** The slot paints its own tint. `wizard_cutout.png`, the fallback
  mascot, has a yellow disc behind the wizard that fights the card's tint — don't repeat that.

| Role | Hex (`WizColors` token) |
|---|---|
| Outline | `#14121B` (`ink`) |
| Robe / hat | `#7B5EA7` (`purple`), shaded `#4B3F66` (`purpleInk`) |
| Skin, hair | warm orange `#F0A045` family (no token) |
| Accent, screens | teal `#4ECDC4` (`teal`) |
| Highlight, sparkles | yellow `#FFD166` (`yellow`) |

## 2. What each plan's image must say

- **Monthly** — settled, in control, the long game (three days free, "one saved deal covers
  the month"). Relaxed, arms open; one large prop that says *repeated*: coins, bills, a
  calendar page. Sits on amber `#FFF1E2`.
- **Weekly** — fast, in motion, right now (no trial, "just this week?"). Mid-spell, sleeves
  up; one large prop: a phone throwing sparkles, or a wand in motion. Sits on mint `#EEF7F6`.

Aim for *still* against *moving*: it survives 120 pt, where calendar-versus-wand would not.
A feature narrower than about 3 pt of the source disappears at that size, so judge the art
at the size it renders, never at full size. Step art must be a Lottie or SVG — a `.png` step
visual is not drawn.

## 3. Generation prompts

Generate a set in one session and keep the seed if the tool offers one. Append the suffix to each.

> **Suffix:** Flat vector cartoon illustration, thick uniform dark outline `#14121B`, flat
> fills, no gradients, no shading detail, no drop shadow. Transparent background, subject cut
> out, no background shapes or discs. Centred, shoulders-to-waist crop, facing viewer.
> Palette: purple robe `#7B5EA7`, orange skin tones, teal `#4ECDC4` accents, yellow `#FFD166`
> highlights.

> **Monthly:** A friendly bearded wizard in a purple pointed hat with a `%` symbol on it,
> wearing dark sunglasses, arms relaxed and open, calm and confident, a neat stack of gold
> coins beside him.

> **Weekly:** A friendly bearded wizard in a purple pointed hat with a `%` symbol on it,
> wearing dark sunglasses, leaning forward mid-spell, one arm raised casting, holding a
> glowing phone with teal sparkles flying off it, sense of speed and motion.

## 4. Cutting out supplied art

Art arrives as a full-frame render on an opaque background with wide margins. Pillow is
installed (`python3`); save as `cut.py` in the scratchpad and run
`python3 cut.py <supplied.png> <scratchpad>/plan_<id>_cutout.png`:

```python
import sys
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
w, h = im.size
for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:  # flood the background to alpha
    ImageDraw.floodfill(im, xy, (0, 0, 0, 0), thresh=25)
im = im.crop(im.getbbox())                   # fill the slot, not blank margins
im.thumbnail((560, 560), Image.LANCZOS)      # long side 560
im = im.quantize(128, method=Image.Quantize.FASTOCTREE)  # palette + tRNS
im.save(out, optimize=True)
check = Image.new("RGBA", im.size, "#FFF1E2")  # the slot's real tint
check.alpha_composite(im.convert("RGBA"))
check.save(out.replace(".png", "_check.png"))
```

- The dark outline stops the flood, so an enclosed light area (a speech bubble, a disc) is
  never reached. Raise `thresh` only if background speckle survives.
- **Look at `_check.png`, not the cutout**: viewers draw transparency as black, which is
  indistinguishable from a black background left behind.
- Targets: 560 px on the long side, ≤ 150 KB (quantising flat art typically takes 1.3 MB to
  ~40 KB), alpha intact. A Lottie: 560 × 560 canvas, transparent, ≤ 150 KB.

## 5. Delivering

1. Name it for its slot: `assets/lottie/plan_<option id>.json` for an animation,
   `assets/images/plan_<option id>_cutout.png` for a still; other art `<subject>_cutout.png`.
   Both folders are bundled, so no `pubspec.yaml` change. Run step 0 first.
2. Point the template at it — `paywall_config.metadata.option_visuals.<option id>`, or
   `steps[].visual` — using the decode/re-encode round trip from the `onboarding-screen`
   skill with `root["paywall_config"]` in place of `onboarding_screens` (byte-identical today).
   The bundled defaults must name a bundled file; an `https://` URL goes in the published
   template only.
3. Never name a supplied original (opaque, often over 1 MB): the tests below fail on it.
4. Tell the user what to publish in Remote Config: the bundled file is only the fallback.

## 6. Verify

```bash
(cd wizard-app && fvm flutter test test/features/paywall/bundled_offer_test.dart test/core/config/remote_config_assets_test.dart)
```

- `bundled_offer_test.dart` ("the art each plan names"): every option names its own file and
  no two share one; each exists under `assets/images/` or `assets/lottie/`; a plan PNG can carry
  transparency (RGBA, grey + alpha, or palette + `tRNS` — opaque RGB fails); each is under
  400 KB; the animation loops and the art fits its block.
- `remote_config_assets_test.dart`: every `assets/…` path in any bundled template exists and
  sits in a folder `pubspec.yaml` bundles (`config`, `images`, `lottie`, `fonts`).

Then look at both cards on a phone. If the two can't be told apart at a glance, the difference
was too fine — go back to pose and silhouette, not detail. Finish with `ship-check`.
