## 1. Subscription Contracts and Configuration

- [x] 1.1 Add immutable premium-access, localized-offer, platform-support, paywall-preparation, presentation-event, purchase, restore, and failure models plus subscription and external-destination contracts to `plantcare_domain`; verify focused domain unit tests cover equality and access-state transitions.
- [x] 1.2 Extend application compile-time configuration with `ADAPTY_PUBLIC_SDK_KEY`, `PRIVACY_POLICY_URL`, and `TERMS_OF_SERVICE_URL`, validate legal destinations as HTTPS, and reject missing values without placeholders; verify environment characterization tests cover configured, missing, and invalid inputs.
- [x] 1.3 Add the compatible Adapty Flutter v4 dependency only to the package that owns the SDK integration, resolve workspace packages, and verify the resolved SDK APIs and native minimum versions match Flutter 3.47.1, Dart 3.13.1, Android, and the existing iOS 15 target.

## 2. Adapty and Platform Integration

- [x] 2.1 Create narrow injectable facades around Adapty/AdaptyUI and external URL launching so static plugin APIs are isolated; verify source and boundary tests show Adapty imports only in `plantcare_data` and no premium widget imports SDK or repository libraries.
- [x] 2.2 Implement Android-only, non-fatal subscription initialization with AdaptyUI enabled, optional UID-at-activation, serialized Firebase auth identification/logout, readiness awaiting, and stale identity-generation rejection; verify data and application lifecycle tests prove activation precedes identify and all profile/Flow/product operations.
- [x] 2.3 Implement `main_paywall` Flow retrieval, view-configuration validation, store product retrieval, and cached Flow/product ownership scoped to the identified UID; verify tests distinguish paywall unavailable from product unavailable and prevent operations before identity readiness.
- [x] 2.4 Validate the `plantcare_premium` monthly base plan, absence of a selected trial/introductory offer, and presence of store-localized price and billing-period metadata without synthesizing values; verify mapping tests cover valid, wrong-product, wrong-base-plan, offered/trial, missing-price, and missing-period products.
- [x] 2.5 Implement fresh single-use native Flow presentation and map SDK events for purchase start, pending, neutral cancellation, failure, dismissal, restore, and profile updates to application-owned events; verify facade tests cover each event and prove a dismissed view is never reused.
- [x] 2.6 Implement `premium` access verification from returned/current profiles, including fallback profile lookup after an unverified success result and monotonic preservation after later refresh or dismissal failure; verify tests cover active, inactive, refresh-failure, newer-expired-profile, and UID-change cases.
- [x] 2.7 Implement Android Restore Purchases and Google Play management launching with a product-specific URL when product context exists and the general subscriptions-center fallback otherwise; verify tests cover restored premium, no active purchase, recoverable restore failure, exact encoded management destinations, and launch failure.
- [x] 2.8 Implement Privacy Policy and Terms launch actions through the injected HTTPS launcher and unsupported iOS/web purchase boundaries; verify tests prove legal launch failures are recoverable and non-Android paths never invoke Adapty purchase or restore APIs.

## 3. Subscription BLoCs

- [x] 3.1 Add an application-scoped `PremiumAccessBloc` that follows authenticated identity and verified profile updates while preserving verified access across non-authoritative failures; verify BLoC tests cover checking, inactive, active, warning, expiration, sign-out, and account-switch states.
- [x] 3.2 Add a route-scoped `PaywallBloc` and factory for load, retry, present, restore, manage, privacy, and terms events; verify BLoC tests cover loading, ready, paywall unavailable, product unavailable, purchasing, pending, neutral cancellation, verified success, no-restore, recoverable failure, duplicate-action suppression, and retry.
- [x] 3.3 Wire subscription contracts, implementations, lifecycle ownership, and both BLoCs through the existing micro-package and application GetIt/injectable graph; run generation and verify DI tests resolve the same subscription instance without direct service-location from widgets.

## 4. Premium Route and Responsive UI

- [x] 4.1 Add `AppRoutes.premium`, include it in validated protected destinations, and compose the authenticated `/premium` route with its BLoCs; verify navigation tests cover signed-out redirect/preserved return, signed-in rendering, and rejection of external redirect variants.
- [x] 4.2 Add an accessible Upgrade to Premium entry and Premium shell title without changing the existing three narrow/wide navigation destinations; verify shell and navigation widget tests cover the entry, tooltip/semantics, title, and existing selected-index behavior.
- [x] 4.3 Correct the responsive Premium page so Free and Premium differ only by the saved-plant allowance; remove claims that AI, guidance, reminders, diagnosis, knowledge, or history require Premium, and verify widget tests assert the accurate labels.
- [x] 4.4 Render Android loading, ready localized price/period, native Flow launch, purchase/restore progress, pending, verified activation, paywall unavailable, product unavailable, recoverable failure, and retry states; verify widget tests assert control enablement, progress semantics, neutral cancellation, success preservation, and no duplicate actions.
- [x] 4.5 Render iOS and web variants with no enabled purchase or restore action, including explicit web text that mobile purchasing is not currently available; verify platform-injected widget tests cover Android, iOS, and web without depending on the host test platform.
- [x] 4.6 Add Manage Subscription, Privacy Policy, and Terms controls that dispatch BLoC events only; verify widget tests cover enabled/disabled configuration, semantic labels, and recoverable launch messages.
- [x] 4.7 Verify the Premium page at narrow Android width, wide web width, keyboard traversal, and increased text scaling with no overflow; add responsive/accessibility widget tests for scrollability, focus order, meaningful semantics, and disabled-action descriptions.
- [x] 4.8 Audit all Flutter-owned premium strings for prices and trial/introductory wording, removing any hardcoded monetary value or offer claim; verify focused widget assertions and a repository search find no `CA$1.50` or trial/intro copy in production premium UI.

