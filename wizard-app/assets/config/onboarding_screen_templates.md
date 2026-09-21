# Onboarding Screen Configuration Templates

This document provides templates for each type of onboarding screen.

## `prompt` — what an option contributes to the system prompt

Every option of a screen that fills a profile answer carries **`prompt`**: one finished
English line telling the negotiation coach what picking that option says about the buyer. It
is never shown in the UI. The app forwards the lines for the answers it is sending with every
AI request (under the same key, `prompt`), and the backend renders them **verbatim, in the
order the screens ask the questions** — so **adding an option, or a whole new question,
changes the prompt with no app release and no function deploy**. Omit it and that answer
contributes *nothing* to the prompt — there is no server-side copy of the option list to fall
back to — and the miss is logged as `undescribed onboarding answer`.

You are writing the line the model reads, not a fragment slotted into one: the backend adds
no label, no ordering and no grouping of its own.

Where it goes, per screen type:

| Screen type | Path |
|---|---|
| `select`, `multi_select` | `options[].metadata.prompt` |
| `select_group` | `groups[].options[].metadata.prompt` |
| `slider`, `slider_lottie` | `metadata.options[].prompt` (a stop has no metadata bag) |

```json
{"label": {"en": "I took the first counter-offer"}, "value": "holding_ground",
 "metadata": {"color": "#7B5EA7",
              "prompt": "Weak spot — tends to accept the first counter: include a line that holds the position."}}
```

which reaches the model as one line of the buyer block:

```
<buyer_profile>
Weak spot — tends to accept the first counter: include a line that holds the position.
Tone: Friendly Collaborator — warm and polite, builds rapport, asks nicely.
Push level: Balanced — a fair anchor around 15-25% under asking, ready to walk away.
</buyer_profile>
```

**Writing one:**

- **English only, never a `{en, es}` map.** The prompt is written in English; the language the
  buyer gets back is `locale`. A localized `prompt` is ignored and the sentence is lost.
- **Describe the buyer, never address the model.** It is read as data about a person, not an
  instruction. No "always", no "ignore the above".
- **Make it stand on its own, and say which question it answers.** Nothing prefixes it, and a
  buyer picks several hurdles, so `"Weak spot — fears sounding rude: …"` works where a bare
  `"fears sounding rude"` would float. The shipped lines use `Tone: …`, `Push level: …`,
  `Marketplace etiquette on X: …`, `Deal frequency: …`, `Weak spot — …`, `Typical deal …` —
  follow them for a new option, and pick a comparable opener for a new question.
- **One line.** Line breaks collapse to spaces. Keep it to a sentence — nothing truncates it, so length is your judgement, and a paragraph crowds the rest of the prompt.
- **Treat a `prompt` edit as a prompt change, not a copy change.** `label` and `subtext` are
  what the person reads; `prompt` is what the model reads, and a careless edit changes answer
  quality.

`functions/tests/test_option_prompts.py` fails if an option in this repo's bundled defaults
has no `prompt`. Fixing a bad sentence is a Remote Config publish, no deploy — but stripping
the key does not restore anything, it removes that answer from the prompt, so edit rather
than delete.

## `scope` — whose answer it is, the person's or the deal's

Beside `answer_key_name`, an answer may declare **`scope`**. `"conversation"` says the answer
describes the *deal* rather than the person: a conversation carries its own value for it, a
chip in the deal's header changes it **for that deal only**, and reopening the deal coaches
from the value it was saved with rather than from today's profile. Anything else — including
leaving it out, which is the default — makes the answer the person's: it lives in the profile,
and the Profile screen is the only place that changes it.

Where it goes, per screen type:

| Screen type | Path |
|---|---|
| `select`, `multi_select`, `slider`, `slider_lottie` | `answer_structure.scope` |
| `select_group` | `groups[].scope` (each group asks its own question, so it carries its own) |

```json
{"type": "select", "answer_structure": {"answer_key_name": "vibe", "scope": "conversation"},
 "options": [ … ]}
```

Two answers carry it today: `vibe` (the tone chip on an Express result and on a Pro chat) and
the `marketplace` group of the "Where do you deal?" screen. Both still travel with every AI
request like any other answer; what `scope` adds is that they also travel as `overrides`, the
map the conversation document stores, and that the deal header offers a chip for each of them,
in onboarding order (`CONVERSATIONS.md`). Marking a third answer is a Remote Config publish:
nothing in the app names these keys.

