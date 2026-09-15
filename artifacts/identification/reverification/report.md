# AI plant-identification fix and re-verification report

Date: 2026-09-14 (America/Toronto)

## Outcome

The five requested application scenarios pass in the repaired Android workflow when run with the explicit debug verification responses. The live Firebase AI request was not claimed as proven because Firebase AI Logic is a live service and cannot authenticate a Firebase Authentication emulator token.

| Scenario | Result | Evidence |
| --- | --- | --- |
| Identify and save a plant from a photo | **PASS — application workflow and persistence contract** | `scenario-1-consent.png`, `scenario-1-candidates-confidence.png`, `scenario-1-profile-review.png`, `scenario-1-saved-details.png`, `firestore-evidence.json` |
| Handle a low-confidence identification | **PASS** | `scenario-2-low-confidence.png` |
| User does not consent to image processing | **PASS** | `scenario-3-no-consent.png`; the checkbox is clear, submit is disabled, and cancel/manual actions remain available. Automated tests prove the service is not called. |
| Reject an invalid image | **PASS** | `scenario-4-invalid-format.png`, `scenario-4-oversize.png`; both inputs are rejected before consent and submission. |
| Save an unsupported plant | **PASS — application workflow and persistence contract** | `scenario-5-unsupported-candidate.png`, `scenario-5-saved-details.png`, `firestore-evidence.json` |

## Root cause and repair

The previous “Could not identify” result was caused by mixing local and live Firebase services: the app signed the user in with the Firebase Authentication emulator and then sent that emulator-issued token to live Firebase AI Logic. The live endpoint rejected it as a missing/invalid authentication credential. The generic mapper did not recognize the exact SDK wording, so the UI collapsed the authentication failure into the fallback message.

The repair:

- prevents a live Firebase AI request when Authentication emulator mode is active;
- recognizes the observed authentication-error wording and maps it consistently;
- adds safe debug diagnostics without tokens, email addresses, image bytes, or AI response text;
- requires explicit AI-processing consent before submission;
- displays numeric confidence together with uncertainty;
- adds an explicit, debug-only, emulator-only response override for deterministic device verification of supported, low-confidence, and unsupported results.

The verification override cannot be enabled in a release build and refuses to run unless Firebase emulator mode is explicitly enabled.

## Runtime environment

- Dedicated Android 14 ARM64 AVD: `PlantCare_Verification_API_34`
- Device: `emulator-5556`
- Emulator process: `qemu-system-aarch64`
- Flutter debug app controlled and visually inspected through Marionette MCP
- Proof frames persisted from the same device framebuffer at 1080 × 2280 PNG
- Local Firebase Authentication and Firestore emulators
- Test account: `qa.ai.fix.20260914.001@example.com`
- Supported fixture: JPEG, 140,478 bytes
- Invalid fixtures: GIF, 730,599 bytes; PNG, 22,969,300 bytes

## Scenario details

### 1. Identify and save

- A supported JPEG is selected and prepared locally.
- The Identify action remains disabled until the consent checkbox is selected.
- Two structured candidates are returned, within the maximum of three.
- Pothos shows 92% confidence, “not guaranteed,” visible evidence, ambiguity, and a confirmation action.
- After confirmation, the environment, pot, pot size, sunlight, and growth-stage profile is reviewed and saved.
- Plant Details displays the Pothos profile and explicitly labels its processed cover image as local-only.
- Firestore contains only the plant profile allowlist and `createdAt`/`updatedAt` timestamp values. No image, candidate, confidence, evidence, ambiguity, consent, or other AI metadata field is present.

### 2. Low confidence

- Every supplied confidence is below 0.60.
- The app displays “Not enough confidence to suggest a match.”
- There is no candidate confirmation action.
- Retry-photo and manual-entry actions are displayed.

### 3. No consent

