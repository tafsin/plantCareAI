# Fix and complete verification

## 1. Restore the unsupported-plant warning after save

**Confirmed defect:** scenario 5's warning is present on candidate/review screens and disappears once the profile is saved. Collection retention and Firestore schema preservation already pass.

1. Reuse the domain's canonical plant-support classification for the saved `Plant` profile. Resolve support in the feature BLoC/presentation state; do not query repositories from widgets.
2. Display the existing limited-guidance message on the saved completion screen and plant details. Add a concise corresponding indicator to unsupported collection cards so reopening the collection preserves the limitation.
3. Derive support from the plant identity and current supported dataset. Do not persist AI identification metadata, confidence, or an AI-authored warning with the plant; no plant-schema migration is required.
4. Apply the same behavior to manually created unsupported plants and to support changes after profile edits. Preserve the normal supported-plant rendering and existing navigation.
5. Add meaningful BLoC/widget/router coverage for unsupported save → completion → collection → reopen details; assert the warning remains visible and the existing Firestore field contract is unchanged. Include a supported-plant control and a manual-entry case.
6. Repeat scenario 5 on the ARM64 QEMU device and replace the failed status only after capturing the post-save warning and retained collection entry.

Likely files: the feature `plant_identification/plant_onboarding_page.dart`, `plants/presentation/pages/my_plants_page.dart`, `plants/presentation/pages/plant_details_page.dart`, their owning BLoCs/states, and relevant tests. Follow established package boundaries; avoid unrelated refactors.

**Exit criterion:** Monstera persists through navigation/relaunch, a limited-guidance warning is visible after saving and reopening, no unsupported advice is shown, and stored plant fields remain unchanged.

## 2. Close the live Firebase AI proof gap

**Unproven integration, not a diagnosed production outage:** this run deliberately used the existing emulator-only response overrides. No live authenticated AI success was obtained or claimed.

1. Use an authorized test account in the configured real Firebase development project. Sign in on the dedicated Android device without publishing credentials to the evidence files.
2. Run without `USE_FIREBASE_EMULATOR` and without `PLANT_IDENTIFICATION_VERIFICATION_SCENARIO`. Firebase AI Logic cannot use an Authentication Emulator token; do not remove the protective guard to force that combination.
3. Verify the project's existing Firebase AI Logic/model and App Check setup. If debug App Check is needed, enable only through the explicit supported debug flag and register its token outside source control. Do not invent configuration or disable enforcement.
4. Select a real supported JPEG or PNG and explicitly consent. Capture candidate results with at most three candidates, confidence, uncertainty, and manual confirmation; complete review/save.
5. Read the resulting authorized development Firestore plant document and assert the same field allowlist and timestamp types. Capture no tokens, photo bytes, or raw provider responses in diagnostics.
6. If the request fails, record the safe error category and exact failed prerequisite, resolve that specific configuration/service issue, and repeat. Do not assume billing or App Check is the cause without evidence.

**Exit criterion:** a non-overridden live model response and successful authorized save, with screenshots plus schema/privacy assertions. Deterministic low-confidence and unsupported branch evidence remains separately labeled.

## 3. Make the proof repeatable

1. Add an emulator-only Android integration runner for the five acceptance paths. Use the existing injected service and explicit response modes; retain release/live-data guards.
2. Make request-counter evidence directly observable through a safe debug extension or runner assertion. Include a positive request control, zero calls without consent, zero calls for GIF and oversized originals, and consent reset when an image changes.
3. Ensure the native picker waits for a fresh UI state before tapping; never reuse a stale UI Automator dump. Identify fixtures by filename and assert the selected fixture before submission.
4. Keep real-AI smoke-test evidence separate from fixture responses. The current fixture service ignores image content, so it proves rendering and workflow rather than botanical correctness.
5. For stronger unsupported-advice coverage, seed reviewed supported knowledge into the emulator and exercise the unsupported care/retrieval entry points. Assert no unrelated knowledge or generated advice substitutes for missing support.
6. After implementing the fix, run the required generation, formatting, analysis, tests, and boundary checks; run rules tests if persistence/rules change. Capture fresh screenshots and hashes for the repaired states.

These are planned follow-ups. No production fix was implemented as part of this verification request.
