## Context

See `proposal.md` for motivation and `specs/premium-subscriptions/spec.md` for the final behavior contract.

The repository already contains an end-to-end subscription slice from the unarchived `add-android-premium-paywall` change: compile-time configuration, Android-only activation, Firebase UID coordination, an Adapty facade and repository, application-owned domain models, application- and route-scoped BLoCs, `/premium` routing, responsive UI, saved-plant capability enforcement, external links, and broad tests. The resolved dependency is `adapty_flutter` 4.0.4. Current code uses SDK v4 `getFlow`/`getPaywallProducts`, enables AdaptyUI, requires a Flow view configuration, and presents a native Flow whose callbacks drive purchase state.

The requested production shape is the manual/custom-paywall path documented for SDK v4: fetch a flow by placement to resolve products, render the entire purchase page in Flutter, and call `makePurchase(product:)`. Adapty's official 4.0.4 documentation confirms that direct purchase returns success, pending, or user-cancelled results; restore returns the current profile even when nothing is restorable; and AdaptyUI can be disabled when Adapty does not render screens. Android uses Google Play Billing Library 8 through this SDK version. The current Flutter 3.47.1/Dart 3.13.1 and iOS 15 baselines meet the documented SDK requirements.

The worktree already contains unrelated user changes (`apps/plantcare_app/pubspec.yaml`, `packages/plantcare_domain/analysis_options.yaml`, an app icon, and Play Store artifacts). Implementation must not overwrite or absorb them.

## Goals / Non-Goals

**Goals:**

- Reuse the existing architecture and narrow the code delta to replacing Flow presentation with direct purchasing.
- Preserve one subscription repository instance, serialized identity transitions, verified entitlement semantics, non-fatal startup, and platform guards.
- Make product selection, localized display data, and purchase ownership explicit and testable.
- Give BLoC one awaited purchase operation so duplicate suppression is local and deterministic.
- Keep the existing accurate saved-plant benefit and all Free AI/care behavior unchanged.

**Non-Goals:**

- Changing subscription pricing, catalog structure, feature entitlements, Firebase Rules, backend services, or account-deletion behavior.
- Adding iOS products, web checkout, yearly plans, trials, discounts, offers, or observer mode.
- Editing the Adapty dashboard, Google Play Console, service accounts, RTDN, publishing configuration, or making a transaction.
- Upgrading Adapty or unrelated dependencies without a verification-driven need.

## Decisions

### Use the SDK v4 manual paywall path and disable AdaptyUI

`FlutterAdaptySdkFacade.activate` will configure `withActivateUI(false)`. The facade will no longer implement Flow UI observers, create views, or register UI callbacks. It will still call `getFlow(placementId:)` and `getPaywallProducts(flow:)`, because SDK v4 uses a flow as the product retrieval container even for custom paywalls.

The repository will not reject a custom paywall because `hasViewConfiguration` is false; a view configuration is relevant only to SDK-rendered UI. Failure to fetch the configured placement remains paywall-unavailable, while absence of a valid matching product remains product-unavailable.

Alternative considered: keep AdaptyUI activated but never present it. That retains unused native UI setup and obscures the intended integration mode.

### Retain an opaque product handle scoped to the identified UID

The data facade's application-owned product wrapper will include localized title, price, period, product ID, base plan, offer metadata, and an opaque SDK handle. The repository will select by exact product/base-plan IDs, reject offered products, validate localized fields, and cache the selected wrapper with the current identity generation. `PremiumOffer` exposes only immutable display metadata; Adapty types remain inside `plantcare_data`.

Before purchasing, the repository will re-check that the cached product belongs to the currently identified UID/generation. Sign-out, account switch, initialization retry, or a new preparation replaces the cache.

Alternative considered: expose `AdaptyPaywallProduct` through the domain contract. That violates package boundaries and makes BLoC/widget tests depend on SDK models.

### Make purchase an awaited repository operation

Replace the presentation-oriented domain operation with a typed purchase result or an operation whose application-owned events are emitted synchronously around a single awaited call. The facade maps `AdaptyPurchaseResultSuccess`, `AdaptyPurchaseResultPending`, and `AdaptyPurchaseResultUserCancelled`; SDK exceptions map to typed network or purchase failures without leaking raw messages.