## 5. Documentation and Manual Google Play Validation

- [x] 5.1 Update documentation for the enforced three-plant Free allowance, unlimited verified-Premium allowance, fail-open subscription behavior, unchanged AI/care availability, existing over-limit accounts, and web/iOS behavior; verify no SDK secret or fabricated URL/value is added.
- [x] 5.2 Document a Google Play license-tester/internal-testing procedure covering signed build installation from Play, Firebase sign-in/UID identity, localized monthly price and period, absence of trial/introductory wording, cancellation, pending purchase where test instruments permit, successful profile-verified activation, restore after reinstall/account continuity, subscription management, legal links, offline/retry behavior, and account switching; explicitly require recording whether a real Play transaction was actually completed.
- [x] 5.3 Verify the published Adapty `main_paywall` Flow is enabled for device display and configured with the specified Android product/base plan, no offer or trial text, restore behavior, and approved legal destinations; record any dashboard item that cannot be inspected as a manual release blocker rather than claiming verification.

## 6. Workspace Verification

- [x] 6.1 Run `melos run generate`, review generated diffs for expected subscription wiring only, and verify no generated file was edited manually.
- [x] 6.2 Run `melos run format` and `melos run analyze`; fix in-scope failures and record exact outcomes.
- [x] 6.3 Run `melos run boundaries` and verify package dependency/import rules pass with Adapty confined to its integration layer.
- [x] 6.4 Run `melos run test` and verify all domain, data, feature, application, navigation, and platform-boundary suites pass without live Firebase, Adapty, or Google Play dependencies.
- [x] 6.5 Run `melos run build:web` without purchase credentials and verify the release web build succeeds with the unsupported-purchasing experience.
- [x] 6.6 Run `flutter build apk --debug` from `apps/plantcare_app` and verify the Android debug artifact builds successfully; report the artifact path and do not claim a real Google Play purchase from this build.
- [x] 6.7 Review `git diff` and `git status` to confirm there are no Firestore Rules, backend, unrelated feature-gating, deployment, or push changes; report all changed files, checks, limitations, missing external configuration, and the truthful manual-purchase status.

## 7. Saved-Plant Capability and Creation Guards

- [x] 7.1 Add an extensible pure-Dart capability policy whose only restricted capability is creating another saved plant: verified Premium is unlimited, all other subscription states retain the Free allowance of three, and the denial uses the exact approved message; verify Free/Premium counts, unknown state, warnings, and existing over-limit accounts in domain tests.
- [x] 7.2 Apply the policy to manual and photo creation entry points, including direct `/plants/new` and `/plants/new/manual` navigation, while keeping existing plant routes and AI/care workflows available; verify route/widget tests block only creation and show the explanation before photo selection.
- [x] 7.3 Re-evaluate the latest count and current entitlement in the final plant-save BLoC path so stale screens cannot save a fourth Free plant; verify BLoC tests cover stale-count rejection, Premium submission, and no repository write on denial.
- [x] 7.4 Preserve manual-versus-photo creation intent when opening `/premium` from a limit prompt and return only after `PremiumAccessBloc` receives verified active access; verify success resumes the intended flow while pending, cancellation, failure, and unverified results remain blocked.
- [x] 7.5 Add regression tests proving Free and existing over-limit users retain AI identification/observations/diagnosis, knowledge retrieval, soil/fertilizer guidance, diagnosis/care history, care logs, reminders, editing, and deletion without Premium authorization checks.

## 8. Corrected Workspace Verification

- [x] 8.1 Run `melos run generate`, review generated diffs, and verify only expected capability-policy and creation-flow wiring is added.
- [x] 8.2 Run `melos run format`, `melos run analyze`, and `melos run boundaries`; fix in-scope failures and confirm subscription/feature boundaries remain valid.
- [x] 8.3 Run `melos run test` and verify all domain, data, feature, application, navigation, platform-boundary, and unrestricted-Free regression suites pass without live services.
- [x] 8.4 Run `melos run build:web` and `flutter build apk --debug`; report exact outcomes and artifact path without claiming a transaction.
- [x] 8.5 Run `git diff --check`, audit premium/capability references and changed paths, and confirm there are no Firestore Rules, backend, deployment, publishing, pushing, real transactions, deletion/hiding of existing plants, or unrelated feature gates.
