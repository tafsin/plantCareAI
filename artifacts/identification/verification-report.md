# AI plant identification verification report

Date: 2026-09-14 (America/Toronto)

## Test environment

- Flutter debug APK running on the existing `Pixel_4_API_34` Android 14 ARM64 AVD under `qemu-system-aarch64` (`emulator-5554`).
- Flutter UI inspected and operated with Marionette MCP through the Dart VM service.
- Firebase Authentication and Cloud Firestore used local emulators.
- Firebase AI Logic is not emulated, so identification attempted the configured live Firebase project/backend.
- Authenticated test account: `qa.identification.20260914.001@example.com`.
- Supported input fixture: `fixtures/pothos-test-fixture-small.jpg` (JPEG, 140,478 bytes).
- Invalid fixtures: `fixtures/unsupported-plant.gif` (GIF) and `fixtures/oversize-plant-v2.png` (PNG, 22,969,300 bytes).

## Outcome matrix

| Scenario | Result | Runtime evidence | Notes |
| --- | --- | --- | --- |
| Identify and save a plant from a photo | **BLOCKED / not proven end to end** | `scenario-3-no-consent-options.png`, `scenario-1-ai-unavailable.png`, `backend-evidence.json` | A supported JPEG was selected and locally prepared. The disclosure and send action were displayed. After submission the app returned “Plant identification is temporarily unavailable. Try later or add manually.” No candidates, confirmation, profile review, save, or post-save Firestore assertions could be reached. Firestore remained empty. |
| Handle a low-confidence identification | **BLOCKED / not proven at runtime** | `scenario-1-ai-unavailable.png` | A live result could not be obtained, so a result with all candidates below 0.60 could not be displayed on the device. Existing deterministic tests cover the threshold and low-confidence copy, but they are not QEMU proof. |
| User does not consent to image processing | **PASS for the current explicit-action design** | `scenario-3-no-consent-options.png` | After image selection, the page states that the photo is sent only when “Identify plant” is selected and offers “Cancel — don’t send photo”; manual entry is also part of this preview state. No request is triggered by selection alone. There is no separate consent checkbox or stored consent value. |
| Reject an invalid image | **PASS** | `scenario-4-invalid-format.png`, `scenario-4-oversize.png` | The GIF is rejected with “Choose a valid JPEG or PNG image.” The 22.97 MB PNG is rejected with “Choose an image smaller than 10 MB.” Both fail before the AI-submit state. |
| Save an unsupported plant | **BLOCKED / not proven at runtime** | `scenario-1-ai-unavailable.png` | The unavailable AI backend prevented candidate confirmation and save. The limited-guidance widget test passes, but collection persistence and the absence of fabricated advice were not observable end to end. |

## Important findings

1. **Live Firebase AI is unavailable in this run.** The app maps the underlying SDK failure to a generic availability message. Android logs also report that no App Check provider is installed during Firebase requests, but the app does not expose enough safe diagnostic detail to prove that App Check is the sole cause.

2. **Candidate confidence is not rendered.** The response schema and domain model validate a numeric `confidence`, and thresholds are implemented, but candidate cards render name, scientific name, visible evidence, optional ambiguity, and a confirmation button without displaying `candidate.confidence`. Therefore the acceptance clause “confidence and uncertainty are displayed” would still not be fully satisfied even if the backend returned candidates.

3. **Consent is action-based, not a separate control.** The preview explains the transfer and makes “Identify plant” the only send action. This is defensible explicit consent-by-action, but there is no checkbox/modal or consent field that can be asserted independently.

4. **Persistence boundaries are correctly represented in code, but not proven after a successful device save.** The save path passes only `PlantDraft` to the plant repository and saves processed image bytes through the local-image repository. The Firestore model allowlist contains only plant profile fields plus server timestamps. Because the live identification never succeeded, runtime Firestore proof after save is still missing.

5. **The shared AVD is storage-constrained.** Flutter's automatic reinstall intermittently failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE`; direct APK install and VM-service forwarding were used without removing unrelated emulator apps.

## Screenshot integrity

All proof screenshots are Marionette captures at 975 × 2000 PNG:

- `scenario-1-ai-unavailable.png` — SHA-256 `be6804604818aaa4c7827addb00414f93f06307efb3a0ad0d4be02c3e1e6a89f`
- `scenario-3-no-consent-options.png` — SHA-256 `41ca70dca42e3844ea0f54160550fbdedbaf1675f63b95a75798828a58d9ccf9`
- `scenario-4-invalid-format.png` — SHA-256 `03c91a5d87c0d7cbeb28b8ab3b70dc32ce6441acea506a5724df826d92029992`
- `scenario-4-oversize.png` — SHA-256 `eb0eb5275a9121a87fc121039e45aab93da1adae0eef82e7767060b688a35aad`

## Automated corroboration

These are supporting checks, not substitutes for the blocked device scenarios:

- `plantcare_domain`: 7 identification tests passed.
- `plantcare_data`: 52 identification/image-processing tests passed.
- `plantcare_features`: 39 identification BLoC/widget tests passed, including full review/save with fakes, confidence 0.3 and 0.7 presentation, unsupported identity warning, and manual fallback.

No production source files were intentionally changed for this verification.
