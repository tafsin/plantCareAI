## Context

PlantCare AI is a Flutter application for Android, iOS, and web. Its authenticated shell currently has three navigation destinations. Authentication supports email/password and Google through Firebase Auth. Google sign-in already uses the native Google SDK on mobile and Firebase popup authentication on web, but the domain contract does not expose linked providers, recent reauthentication, or account deletion.

Known user-owned application data is rooted below `users/{uid}/plants/{plantId}`: observations, diagnoses below observations, soil checks, care logs, fertilizer assessments, and reminders. No Firestore user-profile document currently exists; the Firebase Authentication identity is the account profile. Curated knowledge is stored in separate top-level collections. Existing delete rules require parents to exist, and reminder deletion is currently denied, so account erasure must delete descendants before parents and needs a narrow Rules change. A separate top-level `accountDeletionCleanupRequests/{uid}` document is an approved limited support/admin handoff record rather than plant application content.

Local images are already isolated by UID and expose `LocalPlantImageRepository.deleteAllForUser`. Notification IDs are stored in SharedPreferences under a UID-specific key and exposed through `NotificationScheduler.clearUser`; native scheduled notifications use those identifiers. Web images are session-only. No other persistent user cache was found during the current audit, but deletion coverage must be revisited whenever a user-owned store is added.

Adapty `4.0.4` is currently initialized only on Android. Its client `logout` operation switches identity and may create an anonymous profile; it does not erase the provider profile. Adapty profile deletion uses a server-authorized API with a secret key and cannot be called from Flutter, JavaScript, Firebase client configuration, or public source. Google Play subscription cancellation and provider-retained transaction records are separate from PlantCare account deletion.

Firebase Hosting already rewrites application paths to `index.html`, which can support direct `/account-deletion` navigation once routing excludes the path from authentication redirects. Firebase Auth and Firestore provide no client transaction across descendant deletion and Auth deletion. The Spark-compatible design therefore uses ordered, acknowledged, idempotent client operations and clearly documents the remaining cross-device concurrency limitation.

The approved policy is:

- acknowledge support requests promptly;
- complete verified requests within 30 calendar days after successful ownership verification;
- retain no PlantCare-controlled account/application content after verified deletion completes;
- retain only a minimal deletion-support record for at most 90 days after completion, then purge it permanently;
- retain unverifiable request correspondence for at most 30 days after the last verification attempt, then delete it;
- attempt or queue trusted Adapty profile deletion within the same 30-day window without delaying Firebase deletion; and
- explain provider-controlled retention and inaccessible device-only files separately.

## Goals / Non-Goals

**Goals:**

- Provide a functional, public, signed-out deletion resource and a discoverable authenticated mobile path.
- Reuse one domain deletion contract and one BLoC-driven destructive workflow across mobile and authenticated web.
- Derive UID and linked providers from the active Firebase session at every privileged stage; never accept a UI-selected UID.
- Delete every known PlantCare-controlled Firestore record with bounded child-first work and final verification.
- Clear application-controlled data accessible on the current device before Auth deletion.
- Make subscription status advisory and deletion-independent.
- Preserve Auth until remote and required current-device cleanup succeeds; keep retry idempotent across partial work.
- Enforce the approved 30-day, 90-day, and unverified 30-day support timelines through documentation and admin tooling rather than legal wording alone.
- Keep secrets and privileged Adapty operations out of every client build and source-controlled configuration.
- Record a deterministic, authenticated, create-only Adapty cleanup handoff before any Firestore application data or Firebase Authentication identity is deleted.

**Non-Goals:**

- Cloud Functions, Firebase Admin operations in the application, App Check changes, or another deployed backend.
- Programmatic Google Play cancellation, refunds, or proof that a user cancelled a subscription.
- Erasing Google Play or Adapty records those providers retain for billing, transactions, fraud prevention, tax, or legal obligations.
- Remotely deleting local-only files from an inaccessible or offline device.
- Downloadable export, deletion grace period, scheduled account deletion, or recovery after confirmed erasure.
- Generic recursive Firestore administration or any mutation of curated knowledge.

## Decisions

### Separate account navigation from the public deletion resource

