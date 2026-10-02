## Purpose

Provide authenticated Android Premium purchasing through a PlantCare-owned paywall while Adapty supplies store products, purchase handling, restoration, and verified entitlement state without breaking unsupported platforms.

## ADDED Requirements

### Requirement: Subscription initialization is ordered and non-fatal
The system SHALL read `ADAPTY_PUBLIC_SDK_KEY` from compile-time configuration, activate the Adapty core SDK exactly once on supported Android builds before any other SDK call, and continue the free application when the key is missing, blank, or activation fails. The system MUST NOT log the full key and MUST preserve the existing Firebase initialization, emulator, App Check, and application-service startup order.

#### Scenario: Configured Android startup
- **WHEN** an Android build starts with a non-blank public SDK key
- **THEN** Adapty activation completes before identity, profile, product, purchase, or restore operations are allowed

#### Scenario: Missing SDK key
- **WHEN** the compile-time SDK key is absent or blank
- **THEN** the application remains usable and Premium purchasing reports a configuration-unavailable state without exposing a credential

#### Scenario: Unsupported startup
- **WHEN** the application starts on iOS or web
- **THEN** no Adapty purchase API is activated or invoked and the application continues normally

### Requirement: Authenticated identity isolates subscription state
The system SHALL associate Adapty with the current authenticated Firebase UID, refresh the profile after startup and sign-in, serialize identity transitions, and call the supported Adapty logout/reset operation on sign-out before another UID can publish entitlement state. It MUST NOT send unnecessary personal information.

#### Scenario: User signs in
- **WHEN** Firebase Authentication exposes a new signed-in UID
- **THEN** Adapty identifies that UID and refreshes its profile before Premium operations become ready

#### Scenario: User signs out or switches accounts
- **WHEN** the current Firebase user signs out or changes
- **THEN** cached products and entitlement state for the previous UID are invalidated and cannot unlock the next session

### Requirement: Custom paywall retrieves and validates the monthly product
The system SHALL fetch subscription configuration for placement `plantcare_main_paywall` and select a product only when its Google Play product ID is `plantcare_premium`, its base plan ID is `monthly`, it has no active trial or introductory offer, and it supplies non-empty store-localized title, price, and billing-period metadata. Product selection MUST NOT depend on array position and MUST NOT synthesize price or period values.

#### Scenario: Matching product is returned
- **WHEN** the placement returns the configured monthly product with complete localized metadata
- **THEN** the Flutter paywall becomes ready with the localized title, price, and billing period

#### Scenario: Placement is unavailable
- **WHEN** the placement cannot be fetched or has no assigned custom paywall
- **THEN** the system reports a typed paywall-unavailable outcome with a retry path

#### Scenario: Product is invalid or missing
- **WHEN** products omit the expected product/base-plan pair, contain an offer, or lack localized metadata
- **THEN** the system reports a typed product-unavailable outcome and does not enable purchase

### Requirement: Flutter owns the complete paywall presentation
The Premium route SHALL use PlantCare's responsive Material 3 UI and MUST NOT present an Adapty Flow Builder or legacy Paywall Builder view. It SHALL show only the monthly plan, truthful existing Premium benefits, localized store product information, monthly auto-renewal and cancellation wording, purchase, restore, close/back, management, Privacy Policy, and Terms actions, plus loading, unavailable, retry, pending, success, and recoverable failure states.

#### Scenario: Ready Android paywall
- **WHEN** a valid product has loaded on Android
- **THEN** the page displays its localized title, price, and period and enables one purchase action for the monthly plan

#### Scenario: Truthful benefits and billing disclosure
- **WHEN** the Premium page renders
- **THEN** it describes unlimited saved plants without claiming that existing AI or care features require Premium and explains that billing auto-renews monthly until cancelled through Google Play

#### Scenario: Responsive and accessible use
- **WHEN** the page is used at narrow or wide widths, increased text scaling, or keyboard navigation
- **THEN** content remains scrollable and free of overflow with meaningful labels, focus order, and progress semantics

