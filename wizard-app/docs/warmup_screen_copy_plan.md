# Warmup Screen — Copy and Styling (Updated)

## Copy guidelines

- **"YOU" in uppercase** wherever we want to emphasise the user (e.g. "YOU have fantastic potential", "when YOU negotiate").
- **Side text** near the animation: theme “stop your money from falling away” (e.g. “Stop your money from falling away” or a tight variant).

---

## Recommended copy

### Title

**English:** `YOU have fantastic potential`  
**Spanish:** `TÚ tienes un potencial increíble`  

*(“YOU” / “TÚ” in caps for emphasis; keeps the “fantastic potential” idea.)*

### Description

**English:** `Studies reveal: when YOU negotiate, you often pay up to 40% less.`  
**Spanish:** `Los estudios muestran: cuando TÚ negocias, sueles pagar hasta un 40% menos.`

*(“YOU” / “TÚ” in caps; “Studies reveal” will be bold via remote config; “40% less” gets its own color.)*

### Side text (near the animation)

**English:** `Stop your money from falling away`  
**Spanish:** `Evita que tu dinero se escape`

*(Direct, action-oriented; ties to the falling_money animation.)*

Alternative options if you prefer a shorter line:

- **English:** `Keep your money where it belongs` / `Don’t let it slip away`  
- **Spanish:** `Mantén tu dinero donde corresponde` / `No dejes que se escape`

---

## Config summary

| Field | Value |
|-------|--------|
| **Title** | `{"en": "YOU have fantastic potential", "es": "TÚ tienes un potencial increíble"}` |
| **Description** | `{"en": "Studies reveal: when YOU negotiate, you often pay up to 40% less.", "es": "Los estudios muestran: cuando TÚ negocias, sueles pagar hasta un 40% menos."}` |
| **Side text** (metadata.side_text) | `{"en": "Stop your money from falling away", "es": "Evita que tu dinero se escape"}` |
| **Visual** | `"assets/lottie/falling_money.json"` |
| **highlight_words.description** | `{"Studies reveal": "bold", "40% less": "#2E7D32"}` (or your chosen hex for “40% less”) |
| **highlight_color** | `"#C47A00"` (or existing brand colour for bold-only phrases) |

---

## Implementation notes (unchanged from main plan)

1. **Remote config**  
   - In the warmup screen object inside `onboarding_screens`, set the strings and `visual` / `metadata` as above.
2. **Bold “Studies reveal”**  
   - In `highlight_words.description`, support value `"bold"`; parser adds `wordBold`; `WordHighlightResult` gets `isBold`; rich-text builder uses it (see main plan).
3. **Color for “40% less”**  
   - Use `"40% less": "#2E7D32"` (or another hex) in `highlight_words.description`.
4. **Animation**  
   - `visual`: `"assets/lottie/falling_money.json"`.

Use this doc when you fill the warmup screen in remote config and when implementing bold/colour in the app.
