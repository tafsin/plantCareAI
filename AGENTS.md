# PlantCare AI — Agent Instructions

## Project Overview

PlantCare AI is a Flutter mobile and web application for plant health and care.

Planned capabilities include:

- Managing plant profiles
- Uploading plant images
- Producing AI visual observations
- Providing diagnoses grounded through RAG
- Recording manual soil-moisture checks
- Recommending watering and fertilizer care
- Tracking care and diagnosis history
- Sending scheduled notifications

Build the application incrementally. Implement only the milestone explicitly requested in the current task.

## Technology Stack

### Flutter application

- Flutter and Dart
- Android, iOS, and web
- Material 3
- `flutter_bloc` for state management
- `go_router` for navigation
- `get_it` and `injectable` for dependency injection
- `equatable` or Freezed for value equality
- Feature-first architecture
- Firebase client SDKs

### Backend

- Firebase Cloud Functions using TypeScript
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- Firestore vector search for the initial RAG implementation
- Server-side AI and embedding-provider integrations

## Architecture

Follow the architecture already present in the repository. Inspect existing patterns before introducing new ones.

Use this high-level Flutter structure when applicable:

    lib/
    ├── app/
    │   ├── router/
    │   ├── theme/
    │   └── dependency_injection/
    ├── core/
    │   ├── constants/
    │   ├── errors/
    │   ├── extensions/
    │   ├── utils/
    │   └── widgets/
    └── features/
        └── feature_name/
            ├── data/
            ├── domain/
            └── presentation/

Repository interfaces belong in the domain layer. Firebase implementations belong in the data layer. BLoCs and UI belong in the presentation layer.

Do not create empty layers or files merely to satisfy the directory structure. Add a layer only when it has a real responsibility.

## Core Design Principle

Use this separation consistently:

- AI observes uncertain or visual information.
- RAG retrieves relevant trusted plant-care knowledge.
- Deterministic application code handles dates, schedules, thresholds, and reminder state.
- AI may explain results but must not be the authoritative scheduler.
- Flutter renders structured results and must not parse arbitrary AI prose.

## Flutter Rules

- Use null-safe Dart.
- Follow the repository’s current formatting and lint rules.
- Prefer immutable models and states.
- Use `const` constructors where practical.
- Keep widgets focused and reusable.
- Keep business logic out of widgets.
- Use BLoC for application and feature workflow state.
- Do not introduce or retain Cubits.
- UI widgets must not call repositories directly.
- Simple ephemeral visual state, such as password visibility, focus, and
  controller state, may remain inside a StatefulWidget when it contains no
  business logic.
- Use `go_router` for navigation.
- Resolve dependencies through the existing dependency-injection setup.
- Do not use a service locator directly inside domain entities or UI widgets.
- Design layouts for mobile and web.
- Preserve the existing narrow-screen bottom navigation and wide-screen navigation rail behavior.
- Include loading, empty, success, and error states where applicable.
- Keep user-facing messages clear and nontechnical.

## Firebase and Security

- Never invent Firebase configuration values.
- Never commit service-account credentials, private keys, or AI provider secrets.
- Firebase client configuration is not a server secret; protect data using Authentication, Security Rules, and backend authorization.
- All user-owned documents must include or derive a verified user ID.
- Firestore and Storage rules must enforce ownership.
- Never trust a user ID supplied by the client inside privileged backend operations; derive it from the authenticated request.
- Validate Cloud Function inputs.
- Store server timestamps for persisted creation and update times where appropriate.
- Keep embeddings, vector search, privileged prompts, secure rate limits, and provider keys on the backend.
- Flutter must not call an AI provider directly except through the approved Firebase AI Logic client SDK using Firebase-managed authorization; never embed or manage provider API keys in the client.
- App Check can be added before production but should not be introduced outside an explicitly requested milestone.
- Firebase bootstrap order is Firebase initialization, optional emulator
  configuration, App Check activation, application-service startup, then
  `runApp`. Preserve successful steps when retrying a later failed step.
- App Check debug providers require an explicit `USE_APP_CHECK_DEBUG=true` and
  must never be selected implicitly or allowed in a release build. Never store
  debug tokens or reCAPTCHA Enterprise site keys in source-controlled files.