`/account` is a protected fourth shell destination. Its Privacy and data section contains Privacy Policy, Terms, and Delete account and data. Mobile opens a protected deletion experience; web may link to the same public `/account-deletion` resource in its authenticated state.

`/account-deletion` is a top-level public route outside the authenticated shell. The router treats it as public while Firebase session state changes, so a user can sign in without being redirected home and can complete deletion in place. The page prominently identifies PlantCare AI, works at narrow and wide widths, supports large text and assistive technology, and links to configured legal destinations. Firebase Hosting's existing catch-all rewrite provides direct refresh support.

Alternative considered: keep deletion protected and provide only a support email publicly. A public signed-in flow gives users who still have credentials immediate self-service deletion without reinstalling mobile and satisfies the requested cross-platform experience.

### Use validated build-time support configuration

Add `ACCOUNT_DELETION_SUPPORT_EMAIL` to application configuration. Validation accepts a single syntactically valid mailbox address suitable for a `mailto` URI and rejects missing, malformed, control-character, query-injected, or multi-recipient values. The application constructs the fixed subject and suggested body itself with URI encoding. It never puts credentials, tokens, or account existence claims in the message.

The signed-out page always explains that email starts a request, ownership must be verified, deletion completes within 30 calendar days after successful verification, and responses are neutral about registration status. Invalid or missing configuration remains visibly unavailable with a configuration error; the UI never invents an address or broken link.

### Keep authentication and deletion responsibilities behind focused contracts

`plantcare_domain` defines an `AccountDeletionRepository` for linked-provider inspection, server-backed session validation, password/Google reauthentication, known Firestore erasure and verification, and current Firebase Auth deletion. Its Firebase implementation derives and revalidates `FirebaseAuth.currentUser.uid`; methods do not accept an arbitrary authoritative UID.

Provider credential acquisition remains in `plantcare_data`: native Google authentication on Android/iOS and Firebase Google popup reauthentication on web. Password reauthentication derives the email from the current Firebase user and accepts only the current password. UI and BLoC layers never receive or log tokens and never request a Google password.

Separate domain abstractions expose account-scoped local cleanup and external destinations. Feature code does not depend on Firebase, Adapty, SharedPreferences, notification plugins, or URL-launcher packages.

### Use AccountDeletionBloc as a singular destructive state machine

`AccountDeletionBloc` owns acknowledgement, exact `DELETE` confirmation, linked-provider selection, reauthentication, remote deletion, current-device cleanup, Auth deletion, partial failure, retry, and completion. Public-page sign-in may reuse the existing authentication BLoCs, but only `AccountDeletionBloc` orchestrates destructive work.

The state machine serializes submissions and ignores duplicates while busy. It captures the active identity when confirmation begins and revalidates it before each destructive stage. Widgets retain only ephemeral controller, focus, and password-visibility state. Once remote deletion begins, leaving the route cannot imply cancellation or completion.

The ordered sequence is:

```text
acknowledge warning + exact DELETE
              |
              v
provider-aware recent reauthentication
              |
              v
create authenticated provider-cleanup request
              |
              v
bounded child-first Firestore deletion
              |
              v
server-backed known-path empty verification
              |
              v
current-device local image + notification cleanup
              |
              v
Firebase Auth deletion
              |
              v
clear app identity state and show signed-out completion
```

Any failure before Auth deletion retains the authenticated session. A cleanup-request creation failure stops before application-data erasure, is never described as queued or completed Adapty cleanup, and offers retry plus the configured support-email fallback. Retrying later destructive stages is safe: missing application documents, cleared UID directories, absent preference keys, and already-cancelled local notifications are successful no-ops. If Auth deletion fails after data cleanup, the UI says account identity deletion is incomplete, requests reauthentication again when needed, and retries without regenerating deleted content.

### Treat subscription information as warning enrichment only

Every platform shows that deleting PlantCare AI does not cancel a Google Play subscription, provides `https://play.google.com/store/account/subscriptions`, and requires acknowledgement. It also states that uninstalling the app does not cancel a subscription. Cancellation is recommended but never required to submit or complete deletion.

On Android, an optional bounded Adapty profile lookup may tailor the warning when active Premium is known. Timeout, initialization failure, unknown entitlement, unavailable profile, or any Adapty error falls back to the generic warning and never disables confirmation, reauthentication, or deletion. On web and iOS this workflow makes zero Adapty calls; current Android-only activation remains unchanged. No renewal-status extension is required merely to gate deletion because there is no gate.