The route BLoC enters purchasing before awaiting the repository and ignores further purchase events while busy. Cancellation returns to ready, pending remains non-error, verified success moves to active, and failures retain a retryable ready offer where safe. This removes reliance on global AdaptyUI callback ordering and makes duplicate-tap prevention testable.

Alternative considered: keep a facade event stream for direct purchases. Direct purchase already returns a result to its caller, so an extra global stream adds ordering and lifetime complexity without benefit.

### Verify entitlement with activity and expiration

The facade profile wrapper will preserve the `premium` access level's `isActive` value and expiration timestamp. Repository evaluation will require `isActive` and, when an expiration exists, a timestamp after an injected/testable current instant. A returned success that does not prove access triggers one `getProfile` fallback; an inactive or expired fallback becomes an invalid-entitlement failure.

Existing monotonic behavior remains: transient refresh failure cannot erase active access for the same UID, but a newer successful profile can. Profile refresh stays tied to startup/identity, purchase, restore, SDK profile updates, and the existing application resume lifecycle where currently wired.

Alternative considered: trust `isActive` alone. Explicit expiration validation matches the requested contract and creates deterministic expired-access coverage even if malformed or stale test data claims active access.

### Expand typed failures at the domain boundary

The failure taxonomy will distinguish configuration, unsupported platform, network, paywall unavailable, product unavailable, purchase cancelled, purchase pending, purchase failed, restoration failed, invalid entitlement, not-ready, and launch failures. Neutral cancellation and pending still map to non-error BLoC states; the types exist so repository behavior is explicit and future callers cannot confuse them with generic technical failure.

SDK error-code inspection stays in the data facade/repository. Unknown SDK exceptions use the narrowest safe generic failure and user-facing messages remain nontechnical.

### Extend the existing Material page instead of replacing it

The page already has responsive Free/Premium comparison cards, localized price/period rendering, restore/manage/legal controls, unsupported variants, and semantics. It will add localized title, make the primary action purchase directly, include a close/back control, and add concise monthly auto-renewal/cancellation disclosure. The only Premium benefit remains unlimited saved plants.

No hardcoded price, trial language, guaranteed plant outcome, or invented Premium feature will be added.

## Risks / Trade-offs

- **[Dashboard placement mismatch]** Code will standardize on `plantcare_main_paywall`, so an unpublished or differently named dashboard placement makes the paywall unavailable. → Document the exact custom paywall, product assignment, All Users audience, service-account, and RTDN release blockers.
- **[Base-plan metadata differences]** Google Play product wrappers can vary with catalog configuration. → Require the exact product/base-plan pair and fail closed for purchase while leaving the free app available.
- **[SDK error taxonomy changes]** Adapty error codes can evolve within SDK releases. → Confine mapping to the facade and cover public result classes plus representative network/store exceptions with fakes.
- **[Cached product crosses identity]** Retaining an SDK product is necessary for direct purchase. → Tag it with UID/generation, clear it on every identity transition, and revalidate immediately before purchase.
- **[Existing completed change conflicts]** The earlier change still describes Flow Builder behavior. → Treat this change as the superseding final delta and archive only after its implementation and validation; do not silently rewrite the historical artifact.
- **[Release build cannot prove Play behavior]** A locally built APK/AAB cannot validate a Play-served product or complete licensed billing. → Separate compile/build verification from the documented internal-test/license-tester checklist and report transaction status truthfully.

## Migration Plan

1. Update domain IDs/models/contracts and focused tests, including the placement rename and localized title.
2. Replace AdaptyUI facade behavior with direct product purchase mapping, then adapt the repository while preserving identity and access semantics.
3. Update BLoC and UI actions/states, then regenerate Injectable output if signatures change.
4. Run focused tests before the full Melos verification suite, Android release build with a non-secret test define, and web build.
5. Deploy only after the external custom paywall and placement checklist is complete. Rollback is the prior Flow-presentation code plus the prior `main_paywall` dashboard mapping; no persisted application data migration is involved.
