## Why

PlantCare AI needs an account-linked Android subscription foundation that can present its remotely configured Adapty Flow, complete Google Play purchases, establish premium access without trusting UI outcomes, and apply that entitlement to the saved-plant allowance without restricting AI or care workflows.

## What Changes

- Add an authenticated `/premium` experience and an application-level “Upgrade to Premium” entry point.
- Activate Adapty and AdaptyUI for supported Android builds, identify the signed-in Firebase UID, and prevent paywall or product retrieval until both operations complete.
- Retrieve and present the remotely configured `main_paywall` Flow and its Google Play products, including store-localized price and billing period with no hardcoded price or trial language.
- Model premium status from the `premium` Adapty access level and verify it from a returned or current Adapty profile after purchase or restore.
- Handle paywall and product availability, purchase pending, neutral cancellation, verified success, recoverable failures, retries, and post-success refresh failures without discarding a verified entitlement.
- Add Restore Purchases, Google Play subscription management, Privacy Policy, and Terms actions through injected boundaries rather than SDK or repository calls from widgets.
- Disable purchasing on iOS and web, with explicit web messaging that mobile purchasing is unavailable.
- Add unit, BLoC, widget, navigation, accessibility/responsiveness, and platform-boundary coverage plus manual Google Play license-tester instructions.
- Add a central, fail-open domain capability policy: Free users may save up to three plants and verified Premium users may save unlimited plants, subject to existing technical limits.
- Guard every plant-creation entry and final submission, including manual creation, photo-based creation, and direct routes. Re-check the live plant count at submission so a stale creation screen cannot save a fourth Free plant.
- When a blocked creation upgrades successfully, return to the intended manual or photo creation flow; photo creation explains the plant limit before selecting a photo.
- Keep AI plant identification, visual observations, grounded diagnosis, knowledge retrieval, soil/watering guidance, fertilizer guidance, saved history, care logs, and reminders available to Free users and existing over-limit accounts.
- Never delete, hide, or lock existing plants or historical results, and never describe the saved-plant limit as an AI restriction.
- Do not change Firestore Rules, add backend services, deploy, or push.

## Capabilities

### New Capabilities

- `premium-subscriptions`: Authenticated premium status, Android Adapty Flow presentation, Google Play purchase and restore outcomes, subscription management, legal links, unsupported-platform behavior, and resilience requirements.

### Modified Capabilities

None.

## Impact

- Adds Adapty Flutter SDK integration behind domain contracts and data-layer adapters.
- Extends application bootstrap, authenticated-user lifecycle coordination, dependency injection, routing, and navigation UI.
- Adds subscription presentation BLoCs and a responsive premium page in `plantcare_features` without exposing Adapty types to widgets.
- Requires build-time Adapty public SDK configuration and real Privacy Policy and Terms destinations; no secret key is stored in the client.
- Adds generated dependency-injection output and may update platform dependency lockfiles as required by the SDK.
- Changes only new plant creation availability; existing plant, AI, guidance, history, care-log, and reminder availability remains unchanged.
- Leaves Firebase Rules and backend behavior unchanged; entitlement is not simulated in Firestore security rules.
