## Context

The current Flutter workspace separates domain contracts, Firebase/device data implementations, feature BLoCs and UI, and app-level dependency injection. `SelectedPlantImage` already contains processed bytes, MIME type, and the selected filename. The existing processor creates an orientation-corrected, metadata-free JPEG within the current size limits.

Identification currently requires an explicit AI confirmation and releases its processed image after AI identification, before the profile is saved. Health check also requires a confirmation checkbox, saves a structured Firestore observation before continuing to deterministic retrieval and diagnosis, and clears the image from progress state before the observation save. There is no native filesystem dependency, approved IndexedDB abstraction, local-image settings page, or account-deletion workflow today. Firestore plant and observation schemas must remain unchanged.

## Goals / Non-Goals

**Goals:**

- Add one domain-level local-image contract usable by native and web implementations without exposing paths or plugin types.
- Preserve processed bytes long enough to save them at the correct post-persistence boundary while keeping them out of emitted cloud/domain records.
- Provide durable private native storage and session-only web storage with account isolation and safe cleanup.
- Provide automatic submission/storage state, previews, deletion, storage accounting, missing-image handling, and informational privacy disclosures through BLoCs and injected dependencies.
- Make local persistence failure independent from Firebase record correctness and diagnosis retry behavior.

**Non-Goals:**

- Firebase Storage, Cloud Functions, Firestore image fields, Base64 persistence, public-gallery export, cross-device synchronization, or cloud backup.
- An account-deletion product flow; the local repository will expose and test an account-scoped cleanup operation for the existing or future account-deletion boundary.
- Browser IndexedDB or another durable web database during this milestone.
- New image processing behavior, AI prompts, diagnosis schemas, or changes to existing Firestore rules.

## Decisions

### 1. Use a domain metadata entity plus byte-oriented repository methods

`LocalPlantImage` will contain only portable metadata: an opaque local image ID, purpose, `plantId`, optional `observationId`, creation time, and byte size. `LocalPlantImageRepository` will expose save/read/list/delete/cleanup/storage-size operations using byte buffers and metadata, never a path or filesystem/plugin type. The active account is resolved through the injected authentication-session boundary in the data implementation; an explicit account-scoped delete operation supports account deletion cleanup.

This keeps platform paths private to `plantcare_data` and lets features render previews through repository results. Returning bytes is acceptable at the domain boundary; returning paths would leak platform storage details and would not work on web.

### 2. Use conditional data implementations for native and web storage

The native implementation will use `path_provider` to resolve the application-private support/documents directory and `dart:io` for files. The web implementation will be an in-memory session store selected through a conditional import. Because the repository has no approved IndexedDB abstraction, adding durable browser storage would introduce a larger persistence and privacy surface than this milestone requires.

Native storage will use an account-derived private namespace, an opaque generated JPEG filename, and a metadata index containing relative filenames only. The index will not contain image bytes, Base64, absolute paths, emails, or user-facing names.

### 3. Make image and index updates atomic and self-healing

Native saves will write bytes to a temporary file in the target namespace, flush and rename to the final opaque filename, then update the metadata index through its own temporary-file-and-rename sequence. If either phase fails, the implementation will remove the incomplete entry where possible and report a local-save failure without changing the cloud record. Startup/resume reconciliation will remove temporary files, unindexed files, and metadata records whose files are missing or invalid.

The implementation will validate files on read and treat unreadable or undecodable files as missing. Cleanup will be account-scoped and will never scan or mutate another account's namespace.

### 4. Treat photo submission as the trigger for AI processing and deferred local persistence

The existing pre-analysis confirmation controls will be removed. Pressing the identification or health-check submission action will immediately send the processed image to Firebase AI and mark that image for mandatory local persistence. Informational privacy text will remain visible before submission, but it will not block the action or offer a local-save choice.

Identification will retain the processed bytes privately through candidate confirmation and profile save. After `addPlant` returns its ID, it will save the local cover; a failed local write will not delete the newly created plant or rerun AI.

Health check will retain the processed bytes privately while saving the structured observation. After `saveObservation` returns its ID, it will save the local health image, then proceed with diagnosis from the structured observation. A local-write failure will not cause duplicate observation writes or force diagnosis to depend on image bytes. Retry actions will distinguish cloud-record retries from local-image cleanup/retry.

This ordering prevents orphaned associations and preserves the existing rule that diagnosis uses saved structured observations rather than the source image.

### 5. Add BLoC-owned automatic persistence state and a minimal management surface

Identification and health-check BLoCs will own submission, mandatory local-save status, and the private image lifecycle; widgets will dispatch events and render state only. A dedicated local-image management BLoC will load account-scoped metadata, previews, storage usage, and deletion outcomes. Plant details/history will use the same boundary for local previews and missing placeholders. The Privacy & Safety surface will contain a local-image management section; no widget will access filesystem APIs directly.

Plant deletion will ask whether associated local images should also be removed. The cloud plant deletion remains the source of truth, while local cleanup is a separate best-effort operation with a user-visible failure state if cleanup cannot complete.

### 6. Reconcile local state with authentication and app lifecycle

The local-image data service will respond to authentication changes by switching the active namespace and clearing/hiding in-memory web data for the signed-out account. Native files remain in their account namespace so a returning user can still access them, but they are never exposed while another account is active. App startup and resume will trigger cleanup for the active account. Account deletion callers will invoke `deleteAllForUser` before or as part of account removal.

### 7. Avoid Firestore and rules changes

Local image associations will remain in the local metadata index only. No plant, observation, diagnosis, or rules codec will gain local-image fields. Tests will assert that local-image operations do not call Firebase and that serialized Firestore maps contain no bytes, Base64, paths, URLs, or local-image identifiers.

## Risks / Trade-offs

- **[Risk] Native files can be removed by the OS or user.** -> Treat missing files as normal, show a placeholder, clean stale metadata, and keep cloud history readable.
- **[Risk] A crash can occur between final-file and index updates.** -> Use temporary files, atomic renames, and startup/resume orphan reconciliation.
- **[Risk] Local-write failures occur after a successful cloud write.** -> Keep local persistence non-authoritative, avoid cloud rollback, retain structured retry paths, and report the local limitation without regenerating AI results.
- **[Risk] Automatic AI submission and local retention remove an explicit privacy choice.** -> Show clear informational disclosure before submission, perform neither action before the user presses submit, and provide local delete-one/delete-all controls.
- **[Risk] Web session storage disappears on refresh or tab close.** -> Label web images temporary and make all history usable without them.
- **[Risk] UID-derived directories could expose identifiers in private storage diagnostics.** -> Keep namespaces under application-private storage, never show paths or UIDs in UI/logs, and use opaque generated filenames.
- **[Risk] Adding native filesystem support creates platform build complexity.** -> Isolate plugin usage in `plantcare_data`, register implementations through generated DI, and cover web/native conditional compilation and boundary checks.

## Migration Plan

No data migration or Firestore migration is required. Existing plant, observation, diagnosis, and privacy records remain readable. Existing users have no local image records; after rollout, newly submitted processed images are retained automatically at the defined successful persistence boundary. Rollback removes the feature code and dependency while leaving cloud records unchanged; native local files may remain and can be removed by the app's cleanup implementation or the user clearing app data.
