# Account-deletion completion verification

Date: 2026-09-18
Change: `add-account-management-and-deletion`
Scope: source tests, widget/golden tests, Firebase emulators, local builds, and existing fresh-context runtime evidence only

## Outcome

The change is at 92/93 tasks. Eleven tasks that were open at the start of this pass now have direct executable evidence. Task 14.8 remains open because the Mac UI was locked when Chrome/Android controlled fault-state capture was attempted. No screenshot, Google-provider result, deployment, production mutation, real-user operation, or provider deletion is claimed without evidence.

## New direct evidence

- Domain account-deletion values, provider sets, retry categories, identity-change outcomes, support validation, and encoded mailto tests pass.
- `FirebaseAccountDeletionRepository` tests cover password-only, Google-only, linked providers, cancellation, invalid credentials, provider mismatch, recent-login, popup blocked, network failure, UID changes, cleanup-handoff acknowledgement/failure/repeat behavior, Firestore-before-Auth failure, and Auth-after-Firestore failure.
- Logging tests inject passwords, access/ID tokens, email content, plant content, image data and paths, Firebase configuration, Adapty secrets, and prompt content; none appears in captured diagnostics.
- The Firestore deletion gateway test driver proves multiple two-document pages, sub-500 acknowledged commits, diagnoses-before-observations, descendants-before-plants, empty/missing accounts, interrupted commit plus retry, full rerun, query/verification failures, other-UID preservation, and curated-knowledge preservation.
- Fourteen public/mobile UI tests cover signed-out support, missing support configuration, visible selectable support address, narrow/wide/large-text layouts, keyboard focus, exact case-sensitive `DELETE`, destructive semantics, active/unknown Premium warnings, Adapty failure fallback, Google cancellation, wrong password, web/mobile cleanup-handoff failure, retry/support, every destructive progress stage, remote/Auth partial failures, Auth-last, local image/notification cleanup calls, and completion.
- Router tests prove `/account-deletion` is public, remains open after authentication, and preserves the deletion return path.
- App Check tests prove debug activation is opt-in, release mode rejects the debug provider, production web requires a reCAPTCHA Enterprise key, production chooses the production activation mode, and emulator mode is refused for production.
- Web and iOS Premium boundary tests prove initialize, prepare, refresh, present, and restore paths make no Adapty SDK calls on unsupported platforms. The deletion BLoC skips Premium lookup outside Android.
- Admin-tool tests (14/14) prove dry-run default, exact project confirmation, refusal of production apply without `--allow-production`, safe aggregate output, 30-day pending monitoring, minimal completion records, Adapty not-found idempotency, pending preservation on provider/audit/delete failures, and 90-day expired-only purge eligibility.
- Firestore Rules tests pass 82/82, including exact create-only handoff and client-denied reads/updates/deletes.

## Repository and build checks

- `melos run generate` — passed; the data package emitted its known warning that app-owned configuration is supplied by final app composition.
- `melos run format` — passed, 390 files checked and none changed.
- `git diff --check` — passed.
- `melos run analyze` — passed, no issues.
- `melos run boundaries` — passed.
- `melos run test` — passed for shared, domain, data, features, and app packages.
- Firestore Rules — 82 tests passed against the local emulator.
- Admin tool — 14 tests passed.
- Production-mode `flutter build web --release` — passed with emulator/debug disabled and a non-secret verification placeholder for the required public reCAPTCHA site-key input.
- Emulator-mode `flutter build apk --debug` — passed with `USE_APP_CHECK_DEBUG=false`.

## Screenshot evidence

Existing fresh-context Chrome and Android screenshots remain at:

- `../verification-2026-09-17-fresh/`

They cover signed-out public navigation/refresh, Account and Privacy/data navigation, subscription warning, exact confirmation gate, reauthentication failure, and signed-out completion. The new deterministic widget golden is:

- `../../../packages/plantcare_features/test/features/account_management/goldens/public_account_deletion_narrow.png`

Missing required Chrome/Android screenshots for cleanup-handoff failure/support fallback and deletion-progress/partial-failure remain the sole unchecked OpenSpec task (14.8). Computer control returned: `The Mac is locked and automatic unlock could not unlock it.`

## Unresolved runtime blockers

- Android native Google reauthentication requires a purpose-created authorized non-production Google identity on the emulator. None was supplied; no real identity was used.
- Web Google provider UI was not re-run in this pass because Chrome computer control was blocked by the locked Mac. Provider cancellation/error/success boundaries are covered by injected tests, not claimed as new runtime proof.
- iOS was not run. No-Adapty behavior is proved at the injected platform boundary, not by packet capture on an iOS simulator/device.
- New controlled fault-state screenshots could not be captured while the Mac was locked. Two disposable local-emulator failure fixtures were prepared, but no destructive UI action was performed and no screenshot claim is made.

## Production configuration still required

- Assign the named support/retention operator and validate prompt acknowledgement, 30-day processing, mailbox deletion/trash behavior, and 90-day purge cadence.
- Configure and verify the real `ACCOUNT_DELETION_SUPPORT_EMAIL`, Privacy Policy URL, Terms URL, and production reCAPTCHA Enterprise site key.
- Verify Play Integrity and Apple App Attest-with-DeviceCheck production registration.
- Supply `ADAPTY_SECRET_API_KEY` only in the trusted operator environment and confirm the exact non-production project before any apply run.
- Create purpose-specific non-production Google test identities for Android and web provider reauthentication verification.
- Complete the missing Chrome/Android fault-state screenshot pass on an unlocked host.

## Deployment order awaiting separate approval

Do not run these commands without owner approval and finalized production values.

1. Build and inspect production artifacts:
   - `cd apps/plantcare_app && flutter build web --release --dart-define=APP_ENV=production --dart-define=USE_FIREBASE_EMULATOR=false --dart-define=USE_APP_CHECK_DEBUG=false --dart-define=APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY=<public-site-key> --dart-define=ACCOUNT_DELETION_SUPPORT_EMAIL=<mailbox> --dart-define=PRIVACY_POLICY_URL=<https-url> --dart-define=TERMS_OF_SERVICE_URL=<https-url>`
   - `cd apps/plantcare_app && flutter build appbundle --release --dart-define=APP_ENV=production --dart-define=USE_FIREBASE_EMULATOR=false --dart-define=USE_APP_CHECK_DEBUG=false --dart-define=ACCOUNT_DELETION_SUPPORT_EMAIL=<mailbox> --dart-define=PRIVACY_POLICY_URL=<https-url> --dart-define=TERMS_OF_SERVICE_URL=<https-url>`
2. Dry-run the trusted pending monitor and purge against the exactly confirmed production project; do not use `--apply`:
   - `node tools/account_deletion_admin/src/cli.mjs process-pending --project=<project> --confirm-project=<project>`
   - `node tools/account_deletion_admin/src/cli.mjs purge --project=<project> --confirm-project=<project>`
3. Deploy Firestore Rules before releasing either client surface:
   - `firebase deploy --only firestore:rules --project <project>`
4. Deploy Firebase Hosting and verify the public deep link while signed out:
   - `firebase deploy --only hosting --project <project>`
5. Publish the verified account-deletion URL and disclosures in Google Play Console, then submit the reviewed Android App Bundle.
6. Only after operator approval, use explicit `--apply --allow-production` for a trusted admin processing or purge run. Never process a real request as a deployment smoke test.

No deployment, production write, real-user processing, archive, push, or live Adapty deletion occurred.
