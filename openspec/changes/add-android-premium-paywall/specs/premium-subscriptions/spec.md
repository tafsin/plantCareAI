## Purpose

Define an authenticated, Android-only premium subscription experience that presents store-backed Adapty offers and establishes access exclusively from verified subscription profiles.

## ADDED Requirements

### Requirement: Premium route is authenticated and discoverable
The system SHALL provide an `/premium` route that is protected by the existing authentication redirect behavior and SHALL expose an “Upgrade to Premium” entry from the authenticated application UI without changing the existing primary navigation destinations.

#### Scenario: Signed-in user opens Premium
- **WHEN** a signed-in user activates the Upgrade to Premium entry
- **THEN** the system navigates to `/premium`

#### Scenario: Signed-out user requests Premium
- **WHEN** a signed-out user requests `/premium`
- **THEN** the system redirects to sign-in while preserving `/premium` as the validated post-authentication destination

### Requirement: Subscription operations follow activation and identity ordering
The system MUST NOT retrieve a paywall, retrieve products, present a purchase flow, restore purchases, or refresh the subscription profile until Adapty activation has completed and the active Firebase UID has been identified to Adapty. Subscription identity transitions SHALL be serialized so an operation cannot run against a previous or anonymous profile.

#### Scenario: Signed-in user loads Premium after startup
- **WHEN** Firebase initialization, Adapty activation, and Firebase UID identification complete
- **THEN** the system may request the premium paywall and products for that identified user

#### Scenario: Identification is still pending
- **WHEN** the Premium route is opened before Firebase UID identification completes
- **THEN** the system shows loading and issues no paywall or product request until identification succeeds

#### Scenario: Account changes during subscription setup
- **WHEN** the authenticated Firebase UID changes while subscription setup or retrieval is in progress
- **THEN** stale results from the previous identity are ignored and later operations wait for the new identity transition

### Requirement: Android uses the remotely configured premium Flow
On Android, the system SHALL retrieve the Adapty Flow at placement `main_paywall`, verify that it has a device-renderable configuration, retrieve its store products, and present the remotely configured Flow rather than recreating its purchase UI in Flutter.

#### Scenario: Flow and product are available
- **WHEN** `main_paywall` returns a renderable Flow and at least one purchasable Google Play product
- **THEN** the Premium experience enables presentation of that Flow

#### Scenario: Paywall is unavailable
- **WHEN** the placement cannot return a renderable Flow
- **THEN** the system shows a nontechnical paywall-unavailable state with a retry action

#### Scenario: Product is unavailable
- **WHEN** the Flow loads but no eligible Google Play product is returned
- **THEN** the system shows a distinct product-unavailable state with a retry action and no enabled purchase action

### Requirement: Store-localized offer information is authoritative
The system SHALL display the localized Google Play price and billing period supplied for the retrieved store product and MUST NOT embed `CA$1.50`, another price, trial copy, or introductory-offer copy in Flutter source or generated user-facing messages.

#### Scenario: Localized monthly product is returned
- **WHEN** Google Play returns a localized price and monthly billing period for the offered product
- **THEN** the user sees those returned values in the purchase experience

#### Scenario: Store metadata lacks required display values
- **WHEN** a product lacks a usable localized price or billing period
- **THEN** the system treats the product as unavailable instead of inventing display text

### Requirement: Premium benefits are accurately described
The Premium route SHALL describe the current differentiator accurately: Free includes up to 3 saved plants and Premium includes unlimited saved plants, subject to existing technical limits. It MUST NOT advertise AI, care guidance, reminders, diagnosis, knowledge, or history as Premium-only because those capabilities remain available to Free users.

#### Scenario: User reviews plan comparison
- **WHEN** the Premium route renders on any supported application platform
- **THEN** the saved-plant allowance is visible without trial wording or unsupported Premium capability claims

#### Scenario: Free user opens an existing feature
- **WHEN** a user without verified premium access opens plant, AI, guidance, or history functionality
- **THEN** existing feature availability remains unchanged by this milestone

### Requirement: Saved-plant capability policy is centralized and fail-open
The system SHALL decide whether a user may create another saved plant through a deterministic domain policy. Verified active Premium access SHALL allow creation regardless of saved count. Verified inactive Free access SHALL allow creation only below three saved plants. Checking, signed-out, unknown, warning-only, or otherwise unavailable subscription state SHALL retain Free functionality and SHALL use the Free saved-plant allowance rather than blocking unrelated capabilities.

#### Scenario: Free user has fewer than three plants
- **WHEN** the policy receives verified inactive access and a saved count below three
- **THEN** it allows another saved plant

#### Scenario: Free user is at or above the limit
- **WHEN** the policy receives verified inactive access and a saved count of three or more
- **THEN** it denies only new plant creation with “Your free plan includes up to 3 plants. Upgrade to save unlimited plants.”

