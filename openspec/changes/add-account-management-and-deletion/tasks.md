## 1. Domain Contracts and Configuration

- [x] 1.1 Add account-deletion entities, linked reauthentication methods, workflow stages, typed failures, platform capabilities, and `AccountDeletionRepository` exports in `plantcare_domain`; test equality, provider sets, retry categories, and identity-change outcomes.
- [x] 1.2 Add domain abstractions for account legal/subscription destinations and support requests without importing URL launcher, Firebase, Adapty, SharedPreferences, or notification plugins into features.
- [x] 1.3 Add validated account configuration for existing Privacy Policy and Terms HTTPS URLs plus `ACCOUNT_DELETION_SUPPORT_EMAIL`; test valid single mailbox values and rejection of missing, malformed, control-character, multi-recipient, and query-injection values.
- [x] 1.4 Define the fixed support mailto subject and approved suggested body in application-owned structured configuration; test URI encoding and verify no credential or account-existence language is introduced.
- [x] 1.5 Add a domain provider-cleanup request recorder, source enum, exact request value object, and typed recording failures; keep authenticated UID derivation in the data implementation and provider secrets out of the contract.

## 2. Firebase Authentication and Reauthentication

- [x] 2.1 Add an injectable Firebase Auth facade for current-user/provider inspection, server-backed session refresh, password reauthentication, Google reauthentication, and current-user deletion.
- [x] 2.2 Reuse the current native Google identity boundary on Android/iOS and add Firebase popup-based Google reauthentication on web; never request or expose a Google password or move provider tokens through UI/BLoC state.
- [x] 2.3 Implement `FirebaseAccountDeletionRepository` so every privileged stage derives and revalidates the current Firebase UID; test password-only, Google-only, linked providers, cancellation, wrong credentials, provider mismatch, `requires-recent-login`, popup cancellation/blocking, network failure, and UID change.
- [x] 2.4 Add safe Firebase error mapping and logging tests proving passwords, tokens, Firebase configuration, private documents, images, prompts, and raw provider errors are not logged.
- [x] 2.5 Implement the authenticated create-only recorder for `accountDeletionCleanupRequests/{uid}` with `schemaVersion: 1`, a server timestamp, exactly `providerCleanup: ["adapty"]`, and platform-derived `self_service_mobile` or `self_service_web`; reject or omit every unapproved field.
- [x] 2.6 Test acknowledged creation, network/permission failures, UID changes, exact mobile/web source mapping, no client read/update/delete operation, and conservative repeated-create handling without claiming an unconfirmed request is queued.

## 3. Remote Data Deletion Engine

- [x] 3.1 Add an internal Firestore account-deletion gateway using server-source reads, document-ID pagination, and conservative sub-500-write batches; test page exhaustion, commit acknowledgement, and query/commit failure without live Firebase.
- [x] 3.2 Centralize the known user-owned path manifest and implement child-first deletion for diagnoses, observations, soil checks, care logs, fertilizer assessments, reminders, and plants.
- [x] 3.3 Add final server-backed empty verification for every known user path and prove no curated knowledge collection is queried for deletion or mutated.
- [x] 3.4 Make deletion idempotent across empty accounts, missing documents, more-than-one-page/batch accounts, failure after intermediate commits, and complete reruns.
- [x] 3.5 Add tests proving another UID is untouched, a caller cannot choose a UID, nested diagnoses precede observations, descendants precede plants, and neither Firestore application-data deletion nor Firebase Auth deletion is called before acknowledged provider-cleanup request creation.
- [x] 3.6 Document the audit result that no Firestore user-profile document or persisted local-image reference currently exists, and add a repository checklist requiring future user-owned stores to update the manifest and tests.

## 4. Current-Device Cleanup

- [x] 4.1 Reuse and test `LocalPlantImageRepository.deleteAllForUser` for native UID directories and web session memory, including already-missing storage and cross-user isolation.
- [x] 4.2 Update notification cleanup so UID-scoped SharedPreferences metadata is removed even when scheduling is unsupported; cancel every locally known pending notification where supported and test idempotent retry.
- [x] 4.3 Audit application-owned caches and lifecycle state, add only the account-scoped cleanup boundaries actually required, and test that unrelated device files and another account's state remain untouched.
- [x] 4.4 Verify local cleanup runs after remote verification and before Firebase Auth deletion; preserve Auth and expose retry on required cleanup failure.

## 5. Subscription and Adapty Behavior

