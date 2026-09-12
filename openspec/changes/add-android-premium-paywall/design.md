## Context

See `proposal.md` for motivation and `specs/premium-subscriptions/spec.md` for behavior. The repository currently has no Adapty dependency or subscription code; the `adapty_subscription` branch was created from `main` without additional commits. Firebase and App Check initialize before application lifecycle services start, Firebase Auth is exposed through `AuthenticationSession`, feature UI uses BLoC, application composition owns routing and final GetIt wiring, and platform implementations belong in `plantcare_data`.

The app currently targets Flutter 3.47.1/Dart 3.13.1 and iOS 15, which satisfies Adapty Flutter SDK 4 requirements. The Android package is `com.tasnimalam.plantcare_ai`. No real Adapty public SDK key, Privacy Policy URL, or Terms URL is present in the repository. These values must therefore be supplied through non-secret build-time configuration, and missing configuration must produce an unavailable state rather than invented values or a crash.

## Goals / Non-Goals

**Goals:**

- Keep all Adapty types and static SDK access behind testable data-layer boundaries.
- Serialize SDK activation, Firebase UID identification/logout, Flow retrieval, product retrieval, profile refresh, purchase, and restore operations.
- Maintain an application-owned premium snapshot that can survive navigation and non-authoritative refresh failures.
- Render the remotely configured Adapty Flow on Android while giving the Flutter route enough state to explain loading, unavailability, pending purchase, cancellation, verified activation, and retry behavior.
- Keep the free application and every existing AI/care workflow usable if subscription configuration or Adapty is unavailable.
- Centralize an extensible capability policy whose only enabled Premium distinction is unlimited saved plants.
- Re-check current count and entitlement at every plant save boundary while preserving the intended creation flow through an upgrade.

**Non-Goals:**

- Gating AI identification, observations, diagnosis, knowledge retrieval, guidance, history, care logs, or reminders.
- Persisting entitlement state in Firestore or treating a client cache as proof of access.
- Adding server notifications, receipt processing, web checkout, iOS purchasing, trials, introductory offers, or additional plans.
- Editing the remote Adapty Flow or Google Play catalog from application code.

## Decisions

### Use Adapty Flutter SDK v4 and the native Flow Builder presentation

The data package will integrate the compatible stable Adapty Flutter v4 SDK. It will fetch the Flow by placement `main_paywall`, require a device view configuration, retrieve products for that Flow, and create a fresh single-use Flow view each time presentation is requested. The remote Flow remains responsible for the actual Google Play purchase UI and its localized rendering.

The adapter will validate that an eligible returned Android product matches subscription product `plantcare_premium`, base plan `monthly`, has no selected offer/trial phase, and exposes usable localized price and monthly-period metadata. Application-owned `PremiumOffer` contains only the store-localized display strings and identifiers needed for state and management navigation. It never synthesizes a price.

Alternative considered: implement a complete custom Flutter paywall and call `makePurchase`. This would make every visual state directly testable but would not use the configured Flow Builder experience and would duplicate remotely managed purchase UI.

### Treat remote configuration as an operational prerequisite

Application code cannot guarantee that remotely authored Flow text contains no trial claim. Runtime product validation will reject an unexpected offer, Flutter-owned strings will contain no trial or introductory-offer wording, and the manual release checklist will require verifying the published `main_paywall` Flow, Google Play base plan, localized price/period, legal actions, and absence of trial copy on a license-tester build.

Alternative considered: ignore remote offer metadata because the requested catalog currently has no offer. Rejecting unexpected metadata is safer because it prevents a dashboard drift from silently violating the product promise.

### Add application-owned subscription contracts to the domain package

`plantcare_domain` will define immutable, Equatable application models and contracts for:

- platform purchasing support;
- initialization/identity readiness;
- premium access snapshots for the active UID;
- localized premium offer metadata;
- paywall preparation and presentation events;
- purchase, cancellation, pending, restore, and recoverable failure outcomes;
- external subscription-management and legal-destination launching.

No Adapty object crosses this boundary. The data implementation may retain the current Flow and products internally, tagged with the identified UID/generation, so stale cached objects cannot be used after an account change.

Alternative considered: expose Adapty profiles and products to feature BLoCs. That couples presentation to SDK versions, violates package ownership, and makes platform-boundary tests brittle.

