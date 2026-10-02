## Why

PlantCare AI already has a substantial Android Adapty integration, but its purchase action presents an Adapty-rendered Flow and uses the historical `main_paywall` placement. The product decision is now to keep the existing PlantCare Material 3 paywall as the complete purchase surface, retrieve the monthly Google Play product through Adapty placement `plantcare_main_paywall`, and invoke Adapty's direct purchase API without hardcoded prices, credentials, or entitlement shortcuts.

## What Changes

- Replace native Adapty Flow presentation with the existing responsive Flutter paywall and direct `makePurchase` handling.
- Standardize the placement ID on `plantcare_main_paywall` while retaining product `plantcare_premium`, Android base plan `monthly`, and access level `premium`.
- Retain and validate the matching Adapty product object so purchase selection is based on product and base-plan identifiers rather than array position.
- Expose store-localized product title, price, and monthly period to application-owned models and render them in the Flutter UI.
- Map direct purchase success, cancellation, pending, and failure results into the existing BLoC flow, with entitlement verification from the returned or refreshed Adapty profile.
- Keep SDK activation single-shot and non-fatal, disable unused AdaptyUI rendering, preserve Firebase bootstrap and authenticated UID lifecycle ordering, and retain Android-only purchase/restore guards.
- Preserve the current truthful Premium benefit: unlimited saved plants; all existing AI and care capabilities remain available to Free users.
- Update focused unit, BLoC, widget, platform, documentation, and build verification for the custom-paywall path.
- Do not modify external Adapty or Google Play configuration, publish an app, upload an artifact, make a real purchase, or change prices or offers.

## Capabilities

### New Capabilities

- `premium-subscriptions`: Defines the final authenticated Android custom-paywall behavior, Adapty product retrieval and direct purchase outcomes, verified Premium entitlement, restoration, legal and management actions, and unsupported-platform behavior. This supersedes the Flow-presentation details in the still-unarchived `add-android-premium-paywall` change.

### Modified Capabilities

None. No capability has been archived into the main specification set yet.

## Impact

- `plantcare_domain`: localized offer metadata and subscription operation contracts.
- `plantcare_data`: Adapty v4 facade, activation configuration, placement lookup, retained product ownership, direct purchase result mapping, and typed failures.
- `plantcare_features`: Paywall BLoC events/states and the Material 3 purchase surface.
- `plantcare_app`: existing subscription lifecycle and DI wiring should remain stable except where regenerated types require updates.
- Tests and documentation: replace Flow-view assumptions with custom-paywall purchase assertions and dashboard setup instructions.
- Dependencies: continue using the resolved `adapty_flutter` 4.0.4 integration unless verification exposes a concrete incompatibility; no visual-builder dependency or new platform package is required.
