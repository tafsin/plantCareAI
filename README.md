# PlantCare AI

PlantCare AI is a Flutter mobile and web application for plant health and care.
Spark V1 includes Firebase email/password authentication, user-owned plant
profiles, transient Firebase AI image observation, deterministic metadata
retrieval over reviewed knowledge, source-grounded diagnosis, manual soil
checks, deterministic watering and fertilizer guidance, factual care history,
and best-effort local reminders.

## Spark V1 release scope

The supported plants are tomato, pumpkin, pothos, snake plant, and peace lily.
New knowledge-dependent work uses reviewed dataset `2026-09-03-v2`, retrieval
policy `metadata-v1`, watering policy `manual-watering-v1`, and fertilizer
policy `deterministic-fertilizer-v1`. Existing readable v1 records are retained
for compatibility; new grounded diagnoses, soil checks, and fertilizer
assessments require v2 evidence.

The in-app **Privacy & Safety** page records the release disclosure: selected
images are sent to Firebase AI for analysis but are not saved by PlantCare AI;
structured user records are stored in Firestore; AI output is uncertain and
informational; local reminders are best-effort; web reminders work only while
the app is open; and account deletion and full data export are not V1 features.

## Source-grounded diagnosis (temporary Spark implementation)

A signed-in user can generate a diagnosis from a saved structured observation.
The app runs deterministic `metadata-v1` retrieval first and calls Firebase AI
Logic only when at least one curated chunk meets the existing relevance
threshold and every referenced source record is valid. The request contains a
minimal plant profile, the saved observation, resolved canonical plant key,
paraphrased chunk text and cautions, trusted IDs, dataset version, and retrieval
algorithm version. It contains no image, email, UID, local path, token, raw
Firestore map, or unrelated plant data.

Firebase AI Logic uses the Gemini Developer API and the explicit stable model
`gemini-3.5-flash-lite`. The version 1 schema supports `healthy_appearance`,
`insufficient_evidence`, and `possible_issues_found`, with at most three
possible issues, three recommended actions, and three avoid actions. Every issue and action must cite
supplied chunk IDs. The decoder rejects unknown fields and enums, oversized
content, markup, URLs, unknown evidence IDs, invalid state/array combinations,
and non-cautious summaries or issue reasoning. Trusted source titles,
publishers, and links are resolved from Firestore, never supplied by Gemini.

Validated diagnoses are immutable at:

```text
users/{uid}/plants/{plantId}/observations/{observationId}/diagnoses/{diagnosisId}
```

Only structured output and grounding metadata are stored. Prompts, raw
responses, chunk content, images, URLs, and credentials are never stored. The
repository derives `uid` from Firebase Authentication. Rules permit owner-only
create, read, and delete, deny updates, validate a strict field allowlist and
bounds, require both parent documents, and require a server timestamp. Rules
cannot prove a client record actually came from Gemini: these diagnoses are
client-originated records, not trusted backend attestations.

If generation succeeds but persistence fails, the validated diagnosis stays
visible and “Retry save” writes the same object without calling Gemini again.
Insufficient retrieval evidence never calls Gemini and never substitutes
general-care content. Safety constraints prohibit dosage, restricted-chemical,
medical, food-safety, and unsupported treatment advice.

Before live use, manually verify Firebase Console still enforces App Check for
Firebase AI Logic and Firebase AI Logic authenticated-users mode. The client
cannot verify those console settings. Also sign in, open a saved observation,
inspect retrieved evidence, generate and reopen a diagnosis, verify source
links, and inspect Firestore to confirm no prompt, response, image, or token was
persisted.

This is a temporary client-side grounded-generation slice compatible with the
Spark plan. It is not final server-side vector RAG: there are no embeddings,
vector search, Cloud Functions, Storage, or image persistence.

## Supported platforms

- Android
- iOS
- Web

The app uses Material 3 with light and dark color schemes. Its responsive shell
shows bottom navigation on narrow windows and a navigation rail at widths of
840 logical pixels or greater.

## Architecture

The project follows a feature-first structure:

```text
lib/
├── app/
│   ├── bootstrap/
│   ├── dependency_injection/
│   ├── router/
│   ├── theme/
│   └── app.dart
├── core/
│   ├── constants/
│   ├── errors/
│   ├── utils/
│   └── widgets/
├── features/
│   ├── authentication/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── home/presentation/
│   └── plants/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── main.dart
```

Feature `data` and `domain` directories are intentionally created only when a
feature has real persistence or business logic. Application and feature
workflow state uses event-driven BLoCs from `flutter_bloc`; ephemeral visual
state stays local to widgets. Routes use `go_router`, dependency injection uses
`get_it` and `injectable`, and value equality uses `equatable`.

`EnvironmentConfig` reads the non-secret `APP_ENV` compile-time value. It
defaults to `development` and accepts `staging` or `production`:

```sh
flutter run --dart-define=APP_ENV=production
```

Never place AI provider secrets in Flutter source, assets, or `--dart-define`
values. The observation feature uses Firebase AI Logic's managed authorization
and does not create, copy, or embed a Gemini API key.

## Dependency injection generation

After adding or changing injectable registrations, regenerate the checked-in
configuration:

```sh
dart run build_runner build
```

For active development, use:

```sh
dart run build_runner watch
```

## Firebase setup

This milestone uses one Firebase project for development, staging, and
production builds. `APP_ENV` continues to control application environment
behavior, but it does not select a different Firebase project.

Install the Firebase CLI with Node.js and npm, then install FlutterFire CLI:

```sh
npm install --global firebase-tools
dart pub global activate flutterfire_cli
```

Authenticate and create the approved Firebase project with Google Analytics
disabled:

```sh
firebase login
firebase projects:create plantcare-ai-dev-tasnimalam \
  --display-name "PlantCare AI Development"
```

Configure the existing Android, iOS, and web applications from the project
root. Preserve the current platform identifiers when prompted:

```sh
flutterfire configure \
  --project=plantcare-ai-dev-tasnimalam \
  --platforms=android,ios,web \
  --android-package-name=com.tasnimalam.plantcare_ai \
  --ios-bundle-id=com.tasnimalam.plantcareAi
```

This generates `lib/firebase_options.dart` and the native client configuration
files. This local project intentionally ignores those files, so every new
developer machine and CI environment must run `flutterfire configure` before
analysis or a build. The files contain client configuration rather than server
secrets and may be committed in projects that choose that policy. If Git is
added here later, `firebase.json` may be committed because it can define shared
Firebase tooling and deployment behavior; `.firebaserc` remains a local project
selection file.

Never commit service-account JSON files, private keys, or AI provider secrets.
Firebase client configuration is not a server secret: access control must be
enforced with Firebase Authentication, Security Rules, and authorized backend
operations.

### Enable email/password authentication

The app supports email/password registration, sign-in, password reset, and
logout. It does not support social, anonymous, passwordless email-link, or
email-verification-enforced authentication.

Before using authentication against the development project, open the Firebase
Console for `plantcare-ai-dev-tasnimalam`, then select:

```text
Authentication → Sign-in method → Email/Password
```

Enable **Email/Password** and leave **Email link (passwordless sign-in)**
disabled. The app cannot enable this provider and will not bypass a disabled
provider.

After configuration, fetch dependencies and run the application:

```sh
flutter pub get
flutter run
```

The authentication routes are:

- `/sign-in`
- `/register`
- `/forgot-password`

The protected routes are `/`, `/plants`, `/plants/new`, `/plants/:id`, and
`/plants/:id/edit`. Signed-out users are redirected to `/sign-in`; a validated
internal protected destination is preserved through sign-in or registration.
Signed-in users who open any authentication route are redirected to the
preserved protected destination or `/`.

Registration signs the new user in automatically. Password reset returns to
sign-in and always displays the neutral confirmation: “If an account exists for
that email, a reset link has been sent.”

## Firestore plant data

Each authenticated user owns a private plant subcollection:

```text
users/{uid}/plants/{plantId}
```

A plant contains `commonName`, optional `scientificName`, `environment`,
`growingMedium`, optional `potSizeLiters`, `sunlight`, `growthStage`, optional
`notes`, `createdAt`, and `updatedAt`. Client code never supplies an owner ID;
the repository derives the path from the current Firebase Authentication user.
Creation and update timestamps use Firestore server timestamps. A newly written
record can briefly show “Saving…” while a pending timestamp resolves.

