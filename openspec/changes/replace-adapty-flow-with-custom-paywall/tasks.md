## 1. Contracts and Configuration

- [x] 1.1 Change the canonical placement to `plantcare_main_paywall`, add localized product title and the complete typed failure/result vocabulary to `plantcare_domain`, and verify domain equality/transition tests cover every new field and purchase outcome.
- [x] 1.2 Replace the presentation-oriented repository contract with one direct purchase operation while preserving restore, refresh, and access streams; update all fakes and verify package-boundary tests expose no Adapty type above `plantcare_data`.
- [x] 1.3 Re-audit compile-time `ADAPTY_PUBLIC_SDK_KEY`, Privacy Policy, and Terms handling plus bootstrap ordering; add or update characterization tests proving blank configuration is non-fatal and no credential value is logged.

## 2. Adapty Data Integration

- [x] 2.1 Refactor the Adapty facade to activate core SDK v4.0.4 once with AdaptyUI disabled, remove Flow-view observers/presentation, and verify facade/source tests prove no UI view is created or presented.
- [x] 2.2 Map fetched SDK products into opaque data-layer wrappers containing product handle, localized title/price/period, product/base-plan IDs, and offer metadata; verify tests select `plantcare_premium` + `monthly` by identifiers and reject wrong, offered, or incomplete products regardless of array position.
- [x] 2.3 Fetch `plantcare_main_paywall` without requiring a builder view configuration, cache the selected product by authenticated UID/generation, and verify tests distinguish configuration, network, paywall, product, and stale-identity failures.
- [x] 2.4 Implement direct `makePurchase(product:)` result mapping for success, pending, user cancellation, SDK/network failure, and invalid entitlement; verify repository tests cover returned-profile verification and one current-profile fallback without duplicate SDK calls.
- [x] 2.5 Preserve serialized identify/logout behavior and clear retained products/access on sign-out and account switch; verify startup, login, logout, and cross-session tests prove one user's product or entitlement cannot leak into another session.
- [x] 2.6 Evaluate `premium` from active and unexpired access-level data using a testable current instant, retain verified access across transient refresh failure, and clear it on a newer inactive/expired profile; verify active, no-expiration, expired, warning, and UID-change tests.
- [x] 2.7 Revalidate restore behavior for Adapty 4.0.4, including active Premium, neutral no-access, and recoverable restoration failure, and verify unsupported iOS/web paths make no Adapty product, purchase, profile, or restore calls.

## 3. BLoC and Application Lifecycle

- [x] 3.1 Update `PaywallBloc` to load a custom-paywall offer and await one direct purchase operation, mapping loading, ready, purchasing, cancellation, pending, verified success, invalid entitlement, and recoverable retry states; verify duplicate rapid purchase events reach the repository once.
- [x] 3.2 Preserve `PremiumAccessBloc` as the application-scoped source for the identified user's verified access and confirm refresh after startup/login/purchase/restore and existing resume handling; add focused BLoC/application lifecycle tests for success, warning, expiration, sign-out, and account switch.
- [x] 3.3 Regenerate GetIt/Injectable output for any changed signatures and verify application DI tests resolve one shared subscription repository without direct service location in widgets.

## 4. PlantCare Custom Paywall UI

- [x] 4.1 Update the Material 3 Premium page to display localized product title, price, and monthly period and dispatch direct purchase through the BLoC; verify widget tests contain no Flow-view action, hardcoded monetary value, or array-derived product assumption.
- [x] 4.2 Add clear monthly auto-renewal/cancellation disclosure and a close/back action while retaining only the truthful unlimited-saved-plants benefit; verify widget tests reject trial, guaranteed recovery, and invented Premium feature claims.
- [x] 4.3 Verify loading, ready, purchasing, pending, cancellation, active, paywall unavailable, product unavailable, recoverable failure, restore, management, Privacy, Terms, and retry states including control enablement and progress semantics.
- [x] 4.4 Verify narrow Android, wide web, increased text scale, keyboard focus, and screen-reader semantics remain usable without overflow; verify iOS/web variants have no enabled purchase or restore action and do not depend on the host test platform.

## 5. Documentation and External Configuration

- [x] 5.1 Update premium setup and license-tester documentation to use custom paywall placement `plantcare_main_paywall`, product `plantcare_premium`, base plan `monthly`, access level `premium`, localized store pricing, and no trial/offer; remove obsolete Flow Builder presentation instructions.
- [x] 5.2 Document the remaining manual Adapty/Google Play release blockers: Product `PlantCare Premium Monthly`, custom paywall assignment, All Users placement audience, Google Play service-account JSON, tested RTDN, license-tester/internal-track install, account switching, restore, cancellation, pending where available, and truthful real-transaction status.
- [x] 5.3 Audit Android release configuration, merged manifest/dependencies, Google Play Billing 8 resolution, package `com.tasnimalam.plantcare_ai`, iOS target, and Codemagic `--dart-define` usage; record exact findings without changing external systems or exposing secrets.

## 6. Workspace Verification

- [x] 6.1 Run dependency resolution and `melos run generate`, review generated diffs for expected subscription wiring only, and confirm no generated source was edited manually.
- [x] 6.2 Run `melos run format`, `melos run analyze`, `melos run boundaries`, and all focused domain/data/BLoC/widget/navigation/platform tests; fix in-scope failures and record exact outcomes.
- [x] 6.3 Run `melos run test` and verify the complete workspace passes without contacting live Firebase, Adapty, or Google Play services.
- [x] 6.4 Run the repository web release build without purchase credentials and verify the unsupported purchase experience compiles successfully.
- [x] 6.5 Build an Android release artifact with a safe non-secret `ADAPTY_PUBLIC_SDK_KEY` test value through `--dart-define`, report the artifact path and resolved billing/manifest evidence, and do not claim Play purchase validity from the local build.
- [x] 6.6 Run `git diff --check`, review `git diff`/`git status`, preserve pre-existing user changes, and confirm no Firebase Rules, backend, deployment, publishing, dashboard, price, yearly-plan, trial/offer, service-account, upload, push, or real-transaction action occurred.
