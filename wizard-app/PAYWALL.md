# Paywall

What the paywall sells, how it is configured and how it draws. Everything here is Remote
Config: changing the offer, its wording or its art is a config edit, not a release.

The paywall is `paywall_config` in Remote Config, with its store products in
`subscription_config` and defaults for both in `assets/config/remote_config_defaults.json`.
The bundled value is only the fallback: a published key replaces its whole JSON value, not
field by field, so every change here must also be published (the general rule, and how to
edit a template string safely, are in `AGENTS.md` and the `onboarding-screen` skill).
`test/features/paywall/bundled_offer_test.dart` parses the bundled file and fails if the offer
below drifts, or if any of its wording is missing, loses a placeholder, or ships without
Spanish.

Producing or replacing the character art itself is the `illustration-asset` skill; this file
covers only how the paywall takes and draws it.

## What Premium unlocks

This is the one place in the repo that says which features are paid.

One paid tier, `premium`. The rules are fixed in code (`FeatureGatePolicy`,
`lib/core/config/feature_gate_policy.dart`), because they are part of the offer, not remote
configuration:

| Feature | `free` | `premium` |
|---|---|---|
| Lines that land | yes | yes |
| Express Dealmaker | paywall (context hint `free`) | yes |
| Pro Deal Closer | paywall (context hint `free`) | yes |
| History, Profile | yes | yes |

`FeatureGateService` applies it (`FeatureAccess.ensure` on the Express and Pro pages, the
Home CTAs). `paywall_config.entry_points` and `subscription_config.products[].features` are
informational; neither gates anything.

The entitlement is what the store SDK reports: `in_app_purchase` purchase/restore events →
product id → tier via `subscription_config`, kept in `SharedPreferences`
(`subscription_status`) so the tier is known offline and at cold start. Restore drops it only
when the store reports no active purchase. On iOS the plugin uses StoreKit 2, so Restore
reports only *current* entitlements, and `IAPPaymentProvider` reads the platform-neutral
fields (a cast to `AppStorePurchaseDetails` would throw on StoreKit 2 transactions). Nothing
verifies receipts server-side and the AI functions do not check entitlement: the gate is
client-side only.

## The offer

The tier is sold as two store products, monthly (`com.bargain.wiz.premium.monthly`, $19.99)
and weekly (`com.bargain.wiz.premium.weekly`, $6.99). Each `subscription_config` product
carries an `id` ("monthly" / "weekly") and the `paywall_config` option with the same `id`
buys it, so the paywall resolves prices and product ids per option, not per tier. The store
price is shown with the option's `price_suffix` ("$19.99" + "/mo") so the billing period is
always next to the amount. Prices in `price_label` are only the offline fallback; the stores'
regional price tiers are the source of truth. Monthly leads the offer: it is first in
`options`, it is `default_selected_option_id`, and it is the only card that badges anything.

## Payment provider

`paywall_config.payment_provider` picks the store the paywall charges through: `iap` (the
default) or `stripe`. `RemoteConfigService.getPaymentProviderType()` reads it; anything other
than `stripe`, or no paywall config at all, is IAP. Remote Config is the only switch — there is
no build flag. The choice is resolved once per run, when `injection_container.dart` first
builds the `PaymentProvider` lazy singleton, so a published change reaches an install on a
later launch, after its Remote Config has picked it up.

**`stripe` is a placeholder.** `StripePaymentProvider` throws `UnimplementedError` from every
method, so publishing `stripe` today breaks loading products, purchase and restore.

## The trial and the timeline

`trial_days` is the single source for the trial, and it lives **per option** (the
paywall-level value is only the fallback for an option that omits it): monthly sets 3, weekly
sets 0 explicitly rather than inheriting. Three is deliberate: it is the shortest free trial
either store will create. **The trial itself is a store offer, not app state** — it has to
exist as an introductory offer on the monthly product in App Store Connect and Play Console,
and a mismatch between what the app promises and what the store grants would fail App Store
review under guideline 3.1.2.

An option's `trial_days` drives the trial pill on its card, its note, its CTA, and the three
timeline rows: today, the day before the end, and the billing day. They are titled relatively
— "Today", "In 2 Days – Reminder", "In 3 Days – Billing Starts" — from plural texts so "In 1
Day" reads; the billing row's subtitle names the date and **not** the amount
(`PaywallDates.monthDayYear` spells the year out because that row names the day money moves).
An explicit `trial_timeline` list replaces the derived rows (empty today). Selecting the
weekly card shows no timeline and says nothing about a trial. The Profile card's "Trial ends
in n days" follows the period that was actually bought, so a weekly subscriber never sees
trial copy.