### Requirement: Direct purchase outcomes are typed and entitlement-verified
The system SHALL purchase the retained matching Adapty product through the direct purchase API and represent purchase-in-progress, pending, neutral user cancellation, recoverable failure, and verified success. Repeated taps while an operation is active MUST NOT start duplicate purchases. Premium access SHALL activate only when the returned profile or a subsequent current-profile refresh reports the `premium` access level active and unexpired.

#### Scenario: Purchase succeeds with active entitlement
- **WHEN** a direct purchase returns a profile whose `premium` access level is active and unexpired
- **THEN** the system publishes verified Premium access and refreshes the application-scoped entitlement state

#### Scenario: Purchase is cancelled
- **WHEN** the user cancels the Google Play purchase sheet
- **THEN** the paywall returns to a ready state without displaying a technical error

#### Scenario: Purchase is pending
- **WHEN** Google Play reports a pending purchase
- **THEN** the paywall shows a non-error pending state and does not grant Premium

#### Scenario: Purchase fails or lacks entitlement
- **WHEN** purchasing fails or the returned and refreshed profiles do not prove active unexpired `premium` access
- **THEN** the system retains the prior verified state, reports a typed recoverable or invalid-entitlement failure, and does not unlock Premium

#### Scenario: Purchase button is tapped repeatedly
- **WHEN** the purchase action is triggered again while a purchase is active
- **THEN** only the first direct purchase request reaches the SDK

### Requirement: Profile refresh preserves authoritative access semantics
The active `premium` access level in the identified user's current Adapty profile SHALL be the source of truth. The system SHALL refresh it after startup, login, successful purchase, restore, and appropriate application resume events; a failed refresh MUST NOT erase previously verified active access, while a later successful profile showing inactive or expired access SHALL clear it.

#### Scenario: Active access is unexpired
- **WHEN** the current profile reports `premium` active with no expiration or an expiration after the current instant
- **THEN** the application treats the identified user as Premium

#### Scenario: Access is expired
- **WHEN** a successful current profile reports an expiration at or before the current instant or inactive access
- **THEN** the application treats the identified user as non-Premium

#### Scenario: Refresh fails after verification
- **WHEN** a profile refresh fails after active Premium was verified for the same UID
- **THEN** the verified access is preserved with a non-blocking warning

### Requirement: Restoration and external actions remain available
Android users SHALL be able to restore purchases, manage the matching Google Play subscription, and open configured HTTPS Privacy Policy and Terms destinations. Restore SHALL verify `premium` from the returned profile; no active purchase is a neutral result, while store, network, or launch failures are recoverable.

#### Scenario: Restore proves active Premium
- **WHEN** restoration returns an active unexpired `premium` access level
- **THEN** Premium access is published and the UI reports successful restoration

#### Scenario: Restore finds no active purchase
- **WHEN** restoration succeeds without active `premium` access
- **THEN** the UI explains that no active purchase was found without treating it as a technical failure

#### Scenario: Legal destination is unavailable
- **WHEN** a configured Privacy Policy or Terms URL is missing, invalid, or cannot be opened
- **THEN** the associated action is disabled or reports a recoverable launch failure without inventing a URL

### Requirement: Unsupported platforms remain compile-safe
The web and iOS builds SHALL compile without an invented App Store product and SHALL expose no enabled purchase or restore action. Web SHALL state that background mobile purchasing is unavailable in this version, and platform-independent source MUST NOT import `dart:io`.

#### Scenario: Premium route on web
- **WHEN** the Premium route renders on web
- **THEN** plan information and legal links remain usable while purchase and restore are unavailable and no Adapty purchasing call occurs

#### Scenario: Premium route on iOS
- **WHEN** the Premium route renders on iOS
- **THEN** the page explains that Android purchasing is currently supported and exposes no enabled purchase or restore action

### Requirement: Subscription boundaries are testable without live services
Application widgets MUST dispatch BLoC events rather than calling Adapty or repositories directly, Adapty types MUST remain confined to the data integration layer, and automated tests MUST use injected fakes without contacting Adapty, Firebase production services, or Google Play.

#### Scenario: Automated subscription verification runs
- **WHEN** domain, data, BLoC, widget, navigation, and platform-boundary tests execute
- **THEN** configuration, product matching, entitlement, purchase outcomes, duplicate suppression, identity isolation, restore, page states, and unsupported platforms are verified without live purchases