### Make subscription startup non-fatal to the free app

The final application initializer will start the subscription service after Firebase, emulator configuration, and App Check. Android activation uses an `ADAPTY_PUBLIC_SDK_KEY` build-time value and enables AdaptyUI. When `AuthenticationSession.currentUser` is already available, its Firebase UID is supplied during activation; otherwise the adapter activates and then awaits a serialized `identify(uid)` after authentication.

Initialization failure is retained as a recoverable subscription status consumed by `/premium`; it does not fail the entire application bootstrap. The service subscribes to authentication changes, serializes identity work, calls Adapty logout after Firebase sign-out, and ensures a later sign-in cannot overtake that logout. Every profile/Flow/product/purchase/restore operation awaits readiness for the current UID and checks the identity generation before publishing results.

On iOS and web, the implementation reports purchasing as unsupported and does not activate or invoke Adapty purchase APIs.

Alternative considered: make Adapty activation a required bootstrap step. That would unnecessarily prevent free functionality from starting during an Adapty outage or when build configuration is absent.

### Separate durable entitlement state from route operation state

An application-scoped `PremiumAccessBloc` will subscribe to application-owned profile/access updates and represent checking, inactive, verified active, and refresh-warning states for the active Firebase UID. A route-scoped `PaywallBloc` will manage preparation, Flow presentation, purchase/restore progress, pending, neutral cancellation, unavailable states, external-link failures, and retries.

The verified-active snapshot is monotonic across failures: after a returned or current profile proves `premium` active, presentation dismissal, Flow reload, and profile refresh errors can add a warning but cannot downgrade access. Only a successful newer profile for the same UID reporting inactive access, sign-out, or UID change may clear it. A purchase-success callback without active access triggers one current-profile check; failure or inactive access does not unlock.

The app provides both BLoCs above the route as appropriate through generated DI/factories. Widgets read BLoC state and dispatch events only; they import neither Adapty nor subscription repository contracts.

Alternative considered: keep all state in the route-scoped paywall BLoC. That loses verified status when leaving the route and makes later feature gating harder to add safely.

### Keep capability policy deterministic and narrow

`plantcare_domain` will own a pure capability policy that accepts the latest saved-plant count and application-owned premium snapshot. Its only restricted capability in this milestone is creating another saved plant: active Premium is unlimited, while every non-active or unavailable state retains the Free allowance of three. The policy returns a structured decision and the exact user-facing explanation; it has no Flutter, repository, Firebase, or Adapty dependency and leaves room for future capabilities without marking any current AI or care feature as Premium-only.

Plant creation BLoCs and routing composition will consume this policy through existing streams/factories. Entry guards improve the experience, but the final persistence event always re-reads or observes the latest plant collection and re-evaluates the policy. This closes stale-count races without relying on Firestore Rules, which cannot validate an Adapty entitlement.

Existing over-limit accounts are never normalized or hidden. Read, edit, observe, diagnose, retrieve knowledge, apply deterministic guidance, view history, log care, schedule reminders, and delete behavior remains unchanged. Only another create is denied.

Alternative considered: enforce the count in Firestore Rules. Rules have no trusted Adapty profile and would either be bypassable or incorrectly deny valid Premium users, so enforcement remains an application-domain policy for this milestone.

### Preserve creation intent through Premium

Manual and photo creation use validated internal destinations carried through the existing `/premium` route. A plant-limit prompt navigates to Premium with the intended creation destination. The application returns only after `PremiumAccessBloc` receives profile-verified active access; a button result, cancellation, pending state, or recoverable error never resumes creation. Photo creation is checked before image selection so the message is explicitly about saving another plant, not access to AI.

Alternative considered: return immediately when the native Flow dismisses. Dismissal does not prove entitlement and would violate profile-based access verification.

### Use a Flutter route as the resilient shell around the native Flow

`/premium` will always render a responsive, scrollable comparison of the specified Free and Premium benefits. On Android it loads offer readiness and exposes an enabled “View Premium” action only when the Flow and validated product are ready; the action presents the native Flow. It also exposes Restore Purchases, Manage Subscription, Privacy Policy, and Terms actions as applicable.

The route owns Flutter loading/unavailable/pending/success/retry messaging, while the Flow owns its purchase controls. The localized price and monthly period from the selected store product are shown in the Flutter shell and by the remote Flow. Cancellation returns the shell to ready without an error snackbar. All in-progress actions disable conflicting controls and expose progress semantics.