Validation is shared conceptually by the form and Security Rules:

- `commonName` is trimmed, required, and 1–80 characters.
- `scientificName` is optional, trimmed, and at most 120 characters.
- `notes` is optional, trimmed, and at most 1,000 characters.
- `potSizeLiters` is optional for a potted plant, greater than 0, and no more
  than 10,000; it must be absent or null for a plant in the ground.
- `environment` allows `indoor` or `outdoor`; `growingMedium` allows `pot` or
  `ground`; `sunlight` allows `low`, `partial`, or `full`; and `growthStage`
  allows `seedling`, `vegetative`, `flowering`, `fruiting`, or `mature`.
- No additional document fields are accepted.

Security Rules allow a signed-in user to create, list, read, update, and delete
only documents in their own plant subcollection. They reject unknown or missing
fields, untrimmed or oversized text, unsupported enum values, invalid pot sizes,
client-controlled timestamps, and direct writes to `users/{uid}`. The current
query orders plants by `updatedAt`, so Firestore's automatic single-field index
is sufficient and no composite index file is required.

## AI-assisted visual observations

The project remains on the Firebase **Spark** plan. The observation feature
uses the Flutter `firebase_ai` SDK with the **Gemini Developer API**, selected
for no-cost prototyping. Do not switch this project to Agent Platform Gemini
API (formerly Vertex AI) or attach a billing account for this milestone.

Enable the service before running a live observation:

```text
Firebase Console → plantcare-ai-dev-tasnimalam
→ AI Services → AI Logic → Get started → Gemini Developer API
```

The model name is centralized as the explicit stable model
`gemini-3.5-flash-lite`; no `-latest` alias is used. New observations persist
that model name. Existing records created with `gemini-2.5-flash-lite` remain
readable and are not rewritten. Google schedules Gemini 2.5 Flash-Lite's
Gemini Developer API shutdown for October 16, 2026. Gemini 3.5 Flash-Lite was
released July 21, 2026, and its published earliest shutdown date is July 21,
2027; revalidate the model before that date.

### Image handling and privacy

Android and iOS can choose one gallery image or take one camera photo. Web can
choose one file; browser camera capture is hidden because support is
inconsistent. Accepted inputs are JPEG and PNG. The original must be no more
than 10 MB. A local, orientation-corrected analysis copy is resized to a long
edge near 1600 pixels and re-encoded as metadata-free JPEG, with further
quality or size reduction when needed. The final copy must be no more than
2 MB. The user's original file is never modified.

Processed bytes are held only for preview and submission, then cleared after a
successful submission, cancellation, replacement, or page disposal. PlantCare
AI does not upload images to Firebase Storage and does not store image bytes,
Base64, URLs, local paths, or browser object URLs in Firestore.

Before analysis, the UI requires explicit confirmation that the image will be
sent to Google's Gemini service. Under the Gemini Developer API free tier,
submitted content may be used by Google to improve its products. Users are
warned to avoid faces, children, documents, addresses, and private home details.

### Observation boundary and stored schema

Gemini is prompted to report visible evidence and uncertainty only. It must not
diagnose disease, infer soil moisture, or recommend treatment, pesticides,
fertilizer, or watering. The SDK requests JSON structured output, and app code
strictly validates the schema version, required keys, types, enums, confidence
ranges, array sizes, and text lengths before displaying or saving it. Arbitrary
Markdown, HTML, URLs, prompts, and raw responses are not rendered or persisted.

Validated observations are immutable documents stored newest-first at:

```text
users/{uid}/plants/{plantId}/observations/{observationId}
```

Each document contains only `schemaVersion`, `plantVisible`, flattened image
quality fields, optional possible-identification fields, `affectedParts`, the
bounded structured `observations` list, `distribution`, `severity`, follow-up
photo fields, `modelName`, server `createdAt`, and
`source: firebase_ai_client`. The authenticated repository derives the UID.
Rules require the owner and an existing parent plant, validate every field, and
deny updates. These records are client-originated AI output and must not be
treated as cryptographically trusted backend attestations.

The protected routes are:

- `/plants/:plantId/observe`
- `/plants/:plantId/observations`
- `/plants/:plantId/observations/:observationId`

