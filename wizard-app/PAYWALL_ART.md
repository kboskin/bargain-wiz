# Paywall plan art

What the illustration on each plan card has to be, and why. One image per billing period, so a
glance at the two cards says something before a word is read.

Everything here is Remote Config: swapping art is a config edit, not a release.

**Shipping today** (2026-09-23): monthly plays `assets/lottie/plan_monthly.json` — a 600 × 600,
5.6 s Lottie of the wizard behind a grid of checks filling in, transparent, 148 KB, looping. Weekly
shows `assets/images/plan_weekly_cutout.png`, the wizard holding a week planner, 560 × 560
with alpha, 36 KB. The animation against the still image is itself the contrast the two cards
needed.

One note on the weekly file. It was supplied as `plan_weekly.png`, 1254 × 1254 **opaque RGB**
— `plan_weekly_cutout.png` is that file with its near-black background flooded to alpha and
resized to 560; the original is kept beside it, unused, in case the cutout needs redoing.

## Where it plugs in

| Key | Today | Meaning |
|---|---|---|
| `paywall_config.metadata.option_visuals.<option id>` | monthly `assets/lottie/plan_monthly.json`, weekly `assets/images/plan_weekly_cutout.png` | that plan's art — a bundled asset path **or an `https://` URL**; `.png` / `.jpg`, `.json` (Lottie) or `.svg` |
| `paywall_config.options[].art_color` | monthly `#FFF1E2`, weekly `#EEF7F6` | the tint behind it |
| `paywall_config.metadata.visual_width` / `visual_height` | `120` | how big the art is drawn (default 88; height is capped at the block) |
| `paywall_config.metadata.art_block_height` | `132` | height of the tinted block, shared by every card (default 110) |
| `paywall_config.metadata.animation_looped` | `true` | whether a Lottie repeats or plays once |

Point an option at a new file and that card draws it; name nothing and the card falls back to
the shared mascot. Either way it goes through `VisualAssetWidget`, the same widget the
onboarding and home templates use for configured visuals, so images, Lottie, SVG, bundled
assets and URLs all behave identically here. **Art is drawn as given** — never dimmed, never
tinted — so the file is the final word and `art_color` is only what sits behind it.

### Bundled file or URL

A value starting with `http://` or `https://` is fetched instead of loaded from the bundle, so
**art can be replaced without an app release** — the same is true for a Lottie or an SVG. A
bare path like `images/plan_monthly.png` gets `assets/` prepended.

Two things to know before relying on it. There is no loading or error state on that path: a
slow URL shows nothing until it arrives and a dead one shows nothing at all, rather than
falling back to the mascot. And it is a network fetch while the paywall is on screen, on a
screen that decides revenue. So bundle the launch art, and keep the URL for changing art
afterwards or for an experiment. Serve it over `https` from a CDN, at the same pixel size as a
bundled file would be.

## Hard constraints

These come from the code, not from taste.

| | Value |
|---|---|
| Rendered size | **120 pt** on the plan cards (`visual_width` / `visual_height`, default 88), 64 pt in the compact layout |
| Art block | **132 pt** tall (`art_block_height`, default 110), full card width (~132 pt on a 390 pt phone), 14 pt corner radius, clipped |
| Source size | ~560 × 680 px, matching `wizard_cutout.png` (558 × 678) — comfortably above 3× |
| Format | PNG with alpha. RGBA, not RGB |
| Background | **None.** The card paints `art_color` behind it |
| Weight | ≤ 150 KB each after optimisation |

Two consequences worth internalising:

- **120 points is still small.** A feature narrower than about 3 pt of the source disappears.
  Anything the two images are supposed to differ by has to survive being drawn that size on a
  phone. Test it by looking at the art at that size, not at full size.
- **The block caps the art.** `visual_height` is clamped to `art_block_height`, so growing the
  art means raising both — the block clips, and every card shares its height so the pair stays
  level. Raising it makes the whole card taller.
- **No baked-in background.** The current cutout has a yellow disc painted behind the wizard,
  which fights the card's own tint. New art must be a clean cutout on transparency.

## The character, shared

Both images are the same wizard, drawn the same way. Only pose, prop and palette change.

- Bearded wizard, shoulders-up or waist-up, facing the viewer.
- Purple pointed hat carrying a `%` symbol. Dark sunglasses. Ginger beard and hair.
- Flat vector cartoon. Thick dark outline, uniform weight. Flat fills, minimal shading, no
  gradients, no texture, no drop shadows.
- Same crop and same eye line in both, so the pair sits level across the two cards.

Palette, from the design tokens:

| Role | Hex |
|---|---|
| Outline | `#14121B` |
| Robe / hat | `#7B5EA7`, shaded `#4B3F66` |
| Skin, hair | warm orange `#F0A045` family |
| Accent, screens | teal `#4ECDC4` |
| Highlight, sparkles | yellow `#FFD166` |

## What each plan's image has to say

### Monthly — the committed plan

Sold as the better deal: three days free, "one saved deal covers the month", 34% cheaper than
paying weekly. The image should read as **settled, in control, playing the long game**.

- Pose: relaxed and confident. Arms open or leaning back, unhurried.
- Prop, one and large: a stack of coins or bills, or a calendar page — something that says
  *repeated* rather than *once*.
- Tint: warm amber `#FFF1E2`.

### Weekly — the quick plan

No trial, "just this week?", one deal and out. The image should read as **fast, in motion,
right now**.

- Pose: mid-action. Casting, pointing, sleeves up, leaning into it.
- Prop, one and large: the phone mid-spell with sparkles coming off it, or a wand in motion.
- Tint: cool mint `#EEF7F6`.

