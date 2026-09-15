# Plant identification — device verification

Run started: September 14, 2026, 23:38 America/Toronto.

## Outcome

**Three scenarios passed in the local test configuration; one is partially proven; one fails the post-save warning requirement.** Live Firebase AI identification remains unproven. The existing debug response overrides were used transparently for predictable results.

| Requested scenario | Result | Evidence |
| --- | --- | --- |
| 1. Identify and save from a photo | **PARTIAL:** application flow and emulator persistence passed; live AI exchange unproven | [Photo](screenshots/01-photo-preview.png), [consent](screenshots/01-consent-checked.png), [first candidate](screenshots/01-candidates.png), [second candidate](screenshots/01-candidates-bottom.png), [questions](screenshots/01-profile-questions.png), [review](screenshots/01-profile-review.png), [saved details](screenshots/01-saved-details.png), [Firestore](firestore-evidence.json) |
| 2. All candidates below 0.60 | **PASS with deterministic response:** no confident identity or confirm action; retry/manual offered | [Low confidence](screenshots/02-low-confidence.png), [request log](logs/low-confidence-request-events.jsonl) |
| 3. No consent | **PASS in local configuration:** unchecked consent, disabled submit, no service call; manual fallback opens | [No consent](screenshots/03-no-consent.png), [repeat with recorder](screenshots/03-no-consent-with-recorder.png), [manual form](screenshots/03-manual-fallback.png), [request log](logs/low-confidence-request-events.jsonl) |
| 4. Invalid image | **PASS in local configuration:** GIF and >10 MB PNG rejected before identification | [GIF rejection](screenshots/04-invalid-format.png), [oversize rejection](screenshots/04-oversize.png), [GIF repeat](screenshots/04-invalid-with-recorder.png), [oversize repeat](screenshots/04-oversize-with-recorder.png), [request log](logs/low-confidence-request-events.jsonl) |
| 5. Save unsupported plant | **FAIL for warning after save:** saving and collection retention pass, warning appears before save but disappears afterward | [Candidate warning](screenshots/05-unsupported-candidate.png), [review warning](screenshots/05-profile-review-warning.png), [saved screen](screenshots/05-saved-no-warning.png), [collection](screenshots/05-collection-no-warning.png), [details](screenshots/05-saved-details-top.png), [Firestore](firestore-evidence.json) |

See [the fix and completion plan](fix-plan.md) and [all screenshots](screenshots.md). Earlier reports in sibling folders were not treated as proof for this run. In particular, the earlier blanket pass for scenario 5 does not establish its post-save warning clause.

## Environment and evidence method

- Existing dedicated Android 14 ARM64 AVD `PlantCare_Verification_API_34`, device `emulator-5556`.
- Verified running process: `/Users/tasnimalam/Library/Android/sdk/emulator/qemu/darwin-aarch64/qemu-system-aarch64 -avd PlantCare_Verification_API_34 -port 5556 -no-snapshot -no-audio -gpu host -partition-size 8192`.
- Flutter 3.47.1 / Dart 3.13.1, debug Android build of the current working tree. Base commit `c072f9745b10e9ad64e6df90c5fb497f0ffeb7a6`; pre-existing uncommitted implementation changes were preserved.
- Flutter controls, state inspection, and visual captures used Marionette MCP. Native Android photo/file picker interactions used ADB and UI Automator because Marionette sees Flutter widgets only.
- The 25 stored proof PNGs are unedited 1080 × 2280 device framebuffer captures using `adb -s emulator-5556 exec-out screencap -p`, taken at the inspected Marionette states. Marionette's displayed captures omit system chrome and have different dimensions.
- Firebase Authentication and Firestore ran locally on ports 9099 and 8080 for project `plantcare-ai-dev-tasnimalam`. Only the emulator was written.
- New isolated test user `qa.identification.2338@example.com`, UID `tXwYOri17uDhuIc8uLfZYYzyUqIi`. Collection was empty before this run; two plants were saved through the app.
- Existing response override values: `supported`, `low_confidence`, `unsupported`. These replace the identification service; they do not call or validate Gemini. The override is rejected for release builds or non-emulator data, as covered by the app tests.

Reproduction from `apps/plantcare_app`:

```sh
flutter run -d emulator-5556 --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=PLANT_IDENTIFICATION_VERIFICATION_SCENARIO=supported
```

Restart with `low_confidence` or `unsupported` for the other response branches. Connect Marionette to the VM service URI printed by each run. [Launch logs](logs/unsupported-launch.txt) record the final build; do not reuse expired VM-service URLs.

## Observations

### 1. Supported identification and save

The JPEG plant fixture was selected through the Android picker, previewed, and explicitly consented to. The application displayed Pothos at 92% and Peace Lily at 66%, with visible evidence, ambiguity, and “not guaranteed.” Both cards required confirmation. Two candidates satisfy the three-candidate maximum for this response; domain/codec tests corroborate validation of the contract.

Pothos was confirmed. Its profile was reviewed with indoor environment, pot, 5 L, partial sun, and vegetative growth. Saving produced a real Firestore emulator document and an accessible details page. The original first attempt was interrupted by a system-back automation action; the profile and save flow was repeated successfully and its proof frames recaptured.