Alternative rejected: require verified cancellation. Google Play treats account deletion and subscription cancellation separately, and making third-party availability a prerequisite would obstruct account erasure.

### Record a deterministic provider-cleanup handoff before erasure

After recent reauthentication succeeds and before deleting any user application document or Firebase Authentication identity, the data layer attempts to create:

```text
accountDeletionCleanupRequests/{authenticatedUid}
```

The document ID is exactly the active Firebase UID derived by the repository. The client does not accept a caller-supplied authoritative UID. The document contains exactly:

```text
schemaVersion: 1
requestedAt: server timestamp
providerCleanup: ["adapty"]
source: "self_service_mobile" | "self_service_web"
```

It contains no email, entitlement or subscription status, purchase history, plant data, images, diagnoses, credentials, tokens, Firebase configuration, or other fields. Source is derived from the runtime platform surface, not arbitrary user input. Android and iOS self-service use `self_service_mobile`; authenticated public web uses `self_service_web`.

Rules allow only `request.auth.uid == uid` to create the UID-keyed document with exact keys, schema version, `requestedAt == request.time`, the fixed one-item provider list, and a supported source. Clients cannot get, list, update, or delete cleanup requests. The trusted admin environment bypasses client Rules through its authorized server credentials.

The deterministic path prevents duplicates. Because Flutter Firestore clients do not have an authorized read or update path for this collection, create-only replay has deliberately conservative semantics: a request that was successfully created remains unchanged, but a later client that did not itself observe that success cannot prove an existing request by reading or overwriting it. Such an attempt must not claim the request is queued; it stops before destructive deletion and offers retry plus support. The same running workflow may remember its acknowledged create and continue idempotently through later stages without writing the request again.

Alternative rejected: permit no-op client updates to make replay return success. That would contradict create-only authorization, complicate preservation of the original server timestamp, and broaden client mutation of an admin handoff record.

### Delete known Firestore descendants through a bounded gateway

`plantcare_data` uses a narrow internal Firestore gateway so ordering, pagination, and failures can be tested without live services. Production reads use server source and document-ID pagination. Commits use a conservative size below Firestore's 500-write maximum.

For each plant the implementation repeatedly:

1. enumerates observations;
2. deletes all diagnoses beneath each observation;
3. deletes observations;
4. deletes soil checks, care logs, fertilizer assessments, and reminders;
5. deletes the plant document.

It then verifies every known path is empty using server reads before Auth deletion. Missing documents are complete work. A query, commit, or verification failure stops the sequence and returns a typed retryable failure. The gateway never scans or mutates curated knowledge. The manifest of known paths is centralized and must be updated alongside every future user-owned collection.

The current audit found no Firestore user-profile document or persisted saved-image reference. Documentation and tests describe only data that actually exists; future additions must extend the manifest before release.

### Change only reminder deletion authorization

Firestore Rules change reminder deletion from unconditional denial to authenticated-owner deletion while the parent plant exists. Existing child collections already permit owner deletion subject to parent existence. Curated knowledge remains client-unwritable and the fallback deny remains intact.

Pending provider handoffs use `accountDeletionCleanupRequests/{uid}` with owner-create-only client access and universal client read/update/delete denial. Admin-managed completion/support records use a separate top-level collection such as `accountDeletionRequests`; client Rules deny all reads and writes there. Only trusted local admin tooling using Application Default Credentials or an equivalent operator-authorized environment may process either collection. No credential is stored in the repository or client configuration.

### Make local cleanup account-scoped and platform-honest

After remote verification, deletion calls `LocalPlantImageRepository.deleteAllForUser(capturedUid)` and clears all known notification IDs and scheduled notifications for that UID. Notification cleanup must remove account metadata even when notification scheduling itself is unsupported; platform no-op behavior must not leave a SharedPreferences namespace behind. In-memory user caches are cleared through their owning lifecycle boundaries.

Only files reachable on the requesting device can be erased. The public page and support procedure explain that files remaining exclusively on another inaccessible device require clearing that app's data or uninstalling PlantCare AI. Local cleanup never traverses unrelated directories or another UID's namespace.