The contrast to aim for is *still* against *moving*. That survives shrinking to 88 pt, where a
calendar versus a wand would not.

## Generation prompts

Ready to paste. Generate both in one session so the character stays consistent, and keep the
seed if the tool offers one.

**Shared style suffix** — append to both:

> Flat vector cartoon illustration, thick uniform dark outline `#14121B`, flat fills, no
> gradients, no shading detail, no drop shadow. Transparent background, subject cut out, no
> background shapes or discs. Centred, shoulders-to-waist crop, facing viewer. Palette: purple
> robe `#7B5EA7`, orange skin tones, teal `#4ECDC4` accents, yellow `#FFD166` highlights.

**Monthly:**

> A friendly bearded wizard in a purple pointed hat with a `%` symbol on it, wearing dark
> sunglasses, arms relaxed and open, calm and confident, a neat stack of gold coins beside him.

**Weekly:**

> A friendly bearded wizard in a purple pointed hat with a `%` symbol on it, wearing dark
> sunglasses, leaning forward mid-spell, one arm raised casting, holding a glowing phone with
> teal sparkles flying off it, sense of speed and motion.

## Delivering

1. Save as `assets/images/plan_monthly.png` and `assets/images/plan_weekly.png`. The folder is
   already bundled, so no `pubspec.yaml` change. (To try art without a build, host it and put
   the `https://` URL in the config instead — see above.)
2. Optimise (`pngquant` or `oxipng`) and confirm each is under 150 KB with alpha intact.
3. Point the config at them:

```json
"option_visuals": {
  "monthly": "assets/images/plan_monthly.png",
  "weekly": "assets/images/plan_weekly.png"
}
```

4. Look at both cards on a phone. If you cannot tell the two apart at a glance, the difference
   was too fine — go back to pose and silhouette, not detail.

## The explainer steps

The two screens before the plans take their own art from `paywall_config.steps[].visual`,
the same path rules as above. Today: intro plays `assets/lottie/wizard_hearts.json`
(560 × 540, 4 s, transparent, hearts rising over the wizard), reminder plays
`assets/lottie/notification.json`.

Size comes from `steps[].visual_size`, defaulting to 180 — intro ships **270**. The screen
scrolls above the note and button, so a large one costs only the room it takes; the copy and
the CTA stay reachable on a 320 pt phone. Step visuals **always loop**: they ignore
`animation_looped`, which only governs the plan cards. A `.png` there is special-cased onto a
yellow disc (`WizMascotOnDisc`); anything else renders as-is.

## Cutting out supplied art

Art has arrived as a full-frame render with an opaque background and wide margins each time.
The recipe that turns one into a usable asset, the same for every `*_cutout.png` in the repo:

1. Flood-fill from all four corners with a tolerance of about 25. The background goes; the
   illustration's dark outline stops the flood, and an enclosed light area — a speech bubble,
   a yellow disc — is never reached because its outline encloses it.
2. Turn the flooded region into alpha, then crop to `getbbox()` so the art fills its slot
   instead of floating in blank space.
3. Resize the long side to 560 and quantise to 128 colours. Flat vector art loses nothing
   visible and the file drops by an order of magnitude — 1.3 MB to 43 KB is typical.
4. Check it by compositing over the real background colour, not by looking at the alpha: a
   viewer shows transparency as black, which is indistinguishable from a black background.

Keep the original until the cutout is confirmed; a supplied file that is not yet in git has no
other copy. Flutter does leave one in `build/unit_test_assets/` after a test run.

## Elsewhere in the app

The same cutout discipline applies to any illustration a template names. Rate us uses
`assets/images/wizard_yes_cutout.png` on both of its surfaces — the onboarding step and the
home dialog — cut out from the supplied `wizard_yes.png`, which arrived 941 × 1672 with an
opaque white background and wide empty margins. It is cropped to its content so the art fills
the slot it is given rather than floating in blank space: 330 pt on the onboarding step
(`metadata.width` / `height`) and 210 pt in the dialog (`rate_us_modal_config.visual_width` /
`visual_height`, which the dialog ignored until it was wired on 2026-09-23). The art is
portrait at 451 × 560, so a square slot is filled by its height — 330 draws it 266 × 330.

At that size the onboarding step has little room left for its title, body and two buttons, so
the visual sits in a `Flexible` + `FittedBox(scaleDown)`: on a short screen the art gives way
instead of overflowing, and on a normal one nothing changes. Raise the number freely; the
layout absorbs it.

A test walks every value in the bundled template and fails if an `assets/` path it names is
missing or sits outside a folder `pubspec.yaml` bundles
(`test/core/config/remote_config_assets_test.dart`).

## Known limits

- Cut out and ready but referenced by nothing: `plan_monthly_cutout.png` (the still of the
  monthly scene, which the Lottie animates) and `wizard_hearts_cutout.png` (the still of the
  paywall intro scene). `plan_monthly.png` is the last 1.7 MB original still in the tree and
  is superseded by its cutout.
- `wizard_cutout.png` and `wizard_mascot.png` are the same illustration, cut out and not; the
  second is unused. They remain the fallback when a plan names no art.
- `metadata.visual_opacity` is still read only by the legacy onboarding paywall widget.
  Nothing applies it here on purpose: fading art a plan named would be editing it rather than
  laying it out. `visual_width` / `visual_height` are wired as of 2026-09-23.
- Nothing else about the block is configurable: its corner radius and the card's padding
  around it are fixed in code.