- [x] 5.1 Keep Adapty activation and profile calls Android-only; add platform tests proving no Adapty initialization or lookup occurs on web or iOS.
- [x] 5.2 Add an optional bounded Android Premium-status lookup used only to tailor warning copy; test active, inactive, unknown, failure, timeout, unavailable profile, and missing configuration.
- [x] 5.3 Ensure every Adapty failure/unknown outcome falls back to a generic warning and never blocks confirmation, reauthentication, remote deletion, local cleanup, or Auth deletion.
- [x] 5.4 Expose and validate the fixed Google Play subscriptions URL on all deletion surfaces; test launch failure remains non-blocking and cancellation proof is never requested.
- [x] 5.5 Ensure ordinary Android Adapty logout/identity reset is never named profile deletion and its failure does not change PlantCare deletion completion.

## 6. AccountDeletionBloc

- [x] 6.1 Add `AccountDeletionBlocFactory`, events, immutable states, and a singular state machine for explanation, acknowledgement, exact confirmation, provider selection, reauthentication, cleanup-request recording, remote deletion, local cleanup, Auth deletion, retry, and completion.
- [x] 6.2 Require exact case-sensitive `DELETE` plus subscription-warning acknowledgement before reauthentication; test all near matches, whitespace, casing, and missing acknowledgement.
- [x] 6.3 Implement provider-aware password and Google flows with neutral cancellation and retry; assert no destructive dependency is called before successful recent authentication.
- [x] 6.4 Implement the ordered sequence as reauthentication, acknowledged cleanup-request recording, remote deletion/verification, current-device cleanup, and Firebase Auth deletion; test every failure boundary, identity change, partial completion, recent-login retry, and idempotent resume.
- [x] 6.5 Prevent duplicate submissions and stale asynchronous results; test rapid repeated events and account/session changes.
- [x] 6.6 Emit honest partial-failure and completion states; never claim completion until Auth deletion succeeds and the auth session becomes unauthenticated.
- [x] 6.7 On cleanup-request failure or an unconfirmed repeat, stop before destructive deletion, avoid queued/completed Adapty wording, and expose both retry and the configured support-email fallback; test missing support configuration as a separate visible state.

## 7. Public Account-Deletion Page

- [x] 7.1 Add public `AppRoutes.accountDeletion` at `/account-deletion` outside the protected shell and authentication redirect; preserve the route across sign-in/session changes.
- [x] 7.2 Build a responsive, accessible page that prominently identifies PlantCare AI and supports signed-out, authenticated, support-request, invalid support configuration, loading, offline, partial failure, and complete states.
- [x] 7.3 Reuse existing email/password and Google sign-in behavior within the public route, then provide the same `AccountDeletionBloc` destructive workflow as mobile.
- [x] 7.4 Add the configured support mailto option with fixed subject/body, neutral ownership language, prompt-acknowledgement expectation, and explicit warning never to send credentials or payment details.
- [x] 7.5 Display exact deleted-data, 30-day verified-processing, 90-day minimal-record, unverified-correspondence, provider-retention, subscription, and inaccessible-device disclosures.
- [x] 7.6 Add Privacy Policy and Terms links with visible missing/invalid/launch errors.
- [x] 7.7 Add router/widget tests for signed-out access, direct navigation and refresh, auth-guard exclusion, staying on route after sign-in, Google/email authentication, missing support email, neutral messaging, narrow/wide/large-text layouts, and semantics.
- [x] 7.8 Verify web creates a `self_service_web` cleanup request through Firestore but makes zero Adapty SDK calls and does not require app download or reinstallation.
- [x] 7.9 Add authenticated-web UI tests for cleanup-request recording progress, failure, retry, support fallback, and transition to destructive deletion only after acknowledged creation.

## 8. Authenticated Account and Mobile UI

- [x] 8.1 Add protected Account as the fourth navigation destination on narrow and wide shells while preserving indices 0-2 and existing top-bar actions.
- [x] 8.2 Build `Account -> Privacy and data -> Delete account and data`, with Privacy Policy and Terms also available from Privacy and data.
- [x] 8.3 Add permanent-deletion explanation, exact data list, subscription warning/acknowledgement, Google Play management action, and exact `DELETE` gate using destructive styling and accessible labels.
- [x] 8.4 Add email/password, Google, and linked-provider reauthentication UI without displaying Google-password input; keep password visibility, controllers, and focus as ephemeral widget state.
- [x] 8.5 Add reauthentication progress, deletion progress, duplicate-action disabling, interruption warning, network failure, honest partial failure, retry, and accessible completion announcements.
- [x] 8.6 Add mobile widget/golden coverage for narrow, wide, large-text, keyboard, focus, cancellation, wrong credentials, active/unknown Premium warnings, Adapty failure, and every BLoC phase.
- [x] 8.7 Add mobile cleanup-request recording progress and failure UI with retry and configured support-email fallback; verify it never describes an unacknowledged write as queued Adapty cleanup.