### Keep Firebase Auth deletion last

Firebase Auth deletion occurs only after remote application-data deletion, final verification, and required current-device cleanup succeed. The app waits for the unauthenticated session transition, clears account-scoped in-memory state, and navigates to a fixed signed-out completion notice without automatically invoking Google sign-in.

Client-side Adapty logout may occur as ordinary identity cleanup on Android, but its success is outside the deletion completion condition and the UI never calls it profile deletion. After the cleanup request has been successfully recorded, Firebase application-data and Auth deletion never wait for Adapty API completion.

### Handle support/admin requests without deploying a backend

The public mailto flow creates no client-readable Firestore support request and reveals nothing about account existence. Authenticated self-service deletion creates only the fixed-shape provider-cleanup handoff. A trained operator acknowledges emailed requests promptly, verifies ownership using the documented neutral procedure, records only the approved minimum fields, and completes Firebase Auth/application-data deletion within 30 calendar days after verification.

The admin support record contains only:

- opaque request identifier;
- Firebase UID or minimally necessary verified-email reference;
- verification status;
- request date;
- completion date when applicable; and
- completion/failure status.

It contains no plant content, images, diagnoses, AI output, care history, subscription details, credentials, tokens, or raw Firestore documents. The record is stored in the client-denied admin collection and is not part of normal app state.

A repository-owned admin command validates the exact schema, defaults to dry-run, lists only records eligible for removal, requires an explicit apply flag for deletion, and permanently deletes completed records at 90 days. The documented support procedure separately deletes unverifiable correspondence no later than 30 days after the last verification attempt; because correspondence resides in the configured support mailbox rather than Firestore, mailbox deletion and trash-expiry verification are explicit checklist steps. A new request may be submitted later.

The trusted admin tool enumerates pending `accountDeletionCleanupRequests`, deletes the corresponding Adapty profile using the provider's server-authorized API, records the approved minimal completion status, and deletes the pending request only after the outcome is recorded. The secret is supplied only from the operator's secure environment. Each pending request is part of the limited support/admin-record exception and must be processed within 30 days. Adapty completion cannot postpone Firebase account and application-data deletion after the handoff has been recorded.

### Make retention and provider disclosures exact

The public page, Privacy & Safety copy, README, and support documentation consistently state:

- requests are acknowledged promptly;
- verified requests finish within 30 calendar days after ownership verification;
- PlantCare retains no listed account/application content after completed deletion;
- minimal completed support records may remain for up to 90 days and are then permanently deleted;
- unverifiable correspondence remains for no more than 30 days after the last verification attempt;
- Google Play and Adapty may independently retain billing, transaction, fraud-prevention, tax, or legally required records under their policies;
- subscription cancellation is separate and recommended, not required; and
- inaccessible device-only files require clearing app data or uninstalling the app.

### Reuse legal URL validation with visible failure states

Privacy Policy and Terms remain configured absolute HTTPS destinations. The Account and public deletion pages always render both actions. Missing, malformed, or failed launch states produce nontechnical visible errors rather than hiding the links. `ACCOUNT_DELETION_SUPPORT_EMAIL` is validated separately as an email destination.

## Risks / Trade-offs

- **A second device writes while client deletion runs or uses an already-issued token.** Use server-only enumeration, final known-path verification, and immediate Auth deletion. Document that perfect global revocation would require a trusted backend beyond Spark.
- **Deletion fails after immutable history has already been removed.** Warn that confirmed work is irreversible, retain Auth, report the exact incomplete stage, and use idempotent retry.
- **Auth deletion requires recent login again after cleanup.** Preserve the session, return to reauthentication, and retry only the remaining idempotent sequence without claiming completion.
- **Cleanup-request creation fails or its result is uncertain.** Stop before destructive deletion, never claim Adapty cleanup is queued, and offer retry plus the configured support-email path.
- **A repeat encounters an existing create-only request.** Preserve the existing record without mutation; continue only when the active workflow already observed its successful creation, otherwise use the honest unconfirmed-request fallback.
- **Adapty fails or never initialized.** Fall back to the generic subscription warning and continue; provider cleanup belongs to the trusted support procedure.
- **A support operator misses a retention deadline.** Use due-date fields/checklists, dry-run purge reporting, explicit apply mode, and verification output; document operational ownership and cadence.
- **Support correspondence cannot be purged by the Firestore command.** Treat mailbox deletion as a separate required admin step and verify trash/retention behavior for the configured provider before release.
- **A future user-owned collection is omitted.** Centralize the deletion manifest and make deletion-coverage updates an architecture and release-checklist requirement.
- **Local files remain on another device.** Disclose the limitation and instruct the user to clear application data or uninstall on that device.
- **Public mailto configuration is missing.** Keep the page functional for self-service sign-in but show an explicit support configuration error and do not publish the Play Console URL until release configuration is verified.