Automated tests inject fakes and never call live Firebase AI Logic. The
Firestore Rules suite runs against the emulator with `npm run test:rules`.

### Firebase AI authentication and App Check

Firebase initializes first, then optional Auth/Firestore emulators are
configured, App Check is activated when requested, application services are
resolved, and Flutter starts. `firebase_ai` 4.0.0 automatically attaches the
active Firebase Authentication and App Check credentials. The observation
service also refuses to issue a request when no signed-in Firebase user exists;
tokens are never passed through widgets or BLoCs and are never persisted.

`USE_APP_CHECK_DEBUG` defaults to false. Development does not select a debug
provider implicitly. To register a local Chrome debug token, run exactly:

```sh
flutter run -d chrome \
  --dart-define=USE_APP_CHECK_DEBUG=true
```

Obtain the SDK-generated token from the browser logs and register it at
**Firebase Console → App Check → Apps → Manage debug tokens**. Keep the token
private and never commit or share it. After registration, enforce baseline App
Check for **Firebase Console → App Check → APIs → Firebase AI Logic → Enforce**,
then retry a real signed-in observation. Replay protection remains disabled for
this milestone and is a future production decision. Do not incidentally enforce
App Check for Firestore or Authentication.

For production, Android uses Play Integrity and iOS uses App Attest with a
DeviceCheck fallback. Web uses reCAPTCHA Enterprise and requires its real site
key at build/run time:

```sh
flutter build web --release \
  --dart-define=APP_ENV=production \
  --dart-define=APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY=YOUR_REAL_SITE_KEY
```

No placeholder key belongs in source control. A production web startup fails
safely if the key is absent. A release build also rejects
`USE_APP_CHECK_DEBUG=true`. Development builds with neither App Check debug nor
production mode intentionally leave App Check inactive; use the explicit debug
flag for real AI verification.

After the debug token and live observation have been verified, also enable
**Firebase Console → AI Services → AI Logic → Settings → Authenticated-users
mode → Enforced**. Authenticated-users mode complements App Check; it does not
replace it. Firebase AI Logic makes App Check enforcement mandatory beginning
November 2, 2026. These Console settings are manual and are not changed by this
repository.

### Create the development database

In the Firebase Console for `plantcare-ai-dev-tasnimalam`, open **Firestore
Database**, choose **Create database**, and select **Production mode**. The
database location is permanent. For development near Toronto, the recommended
location is `northamerica-northeast2` (Toronto); confirm that location against
the expected production users and backend placement before creating it.

Deploy the checked-in rules only after reviewing the active Firebase project:

```sh
firebase deploy --project plantcare-ai-dev-tasnimalam --only firestore:rules
```

### Firebase emulators

The app can explicitly connect to the Firebase Authentication Emulator after
Firebase initialization. The switch defaults to false and is ignored for
production environments and release builds.

The same compile-time switch configures both Authentication and Firestore.
Start both emulators from the project root:

```sh
firebase emulators:start --only auth,firestore
```

Run a debug build with emulator use enabled:

```sh
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

Web and the iOS simulator connect to `localhost` on ports `9099` and `8080`.
An Android emulator connects to the host machine through `10.0.2.2` on the
same ports. A physical device needs additional host/network support and is not
configured by this flag.

Unit, BLoC, router, and widget tests use injected fake repositories and never
contact the live Firebase project. Security Rules tests use the official
Firebase Rules Unit Testing library and an automatically managed Firestore
emulator:

```sh
npm install
npm run test:rules
```

## Curated plant-care knowledge foundation

The repository contains a reviewed, source-controlled knowledge dataset for
five canonical plants: tomato (`tomato`), pumpkin (`pumpkin`), pothos
(`pothos`), snake plant (`snake_plant`), and peace lily (`peace_lily`). Its
purpose is to provide small, attributable facts for deterministic retrieval
from saved observations.

Versioned chunks are stored at `knowledgeChunks/{chunkId}` and source metadata
at `knowledgeSources/{sourceId}`. Schema version 1 requires canonical identity,
category and stable issue keys, environment, affected parts, growth stages,
normalized symptom keywords, bounded title/content/cautions, source references,
review state, dataset version, and timestamps. IDs are deterministic from the
canonical plant key, category, and issue key, so revising wording updates the
same logical record. No embeddings are stored and no vector or semantic search
exists in this milestone.

Sources are limited to government, university extension, recognized botanical
garden, peer-reviewed, or comparable institutional horticulture material. Each
page is manually reviewed before it enters the manifest. Chunks paraphrase
facts in concise original wording rather than copying source passages or
tables; every production chunk references one or more manifest entries.

Install, validate, test, and dry-run the standalone tool:

```sh
cd tools/knowledge_ingestion
npm install
npm run format:check
npm run build
npm test
npm run validate
npm run dry-run
```

Dry-run is the default and requires an explicit project ID. Production writes
are restricted to `plantcare-ai-dev-tasnimalam` and require credentials, the
production flag, and an exact typed confirmation. Application Default
Credentials are recommended:

```sh
gcloud auth application-default login
npm exec tsx src/cli.ts -- \
  --project plantcare-ai-dev-tasnimalam \
  --write-production
