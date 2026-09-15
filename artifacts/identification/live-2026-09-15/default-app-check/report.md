# Live Firebase rerun with default App Check configuration

## Outcome

Removing `--dart-define=USE_APP_CHECK_DEBUG=true` resolved the observed identification failure. The user's Firebase settings were not changed. The earlier debug-token registration request is withdrawn.

The app ran with `flutter run -d emulator-5554`, using real Firebase Authentication, Firestore, and Firebase AI in project `plantcare-ai-dev-tasnimalam`. There were no Firebase emulator or simulated AI response flags. Marionette MCP controlled the Flutter flow; ADB controlled the native picker and saved screenshots. The running Android emulator uses `qemu-system-aarch64`.

## Scenario results

| Scenario | Result |
| --- | --- |
| Identify and save from photo | **Requested data flow passed live; post-save UI defect observed.** One Golden Pothos candidate, scientific name Epipremnum aureum, confidence 95%, uncertainty warning, and explicit candidate confirmation. Profile reviewed and saved. Live Firestore document has exactly the ten existing plant fields and no image or AI identification metadata. |
| Low confidence below 0.60 | **Not verified live.** The successful result was 0.95. The existing BLoC confidence-branch tests passed in the preceding run, but are not live model evidence. |
| No consent | **UI verified in preceding live-backend run**, with disabled submission and cancel/manual choices. Existing consent-guard unit test passed. No network-level absence-of-request trace was collected. |
| Invalid image | **UI verified in preceding live-backend run**, with GIF and oversized PNG rejected before submission. Existing image-failure BLoC test passed. No network-level absence-of-request trace was collected. |
| Unsupported plant save | **Not verified with a new live AI result.** The pre-existing unsupported Ice plant remained visible, but its inspected details lacked a limited-guidance warning. |

## Screenshots and persistence

- [Live candidate and uncertainty](screenshots/01-live-candidate.png)
- [Plant-profile questions](screenshots/01-profile-questions.png)
- [Final profile review](screenshots/01-review.png)
- [Unexpected limit screen immediately after save](screenshots/01-after-save-limit-screen.png)
- [Saved plant in collection](screenshots/01-saved-collection.png)
- [Saved plant details](screenshots/01-saved-details.png)
- [Live Firestore document and field assertion](firestore-supported.json)
- [No consent](../screenshots/03-no-consent.png), [manual entry](../screenshots/03-manual-entry.png), [invalid GIF](../screenshots/04-invalid-gif.png), [oversized PNG](../screenshots/04-oversize-png.png), [existing unsupported plant](../screenshots/05-existing-unsupported-details.png)

New document ID: `eGUh6GIJ1w3agL1P1w1m`. The user account now has three plants. The verification plant is labeled through its notes: “Live photo-identification verification 2026-09-15.” The two pre-existing plants were not changed. Firestore evidence was read with the supplied user's own authentication, not an administrative credential. Credentials and tokens were not written into artifacts.

The saved document contains only `commonName`, `scientificName`, `environment`, `growingMedium`, `potSizeLiters`, `sunlight`, `growthStage`, `notes`, `createdAt`, and `updatedAt`. Both date fields are server timestamps. This proves absence of photo and AI metadata in this document, not a complete audit of every storage location.

## Additional observed defect

After saving the third plant, the creation route displayed “Plant limit reached” instead of the successful onboarding state. Returning to My Plants showed that the save had succeeded. The details view also showed no local cover image. The route's reactive creation gate may be disposing the onboarding flow when the new Firestore count reaches three; that explanation is a source-based hypothesis, not a verified fix.

## Remaining work

The three-plant free limit now blocks additional photo creation. Approval is pending to remove only this newly created verification plant after preserving evidence, so the low-confidence and unsupported scenarios can continue. No deletion, purchase, entitlement override, or Firebase security change has been performed.

## Checks and files

Android debug build, launch, live identification, app save, and read-only live Firestore field assertion passed. The preceding targeted BLoC run passed 31 tests. No implementation code changed, so full generation, formatting, analysis, workspace tests, and boundary checks were not rerun. Screenshots, this report, a manifest, and Firestore evidence were added under this directory; the parent report now links here.
