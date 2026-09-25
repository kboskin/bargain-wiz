---
name: ship-check
description: Verification ritual before handing work back or committing in this repo — which checks to run for app vs backend changes, and how to read their noisy output. Use when finishing a change, preparing a commit, or asked whether something is ready.
---

# Ship check

Run what the change touched, report what actually happened. Never call something verified
because it "should" work.

## Flutter app (`wizard-app/`)

```bash
fvm flutter test
fvm flutter analyze lib test 2>&1 | grep -E "error •|warning •"
```

- The analyzer has ~2900 pre-existing **infos**; the grep above is the signal. A clean grep
  means no errors or warnings, not a clean analyzer — say it that way.
- Touching plugins, Gradle, Xcode configs or `pubspec.yaml`? Prove it still builds:
  `fvm flutter build apk --debug --flavor dev` (~45s warm). iOS plugins come through Swift
  Package Manager, so a new plugin lands in `ios/Flutter/ephemeral/Packages/…/Package.swift` —
  check it is there rather than assuming `pod install` did it.
- Behaviour change in a flow? Exercise it against the emulators (`local-stack` skill).

## Backend (`wizard-backend/functions/`)

```bash
venv/bin/python -m pytest -q -rs
venv/bin/ruff check .
```

- `-rs` lists what was skipped and why. Model tests run against the local Ollama model
  (`TEST_AI_MODEL`, default `ollama/qwen2.5vl:7b`) and skip with the `ollama pull …` that
  fixes it; say which ran and which skipped when handing work back. Never fake a model to make
  them run.
- Changed `.env` or `core/config/settings.py`? The CLI rejects the whole `.env` on a reserved
  key, and that only shows when the emulator or a deploy loads it; run the manifest discovery
  in `functions/README.md` to check the params still resolve.
- Changed a query? Confirm the composite index exists in `firestore.indexes.json`.
- Changed a Firestore or Storage adapter, the queue, or a flow end to end? The in-memory tests
  cannot see those; run `E2E=1 venv/bin/python -m pytest tests/test_e2e.py -rs` against a
  freshly restarted emulator suite (`local-stack` skill) and say whether it ran.

## Both

- Wire format changed on one side → the other side and its doc change in the same commit
  (`CONVERSATIONS.md`, `AI_INTEGRATION.md`, `PROFILE_SYNC.md`, `LINES_THAT_LAND.md`,
  `functions/README.md`).
- Git runs from the repo root (`bwiz/`), not from a project folder: `git -C .. status`.
- Commit or push only when asked. If work is blocked by the environment (Vertex AI disabled,
  no deploy credentials), say so plainly instead of routing around it.
