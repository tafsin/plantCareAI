# PlantCare AI

PlantCare AI is a Flutter mobile and web application for managing plants and,
in later milestones, receiving AI-assisted, source-grounded plant-care guidance.
This repository currently contains the cross-platform foundation, Firebase
email/password authentication, user-owned Firestore plant data, and a first
AI-assisted plant-image observation vertical slice.

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

The production dataset is `2026-09-03-v1` with schema version 1. Retrieval makes
no Gemini request and persists no result, so it remains Spark-compatible. It is
metadata and keyword retrieval, not vector RAG: there are no embeddings,
semantic similarity, or server-side vector queries. Every result preserves its
publisher, source title, and external link and states: “These are potentially
relevant references, not a confirmed diagnosis.” A future, separately approved
milestone can move retrieval to a trusted backend and add vector search while
preserving structured evidence and attribution.

## Run and verify

```sh
flutter pub get
flutter run
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Select a specific target with `flutter run -d chrome`, an Android device ID, or
an iOS simulator ID.

## Intentionally deferred

This milestone does not create Firestore user-profile documents. It also does
not include Firebase Storage, Cloud Functions, vector search, diagnosis,
treatment,
pesticide guidance, soil-moisture records, watering or fertilizer workflows,
notifications, App Check enforcement, Analytics, or Crashlytics. Images are
analyzed transiently and remain intentionally absent from history and details.