- The consent checkbox remains unchecked.
- Identify remains disabled.
- “Cancel — don’t send photo” and “Add manually” remain available.
- BLoC and widget tests assert that no identification-service call is made.

### 4. Invalid image

- GIF is rejected with “Choose a valid JPEG or PNG image.”
- A 22.97 MB PNG is rejected with “Choose an image smaller than 10 MB.”
- Both return to step 1 before the AI request path exists.

### 5. Unsupported plant

- Monstera is shown as a possibility with 91% confidence and confirmation required.
- The app displays the limited-guidance warning before confirmation and again on profile review.
- The saved Monstera remains available in Plant Details.
- The persisted document contains only the existing plant schema, so identification metadata and generated advice are not carried into the plant record.

## Firestore evidence

`firestore-evidence.json` was captured from the authenticated Firestore emulator REST endpoint immediately after both saves. It records two documents and their exact persisted field names. Both timestamp fields are Firestore `timestampValue` values. The recorded assertions are:

- original image persisted in Firestore: false;
- AI identification metadata persisted in Firestore: false;
- server timestamp fields are timestamp values: true.

## Automated checks

- `melos run generate`: passed.
- `melos run format`: passed, 371 files checked and 0 changed.
- `melos run analyze`: passed with no issues.
- `melos run test`: passed for shared, domain, data, features, and app packages.
- `melos run boundaries`: passed.
- `npm run test:rules`: passed, 79 tests.
- `git diff --check`: passed.

## Remaining live-integration proof and plan

The live Firebase AI exchange itself is still not proven by this emulator run. Deterministic verification responses prove the application state machine, validation, consent, presentation, and Firestore/local-storage boundaries, but they do not prove that the deployed Google AI backend accepts the project’s production Auth and App Check credentials.

To close that final integration gap:

1. Run a debug build without `USE_FIREBASE_EMULATOR` and without `PLANT_IDENTIFICATION_VERIFICATION_SCENARIO`.
2. Sign in with a test account in the real Firebase project.
3. Ensure the Android app is registered for Firebase App Check and use an explicitly authorized debug App Check token only for the test device.
4. Repeat the supported-photo scenario and capture the successful candidate response.
5. Confirm that the live response still validates against schema version 1 and contains at most three candidates.

No production provider key is required or stored in the Flutter client.

## Screenshot integrity

| File | SHA-256 |
| --- | --- |
| `scenario-1-consent.png` | `4a5c2b2ec6fa3bea0986621e544b666098e88a1acd4c48fde23f4429c44f62ec` |
| `scenario-1-candidates-confidence.png` | `be99975cfe2da6e9dadce4ab8393b29cd2d14ce1788f298ec416dd3393adfe4d` |
| `scenario-1-profile-review.png` | `8b1c01e081be020e9cc95c163753055f130aacedcc096b931d6db957abcdef2f` |
| `scenario-1-saved-details.png` | `0dfea4517cac4bea00e0810a0827861c02188845b2ca68c2bcd8143d74d1b7e0` |
| `scenario-2-low-confidence.png` | `c422570a1d1d50fc27ef0c4ea344136b5303347740a4e85e36735abb4a4cb3e7` |
| `scenario-3-no-consent.png` | `574d3305a702ccfdaf7c30a756e00deef1cb1121274b38d77b150536f6ba532f` |
| `scenario-4-invalid-format.png` | `e10eb466f17d167218e16ffccec746ec1ebe00a196ba7fed7dfac0fb1f5804da` |
| `scenario-4-oversize.png` | `89d4ff50a564d01ee7a8b140463f5ad0f6e11d9ab6895f074d8ff32bb747f886` |
| `scenario-5-unsupported-candidate.png` | `8e4699ed2aaabc505dda55ebf1e82595d87dc4d179ab9f41b0a25c1712176e82` |
| `scenario-5-saved-details.png` | `36d3ca1550c94ecbd2122f38def5d7d5e9aac2cc3d500d59043ac473b6acf876` |