#### Scenario: Premium user has any existing count
- **WHEN** the policy receives verified active Premium access
- **THEN** it allows another saved plant subject to existing technical limits

#### Scenario: Subscription state is unavailable
- **WHEN** Premium status is checking, unknown, unavailable, or carries a non-authoritative warning
- **THEN** all Free functionality remains available and new plant creation follows the Free allowance

### Requirement: Every plant-creation path enforces the live allowance
Manual creation, photo-based creation, direct navigation to creation routes, and final save submission SHALL apply the same central policy. Final submission MUST use the latest saved-plant count and current verified entitlement so an earlier allowed screen cannot save a fourth Free plant after the count becomes stale.

#### Scenario: Photo creation is blocked before photo selection
- **WHEN** a Free user with three or more plants starts photo identification specifically to create another plant
- **THEN** the system shows the plant-limit explanation before opening the image picker and does not describe AI as restricted

#### Scenario: Direct creation route is requested at the limit
- **WHEN** a Free user at or above the limit opens a manual or photo creation route directly
- **THEN** the system prevents creation and offers Upgrade to Premium

#### Scenario: Count becomes stale before submission
- **WHEN** a Free user entered creation below the limit but the latest count is three or more at final submission
- **THEN** the save is rejected with the plant-limit explanation and no plant is created

#### Scenario: Existing Free account is already over limit
- **WHEN** a Free user already has more than three saved plants
- **THEN** all existing plants and historical results remain visible and usable, deletion remains available, and only creating another plant is denied

### Requirement: Upgrade returns to intended plant creation
A creation-limit prompt SHALL offer Upgrade to Premium and preserve whether the user intended manual or photo-based creation. After the current profile verifies successful Premium activation, the user SHALL return to that intended creation flow. Cancellation, pending purchase, failure, or unverified purchase SHALL NOT bypass the creation policy.

#### Scenario: Manual creator upgrades successfully
- **WHEN** a blocked manual-creation user completes a profile-verified purchase
- **THEN** the application returns to manual plant creation

#### Scenario: Photo creator upgrades successfully
- **WHEN** a blocked photo-creation user completes a profile-verified purchase
- **THEN** the application returns to photo identification for new-plant creation before any photo is selected

#### Scenario: Purchase does not verify Premium
- **WHEN** purchase is cancelled, pending, fails, or lacks active Premium access
- **THEN** the system retains the creation limit and does not navigate into an otherwise blocked save flow

### Requirement: AI and care capabilities remain available to Free users
The system MUST NOT consult Premium entitlement to authorize AI plant identification when creation is otherwise allowed, AI observations or diagnosis for existing plants, knowledge retrieval, soil/watering guidance, fertilizer guidance, saved diagnosis or care history, manual care logs, or manual reminders.

#### Scenario: Free user works with an existing plant
- **WHEN** a Free user, including an existing over-limit user, opens any AI, knowledge, guidance, history, care-log, or reminder workflow for an existing plant
- **THEN** that workflow remains available under its existing rules without a Premium prompt

#### Scenario: Free user identifies a savable plant
- **WHEN** a Free user below three saved plants starts photo identification to create a plant
- **THEN** identification and saving remain available under the existing workflow

### Requirement: Purchase outcomes are explicit and entitlement-verified
The system SHALL represent purchase-in-progress, pending, cancelled, verified-success, and recoverable-failure outcomes. A purchase SHALL unlock premium status only when the returned purchase profile or a subsequently retrieved current profile reports the `premium` access level as active.

#### Scenario: Purchase returns active premium profile
- **WHEN** Google Play purchase completion returns a profile whose `premium` access level is active
- **THEN** the system records verified premium activation and presents a success state

#### Scenario: Purchase result lacks active premium access
- **WHEN** a nominally successful purchase result does not contain active `premium` access
- **THEN** the system checks the current identified profile and activates premium only if that profile reports active access

#### Scenario: Purchase remains pending
- **WHEN** Google Play reports the purchase as pending
- **THEN** the system shows a non-error pending state and does not activate premium

#### Scenario: User cancels purchase
- **WHEN** the user cancels the Google Play purchase sheet
- **THEN** the system returns to a usable ready state without displaying cancellation as an error

#### Scenario: Purchase fails recoverably
- **WHEN** a network, billing, or presentation failure prevents purchase completion
- **THEN** the system keeps premium inactive, displays a clear recoverable message, and offers retry where applicable

### Requirement: Verified success survives later refresh failure
Once the active identified user has a verified active `premium` profile, a later paywall, presentation-dismissal, or profile-refresh failure MUST NOT replace that verified result with a non-premium state. Verified access MAY be cleared only by a successful newer profile for the same user showing inactive access or by an authenticated-user transition.

#### Scenario: Refresh fails after verified purchase
- **WHEN** premium activation has been verified and a later UI or profile refresh fails
- **THEN** the system preserves the successful premium state and may show a non-blocking refresh warning

