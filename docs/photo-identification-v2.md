# V2 photo identification and guided plant onboarding

## Implemented flow

`/plants/new` starts a route-scoped, non-persisted workflow. Identify from photo
is primary; camera capture appears on supported platforms, and Add manually
opens `/plants/new/manual` with the existing manual form and save behavior.

Photo selection runs the existing JPEG/PNG validation and in-memory processing
pipeline (10 MB input, at most 2 MB processed JPEG). Processing alone does not
send a request. The explicit **Agree & identify** action sends the processed
image to Firebase AI. No plant is created by identification.

Candidates require explicit confirmation before their two names prefill the
existing profile form. The user reviews common/scientific names, indoor/outdoor,
pot/ground, optional pot liters, sunlight, growth stage, and optional notes.
Pot size is hidden and removed for ground planting. The guided houseplant form
omits fruiting as a new selection for pothos, snake plant and peace lily; the
other existing lifecycle stages remain available. A restored existing choice
remains representable. Other identities show the existing full lifecycle list.
Manual entry keeps its original fields and options.

The final review lists the normalized plant draft, allows editing, and saves
only after **Save plant**. Save failures retain that draft and retry the existing
repository save without re-running AI. Successful save opens plant details.

## Strict identification response

The JSON object has exactly these required fields:

```json
{
  "schemaVersion": 1,
  "imageStatus": "usable_image",
  "identification_candidates": [
    {
      "commonName": "Pothos",
      "scientificName": "Epipremnum aureum",
      "confidence": 0.9,
      "visibleEvidence": ["Heart shaped leaves"],
      "ambiguityNote": "Similar leaf shapes occur in other plants"
    }
  ]
}
```

`imageStatus` is `usable_image`, `no_plant_visible`, or
`insufficient_image_quality`. Unusable images require an empty candidate list.
Usable images may have zero to three candidates. Candidate fields are required
except `ambiguityNote`, which must be omitted rather than null when absent.

Bounds: common name 80 characters, scientific name 120, one to four evidence
items of at most 160 characters each, ambiguity note at most 200 characters,
and raw response at most 6,000 characters. Text must be nonempty, trimmed,
plain text. Confidence must be finite and within [0, 1]. The decoder rejects
missing/extra fields, incorrect types, enum/version errors, oversize content,
markup, URL patterns and numeric percentage prose. Evidence/ambiguity also
reject care-advice vocabulary. Domain constructors validate the same bounds and
own immutable lists. The Firebase response schema and prompt constrain output;
local decoding remains authoritative for acceptance. Lexical text checks are
additional defenses, not proof of factual correctness or backend attestation.

The centralized `FirebaseAiConfig.model` remains `gemini-3.5-flash-lite`. Requests
use Firebase AI Logic with a structured schema, low temperature, low thinking
level, safety settings, and no tools or search grounding. Authentication is
checked before the call and again before returning the result. Firebase SDK
credentials remain inside the data layer.

## Confidence and supported plants

Candidates are ordered by numeric confidence. These are presentation thresholds,
not calibrated probabilities:

- **High:** leading score at least 0.85; leading card emphasized, confirmation
  still required.
- **Medium:** leading score at least 0.60 and below 0.85; candidate cards receive
  equal visual treatment.
- **Low:** leading score below 0.60 or no candidates; no confirmation action,
  request another photo or manual entry.

No numeric confidence percentages are displayed or saved. Identification is
always presented as uncertain. All candidates remain unconfirmed until chosen.

Tomato, pumpkin, pothos, snake plant and peace lily use existing canonical-name
matching. Unsupported names can be saved, with this warning on candidate and
final-review screens:

> Plant identification is available, but detailed PlantCare guidance is currently limited for this plant.

Conflicting recognized common and scientific names stop review until corrected.
Unknown scientific names conservatively receive the limited-guidance warning.
No knowledge chunks, curated support, or care recommendations were added.

## Architecture and routes

- **Domain:** service contract, versioned result/candidate value objects,
  confidence presentation policy, text constraints, safe failure types and
  canonical-name support checks.
- **Data:** Firebase AI adapter and strict decoder, reusing the existing image
  picker/processor and centralized model configuration. The public barrel exposes
  the decoder; Firebase-specific implementation stays under `src`.
- **Features:** one bounded `PlantIdentificationBloc` owns the whole transient
  identification-to-save workflow. A second onboarding BLoC would duplicate draft
  ownership and lifecycle cleanup. The reusable existing plant form accepts an
  initial draft and review callback, while manual/edit mode still uses its
  existing `PlantFormBloc`.
- **App:** factory composition through generated Injectable modules; protected
  `/plants/new` and `/plants/new/manual` routes inside the existing adaptive shell.

Intermediate steps share `/plants/new` rather than encoding names, candidates,
consent or images into URLs or route extras. Refresh therefore restarts at method
selection. External redirect URLs and query-carried onboarding data are rejected.
The bottom navigation and wide-screen navigation rail remain unchanged.

