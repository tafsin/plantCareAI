# Live Firebase identification verification — September 15, 2026

> **Update:** The user clarified that App Check is not enabled in Firebase. A rerun without `USE_APP_CHECK_DEBUG=true` successfully identified and saved Golden Pothos in live Firestore. See the [latest results](default-app-check/report.md). The debug-token registration request is withdrawn; the initial failure below does not establish that Firebase enforcement was enabled.

## Result: incomplete; live AI is blocked

The application built and ran on the existing Android 14 ARM64 emulator, using Marionette MCP for Flutter interaction. The process was `qemu-system-aarch64 -avd Pixel_4_API_34`, device `emulator-5554`. Sign-in with the supplied real account succeeded, and live Firestore loaded its existing Ice plant and Tomato records. The add-plant flow was available.

Launch from `apps/plantcare_app`:

```sh
flutter run -d emulator-5554 --dart-define=USE_APP_CHECK_DEBUG=true
```

Neither Firebase emulators nor identification response overrides were enabled. The project is `plantcare-ai-dev-tasnimalam`.

| Scenario | Result and evidence |
| --- | --- |
| Identify and save from a photo | **Blocked.** JPEG selection, preparation and explicit consent worked. Live identification returned “Could not identify this plant.” No candidates or new saved document were produced. [Photo](screenshots/01-photo.png), [consent](screenshots/01-consent.png), [failure](screenshots/01-live-identification-failed.png). Candidate limits, confirmation, review, save schema and persistence privacy remain unverified live. |
| Low-confidence identification | **Not reached.** No successful live result was returned, so the below-0.60 precondition could not be established. The failure screenshot above is blocker evidence, not a low-confidence result. No simulated screenshot is substituted. |
| No consent | **UI passed; request guard corroborated by unit test.** Unchecked consent leaves Identify plant disabled and offers cancel/manual entry. [No consent](screenshots/03-no-consent.png), [manual entry](screenshots/03-manual-entry.png). The manual form was opened later from method selection. No network trace was collected, so screenshots alone do not prove absence of AI traffic. |
| Invalid image | **UI passed; request guard corroborated by unit test.** A GIF produced “Choose a valid JPEG or PNG image.” A 22.97 MB PNG produced “Choose an image smaller than 10 MB.” Both returned to method selection before consent/submission. [GIF](screenshots/04-invalid-gif.png), [oversized PNG](screenshots/04-oversize-png.png). No network trace was collected. |
| Save unsupported plant | **New photo-to-save flow blocked.** The account's pre-existing Ice plant (Lampranthus) remained accessible. Its inspected detail screen has no limited-guidance warning: [existing unsupported details](screenshots/05-existing-unsupported-details.png). This is not evidence of a new save, and downstream advice generation was not exercised. |

## Blocking evidence and next action

The Android Firebase SDK reports HTTP 403 **App attestation failed** and failed debug-token exchanges; see [redacted errors](app-check-errors.txt). Identification failed after consent on both attempts. This establishes an App Check configuration problem; the generic UI error does not prove it is the only AI failure.

Approval was requested to register this emulator's debug token in the configured Firebase project's Android app. No registration or security setting change was performed. After approval, register the token privately, restart the app to clear SDK backoff, and repeat the live AI scenarios. Do not disable App Check enforcement. Tokens and the password are excluded from these artifacts.

## Checks and limitations

- Android debug build and launch: passed. Initial installation failed for insufficient storage; Flutter automatically uninstalled the old app and successfully reinstalled. This clears this emulator's former app-local data.
- `flutter test test/features/plant_identification/plant_identification_bloc_test.dart` in `packages/plantcare_features`: **31 tests passed**, including explicit consent, local image-processing failure, confidence policy, save flow, and cancellation. These use fakes and do not establish live AI behavior.
- Full `melos run generate`, `format`, `analyze`, `test`, and `boundaries`: not rerun; this task adds evidence only and makes no implementation changes.
- No new plant was saved, no live Firestore write was verified, and no existing cloud record was edited or deleted.
- Native Android picker controls used ADB/UI Automator. Stored PNGs are unedited ADB framebuffer screenshots, taken at Marionette-inspected states; Marionette screenshots were also visually inspected. [SHA-256 manifest](screenshot-manifest.json).
- Earlier emulator/simulated evidence in sibling directories is not proof for this live run.

Files added by this run: this report, redacted App Check errors, screenshot manifest, and eight PNGs in `screenshots/`. Existing source changes were preserved.