#### Scenario: Newer profile confirms expiration
- **WHEN** a later successful profile refresh for the same user reports inactive `premium` access
- **THEN** the system updates the entitlement to inactive

### Requirement: Purchases can be restored
The Android Premium experience SHALL provide Restore Purchases and SHALL verify restored access from the profile returned by the restore operation. A successful restore call with no active `premium` access SHALL be a neutral no-access outcome rather than a purchase success.

#### Scenario: Restore returns active premium
- **WHEN** Restore Purchases returns a profile with active `premium` access
- **THEN** the system records verified premium activation and reports that access was restored

#### Scenario: Restore finds no premium access
- **WHEN** Restore Purchases completes but the returned profile has no active `premium` access
- **THEN** the system leaves premium inactive and explains that no active purchase was found without treating the outcome as a technical failure

#### Scenario: Restore fails recoverably
- **WHEN** restoration fails because of a recoverable SDK, store, or network problem
- **THEN** the system retains the prior verified entitlement state and offers retry

### Requirement: Android users can manage subscriptions
The Android Premium experience SHALL provide Manage Subscription and open the appropriate Google Play subscription-management destination. The product-specific destination SHALL use the application package and applicable Google Play product identifier when available, with the general Google Play subscriptions center as a safe fallback.

#### Scenario: Product-specific management is available
- **WHEN** the application knows the Google Play product identifier and the user activates Manage Subscription
- **THEN** the system opens the product-specific Google Play subscription-management destination externally

#### Scenario: Specific product context is unavailable
- **WHEN** the user activates Manage Subscription without usable product context
- **THEN** the system opens the general Google Play subscriptions center externally

#### Scenario: Management destination cannot open
- **WHEN** the platform cannot launch the Google Play destination
- **THEN** the system retains the current entitlement and displays a recoverable message

### Requirement: Legal destinations are available
The Premium experience SHALL provide Privacy Policy and Terms links backed by configured HTTPS destinations and SHALL report an unavailable or launch-failure state without inventing URLs.

#### Scenario: Legal link opens
- **WHEN** a user activates a configured Privacy Policy or Terms link
- **THEN** the system opens that HTTPS destination externally

#### Scenario: Legal destination is missing or invalid
- **WHEN** a legal destination is not configured as a valid HTTPS URL
- **THEN** its action is unavailable and the UI explains that the link is currently unavailable

### Requirement: Unsupported platforms cannot initiate purchases
Only Android SHALL expose an enabled action that presents the Adapty purchase Flow or restores Google Play purchases. iOS and web SHALL not activate an enabled purchase action, and web SHALL clearly state that mobile purchasing is not currently available.

#### Scenario: Premium route on web
- **WHEN** the Premium route is rendered on web
- **THEN** the plan comparison and legal links remain available, purchase and restore actions are not enabled, and the page states that mobile purchasing is not currently available

#### Scenario: Premium route on iOS
- **WHEN** the Premium route is rendered on iOS
- **THEN** no enabled purchase or restore action is displayed and the page explains that Android purchasing is currently supported

#### Scenario: Unsupported platform boundary is invoked
- **WHEN** application logic attempts a purchase operation on a non-Android platform
- **THEN** the platform boundary returns an unsupported outcome without invoking Adapty purchasing APIs

### Requirement: Premium UI is accessible and responsive
The Premium route SHALL remain usable on narrow mobile and wide web layouts, expose meaningful semantic labels for interactive controls and progress, avoid obscuring content at large text scales, and present loading, unavailable, pending, success, and recoverable error states with clear next actions.

#### Scenario: Narrow Android layout
- **WHEN** the Premium route is displayed at a narrow mobile width with increased text scaling
- **THEN** plan content and actions remain readable, scrollable, and free of layout overflow

#### Scenario: Wide web layout
- **WHEN** the Premium route is displayed on a wide web viewport
- **THEN** content is width-constrained, logically grouped, and keyboard-accessible

#### Scenario: Async operation is active
- **WHEN** paywall loading, purchase presentation, or restore is in progress
- **THEN** the UI exposes progress semantics and prevents duplicate conflicting actions

### Requirement: SDK and repository boundaries are preserved
Application widgets MUST NOT import Adapty libraries or call subscription repositories directly. Subscription operations SHALL be mediated by BLoC events and platform/data boundaries, and Flutter-visible state SHALL contain only application-owned models.

#### Scenario: Presentation requests an operation
- **WHEN** a widget initiates loading, Flow presentation, restore, management, or legal navigation
- **THEN** it dispatches a BLoC event and does not invoke a repository or Adapty API

#### Scenario: Workspace boundaries are checked
- **WHEN** package boundary validation runs
- **THEN** Adapty imports are confined to the owning integration layer and no package imports another package's private `lib/src` implementation
