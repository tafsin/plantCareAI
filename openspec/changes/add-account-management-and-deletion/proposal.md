## Why

PlantCare AI allows users to create Firebase-backed accounts, so Google Play requires both a readily discoverable in-app deletion path and a functional public web resource where a user can request deletion without reinstalling the app. The current product has neither a self-service account-erasure workflow nor an approved support-request process, and its Privacy & Safety copy explicitly says account deletion is unavailable.

The milestone must remain compatible with Firebase Spark, preserve the current package boundaries, and handle irreversible client-side deletion honestly. Subscription cancellation and third-party billing retention are separate from deleting PlantCare-controlled account and application data.

## What Changes

- Add Account as the fourth authenticated navigation destination on Android, iOS, and web, with `Account -> Privacy and data -> Delete account and data` as the discoverable mobile path.
- Add a public `/account-deletion` route that remains accessible while signed out, survives direct Firebase Hosting navigation, identifies PlantCare AI, and links to the configured Privacy Policy and Terms.
- Let users sign in on the public page with existing email/password or Google authentication and complete the same confirmation, provider-aware reauthentication, and deletion workflow used by mobile.
- Add a signed-out support-request option using a validated `ACCOUNT_DELETION_SUPPORT_EMAIL` mailto destination. Missing or invalid configuration produces a visible configuration error and never fabricates an address.
- Require acknowledgement of the subscription warning and exact case-sensitive `DELETE` confirmation, but never require subscription cancellation or proof of cancellation.
- Keep Adapty Android-only. Android may use an optional, bounded profile lookup to improve the warning; lookup failure, timeout, unavailable profile, or unknown entitlement never blocks deletion. Web and iOS never initialize or call Adapty for this workflow.
- After successful reauthentication and before deleting Firestore data or Firebase Authentication, create the deterministic provider-cleanup request `accountDeletionCleanupRequests/{uid}` with the exact approved schema. Only the authenticated UID may create its own request; clients cannot read, update, or delete requests.
- Make cleanup-request creation safe and state-idempotent: the UID-keyed document cannot be duplicated or mutated by a repeat. Destructive deletion proceeds only after the active workflow observes successful creation; an unconfirmed or failed attempt is never described as queued and offers retry plus the configured support-email fallback.
- Delete all known PlantCare-controlled Firestore descendants in bounded child-first work, clear account-scoped local images and notification metadata accessible on the current device, then delete Firebase Authentication last.
- Make destructive work serial, idempotent, and retryable. Preserve the authenticated session before Auth deletion and report partial completion honestly if a later stage fails.
- Update reminder-delete authorization without weakening ownership or curated-knowledge rules.
- Adopt the approved support policy: prompt acknowledgement; completion within 30 calendar days after successful ownership verification; minimal support/audit records retained for at most 90 days after completion; unverified correspondence retained for at most 30 days after the last verification attempt; and a documented, enforceable admin purge procedure.
- Document that PlantCare retains no plant content, care data, images, reminders, or Firebase account data after verified deletion completes. Distinguish limited PlantCare support records from provider-controlled Google Play and Adapty billing, transaction, fraud-prevention, tax, or legally required records.
- Add an admin-only support procedure that processes pending cleanup requests through the Adapty server API, records only the approved minimal completion audit, and removes the pending request. A successfully recorded request is part of the limited support/admin-record exception and must be processed within 30 days. Firebase deletion does not wait for Adapty API completion after the request is recorded; SDK logout is not described as profile deletion.
- Update Privacy & Safety, release/support documentation, and tests. Do not deploy, process a real user, modify production, or push.

## Capabilities

### New Capabilities

- `account-management`: Authenticated Account navigation, public and authenticated deletion entry points, validated support requests, provider-aware reauthentication, non-blocking subscription disclosures, Spark-compatible erasure, current-device cleanup, partial-failure retry, verified support/admin processing, minimal-record retention and purge, trusted Adapty cleanup, and completion behavior.

### Modified Capabilities

None. The existing informational Privacy & Safety page is implementation content rather than an archived OpenSpec capability; its copy changes as part of the new `account-management` capability.

## Impact

- `plantcare_domain`: Account-deletion contracts, entities, typed failures, provider methods, platform capabilities, configuration, and external-destination abstractions.
- `plantcare_data`: Firebase Auth reauthentication/deletion, deterministic create-only provider-cleanup request recording, bounded Firestore erasure, Google reauthentication adapters, account-scoped local cleanup reuse, and optional Android-only subscription-warning enrichment.
- `plantcare_features`: Account and Privacy and data pages, `AccountDeletionBloc`, public deletion UI, support mailto state, disclosures, confirmation, progress, retry, and accessible responsive states.
- `plantcare_app`: Public and protected routing, fourth shell destination, configuration, Firebase Hosting deep-link behavior, dependency injection, and post-deletion signed-out navigation.
- `firestore.rules` and emulator tests: owner-only reminder deletion; authenticated owner-only creation of the exact cleanup-request document; client denial of cleanup-request reads, updates, and deletes; and client denial for admin-managed deletion-support records.
- Admin tooling/docs: pending cleanup-request processing, verified support deletion procedure, minimal completion-record handling, dry-run-by-default purge, and trusted Adapty server-authorized cleanup without committed secrets.
- Documentation: README, Privacy & Safety, Google Play release checklist, Hosting instructions, subscription documentation, and account-deletion support procedure.
- No Cloud Functions, paid backend, Firebase Storage, client-side provider secret, automatic subscription cancellation, deployment, production mutation, or unrelated feature work is introduced.