```

When prompted, type `ingest plantcare-ai-dev-tasnimalam`. For automation, the
intentional noninteractive equivalent is:

```sh
npm exec tsx src/cli.ts -- \
  --project plantcare-ai-dev-tasnimalam \
  --write-production \
  --non-interactive-confirm "ingest plantcare-ai-dev-tasnimalam"
```

A manually downloaded service-account JSON may instead be kept outside this
repository and passed with `--credential /absolute/outside/path/key.json`.
Never commit or log that file. Use `--report-stale` for a read-only stale-ID
report; the tool never deletes stale documents.

Authenticated clients may read both knowledge collections, but Security Rules
deny unauthenticated reads and all client creates, updates, and deletes. Admin
SDK ingestion bypasses those client rules, so the tool independently validates
the entire dataset before writing. Run the complete emulator-backed rules suite
from the repository root with `npm run test:rules`.

### Deterministic observation retrieval

Saved observation details include **Find relevant knowledge**. The client first
maps a saved profile name or a qualifying AI identification to one of the five
canonical keys. Scientific profile name, common profile name, possible AI
scientific name, and possible AI common name are considered in that order; AI
identification is ignored below `0.70`. Matching is exact after safe case,
whitespace, punctuation, apostrophe, hyphen, and underscore normalization. It
does not use broad fuzzy matching.

If the saved profile and a qualifying AI identification map to different
supported plants, the user must choose between both candidates. That selection
is local to the retrieval and never edits the profile or observation. An
unresolved plant shows the five currently supported plants.

The repository queries only `knowledgeChunks` whose `canonicalPlantKey` equals
the resolved key. Malformed records and unsupported schema or dataset versions
are excluded with safe diagnostics; valid records can still be ranked. Only
source documents referenced by the five-or-fewer ranked results are then read.
Missing or malformed sources are shown as unavailable rather than crashing the
result. Source links must parse as HTTPS URLs and open externally; arbitrary
HTML is never rendered.

Ranking algorithm `metadata-v1` is pure, local Dart with these constants:

- exact normalized symptom-keyword phrase: 12 points;
- each normalized symptom-token overlap: 3 points;
- each affected-part overlap: 5 points;
- environment match: 3 points;
- growth-stage match: 2 points;
- category relevance to a structured visible-observation type: 2 points; and
- caution relevance for poor image quality or severe/unclear observations: 1
  point.

Canonical plant equality is required rather than scored. Ties sort by score
descending, then title and document ID ascending. At most five chunks are
returned, and the minimum score is 14. Identity and basic-care chunks receive
no automatic priority. Exact token and phrase boundaries plus conservative
singular/plural handling avoid obvious substring false positives. Match reasons
are displayed, but keyword or category relevance is never treated as proof of
disease.

The production dataset is `2026-09-03-v2` with schema version 1. Retrieval makes
no Gemini request and persists no result, so it remains Spark-compatible. It is
metadata and keyword retrieval, not vector RAG: there are no embeddings,
semantic similarity, or server-side vector queries. Every result preserves its
publisher, source title, and external link and states: “These are potentially
relevant references, not a confirmed diagnosis.” A future, separately approved
milestone can move retrieval to a trusted backend and add vector search while
preserving structured evidence and attribution.

### Deterministic fertilizer guidance

Dataset `2026-09-03-v2` is the active reviewed production release. It contains
15 trusted sources and 50 reviewed chunks, including nine fertilizer chunks.
New retrieval, diagnosis, watering, and fertilizer work uses v2; persisted v1
observations, diagnoses, soil checks, and metadata remain readable and are not
rewritten.

The evidence audit covers all five supported plants:

| Plant | Supported claim | Broad category supported | Timing or limit | Safety evidence |
| --- | --- | --- | --- | --- |
| Tomato | Soil-test-guided fertilizer may be considered when first fruit enlarges | Vegetable or tomato | Fruit enlargement; no fixed interval | Excess nitrogen can delay fruiting; do not fertilize a stressed plant |
| Pumpkin | Soil-test-guided fertilizer may be considered once runners develop | General garden or compost amendment | Runner development; no fixed interval | Wait during stress and avoid treating symptoms with fertilizer |
| Pothos | Routine fertilizer is limited to active indoor growth | Balanced houseplant | No more often than every other month; not during winter dormancy | Wait while unhealthy and at least 2–4 weeks after repotting |
| Snake plant | Fertility needs are minimal during active spring or summer growth | Balanced houseplant or compost amendment | Seasonal only; no defensible repeat interval | Wait while unhealthy and at least 2–4 weeks after repotting |
| Peace lily | Fertility needs are low and limited to healthy active growth | Balanced houseplant | Active growth only; no plant-specific repeat interval | Overfertilizing can burn tips and roots; wait after repotting |

Pure Dart policy `deterministic-fertilizer-v1`, record schema 1, uses structured
constants and audited chunk IDs; it never parses knowledge prose or calls
Gemini. Assessments ask for `active_growth`, `slow_or_dormant`,
`stressed_or_unhealthy`, `recently_repotted`, or `unknown` and may return
`consider_fertilizing`, `wait`, `avoid_while_stressed`,
`more_information_needed`, `insufficient_evidence`, or `unsupported_plant`.
Stressed plants must avoid routine fertilizer, dormant plants must wait,
recently repotted houseplants must wait, and unknown activity must request more
information. The latest user-entered fertilizer care log is history only;
missing or old history is not proof of need.

Only audited broad categories can be displayed: `balanced_houseplant`,
`vegetable_or_tomato`, `flowering_or_fruiting`, `general_garden`, or
`compost_or_organic_amendment`. The UI never recommends brands, exact dosage,
mixing instructions, application quantities, or diagnosis-based fertilizer.
It tells users to follow the product label and not treat disease with
fertilizer.

Immutable assessments are stored at
`users/{uid}/plants/{plantId}/fertilizerAssessments/{assessmentId}`. The UID is
derived from Firebase Authentication. Before saving, all evidence chunks and
trusted sources must exist, match the plant, and use v2. Security Rules enforce
owner access, exact shape, bounds, version fields, timestamps, and denied
updates, but cannot prove the official client policy created a record.

Validate and dry-run the candidate without network access or writes:

```sh
cd tools/knowledge_ingestion
npm run validate
npm run dry-run
```

Fertilizer recommendations remain deterministic; the separate reminder feature
can use a saved `suggestedReviewAt` only after the user reviews and confirms it.

### Manual soil checks and deterministic watering guidance

Plant details offers a manual finger test. Check about 2–3 cm below the
surface, not only the top layer, and choose `very_dry`, `dry`,
`slightly_moist`, `moist`, or `wet`. This qualitative observation is never
converted to a made-up percentage. Large pots and ground plants should be
checked in more than one spot when practical.

Pure Dart policy `manual-watering-v1` produces schema version 1 records:

| Preference | Very dry | Dry | Slightly moist | Moist | Wet |
| --- | --- | --- | --- | --- | --- |
| Consistently moist (tomato, pumpkin, peace lily) | water now | water now | check again | wait | wait |
| Surface may dry (pothos) | water now | water now | check again | wait | wait |
| More complete drying (snake plant) | water now | check again | check again | wait | wait |

An environment outside the reviewed policy returns `inconsistent_input`; an
unresolved plant returns `unsupported_plant`. Suggested times are reminders to
check again, never fixed watering schedules. Guidance does not specify a water
volume, use AI, infer moisture from leaves, or recommend fertilizer. Outdoor
results explicitly note that recent and expected rainfall are not considered;
no weather service or sensor data is used.

Every plant policy names its reviewed watering/soil chunk IDs. Before saving,
the client reloads those chunks and confirms plant identity, dataset
`2026-09-03-v2`, and complete trusted source records. Records are stored at
`users/{uid}/plants/{plantId}/soilChecks/{soilCheckId}` with server creation
time, immutable input snapshots, deterministic result, evidence IDs, and an
optional next-check time. There is no numeric moisture field and no derived
moisture value on the plant document.

Security Rules allow only the owner to create, read, and delete a bounded,
versioned record and deny updates. Rules validate ownership and shape, but
cannot prove that a client ran the official deterministic engine. These remain
client-originated records rather than trusted backend attestations.

### Watering and fertilizer care history

Authenticated users can record factual actions at
`users/{uid}/plants/{plantId}/careLogs/{careLogId}`. The single immutable
collection uses a discriminated `type` (`watering` or `fertilizing`), schema
version 1, source `user_entered`, a user-selected Firestore `occurredAt`, and a
server timestamp `createdAt`. Incorrect entries are deleted and recreated; the
app and Security Rules deny updates.

Watering records require `wateringMethod` (`top`, `bottom`, `soak`, `drip`, or
`other`) and may contain a positive `amountMl` no greater than 100,000.
Fertilizing records require `fertilizerForm` (`liquid`, `granular`,
`slow_release`, `compost`, `organic_other`, or `other`) and may contain a
trimmed product name and application note. Type-specific fields are exclusive:
a watering record never stores fertilizer fields and a fertilizing record
never stores watering fields. Common optional notes and application notes are
limited to 500 characters; product names are limited to 120. Optional strings
are omitted when blank and cannot be whitespace-padded when stored.

The selected action time may be at most five minutes ahead of the server and
no more than 365 days before creation. Dates are persisted as timestamps and
formatted only for display. Plant Details calculates the latest watering and
fertilizing actions from care logs by `occurredAt`, breaking equal-time ties by
document ID. A soil-check recommendation is never counted as performed
watering. Ordering by a single `occurredAt` field uses Firestore's automatic
single-field index, so this feature adds no speculative composite index.

Care history is user-entered and not independently verified. It does not
recommend watering, fertilizer, a product, or an amount, and it does not
confirm that a fertilizer is safe or suitable. Security Rules enforce owner
access, parent-plant existence, exact conditional fields, bounds, timestamp
rules, and immutability, but cannot prove the action occurred. Fertilizer
guidance remains separate from factual history. Weather and sensor inputs are
deferred.

### Spark V1 local care reminders

Authenticated users can create `soil_check` and `fertilizer_review` reminders
at `users/{uid}/plants/{plantId}/reminders/{reminderId}`. Schema version 1
stores a UTC `dueAt`, status (`active`, `completed`, or `cancelled`), bounded
title and optional note, server `createdAt`/`updatedAt`, and a source. A
`soil_check_suggestion` may reference only a same-plant soil check; a
`fertilizer_assessment_suggestion` may reference only a same-plant assessment;
`user_created` has no record reference. Suggested dates are prefilled but are
never saved or scheduled without confirmation, and no date is invented when a
source record has none.

Android and iOS use `flutter_local_notifications` with `timezone` and
`flutter_timezone`. The app discovers the device's IANA zone, schedules with a
DST-aware zoned API, and refreshes that zone while reconciling on the next app
resume. Android uses inexact alarms and does not request exact-alarm access.
Notification permission is requested only after the user enables device
notification delivery while saving. Denial or scheduling failure does not roll
back Firestore: the reminder remains visible in the app and may be retried.
Notification text contains only the reminder kind and plant name. Taps carry a
protected in-app reminder route.

Each device maintains collision-aware, deterministic notification IDs in local
preferences, partitioned by authenticated UID. Reconciliation watches saved
records, schedules only future active reminders, replaces duplicate schedules,
and cancels stale, completed, cancelled, or past entries known to the app. On
sign-out it cancels and clears only the departing account's local metadata; it
does not change Firestore status. Every signed-in device schedules its own copy,
so Firestore never treats a device notification ID as authoritative.

Web uses the same Firestore records and live dashboard categorization for
overdue, due-today, upcoming, and history. It does not invoke the notification
plugin, request browser permission, register a service worker, or promise
delivery when closed: “Web reminders appear while you use PlantCare AI.
Background notifications are not available in this version.” Local mobile
delivery is also best-effort—there is no server guarantee. A future paid-tier
migration can add authorized Cloud Functions and FCM without changing reminder
record ownership or making AI the scheduler.

Platform notes: simulators can exercise permission and routing, but notification
delivery timing should be confirmed on a real device. OS power management, user
settings, uninstall/reinstall, and platform scheduling limits can delay or
remove local notifications. If permission is denied, enable PlantCare AI
notifications in the device's system Settings.

## Release preparation and verification

```sh
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
npm run test:rules
(cd tools/knowledge_ingestion && npm run build && npm test && npm run validate && npm run dry-run)
git diff --check
```

Run against local Auth and Firestore emulators on Android with:

```sh
firebase emulators:start --project demo-plantcare-ai --only auth,firestore
flutter run -d emulator-5554 --dart-define=USE_FIREBASE_EMULATOR=true
```

Build release artifacts with explicit production App Check configuration:

```sh
flutter build web --release --dart-define=APP_ENV=production \
  --dart-define=APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY=YOUR_NON_SECRET_SITE_KEY