Handled UI states: selecting/processing, cancelled picker, consent/cancelled
consent, AI loading/cancellation, no plant, poor quality, low confidence,
candidates/rejection, safe AI failure, profile validation, review/edit, saving,
retained-draft save failure and successful navigation. Epoch checks ignore late
picker/AI responses after cancellation, replacement or route disposal. Submission
state guards reject duplicate picker, AI and save actions.

## Persistence and privacy

Only the confirmed, normalized `PlantDraft` reaches `PlantRepository.addPlant`.
The existing plant schema, Firestore paths and Security Rules are unchanged.
No Storage, Cloud Functions, vector retrieval, grounding, notifications, weather,
sensors, or new care features were added.

PlantCare does not persist the original/processed image, base64, filename/path,
URL, raw response, prompt, unconfirmed candidates, confidence, evidence, ambiguity
notes, or consent. Image bytes are private BLoC resources, excluded from emitted
state and events. Owned original and processed buffers are zeroed/released on
completion, rejection, cancellation and disposal. Candidate state is dropped on
confirmation/reset/disposal; the saved draft contains only ordinary plant fields.
Managed-runtime, operating-system and Firebase SDK copies are outside this
best-effort buffer cleanup. A request already sent cannot be retracted; cancelling
prevents its response from re-entering the workflow. Firebase provider processing
is distinct from PlantCare persistence.

## Stitch design reference

