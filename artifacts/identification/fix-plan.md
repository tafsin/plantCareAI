# AI plant identification remediation and re-verification plan

## 1. Restore a usable non-production Firebase AI path

1. Confirm that Firebase AI Logic is enabled for the exact Firebase project compiled into the Android app and that the configured model is available to that project/region.
2. Confirm quota/billing and API restrictions for the Android application ID and signing certificate used by this debug APK.
3. Run a debug build with `USE_APP_CHECK_DEBUG=true`, capture its generated debug token, and register that token only in the non-production Firebase project. Never commit the token.
4. Add debug-only, redacted diagnostics for Firebase AI failures (exception type/code and request correlation only; never image bytes, user tokens, prompts, or provider responses) so `appCheck`, quota, model access, and network failures can be distinguished.
5. Re-run the supported JPEG flow on QEMU before making UI changes. The exit criterion is a valid schema-v1 response on the device.

## 2. Close the acceptance gaps

1. Display confidence for every candidate using a clear numeric or bounded qualitative label derived from the validated value, alongside the existing non-guarantee copy and ambiguity note. Keep the maximum at three candidates.
2. Decide and document the consent contract. If the acceptance test requires a distinct value, add an unchecked consent control and keep “Identify plant” disabled until checked. Cancel/manual entry must remain available, and changing/removing the image must clear consent.
3. Preserve the low-confidence rule: top confidence below 0.60 must render no confirm action and must offer another photo and manual entry.
4. Preserve the unsupported-plant warning in candidate, review, saved collection, and details contexts. Do not add care/diagnosis text to identification results.

## 3. Make the device scenarios deterministic

1. Add a debug/test-only injected `PlantIdentificationService` selected by an explicit non-release Dart define. Provide fixed schema-valid responses for supported success, all-below-0.60, and unsupported identity. Fail startup if this switch is present in a release build.
2. Add a debug request recorder that records only request count and state transitions, never image data. Use it to prove zero requests for no-consent and invalid-image paths.
3. Add an Android integration test that drives the same UI and asserts:
   - supported image → at most three candidates → explicit confirmation → profile review → save;
   - low confidence → no confirm action → retry/manual actions;
   - no consent → request count zero;
   - invalid format and >10 MB → request count zero plus corrective copy;
   - unsupported identity → saved collection/details warning and no advice UI.

## 4. Prove Firestore and local-only image persistence

After a successful supported and unsupported save, query `users/{uid}/plants/{plantId}` in the Firestore emulator and assert the exact field allowlist:

`commonName`, `scientificName`, `environment`, `growingMedium`, `potSizeLiters`, `sunlight`, `growthStage`, `notes`, `createdAt`, `updatedAt`.

Assert that `createdAt` and `updatedAt` are Firestore timestamps, and recursively assert that no image bytes/path, filename, candidate list, confidence, evidence, ambiguity, raw response, prompt, or other AI identification metadata exists in the document. Separately verify that the processed cover image exists only through the authenticated user's local-image repository.

## 5. Re-run and archive proof

1. Use a dedicated ARM64 AVD with enough free data-partition space for the 168 MB debug APK and extracted artifacts.
2. Run the relevant unit/BLoC/widget suites, then the Android integration scenarios against Auth/Firestore emulators.
3. Run one live-AI smoke test with the configured non-production App Check setup; use deterministic responses for low-confidence/unsupported branch proof.
4. Capture Marionette screenshots for candidate list/confidence, low-confidence fallback, no-consent options, both invalid-image errors, supported save/details, unsupported save/details, and Firestore inspection output.
5. Update `verification-report.md` only when every assertion is directly evidenced; do not infer a pass from implementation code alone.