Wide layouts constrain content and may place Free and Premium cards side by side; narrow and large-text layouts stack them in a scroll view. The existing bottom-navigation/rail destinations remain unchanged. A top-level application action or home call-to-action supplies the Upgrade entry, and the shell title recognizes `/premium`.

Alternative considered: add Premium as a fourth navigation destination. This would disturb the established three-destination narrow/wide navigation contract for a secondary account action.

### Launch management and legal destinations through injected boundaries

An injected launcher implementation will validate HTTPS destinations and use external-application launch mode. Android management uses the product-specific Google Play URL with the runtime product identifier and application package when available, falling back to `https://play.google.com/store/account/subscriptions` when product context is unavailable.

Privacy Policy and Terms use `PRIVACY_POLICY_URL` and `TERMS_OF_SERVICE_URL` build-time values. Missing or invalid values disable the corresponding action with an explanatory state. The Adapty public SDK key is a client public key, but it is still supplied as `ADAPTY_PUBLIC_SDK_KEY` instead of inventing or committing a value. No Adapty secret key is accepted by the client configuration.

Alternative considered: hardcode legal URLs or treat the existing Privacy & Safety page as the Privacy Policy. No legal destinations currently exist, and the informational page is not a substitute for an operator-approved legal policy.

### Verify with injected SDK and platform facades

Static Adapty and URL-launcher calls will be wrapped by narrow injected facades. Data tests will use fakes to prove call ordering, platform no-op behavior, product validation, identity-generation rejection, outcome mapping, and profile-based access checks without contacting Firebase, Adapty, or Google Play.

Feature tests will cover BLoC transitions and widget behavior for Android, iOS, web, narrow/wide layouts, text scaling, semantics, and all required states. Application tests will cover `/premium` authentication redirects, preserved destinations, shell entry/title behavior, DI, and startup ordering. Existing package-boundary checks will be extended if needed to prevent Adapty imports outside `plantcare_data`.

## Risks / Trade-offs

- [Remote Flow text or product assignment drifts from the no-trial monthly configuration] -> Validate returned product/base-plan/offer metadata where the SDK exposes it and make dashboard/device verification a release checklist gate.
- [A public key or legal URL is absent in automated builds] -> Compile and test with injectable configuration; show subscription/legal unavailability at runtime instead of breaking the free app or committing placeholders.
- [Auth changes race with Adapty profile operations] -> Serialize lifecycle commands, bind cached data and events to a UID generation, and ignore stale completions.
- [Google Play reports pending and activates later] -> Keep pending neutral, listen for profile updates, and activate only when an identified profile reports active `premium` access.
- [The native Flow view is single-use] -> Retain the Flow/products only as preparation data and create a new view for every presentation attempt.
- [A verified user is visually downgraded by a transient refresh error] -> Preserve the last verified snapshot and represent refresh failure separately as a warning.
- [Plant count changes after an entry guard] -> Re-evaluate the live plant count and current entitlement at final submission before writing.
- [Adapty status is unavailable] -> Fail open for all Free functionality and apply only the deterministic Free saved-plant allowance.
- [Existing Free account already exceeds the limit] -> Preserve all existing records and workflows; deny only another create.
- [Client-only entitlement is insufficient for future privileged operations] -> Do not use this foundation as backend authorization; any future server-controlled premium capability must verify access server-side in its own milestone.

## Migration Plan

1. Add domain contracts and fakes first so feature and data work can be tested independently.
2. Add Adapty/platform adapters, build-time configuration, and the non-fatal subscription lifecycle service.
3. Add global access and route paywall BLoCs, the `/premium` UI, routing, and application entry.
4. Add the pure saved-plant capability policy, creation-entry/final-submit guards, and verified-upgrade return routing without changing existing-feature authorization.
5. Generate DI, update documentation, and run the complete workspace checks plus web release and Android debug builds.
6. Configure a local/internal-testing build with the real public key and legal URLs, then manually verify the published Flow using a Google Play license tester.

Rollback consists of removing the Premium entry/route and subscription lifecycle registration, then removing the Adapty dependency and generated wiring. Firestore and backend rollback are unnecessary because this change persists no server data.