New project, explicitly requested by the user:
[PlantCare AI V2 — Photo identification and onboarding](https://stitch.withgoogle.com/projects/9887505270245843180).

Stitch generated Method Selection, Photo & Privacy, AI Identification, Guided
Profile, and Final Review using its Botanical Intelligence System
(`assets/5a841d1377a54921aa192f99e4f9ec0a`). The guided-profile reference is screen
`6940dded5c15405886728b1fa657b131`; its screenshot was inspected.

Implementation retains the app's Material 3 green seed, 20px cards, 24px outer
spacing and 680px maximum form width. The existing form controls, typography,
actual domain enum labels and navigation are reused instead of replacing the
application design system. Generated design prose that suggested diagnostics,
care states or different navigation destinations was excluded from this milestone.
These are design adaptations, not a claim of pixel-identical reproduction.
Stitch also suggested optional desktop-rail, growth-stage-icon and network-error
screen variants; those are future design refinements, not additional scope here.

## Verification and remaining live checks

Automated verification completed successfully:

| Check | Outcome |
| --- | --- |
| `melos run generate` | Passed for data, features and app; generated diffs reviewed |
| `melos run format` | Passed: 304 Dart files, zero formatting changes |
| `melos run analyze` | Passed: no issues |
| `melos run test` | Passed: 358 tests (shared 3, domain 74, data 91, features 140, app 50) |
| Final targeted verification | Passed: identification domain 7, data 49, features 33; the 3 onboarding route tests also passed, including in the full app suite |
| `npm run test:rules` | Passed: 48 tests across 8 suites in the Firestore emulator |
| Knowledge `npm test` | Passed: 17 tests across 4 suites |
| `melos run boundaries` | Passed after backing up obsolete generated root platform artifacts |
| `flutter build web --release --no-wasm-dry-run` | Passed; output `apps/plantcare_app/build/web` |
| `git diff --check` | Passed |

There are 92 identification/onboarding tests across domain, data, features and
app routing. Seven were added after the full workspace run and passed in the
final focused runs. Thus 365 distinct workspace tests were exercised across
the full run and targeted verification; counts for reruns are not added twice.

The initial default web build was stopped during its optional WebAssembly
compatibility probe after further source changes. The final JavaScript release
build succeeded with that probe disabled; WebAssembly compatibility is not
claimed. Flutter emitted a nonblocking warning about a referenced CupertinoIcons
font not present in the asset set. The release build still completed; native
platform builds and physical-device icon checks were not performed.
Tests cover strict decoding, domain bounds, confidence bands, service error
mapping/auth changes, consent, cancellation/stale requests, duplicates, candidate
confirmation/rejection, unsupported warnings, form conditions, review/edit,
retained-draft retries, buffer cleanup, fresh workflow reset, protected routes,
adaptive layouts and DI registration. Tests use injected fakes, not live AI.

Before release, manually check on a signed-in device and web session:

1. Gallery JPEG/PNG and native camera capture; platform permission cancellation.
2. Real Firebase AI responses for the five supported plants, an unsupported
   plant, a non-plant photo and a blurry photo.
3. Project quota, Auth, configured App Check and safety/error behavior.
4. Consent wording and no request before consent using the network inspector;
   cancellation after send ignores the result.
5. Live Firestore save and retry, confirming only the existing plant fields
   exist and no image/candidate metadata is written.
6. Browser refresh, browser back and sign-out during a pending workflow.
7. Physical-device accessibility, large text, camera permissions and keyboard.

No deployment was performed and no live Firebase AI identification was claimed.

## Recommended next milestone

Build a V2 guided manual soil-check experience on the existing
`manual-watering-v1` policy and reviewed v2 evidence. Ask for a qualitative finger
test approximately 2–3 cm below the surface, show the deterministic decision and
its sources, and distinguish a suggested next check from watering performed.
Keep watering logs explicit user actions. Preserve the unsupported-plant gate;
do not infer moisture or watering need from the onboarding photo or AI confidence.

## Files changed for this milestone

The following 27 files comprise this milestone. Existing unrelated authentication, native-platform, asset and dependency edits were preserved. Generated DI diffs also retain the pre-existing Google authentication registrations.

- [README.md](/Users/tasnimalam/Documents/plantcare_ai/README.md)
- [apps/plantcare_app/lib/app/dependency_injection/app_module.dart](/Users/tasnimalam/Documents/plantcare_ai/apps/plantcare_app/lib/app/dependency_injection/app_module.dart)
- [apps/plantcare_app/lib/app/dependency_injection/injection.config.dart](/Users/tasnimalam/Documents/plantcare_ai/apps/plantcare_app/lib/app/dependency_injection/injection.config.dart)
- [apps/plantcare_app/lib/app/router/app_router.dart](/Users/tasnimalam/Documents/plantcare_ai/apps/plantcare_app/lib/app/router/app_router.dart)
- [apps/plantcare_app/test/app/dependency_injection_test.dart](/Users/tasnimalam/Documents/plantcare_ai/apps/plantcare_app/test/app/dependency_injection_test.dart)
- [apps/plantcare_app/test/app/plant_onboarding_routes_test.dart](/Users/tasnimalam/Documents/plantcare_ai/apps/plantcare_app/test/app/plant_onboarding_routes_test.dart)
- [docs/photo-identification-v2.md](/Users/tasnimalam/Documents/plantcare_ai/docs/photo-identification-v2.md)
- [packages/plantcare_data/lib/plant_identification.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_data/lib/plant_identification.dart)
- [packages/plantcare_data/lib/src/dependency_injection/injection.module.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_data/lib/src/dependency_injection/injection.module.dart)
- [packages/plantcare_data/lib/src/plant_identification/firebase_ai_plant_identification_service.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_data/lib/src/plant_identification/firebase_ai_plant_identification_service.dart)
- [packages/plantcare_data/lib/src/plant_identification/plant_identification_codec.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_data/lib/src/plant_identification/plant_identification_codec.dart)
- [packages/plantcare_data/test/plant_identification/firebase_ai_plant_identification_service_test.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_data/test/plant_identification/firebase_ai_plant_identification_service_test.dart)
- [packages/plantcare_data/test/plant_identification/plant_identification_codec_test.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_data/test/plant_identification/plant_identification_codec_test.dart)
- [packages/plantcare_domain/lib/plant_identification.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_domain/lib/plant_identification.dart)
- [packages/plantcare_domain/lib/src/plant_identification/plant_identification.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_domain/lib/src/plant_identification/plant_identification.dart)
- [packages/plantcare_domain/test/plant_identification/plant_identification_test.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_domain/test/plant_identification/plant_identification_test.dart)
- [packages/plantcare_features/lib/plant_identification.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/lib/plant_identification.dart)
- [packages/plantcare_features/lib/src/dependency_injection/injection.module.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/lib/src/dependency_injection/injection.module.dart)
- [packages/plantcare_features/lib/src/navigation/app_routes.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/lib/src/navigation/app_routes.dart)
- [packages/plantcare_features/lib/src/plant_identification/plant_identification_bloc.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/lib/src/plant_identification/plant_identification_bloc.dart)
- [packages/plantcare_features/lib/src/plant_identification/plant_identification_bloc_factory.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/lib/src/plant_identification/plant_identification_bloc_factory.dart)
- [packages/plantcare_features/lib/src/plant_identification/plant_onboarding_page.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/lib/src/plant_identification/plant_onboarding_page.dart)
- [packages/plantcare_features/lib/src/plants/presentation/pages/plant_form_page.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/lib/src/plants/presentation/pages/plant_form_page.dart)
- [packages/plantcare_features/test/dependency_injection/features_module_test.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/test/dependency_injection/features_module_test.dart)
- [packages/plantcare_features/test/features/plant_identification/fakes.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/test/features/plant_identification/fakes.dart)
- [packages/plantcare_features/test/features/plant_identification/plant_identification_bloc_test.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/test/features/plant_identification/plant_identification_bloc_test.dart)
- [packages/plantcare_features/test/features/plant_identification/plant_onboarding_page_test.dart](/Users/tasnimalam/Documents/plantcare_ai/packages/plantcare_features/test/features/plant_identification/plant_onboarding_page_test.dart)

### Pre-existing root platform artifacts

The initial boundary run failed because untracked generated `android/` and `ios/` directories existed at the repository root before this task. They contained generated registrants, Flutter environment files and local properties rather than application source. To restore the required orchestration-only root, both directories were relocated intact to [/Users/tasnimalam/.codex/backups/plantcare-ai-v2-root-platforms-20260905](/Users/tasnimalam/.codex/backups/plantcare-ai-v2-root-platforms-20260905). The real native applications remain under `apps/plantcare_app`. No tracked native or authentication source was removed. Restoring these two root directories would recreate the boundary violation.