flutter build apk --release --dart-define=APP_ENV=production
flutter build ios --release --no-codesign --dart-define=APP_ENV=production
```

Release builds reject `USE_APP_CHECK_DEBUG=true`. The web reCAPTCHA Enterprise
site key is a public build-time identifier, not a provider secret; do not place
debug tokens, service-account credentials, or AI provider keys in source or
build defines.

`firebase.json` serves `build/web`, rewrites all application paths to
`index.html` for `go_router` deep links, and prevents aggressive caching of the
HTML/bootstrap/service-worker entry points. Flutter does not emit reliably
content-hashed names for every generated asset, so this configuration does not
apply immutable caching to unhashed output.

Preview and production Hosting commands are:

```sh
firebase hosting:channel:deploy release-candidate --project plantcare-ai-dev-tasnimalam
firebase deploy --only hosting --project plantcare-ai-dev-tasnimalam
```

Deploy only Firestore Rules with:

```sh
firebase deploy --only firestore:rules --project plantcare-ai-dev-tasnimalam
```

Do not run any deploy command until the project owner explicitly approves it.

### Required Console checks

Before release, manually verify project `plantcare-ai-dev-tasnimalam` remains
on the Spark plan, Email/Password Authentication is enabled, the intended
Firestore Rules version is active, and Firebase AI Logic enforces both App
Check and authenticated-users mode. These Console states cannot be proven by
the client build.

### Real-device reminder acceptance

1. Grant notification permission after saving a future reminder; confirm it is
   saved, scheduled, delivered in the background, and opens the same reminder.
2. Deny permission on a clean install; confirm the reminder remains in the app
   and the UI explains how to enable notifications later.
3. Complete and cancel separate active reminders; confirm their pending local
   notifications disappear while their Firestore history remains.
4. Reactivate a completed or cancelled reminder with a future time; confirm it
   is rescheduled once without creating another Firestore record.
5. Sign out; confirm only that account's known local notifications are cleared.
   Sign back in and resume the app; confirm future active reminders reconcile.
6. Change the device timezone and cross a DST boundary where practical;
   confirm local display and delivery follow the selected local wall time.
7. On web, confirm the app states that reminders appear only while the app is
   in use and no browser notification permission is requested.

## Intentionally deferred

Spark V1 does not include Firebase Storage, Cloud Functions, FCM, vector search,
embeddings, weather, sensors, browser push, subscriptions, Analytics,
Crashlytics, server-authoritative diagnosis or treatment, pesticide guidance,
exact fertilizer dosage, server-guaranteed notifications, account deletion, or
full data export. Images are analyzed transiently and remain absent from
history and details. Lists intentionally load the most recent bounded V1
history; pagination is deferred.
