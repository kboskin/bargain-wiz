# Bargain Wiz – Product & Design Specification

> Brief for a design service. Goal: understand the product well enough to redesign it and generate high-fidelity mockups.
> Source of truth: the current Flutter codebase (`wizard-app/`) and its remote-config defaults. Everything below describes what exists today plus clearly labeled gaps.

---

## 1. One-liner

**Bargain Wiz is an AI negotiation coach in your pocket.** Drop a screenshot of a marketplace listing or a chat with a seller, and the "wizard" hands you ready-to-paste lines that get you a better price.

Tagline in product: *"Get the Best Deals. Outsmart every price. Never overpay again."*

---

## 2. Problem & purpose

### The problem
People buy and sell on peer-to-peer marketplaces (eBay, Facebook Marketplace, OLX, Craigslist, Amazon third-party) every day, but most of them:

- never negotiate because they don't know how to open;
- accept the first counter-offer because they don't know how to push back;
- worry about sounding rude or cheap;
- have no idea what a fair price actually is.

Negotiation is a learnable skill, but nobody wants to read a book about it in the 30 seconds between seeing a listing and messaging the seller.

### What the app does
It collapses that skill into a copy-paste action:

1. User captures the situation (screenshot of listing / chat, or a typed description).
2. AI reads it and proposes 3+ negotiation lines in the user's chosen tone.
3. User taps a line, it's copied, they paste it into the marketplace chat.

Secondary value: a library of proven "lines that land" for opening, following up, and closing, available even without a screenshot.

### Business model
Free tier (Lines that land, History, Profile) plus one paid plan, Premium, sold monthly ($19.99, preselected as "Best value") or weekly ($6.99). The 3-day free trial is on the monthly product only, and monthly leads (first, preselected, "Best value" badge; 2026-09-22); the earlier text-only vs. vision tiers were dropped on 2026-09-21. Three days is the shortest free trial App Store Connect and Play Console will create, so the in-app copy matches what the store product grants; the trial is an introductory offer on the monthly product, set up per store. Referral program and share prompts for growth. Rate-us prompt feeding App Store / Play Store reviews.

---

## 3. Target users & personas