## 9. Routing, Dependency Injection, and Completion

- [x] 9.1 Register protected Account/Privacy and data routes and public `/account-deletion`; update protected-destination validation without treating the public route as a sign-in redirect target.
- [x] 9.2 Add fixed deletion-complete signed-out navigation only after auth state becomes unauthenticated; reject arbitrary notice text and never automatically invoke Google sign-in.
- [x] 9.3 Wire repositories, Firebase facades, platform adapters, configuration, launchers, local cleanup services, and BLoC factories through app-owned GetIt/Injectable composition.
- [x] 9.4 Run `melos run generate`, review generated diffs, and ensure only expected data, features, and app registrations change.
- [x] 9.5 Extend boundary tests so account widgets/BLoCs cannot import Firebase, Adapty, URL launcher, SharedPreferences, notification plugins, another package's `lib/src`, or test code.

## 10. Firestore Security Rules

- [x] 10.1 Change reminder deletion from unconditional denial to authenticated-owner deletion while the parent plant exists, without changing reminder create/update transitions.
- [x] 10.2 Add exact Rules for `accountDeletionCleanupRequests/{uid}`: only the matching authenticated UID may create; keys and values must exactly match schema version 1, `requestedAt == request.time`, `["adapty"]`, and the source enum; all client get/list/update/delete operations are denied.
- [x] 10.3 Add an explicit client-denied top-level admin completion/support-record collection used by the admin tool; retain fallback denial and never allow a client to create or inspect those records.
- [x] 10.4 Add emulator tests for exact owner cleanup-request creation; unauthenticated, cross-user, wrong-ID, extra/missing-field, wrong-timestamp, wrong-provider, and wrong-source denial; repeated update denial; read/list/delete denial; owner reminder deletion; child-first descendant deletion; curated-knowledge denial; and completion/support-record denial.

## 11. Support Records, Purge, and Adapty Admin Procedure

- [x] 11.1 Define the admin-only minimal support-record schema: opaque request ID, UID or minimally necessary verified-email reference, verification status, request date, optional completion date, and completion/failure status; reject plant content, images, diagnoses, AI output, care history, subscription details, credentials, tokens, and raw Firestore data.
- [x] 11.2 Add a repository-owned admin purge command that uses operator-supplied Application Default Credentials or an equivalent trusted environment, validates exact schema/cutoffs, defaults to dry-run, and requires an explicit apply flag.
- [x] 11.3 Test purge boundary dates, completed-record 90-day eligibility, malformed/incomplete/new record preservation, idempotent reruns, safe output, and refusal to run against an unconfirmed project/environment.
- [x] 11.4 Document prompt acknowledgement, neutral ownership verification, the 30-calendar-day clock starting at successful verification, verified Firebase deletion, completion/failure recording, and escalation.
- [x] 11.5 Document deletion of unverifiable support correspondence no later than 30 days after the last verification attempt, including mailbox trash/retention verification and allowance for a future new request.
- [x] 11.6 Extend the trusted admin tool to enumerate pending `accountDeletionCleanupRequests`, call the Adapty server-side deletion API for the UID, record only minimal completion/failure status, and delete the pending request only after recording the outcome; supply secrets only from the operator environment and never print them.
- [x] 11.7 Test pending-request processing success, Adapty not-found idempotency, provider/API failure preservation, minimal audit contents, audit-write failure preserving the pending request, pending-delete retry, malformed request quarantine, and safe logs with mocked provider/Firebase boundaries only.
- [x] 11.8 Add 30-day age monitoring and operational escalation for pending cleanup requests; verify Firebase account/application deletion never waits for provider API completion after acknowledged handoff creation.
- [x] 11.9 Document that SDK logout is identity reset rather than profile deletion and that only the trusted server-authorized operation satisfies the pending provider cleanup.

## 12. Privacy, Release, and Operations Documentation

- [x] 12.1 Replace obsolete Privacy & Safety account-limit copy with the approved deletion scope, 30-day processing, 90-day minimal-record retention, unverified 30-day correspondence limit, local-device limitation, subscription separation, and provider-controlled retention.
- [x] 12.2 Update README configuration with `ACCOUNT_DELETION_SUPPORT_EMAIL`, Privacy Policy/Terms requirements, no-secret examples, public route behavior, Firebase Hosting deep-link verification, and Spark limitations.
- [x] 12.3 Update the Google Play release checklist with `https://plantcare-ai-dev-tasnimalam.web.app/account-deletion`, but do not claim it works until a release web build and local Hosting verification succeed.
- [x] 12.4 Update subscription documentation to state cancellation is recommended but not required and account deletion never depends on Adapty availability.
- [x] 12.5 Add the full account-deletion support runbook, retention/purge cadence, named-operator placeholders, evidence checklist, provider-record distinction, and commands awaiting separate production approval.
- [x] 12.6 Document the self-service-to-admin cleanup handoff, exact pending schema, create-only client permissions, conservative repeat behavior, 30-day pending deadline, admin outcome/audit order, and support fallback.
- [x] 12.7 Update AGENTS.md only with durable architecture/security/retention rules that future milestones must preserve; avoid copying transient task steps.

