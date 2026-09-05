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

The root is orchestration-only. Production Dart code is owned by five workspace packages:

    apps/plantcare_app/             executable, bootstrap, routing, theme, final DI
    packages/plantcare_features/    pages, widgets, BLoCs, feature navigation APIs
    packages/plantcare_data/        Firebase and device/plugin implementations
    packages/plantcare_domain/      entities, contracts, validators, deterministic policies
    packages/plantcare_shared/      minimal pure-Dart errors and environment abstractions

Dependencies flow downward: app to features/data/domain/shared; features to
domain/shared; data to domain/shared; domain to shared. Shared has no internal
dependency. Never import another package's `lib/src`, another package's test
directory, or the obsolete `package:plantcare_ai` package.

Repository interfaces belong in `plantcare_domain`. Firebase and platform
implementations belong in `plantcare_data`. BLoCs and feature UI belong in
`plantcare_features`. App bootstrap, GoRouter composition, application-wide
theme/shell, and final GetIt ownership belong in `plantcare_app`.

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
- Client-side grounded diagnoses must use the saved structured observation and
  must never resend or persist the original image.
- Diagnosis generation must stop before the AI call unless deterministic
  retrieval has at least one above-threshold chunk with complete trusted source
  records. Never substitute unrelated general-care chunks.
- Diagnosis output uses a versioned, strictly validated structured schema.
  Every possible issue and action must reference supplied chunk IDs; source
  attribution is resolved from trusted Firestore source records, never AI text.
- Client-originated diagnoses are immutable user records, not trusted backend
  attestations. Security Rules cannot prove that a record came from Gemini.
- If AI generation succeeds and persistence fails, retain the validated result
  and retry only the save operation without regenerating.
- While diagnosis remains on Spark, document it as temporary client-side
  grounded generation rather than final server-side vector RAG.
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

## Manual soil-check policy

- The supported manual method is `manual_finger_test`, checked approximately
  2–3 cm below the surface; it is qualitative and must never be shown as a
  numeric percentage.
- Moisture values are `very_dry`, `dry`, `slightly_moist`, `moist`, and `wet`.
- Watering decisions use pure Dart policy `manual-watering-v1` and record
  schema version 1. Gemini, weather APIs, and sensors are not decision inputs.
- Tomato, pumpkin, and peace lily water at dry; pothos waters after surface
  drying; snake plant asks for another check at dry and waters at very dry.
  Slightly moist asks for another check; moist and wet always wait.
- Every supported plant policy must name reviewed chunk IDs from current
  dataset `2026-09-03-v2`. Validate chunk existence, plant identity, dataset,
  and trusted source records before saving; never interpret chunk prose to
  alter the decision.
- Store immutable client-originated records at
  `users/{uid}/plants/{plantId}/soilChecks/{soilCheckId}`. Security Rules can
  validate shape and ownership but cannot attest that the official engine ran.
- Suggested times are check reminders, not fixed watering schedules. Soil-check
  records are never proof that watering occurred. Do not use fertilizer,
  weather, sensors, AI watering decisions, or notifications as inputs.

## Care-log policy

- Store immutable, factual user-entered actions at
  `users/{uid}/plants/{plantId}/careLogs/{careLogId}`. Supported types are
  `watering` and `fertilizing`; users may delete and recreate incorrect logs,
  but may not edit them.
- Care logs use schema version 1, source `user_entered`, a user-selected
  Firestore `occurredAt`, and server timestamp `createdAt`. Latest actions are
  selected by `occurredAt`, with document ID as the deterministic tie-breaker.
- Watering fields are `wateringMethod` and optional positive `amountMl` up to
  100,000. Fertilizing fields are `fertilizerForm`, optional `productName`, and
  optional `applicationNote`. Never store the other type's fields.
- Optional strings must be non-empty and trimmed when present. Notes and
  application notes are limited to 500 characters; product names to 120.
- Security Rules enforce authentication, ownership, parent existence, exact
  fields, timestamps, enums, limits, immutability, and owner-only deletion.
  They cannot verify that the recorded action actually occurred.
- A care log records what a user says they did. It is not a watering or
  fertilizer recommendation and does not establish product safety,
  suitability, or dosage.

## Local reminder policy

- Spark V1 reminders are stored at
  `users/{uid}/plants/{plantId}/reminders/{reminderId}` and support only
  `soil_check` and `fertilizer_review`; wording asks users to check or review
  care and never commands watering or fertilizing.
- Android and iOS use best-effort timezone-aware local notifications. Web shows
  live in-app reminders only and must state that background notifications are
  unavailable in this version.
- Suggested dates from saved soil checks and fertilizer assessments require
  review and explicit confirmation. Never create a reminder automatically or
  invent a missing suggestion.
- Notification permission is requested only after a clear user action. Saving
  succeeds independently of permission or local scheduling, and retrying local
  scheduling must not duplicate the Firestore record.
- Reconcile future active reminders on sign-in and app resume. Cancel only
  locally known entries for the signing-out UID, preserve Firestore status, and
  treat each device's schedule as independent.
- Reminder status is historical: normal UI completes or cancels instead of
  deleting. Reactivation is an explicit reschedule to a future time. Firestore
  Rules validate ownership, shape, references, timestamps, and transitions but
  cannot attest that a local notification was scheduled.

## Fertilizer-assessment policy

- Production knowledge dataset `2026-09-03-v2` contains reviewed fertilizer
  evidence for tomato, pumpkin, pothos, snake plant, and peace lily. New
  knowledge-dependent work uses v2; historical v1 user records remain readable.
- Deterministic policy `deterministic-fertilizer-v1` and record schema 1 use
  canonical plant identity, environment,
  growth stage, user-reported growth activity, fertilizer care-log history,
  and centralized source-backed constants. Never parse chunk prose.
- Stressed or unhealthy plants never receive routine fertilizer guidance;
  slow or dormant plants wait; recently repotted houseplants wait at least
  2–4 weeks; unknown activity requests more information.
- A missing or old fertilizer log does not prove need. Fertilizer must never be
  presented as medicine or inferred from leaf color, diagnosis, or images.
- Guidance may show only a source-supported broad category and must tell the
  user to follow and not exceed the product label. No brand, dosage, mixing
  instruction, or application quantity may be generated.
- Reminders, notifications, AI fertilizer decisions, weather, sensors, Cloud
  Functions, Storage, and vector search remain deferred.
- Store immutable client-originated assessments at
  `users/{uid}/plants/{plantId}/fertilizerAssessments/{assessmentId}`. Validate
  all evidence and sources against v2 before saving. Security Rules cannot
  attest that the official deterministic engine ran.

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

    melos run generate
    melos run format
    melos run analyze
    melos run test
    melos run boundaries

If a check is not applicable or cannot run, state that clearly in the completion report.

## Generated Code

- Do not edit generated files by hand.
- Change the annotated source and regenerate outputs instead.
- Run `melos run generate` after changing injectable code. It generates data,
  then features, then the application graph.
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

If blocked, explain the blocker and provide the exact next action.

Never fabricate a successful implementation.
