# Onboarding Screen Configuration Templates

This document provides templates for each type of onboarding screen.

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
  - `metadata` (optional): Additional metadata
- `answer_structure` (required): Answer storage configuration
  - `answer_key_name` (required): Unique key for storing the answer
  - `answer_key_name` is also the field the answer is sent to the backend as, so name it after
    the field the functions read — `vibe`, `push`, `marketplace`, `deals_per_month`,
    `deal_size`, `hurdles`, `referral_code`. Any other key rides along and is ignored; keep
    screens asking for `vibe` and `push`, which the AI functions require (`PROFILE_SYNC.md`)
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
  - `answer_key_name` is also the field the answer is sent to the backend as, so name it after
    the field the functions read — `vibe`, `push`, `marketplace`, `deals_per_month`,
    `deal_size`, `hurdles`, `referral_code`. Any other key rides along and is ignored; keep
    screens asking for `vibe` and `push`, which the AI functions require (`PROFILE_SYNC.md`)
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