Per-option keys, overriding the paywall-level ones so a period with a trial and one without
never share a sentence: `trial_days`, `trial_badge` (a plural text filled with `{n}`, shown
**first in the badge row** while that option's trial is greater than zero), `note_text` and
`button_text`. `steps` holds the two explainer screens shown before the plans (intro, then
the reminder step whose `button_action: request_permission` asks for push); an offer with
`steps: []` and `trial_days: 0` renders as a single screen with no timeline.

## Where the wording lives

**No offer wording lives in Dart.** The app decides *which* line applies and the template
decides *what it says*, so a plan change is a Remote Config edit and never a release. An
unconfigured string renders as nothing rather than as English describing an offer this build
cannot know. That covers the plans step (title, description, the cards, the note, the CTA and
the context hint), the explainer steps, the timeline (`timeline_*_text` /
`timeline_*_subtitle`, placeholders `{day}`, `{date}`, `{plan}`, `{price}`; only the day
numbers are computed) and — via the `plan_card` section — the Profile "current plan" card and
the drawer footer's plan name:

| `plan_card` key | Shown when | Placeholders |
|---|---|---|
| `label` · `free_name` · `paid_name` | always | — |
| `free_subtitle` | free tier | — |
| `trial_subtitle` (`{"one": …, "other": …}`) | paid, inside the trial | `{n}`, `{price}` |
| `trial_ends_today_subtitle` | paid, the last day of the trial | `{price}` |
| `renews_subtitle` | paid, the store reported a renewal date | `{date}`, `{price}` |
| `active_subtitle` | paid, no date (a restore, or a QA tier override) | `{price}` |
| `upgrade_cta` · `manage_cta` | free / paid | — |

The exceptions are strings that cannot come from the template by definition: the "plans are
unavailable" state (shown when the config itself is missing), the store-timeout and
restore-result toasts, and the debug tier-override labels.

Two switches sit beside `show_restore` / `show_close` (the close button appears after
`close_button_delay_seconds`, 5), both currently **false**, with their wording left configured
so either comes back without a release: `show_context_hint` (the amber hint above the plans)
and `show_note` (the line between the plans and the CTA). The note is where the
trial-to-billing terms were spelled out, so while it is hidden the trial timeline is what
states them — keep `trial_days` above zero — and the plan card's price line is the only place
the amount appears, so keep it visible.

## Plan cards

| Key | Today | Meaning |
|---|---|---|
| `metadata.option_visuals.<option id>` | monthly `assets/lottie/plan_monthly.json`, weekly `assets/images/plan_weekly_cutout.png` | that plan's art — a bundled asset path **or an `https://` URL**; `.png` / `.jpg`, `.json` (Lottie) or `.svg`. None named → the shared mascot |
| `options[].art_color` | monthly `#FFF1E2`, weekly `#EEF7F6` | the tint behind the art (`#RRGGBB`); unset → amber for the preselected plan, mint for the rest |
| `metadata.visual_width` / `visual_height` | `120` | how big the art is drawn (default 88; height is capped at the block) |
| `metadata.art_block_height` | `132` | height of the tinted block, shared by every card (default 110) |
| `metadata.animation_looped` | `true` | whether a Lottie repeats or plays once |
| `metadata.card_style` | `glow` | how the **selected** card is emphasised on top of its ink border: `glow` (the handoff's amber halo), `shadow` (a plain drop shadow) or `flat` (border only); cards and list rows alike, an unknown value falls back to `glow` |
| `metadata.title_font_size` · `description_font_size` | `17` · `12.5` | card title and description |
| `metadata.price_font_size` · `price_font_weight` · `price_font_family` | `11` · `300` · `body` | the price |
| `metadata.price_glow` | `false` | an amber halo (`WizShadows.textGlow`) on the **selected** card's price only |
| `options[].badges` | `[]` | extra pills, in the template's order, after the trial pill |
| `options[].description_highlight_words` | monthly `{"You save 34% with this plan": "bold #117E76"}` | phrases emphasised inside that card's own description |

`metadata.visual_opacity` (0.95 in the template) is ignored here on purpose — fading art a
plan named would be editing it rather than laying it out; only the legacy onboarding paywall
widget reads it.

The price is deliberately the quietest text on the card: smaller than the description and
genuinely light. **A weight only renders if it is bundled** — asking for one that is not
silently falls back to the nearest that is. Outfit ships 500/600/700; Figtree ships
300/400/500/600, and a test fails if `price_font_weight` names a file `pubspec.yaml` does not
carry. One `priceStyleOf` builds the style for the cards, list and compact layouts alike.

Badges are a **row** straddling the card's top edge. The trial pill is prepended to `badges`
rather than stored in it, so a claim about the trial cannot outlive `trial_days`; the saving is
stated in monthly's description instead of a badge, so the card carries one pill. The row
wraps over the art instead of clipping when it outgrows the card, and the older single `badge`
field still renders as a one-pill row. A highlight value is `bold`, a hex colour, or **both
together**; that form works anywhere the shared highlighter is used, including the onboarding
templates. Matching is case-insensitive so both languages fit in one map, and a test fails if
a highlighted phrase is not actually written in the copy.

## Plan art

Each plan's art is `metadata.option_visuals.<option id>`, drawn over that option's
`art_color` in a block `art_block_height` tall. Point an option at a new file and that card
draws it; name nothing and the card falls back to the shared mascot
(`assets/images/wizard_cutout.png`). Either way it goes through `VisualAssetWidget`, the same
widget the onboarding and home templates use for configured visuals, so images, Lottie, SVG,
bundled assets and URLs all behave identically here. **Art is drawn as given** — never
dimmed, never tinted — so the file is the final word and `art_color` is only what sits
behind it.

### Bundled file or URL

A value starting with `http://` or `https://` is fetched instead of loaded from the bundle, so
**art can be replaced without an app release** — the same is true for a Lottie or an SVG. A
bare path like `images/plan_monthly.png` gets `assets/` prepended.

Three things to know before relying on it. There is no loading or error state on that path: a
slow URL shows nothing until it arrives and a dead one shows nothing at all, rather than
falling back to the mascot. It is a network fetch while the paywall is on screen, on a screen
that decides revenue. And a URL belongs in the **published** template only: the bundled
defaults must name files under `assets/images/` or `assets/lottie/`, which the bundled-offer
test enforces. So bundle the launch art, and keep the URL for changing art afterwards or for
an experiment. Serve it over `https` from a CDN, at the same pixel size as a bundled file
would be.

### What the card renders

These come from the code, not from taste.

| | Value |
|---|---|
| Rendered size | **120 pt** on the plan cards (`visual_width` / `visual_height`, default 88), 64 pt in the compact layout |
| Art block | **132 pt** tall (`art_block_height`, default 110), the card's full inner width (about 135 pt on a 390 pt phone), 14 pt corner radius, clipped |
| Format | A Lottie (`.json`, transparent — what monthly ships), a PNG that carries alpha (RGBA, or palette + `tRNS` — what weekly ships), a JPG or an SVG |
| Background | **None.** The card paints `art_color` behind it |

The **block caps the art.** `visual_height` is clamped to `art_block_height`, so growing the
art means raising both — the block clips, and every card shares its height so the pair stays
level. Raising it makes the whole card taller.

The bundled-offer test also holds the bundled art to this: every option names its own file
and no two share one, each file exists in a bundled folder, a plan PNG must be able to carry
transparency (opaque RGB fails — it would paint a block over `art_color`), each file is under
400 KB, the animation loops and the block is taller than its default.

## The explainer steps

The two screens before the plans take their own art from `paywall_config.steps[].visual`,
the same path rules as above except for a `.png` (below). Today: intro plays
`assets/lottie/wizard_hearts.json` (hearts rising over the wizard), reminder plays
`assets/lottie/notification.json`.

Size comes from `steps[].visual_size`, defaulting to 180 — intro ships **270**. The screen
scrolls above the note and button, so a large one costs only the room it takes; the copy and
the CTA stay reachable on a 320 pt phone. Step visuals **always loop**: they ignore
`animation_looped`, which only governs the plan cards. A `.png` path there is **not drawn**:
`PaywallStepVisual` shows the shared mascot on a yellow disc (`WizMascotOnDisc`) instead,
whichever file was named. Give a step a Lottie or an SVG; any path not ending in `.png`
renders as-is through `VisualAssetWidget`.

A step's CTA advances to the next step; `button_action: request_permission` (or, in older
configs with no `button_action`, the id `reminder`) also asks for notifications through
`FirebaseService.requestNotificationPermission()`.