- Firebase AI Logic requests must originate from a signed-in user. Modern
  `firebase_ai` attaches Auth and App Check credentials; do not manually move
  tokens through UI or BLoC layers.

## AI and RAG

- Separate image observation from diagnosis.
- While the project remains on Spark, plant images are processed locally and sent directly for observation but are never persisted by PlantCare AI.
- Client-originated AI observations are untrusted records, not backend attestations, even when their schema is validated.
- The observation step should describe visible evidence without prematurely selecting a disease.
- The diagnosis step should use the plant profile, observations, and retrieved knowledge.
- AI responses must use validated structured schemas.
- Display uncertainty and alternative possibilities.
- Do not present AI plant diagnosis as guaranteed.
- Recommendations must identify the supporting retrieved sources.
- Deterministic retrieval must expose explainable match signals.
- Profile and qualifying AI plant-identification conflicts must never be
  resolved silently.
- Retrieved evidence is not a diagnosis.
- Client retrieval results are not trusted backend attestations.
- Prefer trusted sources such as universities, agricultural extensions, government horticulture resources, and peer-reviewed material.
- Store source metadata and preserve attribution.
- Production knowledge must be backed by reviewed authoritative sources.
- Curated knowledge must be paraphrased, attributed, focused, and bounded.
- Client applications must never create, update, or delete curated knowledge.
- Knowledge ingestion must default to dry-run and validate the complete dataset
  before any write.
- Do not scrape, ingest, or reproduce copyrighted sources without appropriate permission.
- Avoid unsupported pesticide or fertilizer dosage advice.
- Include safety warnings when treatment may affect people, children, pets, pollinators, or food crops.

## Scope Control

- Implement only the milestone requested by the user.
- Do not pre-build later features.
- Do not perform broad refactors unless required for the current task.
- Do not add packages without a current, concrete use.
- Do not replace established architecture without explaining the necessity.
- Preserve unrelated user changes.
- Ask before making a choice that materially changes product behavior, cost, security, or infrastructure.
- Prefer the smallest complete vertical slice over incomplete broad scaffolding.

## Testing

For every implementation task:

- Add or update relevant unit, BLoC, widget, or integration tests.
- Tests must not depend on live Firebase services unless explicitly requested.
- Prefer Firebase Emulator Suite for repository and Security Rules integration tests.
- Use injected boundaries or fakes instead of mocking static APIs.
- Test success, empty, and failure states where relevant.
- Add authorization and ownership tests when Security Rules change.
- Avoid tests that merely reproduce implementation details.

Before declaring completion, run applicable checks:

    dart run build_runner build --delete-conflicting-outputs
    dart format --output=none --set-exit-if-changed .
    flutter analyze
    flutter test

If a check is not applicable or cannot run, state that clearly in the completion report.

## Generated Code

- Do not edit generated files by hand.
- Change the annotated source and regenerate outputs instead.
- Run `dart run build_runner build --delete-conflicting-outputs` after changing code that uses code generation.
- Commit generated files only when the repository’s existing convention requires them.
- Review generated diffs and ensure they contain only expected changes.

## Dependencies

- Reuse existing dependencies when they meet the current requirement.
- Add a dependency only when the current milestone has a concrete need for it.
- Prefer actively maintained packages that support the project’s target platforms and null safety.
- Check package compatibility before changing version constraints.
- Explain any new dependency and the responsibility it serves.
- Do not upgrade unrelated dependencies as part of a feature task.

## Documentation

- Update documentation when setup, architecture, configuration, or user-visible behavior changes.
- Keep comments focused on intent, constraints, and non-obvious decisions.
- Do not add comments that merely restate the code.
- Document required environment variables and setup steps without including secret values.
- Keep examples aligned with the implemented behavior.

## Completion Report

When completing a task:

- Summarize what changed.
- List the files changed.
- Report the checks and tests run, including their outcomes.
- Call out assumptions, limitations, follow-up work, or checks that were not run.
- Do not claim that code, tests, builds, or integrations work unless they were actually verified.

If blocked, explain the blocker and provide the exact next action. Never fabricate a successful implementation.