## Engagement Screen

Informational/warmup screens that display content with optional visual elements.

```json
{
  "title": "Screen Title",
  "description": "Screen description that can include keywords like bargain, deal, analysis, negotiate, smart, ai for highlighting",
  "type": "engagement",
  "visual": "assets/lottie/animation.json",  // Optional: Lottie animation path
  "next_button_text": "Next",  // Optional: Custom button text
  "show_top_bar": true  // Optional: Show/hide progress bar and back button (defaults to true)
}
```

**Fields:**
- `title` (required): Screen title
- `description` (required): Screen description (keywords will be automatically highlighted)
- `type`: `"engagement"`
- `visual` (optional): Path to Lottie animation file (e.g., `"assets/lottie/welcome.json"`)
- `next_button_text` (optional): Custom button text (defaults to "Next" or "Get Started" for last screen)
- `show_top_bar` (optional): Controls visibility of progress bar and back button (defaults to `true`)

## Select Screen

Multiple choice selection screen with predefined options.

```json
{
  "title": "Question Title",
  "description": "Question description",
  "type": "select",
  "options": [
    {
      "label": "Option 1",
      "value": "option1"  // Optional: value to store (defaults to label)
    },
    {
      "label": "Option 2",
      "value": "option2"
    },
    {
      "label": "Option 3",
      "value": "option3",
      "metadata": {}  // Optional: Additional metadata for the option
    }
  ],
  "answer_structure": {
    "answer_key_name": "question_key"  // Required: Key for storing the answer
  },
  "next_button_text": "Continue",  // Optional: Custom button text
  "show_top_bar": true  // Optional: Show/hide progress bar and back button (defaults to true)
}
```

**Fields:**
- `title` (required): Question title
- `description` (required): Question description
- `type`: `"select"`
- `options` (required): Array of option objects
  - `label` (required): Display text for the option
  - `value` (optional): Value to store (defaults to label)
  - `metadata` (optional): Additional metadata, including `prompt` — the sentence the model
    reads for this option (see "`prompt` — what an option contributes to the system prompt"
    at the top)
- `answer_structure` (required): Answer storage configuration
  - `answer_key_name` (required): Unique key for storing the answer
  - `answer_key_name` is also the key the answer is sent to the backend under and the one the
    profile records it as — today the funnel asks for `vibe`, `push`, `marketplace`,
    `deals_per_month`, `deal_size`, `hurdles` and `referral_code`. No key is required and none
    is special: an answer reaches the model through the `prompt` sentence it carries, so a new
    question coaches without a release and one the funnel drops simply stops being sent
    (`PROFILE_SYNC.md`)
  - `scope` (optional): `"conversation"` marks the answer as the deal's rather than the
    person's — see "`scope` — whose answer it is" at the top; absent means the person's
- `next_button_text` (optional): Custom button text
- `show_top_bar` (optional): Controls visibility of progress bar and back button (defaults to `true`)

## Slider Screen

Numeric input screen with slider control. Supports two modes:

### Discrete Labeled Options (Recommended)

Slider with predefined labeled positions:

```json
{
  "title": "Question Title",
  "description": "Question description",
  "type": "slider",
  "metadata": {
    "options": [
      {
        "value": 50,        // Required: Value to store when selected
        "label": "Below 100 bucks",  // Required: Display label
        "animation": "assets/lottie/slow.json"  // Optional: Animation for this option
      },
      {
        "value": 550,
        "label": "100-1000 bucks",
        "animation": "assets/lottie/moderate.json"
      },
      {
        "value": 5000,
        "label": "1000+ bucks",
        "animation": "assets/lottie/fast.json"
      }
    ]
  },
  "answer_structure": {
    "answer_key_name": "question_key"  // Required: Key for storing the answer
  },
  "next_button_text": "Next",  // Optional: Custom button text
  "show_top_bar": true  // Optional: Show/hide progress bar and back button (defaults to true)
}
```

