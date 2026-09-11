## 1. Domain contracts and portable models

- [x] 1.1 Add the local-image purpose enum and immutable `LocalPlantImage` metadata entity for identification covers and health checks, including opaque ID, plant association, optional observation association, creation time, and byte size; verify domain unit tests cover equality, optional association, and validation boundaries.
- [x] 1.2 Add `LocalPlantImageRepository` to `plantcare_domain` with save, read, list, storage-size, delete-one, delete-by-plant, delete-all-for-current-account, delete-all-for-account, and cleanup operations using bytes and metadata only; verify the public API exposes no filesystem paths or plugin types and package boundary checks pass.
- [x] 1.3 Update domain barrels and add repository test fakes that can inject successful saves, failed writes, missing files, corrupt bytes, and account changes; verify all feature tests can use the fake without Firebase or platform storage.

## 2. Native and web data implementations

- [x] 2.1 Add the smallest required native filesystem dependency and conditional implementation structure for Android/iOS versus web; verify dependency resolution and web compilation succeed without importing `dart:io` into web code.
- [x] 2.2 Implement native application-private storage with UID-isolated namespaces, generated opaque JPEG filenames, relative metadata-index paths, and no user identifiers in user-visible filenames; verify unit tests cover namespace separation and metadata contents.
- [x] 2.3 Implement atomic native image and metadata-index writes using temporary files and renames, with cleanup on failed writes; verify successful atomic save, failed write, no orphan, and storage-size tests.
- [x] 2.4 Implement native read validation, missing/corrupt-file handling, temporary-file cleanup, unindexed-file cleanup, delete-one, delete-by-plant, delete-all, and account-scoped cleanup; verify each operation preserves other accounts and returns safe missing results.
- [x] 2.5 Implement the web session-only repository with in-memory account isolation, temporary-image metadata, delete operations, and no localStorage or SharedPreferences image bytes; verify session reset/sign-out behavior and web-specific tests.
- [x] 2.6 Register both implementations through generated data DI and add authentication/app-lifecycle reconciliation for sign-in, sign-out, app startup, resume, and account-scoped cleanup; verify DI registration tests and lifecycle tests pass after regeneration.

## 3. Identification persistence flow

- [x] 3.1 Remove the identification confirmation gate and any local-save toggle, make the submit action immediately invoke Firebase AI, and show precise informational AI/device-storage disclosure; verify widget and BLoC tests prove there is no toggle or checkbox and no AI call occurs before submit.
- [x] 3.2 Retain the processed image privately through identification, candidate confirmation, profile review, replacement, cancellation, disposal, and plant-save retry without placing bytes in emitted states or Firestore drafts; verify buffer lifecycle tests cover every exit path.
- [x] 3.3 After successful `addPlant`, automatically save the submitted processed image as the local identification cover; verify plant-creation failure creates no local image, successful retry does not rerun AI, and local-write failure does not roll back the plant or create duplicates.
- [x] 3.4 Add identification cover preview, replace/delete behavior, and missing-image placeholder to the relevant plant details surface; verify the preview uses the local repository and remains usable when the file is missing.

## 4. Health-check persistence flow

- [x] 4.1 Remove the health-check confirmation checkbox and any local-save toggle, make the submit action immediately invoke Firebase AI, and show informational native/web storage disclosure; verify widget and BLoC tests prove automatic submission behavior and temporary web wording.
- [x] 4.2 Preserve the processed health-check image privately until structured observation persistence returns an observation ID, then attempt local save with plant and observation associations before releasing bytes; verify observation-save failure leaves no local image and local-write failure leaves the saved observation intact.
- [x] 4.3 Ensure diagnosis generation and assessment retries use the structured saved observation and do not require or resend the local image; verify retry tests perform no duplicate observation save or AI image submission.
- [x] 4.4 Add health-history/detail local-image preview, delete, and missing-image placeholder behavior without changing Firestore observation or diagnosis records; verify deleting a local health image leaves cloud history readable.

## 5. Management UI, plant deletion, and lifecycle behavior

- [x] 5.1 Add a local-image management BLoC and expose it from the Privacy & Safety surface as the local-image management section; verify loading, empty, populated, failure, storage-used, temporary-web, and delete-all-confirmation states with widget tests.
- [x] 5.2 Add confirmation-protected delete-all behavior and individual delete/replace actions through BLoC events; verify repository calls are account-scoped and deletion does not invoke Firebase repositories.
- [x] 5.3 Update plant deletion confirmation to offer removal of that plant's local images and coordinate cloud deletion with best-effort local cleanup; verify accepting, declining, and local-cleanup-failure cases.
- [x] 5.4 Verify sign-out hides the previous account's images, a second account cannot list or delete them, and account-scoped deletion cleanup removes only the deleted account's namespace; add feature/data integration tests using two fake accounts.

## 6. Privacy and documentation

- [x] 6.1 Replace unconditional no-image-save and consent-gated wording in Privacy & Safety, README, and photo-flow documentation with automatic Firebase AI submission and automatic device-only retention behavior, including processed-only storage, metadata removal, no synchronization, and possible loss; verify documentation searches find no contradictory opt-in or confirmation requirement.
- [x] 6.2 Document native private-storage and web session-only limitations, account isolation, deletion behavior, and the absence of Firebase Storage/Firestore image bytes; verify the changed documentation matches the implemented UI strings and architecture.

## 7. Automated coverage and prohibitions

- [x] 7.1 Add data-layer tests for atomic save, failed write, missing/corrupt file, orphan cleanup, storage-size calculation, delete-one, delete-by-plant, delete-all, account isolation, sign-out visibility, and web session-only behavior; verify they run without live Firebase services.
- [x] 7.2 Add identification and health-check BLoC/widget tests for no toggle/checkbox, no processing before submit, automatic AI submission, automatic local persistence ordering, plant/observation failure, local-write failure, retry without duplicate image, replacement, deletion, and missing placeholders; verify all requested scenarios are covered.
- [x] 7.3 Add serialization and boundary tests proving no image bytes, Base64, local paths, browser object URLs, or local image IDs enter Firestore maps, events, route data, or persisted plant/observation records; verify Firestore rules and existing codecs remain unchanged.
- [x] 7.4 Add DI, package-boundary, lifecycle, and platform-conditional tests; verify no feature widget imports filesystem/plugin APIs and no domain API imports data implementation paths.

## 8. Verification and delivery checks

- [x] 8.1 Regenerate injectable code and review generated diffs for only expected local-image registrations; verify `melos run generate` succeeds.
- [x] 8.2 Run formatting and static analysis across the workspace; verify `melos run format` and `melos run analyze` succeed with no unrelated changes.
- [x] 8.3 Run all workspace, rules, knowledge, local-image, and boundary tests; verify `melos run test`, `npm run test:rules`, knowledge tests, and `melos run boundaries` pass.
- [x] 8.4 Build the web and Android targets, and run the applicable iOS build/check; verify platform compilation, conditional imports, and no deployment or Firebase Storage integration.
- [x] 8.5 Review the final diff and privacy documentation, verify no image bytes or secrets are present, and report known limitations including web session loss and the absence of an account-deletion UI.