## 13. Automated Verification

- [x] 13.1 Run `dart pub get`, `melos run generate`, `melos run format`, `melos run analyze`, `melos run boundaries`, and `melos run test`; record actual results.
- [x] 13.2 Run applicable Firestore Rules emulator tests plus admin pending-request and purge-tool tests without live Firebase, Adapty, Google Play, production data, or real users.
- [x] 13.3 Run `flutter build web --release`, `flutter build apk --debug`, and `git diff --check`; record exact blockers for any check that cannot run.
- [x] 13.4 Start the Firebase Auth, Firestore, and Hosting emulators with an explicit non-production project and prepare purpose-created fixture accounts/data; verify runtime logs and configuration show no production Firebase endpoint or project mutation.
- [x] 13.5 Build and run manual-verification targets with Firebase emulator mode enabled and App Check disabled. Omit App Check configuration and `USE_APP_CHECK_DEBUG`, or explicitly set `USE_APP_CHECK_DEBUG=false`; never request, capture, store, or use an App Check debug token.

## 14. Local Manual Verification

- [x] 14.1 After implementation and automated checks pass, hand the approved artifacts and runnable builds to a fresh-context verification agent using Marionette MCP; the implementation agent must not substitute its own prior assumptions for this independent pass.
- [x] 14.2 In Chrome against the local Hosting/Auth/Firestore emulators, verify `/account-deletion` loads and refreshes while signed out, remains on-route after sign-in, and is never redirected to Sign in.
- [x] 14.3 In Chrome, verify web performs no Adapty SDK request, shows the generic subscription warning, supports emulator-safe Google/email authentication boundaries, records the `self_service_web` cleanup handoff, and uses only fake/emulator accounts.
- [x] 14.4 In an Android emulator against Firebase emulators, verify Account is the fourth destination and `Privacy and data -> Delete account and data` requires warning acknowledgement, exact `DELETE`, recent provider authentication, and an acknowledged `self_service_mobile` cleanup handoff; Premium lookup failure remains non-blocking.
- [x] 14.5 On both surfaces, verify cleanup-request failure blocks destructive work and exposes retry/support, then verify child-first deletion, partial failure/retry, Auth-last behavior, local notification/image cleanup where applicable, and no cross-user or curated-knowledge mutation using fakes/emulators only.
- [x] 14.6 On both surfaces, verify configured and missing support-email states, encoded mailto content, Privacy Policy/Terms links, and all approved processing/retention disclosures.
- [x] 14.7 Verify purge dry-run and explicit apply behavior against non-production fixtures only; do not process a real support request.
- [ ] 14.8 Capture redacted screenshots from Chrome and the Android emulator for the signed-out public page, Account/Privacy and data navigation, subscription warning and exact confirmation gate, cleanup-request recording or its observable emulator evidence, cleanup-request failure/support fallback, deletion progress or partial failure, and signed-out completion.
- [x] 14.9 Save screenshots, relevant emulator/browser logs, commands, build inputs, and a scenario-to-evidence verification report under `artifacts/account-deletion/verification-<timestamp>/`; redact emails, UIDs, tokens, credentials, Firebase configuration, private plant content, and other user data.
- [x] 14.10 Confirm from runtime/network evidence that verification contacted no production Firebase service, live Adapty API/SDK surface on web, or real Google Play purchase endpoint. If Marionette MCP, Android emulator, Chrome, Firebase emulators, or screenshot capture is unavailable, record the exact blocker and leave the scenario unverified rather than fabricating proof.

## 15. Completion Report and Production Hold

- [x] 15.1 Report exact mobile/web behavior, deleted data, retained records and reasons, processing/retention periods, reauthentication, subscription behavior, Adapty limitation, Rules changes, tests/builds, manual checks, and known limitations.
- [x] 15.2 Link the timestamped verification report and screenshot evidence directory, list every unverified scenario and blocker, and distinguish automated results from fresh-context Marionette observations.
- [x] 15.3 List exact build, preview, Hosting deployment, Rules deployment, Play Console, support-mailbox, and admin-purge commands that still require owner approval.
- [x] 15.4 Do not deploy, modify production, process a real user, expose credentials, push, or claim successful verification that was not actually performed.