The screenshots prove the application behavior with the injected response. They do not prove a successful live model request, real-world botanical accuracy, or availability of the live Firebase AI deployment.

### 2. Low confidence

The response override supplied scores 0.52 and 0.41. The device displayed “Not enough confidence to suggest a match” and “Try another photo or add your plant manually.” No candidate confirmation action was shown. Low-confidence and unsupported results were injected independently of the image contents; they are controlled branch tests.

### 3–4. Consent and validation

The initial no-consent screenshot uses the plant photo. Tapping the disabled Identify control did not advance the flow. Manual entry opened with empty name fields. A repeated consent test under the VM recorder used a supported picker image, visible as a screenshot thumbnail; the consent gate is independent of image subject.

Invalid fixtures already present in the project:

- `../fixtures/unsupported-plant.gif`: 730,599 bytes; “Choose a valid JPEG or PNG image.”
- `../fixtures/oversize-plant-v2.png`: 22,969,300 bytes; “Choose an image smaller than 10 MB.”
- Supported photo: `../fixtures/pothos-test-fixture-small.jpg`, 140,478 bytes.

Marionette `get_logs` returned `Server error`. A separate read-only subscriber to the Dart VM `Logging` stream recovered the existing debug request counter. [Its log](logs/low-confidence-request-events.jsonl) contains a successful subscription followed by exactly one identification event, `requestCount=1`, at `03:52:23Z`, after explicit consent. The no-consent repeat preceded that event; the correctly selected GIF and oversized PNG repeats followed it and added no calls before the build exited. Native picker transitions initially caused selection retries; only the final inspected rejection screens are labeled as rejection evidence.

This proves no invocation of the injected identification service on those paths. It is not a packet capture of all network traffic. Relevant BLoC and image-processing tests additionally assert zero service calls and validation before decoding/submission.

### 5. Unsupported plant: confirmed defect

The Monstera response showed a limited-guidance warning, as did profile review. The plant saved with indoor/pot/6 L/partial sun/vegetative fields and remained in My Plants. Its record also passed the existing-schema assertions.

**After Save plant, the warning was absent from the saved confirmation, collection card, and details page.** The full details page was inspected by scrolling through cover image, health actions, soil, care, fertilizer, reminders, and profile fields. The screenshots named `05-saved-details-*` capture these sections. The fertilizer panel says “No assessment recorded”; no unsupported advice appeared on the screens exercised.

Source corroboration: `OnboardingPlantSupport.limitedGuidanceMessage` is rendered only by `plant_onboarding_page.dart`; the saved collection and details widgets do not render it. Downstream health checks, fertilizer assessment generation, and retrieval with a populated knowledge dataset were not exercised, so the absence of fabricated advice is established only for the onboarding and saved-profile screens inspected.

## Persistence proof

[firestore-evidence.json](firestore-evidence.json) contains both raw emulator documents and evaluated assertions. [collect_firestore_evidence.py](collect_firestore_evidence.py) is a read-only, emulator-specific reproducer.

Every saved document has exactly these fields:

`commonName`, `scientificName`, `environment`, `growingMedium`, `potSizeLiters`, `sunlight`, `growthStage`, `notes`, `createdAt`, `updatedAt`.

Both date fields are Firestore timestamp values. No image bytes, filename, image path, candidate list, confidence, uncertainty, consent, or identification metadata is present in either plant document. Evidence scope is these saved documents, not an audit of all production storage. `firestore-supported.json` is the intermediate snapshot after the first save.

## Checks run in this verification

| Check | Outcome |
| --- | --- |
| Android debug builds and launches, all three override values | Passed on QEMU |
| Targeted domain identification tests | 7 passed |
| Targeted data identification/image-processing tests | 54 passed |
| Targeted feature identification BLoC/widget tests | 41 passed |
| App verification-override and binding tests | 7 passed |
| `dart run melos run test` | Passed: shared 3, domain 90, data 131, features 194, app 87; total 505 |
| `dart run melos run format` | Passed: 371 files checked, 0 changed |
| `dart run melos run analyze` | Passed: no issues |
| `dart run melos run boundaries` | Passed |
| `git diff --check` | Passed |
| Firestore evidence assertions | Passed for both saved plants |
| `melos run generate` | Not run: no annotated sources or DI changed in this verification task |
| Security Rules suite | Not rerun: no rules changed; actual app saves used the running emulator rules |
| Live Firebase AI / production save / iOS / web | Not tested |

Logs are in [logs](logs/). Passing existing tests does not erase the observed scenario-5 defect; a post-save unsupported-warning regression test is missing.

## Files and remaining work

This task added only this evidence directory: report, fix plan, screenshot gallery and manifest, 25 PNGs, test/runtime logs, two Firestore JSON snapshots, and the read-only evidence script. It did not implement fixes or intentionally modify production source files.

Remaining work: restore the warning in saved-plant contexts, add regression coverage, and complete an authorized live Firebase AI smoke test. Follow [fix-plan.md](fix-plan.md).
