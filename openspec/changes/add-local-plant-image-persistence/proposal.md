## Why

PlantCare AI currently processes plant photos in memory and sends the processed copy to Firebase AI, but it does not retain that copy for later reference. Saving every submitted processed image on the device improves continuity for plant profiles and health history without introducing Firebase Storage, image bytes in Firestore, or cross-device synchronization.

The behavior must be precise because the existing privacy documentation says images are never saved and the current flows require a confirmation before AI submission. This change replaces those behaviors with automatic AI submission and automatic platform-specific local retention after the user submits a photo, while preserving original-image protections and clear privacy disclosure.

## What Changes

- **BREAKING** Remove the local-save toggle and the existing pre-analysis consent checkbox. Submitting a plant-identification or health-check photo automatically sends the processed image to Firebase AI and schedules it for local retention.
- Persist only the existing processed image: orientation-corrected, resized/compressed, metadata-free JPEG bytes.
- Add domain contracts and metadata for local images, including identification-cover and health-check purposes, plant association, optional observation association, and creation time.
- Implement native application-private storage with UID-isolated namespaces, opaque filenames, relative metadata paths, atomic writes, missing/corrupt-file handling, storage accounting, orphan cleanup, and delete operations.
- Implement web persistence as session-only in-memory storage, clearly labeled temporary, with no browser localStorage or SharedPreferences image bytes.
- Save every submitted identification image after successful plant creation and every submitted health-check image after successful structured observation persistence.
- Add local-image previews, replace/delete actions, missing-image placeholders, local-image management, and a delete-all confirmation using BLoCs and injected repositories.
- Offer local-image cleanup when deleting a plant, hide prior-account images on sign-out, and provide an account-scoped cleanup hook for account deletion.
- Update Privacy & Safety and related onboarding/health-check copy to inform users before submission about automatic Firebase AI processing, automatic device-only storage, no synchronization, metadata removal, original-image non-persistence, and possible loss after uninstall/data clearing.
- Add unit, BLoC, widget, integration-boundary, and platform-behavior tests for automatic submission/storage, transactional ordering, failure recovery, isolation, cleanup, and prohibited Firestore/image-byte persistence.

## Capabilities

### New Capabilities

- `local-plant-image-storage`: Automatic, platform-specific local persistence, association, retrieval, management, deletion, cleanup, and privacy behavior for submitted processed plant images.

### Modified Capabilities

None.

## Impact

- `plantcare_domain`: New local-image entity, purpose enum, repository contract, and storage-related value types.
- `plantcare_data`: Native filesystem and web session implementations, metadata index, atomic file operations, UID namespace handling, lifecycle cleanup, and dependency injection. A filesystem path-provider dependency may be required for native application-private directories.
- `plantcare_features`: Identification, health-check, plant deletion, plant details/history, local-image management UI, BLoCs, previews, and privacy copy.
- `plantcare_app`: Generated DI registration and application lifecycle integration only.
- Documentation and tests: README, Privacy & Safety, photo-flow documentation, package tests, app tests, boundary checks, and build verification.
- Firestore schemas and rules remain unchanged; no Firebase Storage, Cloud Functions, Base64 image persistence, image URLs, or image paths are added to Firestore.