**Fields:**
- `title` (required): Question title
- `description` (required): Question description
- `type`: `"slider"`
- `metadata` (required): Slider configuration
  - `options` (required): Array of option objects
    - `value` (required): Numeric value to store when this option is selected
    - `label` (required): Display text shown below the slider position
    - `animation` (optional): Lottie animation path for this option (displayed above the slider)
- `answer_structure` (required): Answer storage configuration
  - `answer_key_name` (required): Unique key for storing the answer
  - `answer_key_name` is also the key the answer is sent to the backend under and the one the
    profile records it as — today the funnel asks for `vibe`, `push`, `marketplace`,
    `deals_per_month`, `deal_size`, `hurdles` and `referral_code`. No key is required and none
    is special: an answer reaches the model through the `prompt` sentence it carries, so a new
    question coaches without a release and one the funnel drops simply stops being sent
    (`PROFILE_SYNC.md`)
  - `scope` (optional): `"conversation"` marks the answer as the deal's rather than the
    person's — see "`scope` — whose answer it is" at the top; absent means the person's
- `next_button_text` (optional): Custom button text
- `show_top_bar` (optional): Controls visibility of progress bar and back button (defaults to `true`)

### Continuous Slider (Legacy)

For continuous numeric input:

```json
{
  "title": "Question Title",
  "description": "Question description",
  "type": "slider",
  "metadata": {
    "min": 0,          // Required: Minimum value
    "max": 100,        // Required: Maximum value
    "step": 1,         // Required: Step increment
    "unit": "USD",     // Optional: Unit to display (e.g., "USD", "deals", "items")
    "format": "currency"  // Optional: Format type ("currency" or "number")
  },
  "answer_structure": {
    "answer_key_name": "question_key"  // Required: Key for storing the answer
  },
  "next_button_text": "Next",  // Optional: Custom button text
  "show_top_bar": true  // Optional: Show/hide progress bar and back button (defaults to true)
}
```

**Note:** If `metadata.options` is provided, the discrete labeled mode is used. Otherwise, the continuous slider mode is used.

## Complete Example Flow

A complete onboarding flow with all three types:

```json
[
  {
    "title": "Welcome to Bargain Wiz",
    "description": "We'll help you get the best deals with AI-powered analysis.",
    "type": "engagement",
    "visual": "assets/lottie/welcome.json",
    "next_button_text": "Let's Get Started"
  },
  {
    "title": "What is your favourite marketplace?",
    "description": "Select your preferred marketplace",
    "type": "select",
    "options": [
      {"label": "eBay", "value": "ebay"},
      {"label": "Amazon", "value": "amazon"}
    ],
    "answer_structure": {
      "answer_key_name": "favorite_marketplace"
    },
    "next_button_text": "Continue"
  },
  {
    "title": "How many deals?",
    "description": "Tell us about your deal frequency",
    "type": "slider",
    "metadata": {
      "min": 1,
      "max": 100,
      "step": 1,
      "unit": "deals",
      "format": "number"
    },
    "answer_structure": {
      "answer_key_name": "deal_count"
    },
    "next_button_text": "Next"
  },
  {
    "title": "You're All Set!",
    "description": "Ready to start negotiating better deals!",
    "type": "engagement",
    "visual": "assets/lottie/all_done.json",
    "next_button_text": "Get Started"
  }
]
```

## Notes

- All screens are stored in an array in the order they should appear
- The `next_button_text` is optional - if not provided, defaults to "Get Started" for the last screen and "Next" for others
- The `show_top_bar` field controls whether the progress bar and back button are displayed on each screen (defaults to `true`)
  - Set to `false` for cleaner, distraction-free screens (e.g., welcome screens, final confirmation screens)
  - When `false`, the top bar is completely hidden, including the progress indicator
- For engagement screens, keywords in descriptions (bargain, deal, analysis, negotiate, smart, ai) are automatically highlighted
- Answers are stored using the `answer_key_name` from `answer_structure`
- The same key is what the answer is sent to the backend as (a `select_group` group carries
  its own), so the app needs no mapping and no release when a question is renamed or replaced.
  Renaming a key does orphan the answers already stored under the old one
- Visual paths can be:
  - Lottie files: `"assets/lottie/filename.json"`
  - Remote URLs: `"https://example.com/animation.json"`
  - Asset paths: `"assets/images/image.png"`

