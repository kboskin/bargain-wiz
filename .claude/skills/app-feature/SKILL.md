---
name: app-feature
description: Add or extend a feature slice in the Flutter app (wizard-app) — entities, datasource, repository, cubit, DI wiring and tests. Use when building UI or client-side behaviour rather than backend work.
---

# App feature

Work from `wizard-app/`, always with `fvm flutter`. Conventions and gotchas:
`wizard-app/AGENTS.md`.

## Slice layout

```
lib/features/<feature>/
  data/        datasources/ · models/ (json_serializable) · repositories/ (impl)
  domain/      entities/ · repositories/ (abstract)   — no use-case classes
  presentation/ cubit/ · pages/ · widgets/
  di.dart      registrations, called from core/di/injection_container.dart (newer slices;
               older ones register inline there — give a new feature its own di.dart)
```

Rules the existing code follows, so follow them:

- State is a **Cubit** with an immutable state class; emit new states, never mutate.
- Repository methods return `Either<Failure, T>` (`dartz`); datasources throw, repositories
  catch and map to `Failure`.
- Wire models are `json_serializable` — regenerate with
  `fvm dart run build_runner build --delete-conflicting-outputs`.
- Dependencies come from GetIt; a widget never constructs a repository.
- User-facing strings go through `lib/l10n/app_en.arb` (+ `app_es.arb`), not string literals.

## Talking to the backend

Do not add a new HTTP path unless the endpoint is genuinely new. Conversation-shaped work goes
through `features/conversation/`: `ConversationsApi` to push, `ConversationsStream` to observe.
The app never writes conversation documents; it sends a turn and renders what the listener
delivers. A pending wizard message with no text is a placeholder — skip it when projecting.

Anything needing a uid must handle `null` (no Firebase user yet) by doing nothing, not by
retrying: `AuthService` throttles sign-in attempts (inside its 5 s cooldown a caller gets
`null`, the next caller after it tries again), so a loop on top only hammers it.

## Verify

```bash
fvm flutter test
fvm flutter analyze lib test 2>&1 | grep -E "error •|warning •"
```

The analyzer carries about 3,150 pre-existing infos; only fix lints in code you touched. Add
tests next to the existing ones under `test/features/<feature>/`; cubit tests use hand-written
fakes (see `test/features/pro_deal_closer/fakes.dart`). Some older features are `Bloc`s on
`features/shared/presentation/bloc/base_bloc.dart`; new state is a Cubit.