### Primary persona: "Casual Marketplace Buyer" – Dana, 29
- Buys 1–5 second-hand items a month (furniture, electronics, kids' gear) on Facebook Marketplace / OLX.
- Knows haggling is normal but freezes when it's time to type the message.
- Wants to feel confident, not pushy. Values speed: is usually standing in the living room with the phone in one hand.
- Success = "I sent that line and they came down $40."

### Secondary persona: "Reseller / Flipper" – Marco, 35
- Buys and sells 6+ items a month. Negotiation is part of the job.
- Wants sharper, faster counter-offers and a consistent tone. Will pay for anything that increases margin.
- Uses the app dozens of times a week; cares about history and re-opening past deals.

### Tertiary persona: "Nervous First-Timer" – Priya, 22
- Never negotiated anything. Onboarding hurdle: "Starting the conversation" / "Worrying about being rude".
- Needs the friendliest tone preset and strong reassurance copy.

### Onboarding signals we already collect (all remote-configurable)
| Question | Answer key | Options |
|---|---|---|
| Gender (playful) | `gender` | Witch / Wizard / Other |
| Deals per month | `deals_per_month` | 0–2 / 3–5 / 6+ |
| Where did you hear about us | `referral_source` | TikTok, YouTube, Google, Play Store, Facebook, Friends, Instagram, X, Other |
| Tried other AI assistants | `tried_other_apps` | Yes / No |
| Primary goal | `primary_goal` | Start negotiating / Negotiate better / Get best price |
| Negotiation vibe (AI tone) | `negotiation_vibe` | Friendly Collaborator / No-Nonsense Buyer / Tactical Strategist / Quiet Closer |
| Biggest hurdle | `main_hurdle` | Starting / Counter-offers / Being rude / Fair price |
| Risk tolerance (slider) | `risk_tolerance` | Conservative → Aggressive (5 stops, emoji + color) |
| Primary platform | `favorite_marketplace` | eBay, Amazon, Facebook, OLX, Craigslist, Other |
| Average deal size (slider) | `average_deal_size` | $0–100 / $100–1000 / $1000+ |

These personalize the AI's voice and are prime material for a "profile" screen that does not exist yet.

---

## 4. Core jobs to be done

| # | Job | Current feature | Priority |
|---|---|---|---|
| J1 | "I have a listing/chat in front of me, give me what to say right now." | **Express Dealmaker** (screenshot → lines) | P0 |
| J2 | "Let me describe the deal and go back and forth with an assistant." | **Pro Deal Closer** (chat with wizard) | P0 |
| J3 | "I just need a good opener / follow-up / closer." | **Lines that land** (curated library) | P1 |
| J4 | "Show me my past deals so I can reuse or continue them." | **Bargains history** (thumbnail grid on home) | P1 |
| J5 | "Set the wizard's tone to match me." | Onboarding questionnaire (no editing later) | P1 |
| J6 | "Unlock the full power / manage my plan." | **Paywall** + tiers | P0 (revenue) |
| J7 | "Tell friends / get rewarded." | Share pill, **Refer** sheet | P2 |
| J8 | "Give feedback / rate." | **Rate Us** dialog → store review or **Feedback form** | P2 |

---

## 5. Platform & technical constraints (affect design)

- **Flutter, iOS + Android**, portrait phone only. No tablet/web today.
- **Light theme only** in production. Dark text-style variants exist in code but no dark palette is designed.
- **Localization: English and Spanish.** All copy must be designed to accommodate ~30% longer Spanish strings.
- **Almost every screen is remote-configured** (Firebase Remote Config): titles, descriptions, button colors, highlight words, Lottie visuals, gradient backgrounds, paywall layout (`cards` / `list` / `compact`), onboarding screen order. Design should be **template-based** – components must survive text and color being swapped without code changes.
- **Onboarding is a screen-type system.** Types available: `welcome`, `engagement`, `warmup`, `select`, `slider`, `slider_lottie`, `image_list`, `permission`, `referral_code`, `create_account`, `paywall`, `data_upload`. Each needs one designed template.
- **Lottie animations** are the primary illustration medium (wizard waving, falling money, potion pot, magic wand, sparkles, notification bell, "all done").
- **Glassmorphism over a pastel gradient** is the current visual language (see §7).
- Interaction primitives already in use: tap-to-copy with haptic, long-press for "more", press-and-hold mic for dictation, bottom sheets with drag handle, vertical page-scroll between "home" and "chat" panes.
- Permissions requested: photo library (required for core flow), notifications (onboarding), microphone (chat dictation).
- Sign-in: Google and Apple only. Account is optional (can be skipped).

---

## 6. Information architecture & screen inventory

```
Splash
└─ Welcome (title, tagline, Get Started, "Already have an account? Sign in")
   └─ Onboarding flow (progress bar + back, ~16 screens, remote-ordered)
      ├─ Select screens ×7 (gender, deals/mo, source, tried others, goal, vibe, hurdle, platform)
      ├─ Slider (deal size, Lottie changes per stop)
      ├─ Slider Lottie (risk tolerance "magic tube")
      ├─ Warmup ("YOU have fantastic potential… pay up to 40% less")
      ├─ Permission (notifications, Allow / Don't Allow)
      ├─ Referral code (optional input)
      ├─ Paywall (see below)
      ├─ Create account (Google / Apple / Skip)
      ├─ Engagement ("You're All Set!")
      └─ Data upload (fake progress: "Setting up your personal magician…")
Home
├─ App bar: ☰ drawer · "Bargain Wiz" · [Share] pill
├─ State A – Empty: headline + wizard Lottie + 3 CTAs
├─ State B – History: 3-col grid of past deals (3:4 thumbnails, ✕ delete) + same 3 CTAs
├─ State C – Express Dealmaker (in place of A/B)
│   ├─ Uploading: centered screenshot cards with scan-line overlay
│   ├─ Ready: screenshot stack · "Add screenshot" · keyword field · "👇 tap a reply to copy 👇" · reply cards · [✨ Get More]
│   └─ Error: per-card Retry, bottom button becomes [🔄 Retry]
├─ State D – Pro Deal Closer (page scrolls down one viewport)
│   ├─ Wizard prompt bubble "What's the deal about?"
│   ├─ User bubbles (text and/or image attachments with scan overlay)
│   └─ Input bar: [+photo] [text field] [mic hold] [send]
├─ Bottom sheet – Lines that land (glass, categories → one pill each, tap to copy)
├─ Bottom sheet – Refer (title, 3 ✓ benefits, [Share invite link])
├─ Dialog – Rate Us ("Are you satisfied?" `wizard_yes_cutout.png` at 210 pt from `visual_width`/`visual_height`, No / Yes)
└─ Drawer (frosted glass): Profile*, Bargains History*, Rate Us, Refer, Terms, Privacy, Log out
Paywall (modal, also shown on app resume)
├─ Step 1 "intro": "We want you to try Bargain Wiz for free." · `wizard_hearts.json` (560×540, 4 s, looping) at 270 pt from `visual_size` [Try for $0.00]
├─ Step 2 "reminder": "We'll send you a reminder before your free trial ends." · `notification.json` [Continue for FREE] → asks for push
└─ Plans: Monthly ("3 days free" badge, preselected) vs Weekly (no trial, no badge) · timeline and note/CTA follow the selected period · Restore · Terms/Privacy · delayed ✕
   (steps and the timeline are config: an offer with `steps: []` and `trial_days: 0` renders as one screen)
Feedback form (email optional, message required, [Send])
Sign-in modal (Google / Apple)
```
`*` = menu item exists, destination screen not built.

---

## 7. Current visual identity (baseline to evolve, not a mandate)

### Mood
Playful-magical meets fintech-clean. A friendly bearded wizard in sunglasses with a "%" on his hat is the mascot; he holds a phone showing a handshake. The interface should feel like "a spell that saves you money", not like a spreadsheet.

### Color
| Role | Value | Notes |
|---|---|---|
| App background gradient | `#E8D5FF → #FFE5B4 → #E0F7FA` (lavender → peach → ice blue, top-left to bottom-right) | Used on onboarding and home |
| Primary CTA | `#000000` pill, white text | High contrast against pastel |
| Secondary CTA | White pill, `#E5E7EB` 1.2px border, black text | |
| Glass surface | White at 25–45% opacity, 20–24px blur, 1–1.5px white 30–40% border | Cards, sheets, drawer, reply cards |
| Accent – teal (success / highlight) | `#4ECDC4` | Highlight words, "Allow", "Yes" glow buttons |
| Accent – amber (money / deals) | `#C47A00` | "Best deals" highlight |
| Accent – orange (energy) | `#FF6B35` | No-Nonsense vibe, "magic tube" |
| Accent – yellow | `#FFD166` | Tactical vibe |
| Mascot palette | Purple `#7B5EA7`-ish robe & hat, yellow `#F9C74F` sun disc, cyan `#5CE1E6` phone | From `wizard_mascot.png` |
| Text primary / secondary / tertiary | `#000000` / `#6B7280` / `#9CA3AF` | |
| Semantic | error `#EF4444`, success `#10B981`, warning `#F59E0B`, info `#3B82F6` | |
| Legacy "primary" (unused in UI) | Indigo `#6366F1` | Defined in theme but not visible anywhere |

### Typography
System font (Roboto / SF Pro) on the Material 3 type scale. Headlines 24–34 bold, body 14–16, labels 14 medium, CTA button text 18 semibold. Highlight words in headlines get a colored or bolder treatment, driven by config.

### Shape
Generous radii: 24px primary buttons, 20px secondary, 12–16px cards, 32px sheet corners. Circles for icon buttons and numeric badges.

### Motion
Staggered fade-up-scale entrance for lists (250 ms per item), pulsing glow on primary onboarding buttons, bobbing hint text, scan-line sweep over uploading screenshots, equalizer bars while recording, Lottie loops for loading states.

### Voice & tone
Confident, short, a little cheeky. "Choose your magic." "Your deal, upgraded." "Lines that land." Avoid corporate hedging. Spanish copy is warm and informal (tú).

---

## 8. Detailed flow specs

### 8.1 First run
1. **Welcome** – gradient bg, large title "Get the **Best Deals**" (highlight amber), two-line tagline, mascot/Lottie inside a 500px glass container, black pill "Get Started", small "Already have an account? Sign in".
2. **Questionnaire** – top bar with back arrow + thin black progress bar. Each `select` screen: title, optional description, list of option cards (icon, label, optional subtext, brand color, sparkle Lottie on select), one continue button with custom text ("Looks Like Me", "Let's Go", "Set My Stance").
3. **Warmup** – persuasion screen with falling-money Lottie and side text "Stop your money from falling away".
4. **Notifications permission** – two glow buttons, grey "Don't Allow" and teal pulsing "Allow".
5. **Referral code** – single input, skippable.
6. **Paywall** – see 8.5.
7. **Create account** – Google / Apple / Skip.
8. **All set** – celebratory Lottie, "Let's go get those deals."
9. **Data upload** – potion pot Lottie, rotating status lines every 2.5 s, 5 s progress ramp, no buttons.

### 8.2 Home (empty)
- Headline center-top: "Add a product or negotiation screenshot" (config) or "Your deal, upgraded." (fallback).
- Waving wizard Lottie, 200×200.
- Bottom CTA stack: **[📷 Express Dealmaker]** black full-width; below it two half-width outlined buttons **[💬 Pro Deal Closer]** and **[✨ Lines that land]**.
- App bar right: black "Share" pill with icon.

### 8.3 Express Dealmaker (J1)
1. Tap CTA → native multi-image picker.
2. Screen swaps to upload view: selected screenshots as 3:4 cards in a row (up to what fits at ~140px), numbered badges, **scan-line overlay** while uploading. Additional images collapse into a 64px thumbnail strip.
3. When all uploads finish, AI reply is auto-requested. Loading = glass card with spinner.
4. Result = 3 glass reply cards, staggered entrance, copy icon on the right. **Tap or long-press copies** with light haptic. Hint above: "👇 tap a reply to copy 👇" bobbing.
5. Optional keyword field above results: "Give us a word or two to focus on" (e.g. "pickup today", "bundle").
6. Bottom sticky button **[✨ Get More]** regenerates; becomes **[🔄 Retry]** on failure. Failed uploads show a Retry chip on the card.
7. Back chevron (top-left, white circle) saves the conversation to history and returns home.

### 8.4 Pro Deal Closer (J2)
- Home page scrolls down one full viewport; back chevron scrolls up and saves.
- Reverse chat list. Wizard's white bubble "What's the deal about?" pinned at top of history.
- User messages right-aligned white bubbles; image attachments render as 165×280 tiles with scan overlay while "uploading".
- Input bar over a white fade gradient: black round buttons for attach / mic / send, white pill text field, mic shows equalizer while held.
- **Gap:** no AI response bubble exists yet. Design must define the wizard's reply (single message vs. multiple copyable options, typing indicator, regenerate, tone chip).

### 8.5 Paywall (J6)
- Multi-step: two persuasion steps (intro with vision-wizard Lottie, reminder with bell Lottie), each with its own headline, note ("No payment due now."), and button text.
- Plan step: title "Unlock Bargain Wiz", subtitle "One plan. Pick how you pay."; two option cards (Monthly · preselected, Weekly), glow border on selected, art per plan: `metadata.option_visuals[<option id>]` names that card's image, Lottie or SVG (honoured for images since 2026-09-22; both plans currently share `wizard_cutout.png`, the only wizard artwork in the repo; the brief for the pair that should replace it is `wizard-app/PAYWALL_ART.md`) and `options[].art_color` tints its 110 h block (monthly `#FFF1E2` warm, weekly `#EEF7F6` cool). Art renders as given, through the shared `VisualAssetWidget` that every configured visual in the app uses; a plan naming nothing falls back to the mascot; a **row** of ink pills with yellow text straddling the card's top edge (top -10, left/right 14, wrapping over the art when it outgrows the card): the `trial_badge` ("{n} days free") comes first while that option has a trial, then whatever `badges` lists (empty today) — so monthly shows just "3 days free" and weekly none — and the card copy does not repeat it — monthly's description carries the saving in bold teal ("One saved deal covers the month. **You save 34% with this plan.**") via that option's `description_highlight_words`, whose values may be `bold`, a hex colour, or both; type is config (`metadata.title_font_size` 17 / `description_font_size` 12.5 / `price_font_size` 12 / `price_font_weight` 300 / `price_font_family` body / `price_glow` false): the price is the quietest text on the card — smaller than the description and light, in Figtree 300 (instanced from the variable font; Outfit stops at 500) — and the optional amber halo (`WizShadows.textGlow`, selected card only) is off; each card carries the same feature list; price line "$19.99/mo" / "$6.99/wk" (store price + period suffix); vertical **trial timeline** derived from `trial_days`, worded on the pattern the category has settled on: "Today / Unlock all the app's features like screenshot reading and more.", "In 2 Days – Reminder / We'll send you a reminder that your trial is ending soon.", "In 3 Days – Billing Starts / Your plan begins on Mar 9, 2026. Cancel any time before then and you pay nothing." (the amount lives on the plan card, not here) Titles are relative and count days (plural texts, so "In 1 Day" reads); only the billing row carries the date, spelled with the year; note "3 days free, then {price}. Cancel anytime." (hidden by `show_note: false`, as is the amber context hint by `show_context_hint: false`; both keep their wording); **[Try 3 days free]**; Restore Purchases; Terms / Privacy links; close ✕ appears after 5 s (configurable).
- The timeline wording is configured (`timeline_*_text` as plural texts, `timeline_*_subtitle`, EN + ES) but the day numbers and dates are not: change an option's `trial_days` and its pill, note, CTA, the timeline and the Profile plan card all follow. The timeline, the note and the CTA belong to the **selected** period, so the weekly card shows no timeline and promises no trial.
- **Every word of the offer is Remote Config**, including the Profile "current plan" card and the drawer's plan name (`paywall_config.plan_card`: label, free / paid name, the free · trial · renews · active subtitles with `{n}` `{price}` `{date}`, and the upgrade / manage CTAs). The app picks which line applies; the template says what it reads. Nothing unconfigured falls back to English, so changing the plan never needs a release — and the plan card hides its label, subtitle or CTA when the template leaves them out. Only states the template cannot describe stay in code: "plans are unavailable" (the config itself is missing), the store-timeout and restore toasts, and the debug tier override.
- Layout variants required: `cards`, `list`, `compact` (`metadata.layout`). `metadata.card_style` picks the selected card's emphasis: `glow` (amber halo, ships), `shadow` or `flat`; it applies to the cards and the list rows, and an unknown value falls back to `glow`.
- Tiers: **Free** = Lines that land, History, Profile. **Premium** = Express Dealmaker, Pro Deal Closer (screenshots included in both), unlimited deals. Billing period (monthly / weekly) is a product choice, not a tier.

### 8.6 Lines that land (J3)
Glass bottom sheet, drag handle, ✕. Loading shows waving wizard. Then category cards (Opening lines, Follow-ups, Closing), each showing one pill-shaped line with a copy icon. Tap = copy + snackbar "Copied to clipboard". Content is remote-configured, so design should allow N categories × N lines and consider a "shuffle / see more" affordance.

### 8.7 History (J4)
Replaces the empty state once ≥1 conversation exists. 3-column grid of 140×187 cards showing first screenshot (or a chat-bubble placeholder for text-only deals), ✕ in the corner to delete. Tap re-opens the conversation in its mode. No titles, dates, marketplace, or outcome are shown today.

### 8.8 Growth & feedback (J7, J8)
- **Share** pill: native share sheet with title, description, deep link.
- **Refer** sheet: glass, title "Invite friends & **earn**", three ✓ benefits, **[Share invite link]**.
- **Rate Us** dialog: glass two-choice modal, star Lottie, "Are you **satisfied**?", grey No → feedback form, teal pulsing Yes (with wand Lottie) → native store review.
- **Feedback form**: config-driven fields (email, textarea), single Send.

---

## 9. Design principles for the redesign

1. **Screenshot to sentence in under 10 seconds.** Every extra tap between "I have a listing" and "I copied a line" is a defect.
2. **Thumb-first.** All primary actions in the bottom 40% of the screen. Long content scrolls; controls don't.
3. **Copy is the conversion.** Reply cards are the hero component. Make them unmistakably tappable and celebrate the copy (haptic + micro-animation).
4. **Configurable by design.** Every screen is a template that survives new copy, new colors, new Lottie, and Spanish text 30% longer.
5. **Magic, not gimmick.** The wizard theme sets tone through illustration and motion, not through cluttered UI. Glass and gradient must never reduce text contrast below WCAG AA.
6. **Show the personality we collected.** The user told us their vibe and risk tolerance; the UI should reflect and let them change it.
7. **Trust around money.** Paywall and trial timeline must be transparent (dates, price, cancel path) to meet store guidelines and reduce refunds.

---

## 10. Known gaps & questions for the design service

| Area | Gap / question |
|---|---|
| Pro Deal Closer | No AI reply UI. Define wizard message bubble, multiple-option layout, typing state, regenerate, tone switcher. |
| Profile | Drawer item exists, no screen. Propose profile with editable vibe / risk / platform, subscription status, account. |
| Bargains History | Drawer item exists; only the home grid exists. Propose a full history screen: list with thumbnail, title (auto from screenshot), marketplace, date, status (won / lost / open), search. |
| Home | Empty state, history grid, and Express mode all share one screen. Consider a clearer home vs. mode separation or a bottom tab bar (Home · Lines · History · Profile). |
| Express results | No way to give feedback on a line (👍/👎), no tone chips, no "explain why this works". Consider adding. |
| Naming | "Pro Deal Closer" page title in code is "Deal lines"; onboarding calls the product "Bargain Wizard" while everywhere else it's "Bargain Wiz". Pick one. |
| Paywall trigger | Opens on the first Express or Pro tap for free users, and from Profile → Upgrade / Manage. No paywall inside onboarding. |
| Free tier | What does a `free` user see? Define locked states / blurred results / "1 free deal per day" style teaser. |
| Dark mode | Text styles exist; palette and glass treatment do not. Optional deliverable. |
| Empty & error states | Network offline, AI failure, no photo permission, gallery unavailable all have copy but no illustrated states. |
| Accessibility | Glass over gradient with grey `#6B7280` secondary text needs contrast verification. Dynamic type behavior on onboarding cards. |
| Sharing results | Users may want to share a "before/after" of a negotiation win. Not present today. |

---

## 11. Requested deliverables

1. **Design system**: color tokens (light, optional dark), type scale, spacing, radii, glass surface recipe, button variants (black pill, outlined, glow, icon-round), card variants (option card, reply card, screenshot card, history card, plan card), bottom sheet, dialog, drawer, input bar, progress bar, snackbar.
2. **Onboarding templates** (one per screen type listed in §5) in EN with one ES variant to prove text fit.
3. **Core flow mockups**: Home (empty / history / express uploading / express results / pro chat), Lines that land sheet, Paywall (steps + 3 layouts), Refer sheet, Rate Us dialog, Feedback form, Sign-in modal, Drawer.
4. **New screens**: Profile, full Bargains History, AI reply in Pro Deal Closer, free-tier locked states, error/empty states.
5. **Motion spec**: staggered list entrance, copy confirmation, scan overlay, glow pulse, page transitions.
6. **Mascot usage guide**: sizes, placements, do/don't with the existing wizard illustration and Lottie set.

---

## 12. Mockup generation prompts (ready to paste)

Use these as starting prompts for an AI mockup tool; each assumes a 390×844 iPhone frame, light theme, lavender-peach-ice gradient background, glassmorphism cards, black pill CTAs, and a friendly bearded wizard mascot.

1. **Home – empty**: "Mobile app home screen for an AI negotiation assistant called Bargain Wiz. Soft pastel gradient background (lavender to peach to ice blue). Centered headline 'Your deal, upgraded.' A cute waving wizard mascot in the middle. Bottom: one full-width black rounded button 'Express Dealmaker' with a photo icon, and two half-width white outlined buttons 'Pro Deal Closer' and 'Lines that land'. Top bar with hamburger menu, title, and a black 'Share' pill."
2. **Express Dealmaker – results**: "Same app. Top-left white circular back chevron. Two marketplace chat screenshots shown as rounded 3:4 cards with numbered badges. Below: an outlined 'Add screenshot' button, a white rounded text field 'Give us a word or two to focus on', a small bobbing hint 'tap a reply to copy', and three frosted-glass reply cards each containing a short negotiation line with a copy icon on the right. Sticky bottom black button '✨ Get More'."
3. **Express Dealmaker – uploading**: "Same app. Two screenshot cards centered on screen with a glowing cyan scan line sweeping across them, everything else hidden."
4. **Pro Deal Closer – chat**: "Same app. Chat UI. Left white bubble from the wizard 'What's the deal about?'. Right-aligned white user bubbles with an attached screenshot. Bottom input bar: black round attach button, white pill text field 'Type a line...', black round mic button, black round send button. Add a wizard reply bubble containing three tappable suggested lines."
5. **Onboarding – select**: "Same app. Thin black progress bar with back arrow at top. Title 'Your Negotiation Vibe?' subtitle 'Align the wizard's personality with yours.' Four option cards: Friendly Collaborator (teal), No-Nonsense Buyer (orange), Tactical Strategist (yellow), Quiet Closer (light grey), each with a short subtext. Bottom black button 'Looks Like Me'."
6. **Onboarding – risk slider**: "Same app. Title 'Risk Tolerance'. A vertical Lottie-style 'magic tube' that fills as a slider moves through five stops labeled Conservative, Cautious, Balanced, Assertive, Aggressive with emoji and colors from purple to red. Button 'Set My Stance'."
7. **Paywall – plans**: "Same app on white. Title 'Unlock Bargain Wiz', subtitle 'Choose your negotiation power.' Two plan cards side by side with wizard illustrations: 'Text Wizard – Perfect for chat-based bargaining' and 'Vision Wizard – Uses screenshots to find leverage' with a 'Recommended' badge and glowing selected border. Below: a vertical 3-step trial timeline (Today, Day 2 reminder, Day 3 billing). Black button 'Try for free', note 'Free trial, then subscription. Cancel anytime.', small 'Restore Purchases', Terms and Privacy links."
8. **Lines that land sheet**: "Same app. Frosted-glass bottom sheet with drag handle and close button over the blurred home screen. Three category cards: Opening lines, Follow-ups, Closing, each with one pill-shaped quote and a copy icon."
9. **History grid**: "Same app home. Three-column grid of rounded 3:4 thumbnails of marketplace screenshots, each with a small dark ✕ in the corner. Same three CTAs at the bottom."
10. **Drawer**: "Same app. Left frosted-glass navigation drawer over the blurred home. Header with sparkle icon and 'Bargain Wiz'. Items: Profile, Bargains History, Rate Us, Refer, Terms, Privacy, Log out."
11. **Profile (new)**: "Same app. Profile screen showing the user's chosen negotiation vibe as a colored chip, risk tolerance meter, favorite marketplace, current plan 'Vision Wizard – trial ends in 2 days' with Manage button, and sign-in status with Google avatar."
12. **Rate Us dialog**: "Same app. Centered frosted-glass dialog with a star animation, title 'Are you satisfied?', grey 'No' button and a glowing teal 'Yes' button with a small magic wand."

---

## 13. Glossary

- **Express Dealmaker** – screenshot-in, lines-out mode ("Simple mode" in code).
- **Pro Deal Closer** – conversational mode ("Chat mode" / "Start with text" in code).
- **Lines that land** – curated library of negotiation phrases by category.
- **Deal reply / reply options** – the list of AI-generated lines returned for a screenshot batch.
- **Vibe** – the tone preset (Friendly / No-Nonsense / Tactical / Quiet Closer) chosen at onboarding.
- **Premium** – the one paid plan (monthly or weekly). "Text Wizard" / "Vision Wizard" were the retired names of the earlier two-tier offer.
- **Bargains history** – saved conversations of either mode, shown as a thumbnail grid.