## Migration Plan

1. Add domain contracts/configuration and data adapters with fakes and unit tests.
2. Implement Rules changes and emulator coverage.
3. Build `AccountDeletionBloc`, authenticated Account/Privacy and data UI, and public `/account-deletion` UI.
4. Wire routing, shell navigation, configuration, and DI; regenerate generated code.
5. Add admin support-record and purge tooling with dry-run tests and no embedded credentials.
6. Update Privacy & Safety and operational/release documentation.
7. Run all repository checks, web and Android builds, Firebase emulator tests, and local route verification using fake accounts only.
8. After implementation checks pass, hand verification to a fresh-context agent using Marionette MCP. Run the Android application in an Android emulator and the website in Chrome against Firebase Emulator Suite services only.
9. Save redacted screenshots and supporting verification logs under a timestamped project directory such as `artifacts/account-deletion/verification-<timestamp>/`.
10. Leave deployment, Play Console changes, production configuration, real-user processing, and pushing for separately approved work.

Rollback before deployment is a normal code revert. After any real deletion is processed, erased account/application data cannot be restored by this workflow; rollout verification must therefore use emulator or purpose-created non-production accounts only.

### Independent UI verification protocol

The final behavioral pass is intentionally performed by a fresh-context agent so it evaluates the implemented experience from the approved requirements rather than relying on the implementation agent's assumptions. The verifier uses Marionette MCP to operate both required surfaces:

- an Android emulator running the debug application; and
- Chrome running the locally served web application and Hosting-emulator deep links.

Both surfaces use Firebase Emulator Suite mode with purpose-created test identities and fixture data. App Check is not enabled for this pass: omit App Check configuration and `USE_APP_CHECK_DEBUG`, or explicitly set `USE_APP_CHECK_DEBUG=false`. Do not obtain, store, or use an App Check debug token. Verification must not contact production Firebase, live Adapty, or Google Play purchase APIs and must not delete a real account.

The verifier covers at minimum:

- signed-out direct and refreshed `/account-deletion` in Chrome;
- configured and missing support-email states;
- email/password and Google-provider UI paths using emulator-safe boundaries where provider UI cannot be exercised without an external account;
- Account as the fourth Android destination and `Privacy and data -> Delete account and data`;
- subscription warning, management link, acknowledgement, and exact `DELETE` gate;
- provider-cleanup request recording and the rule that destructive work cannot start first;
- cleanup-request failure with honest retry and support fallback;
- deletion progress, partial failure/retry, local cleanup, Auth-last behavior, and signed-out completion; and
- confirmation that web initializes or calls no Adapty SDK surface.

Screenshots and logs are saved under `artifacts/account-deletion/verification-<timestamp>/` with a concise verification report that maps evidence files to scenarios and records commands, emulator project identifiers, build inputs, and actual results. Evidence must redact email addresses, UIDs, tokens, credentials, Firebase configuration, private plant content, and any other user data. If Marionette MCP, the Android emulator, Chrome, Firebase emulators, or screenshot capture is unavailable, report the exact blocker and leave the affected scenario unverified; never substitute fabricated evidence or a different surface without approval.

## Open Questions

- Which mailbox/provider will receive `ACCOUNT_DELETION_SUPPORT_EMAIL`, and what exact mailbox controls will enforce deletion of unverifiable correspondence after 30 days? This is a release-operations configuration question, not a blocker to implementing validation and documentation.
- Who is the named operator responsible for prompt acknowledgement, the 30-day verified-request deadline, the 90-day purge cadence, and Adapty trusted cleanup? This must be assigned before publishing the Play Console URL.
