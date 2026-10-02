# Google Play premium validation

Use a Google Play license tester and an Internal testing release installed from
Google Play. A locally installed debug APK can validate layout and recoverable
states, but it does not prove a real Play Billing purchase.

## Release blockers outside this repository

Before distributing the build, an authorized operator must verify in the
Adapty and Google Play dashboards that:

- access level `premium` exists;
- Adapty product **PlantCare Premium Monthly** maps to Google Play product
  `plantcare_premium` and base plan `monthly`;
- a custom paywall contains only that product and is assigned to placement
  `plantcare_main_paywall` for the **All Users** audience;
- the selected product has no free trial or introductory offer;
- the Google Play service-account JSON is configured in Adapty;
- Google Play real-time developer notifications (RTDN) are configured and a
  test notification succeeds;
- the Privacy Policy and Terms destinations are the approved production HTTPS
  pages;
- the Play Console account-deletion URL is
  `https://plantcare-ai-dev-tasnimalam.web.app/account-deletion`; verify a local
  release build and Hosting deep-link refresh before entering or publishing it;
- the Google Play base plan is active in the same application/package and is
  available to the internal-testing track and tester region.

Those dashboard settings cannot be inspected from this repository and remain
manual release blockers until an authorized operator records evidence of each
item. Do not infer their state from unit tests or a successful build.

## Repository release audit

- Android application ID and namespace are
  `com.tasnimalam.plantcare_ai`; release signing continues to use the existing
  `plantcare-upload` configuration.
- The main Android manifest declares internet access and does not contain an
  SDK key or a second subscription initializer.
- The resolved Flutter dependency is `adapty_flutter` 4.0.4. Its Android SDK
  resolves Google Play Billing Library 8; confirm the exact dependency report
  again for the final release artifact.
- The iOS project remains at deployment target 15.0. No App Store product is
  configured by this Android milestone.
- No Codemagic YAML is stored in this repository. The external Codemagic
  workflow must forward `ADAPTY_PUBLIC_SDK_KEY`, `PRIVACY_POLICY_URL`, and
  `TERMS_OF_SERVICE_URL` using `--dart-define`; never echo their values.

## License-tester procedure

1. Add the tester account to the Play Console license-testing list and the
   Internal testing track. Publish the signed app bundle, accept the tester
   invitation with that account, and install the build from Google Play.
2. Sign into PlantCare AI with Firebase Authentication. Record the Firebase UID
   used for the test and confirm the Adapty customer profile uses that same UID.
3. Open **Upgrade to Premium**. Confirm Free lists up to 3 saved plants and says
   AI and care features are included. Confirm Premium lists unlimited saved
   plants and does not claim AI, diagnosis, guidance, history, logs, or reminders
   as Premium-only.
4. Confirm the price and monthly billing period match localized Google Play
   output for the tester account. Confirm no trial or introductory wording is
   visible in the Flutter paywall. Confirm the localized product title is also
   supplied by Google Play through Adapty.
5. Start the purchase and cancel from Google Play. Confirm cancellation is
   neutral and the page remains usable. If Play test instruments provide a
   pending method, exercise it and confirm the pending message appears without
   unlocking Premium.
6. Complete a tester purchase through Google Play. Confirm the UI reports
   Premium only after the returned or freshly fetched Adapty profile shows the
   active `premium` access level. Record the Play order/test evidence and the
   matching Adapty profile. If no transaction is completed, record **not
   completed** rather than reporting purchase success.
7. Close and reopen the app, then sign out and back into the same Firebase
   account. Confirm verified access follows the profile. Reinstall from Play,
   sign into the same accounts, choose **Restore Purchases**, and confirm access
   is restored. Also verify the no-active-purchase result with a clean tester.
8. Choose **Manage Subscription** and confirm Google Play opens the
   `plantcare_premium` subscription for package
   `com.tasnimalam.plantcare_ai`, or the general subscriptions center when
   product context is unavailable.
9. Open Privacy Policy and Terms and confirm both approved HTTPS destinations.
10. Repeat paywall load, restore, management, and legal-link actions while
    offline or after a recoverable interruption. Confirm useful retry messages,
    and confirm a previously verified purchase remains successful if only a
    later profile refresh fails.
11. Switch between two Firebase accounts. Confirm each Adapty profile uses the
    current UID and no price, product, or entitlement result from the previous
    account is reused.
12. On web, confirm the page says mobile purchasing is not currently available
    and has no enabled purchase or restore action. On iOS, confirm the Android
    availability notice and the same disabled purchase boundary.
13. With a Free account holding fewer than three plants, identify a plant from a
    photo and save it. With exactly three plants, start photo-based creation and
    confirm the limit explanation appears before the photo picker. Repeat with
    manual creation and direct navigation to `/plants/new` and
    `/plants/new/manual`.
14. From each limit explanation, open Premium. Cancel or leave purchase pending
    and confirm creation does not resume. After a profile-verified tester
    purchase, confirm the app returns to the exact intended manual or photo flow.
15. Using a Free test account with more than three existing plants, confirm every
    plant and historical result remains visible. Confirm the user can edit,
    diagnose, create observations, retrieve knowledge, use soil/fertilizer
    guidance, add care logs, use reminders, and delete plants, but cannot create
    another plant.
16. Make subscription status temporarily unavailable and confirm the account
    retains the complete Free feature set, with only fourth-and-later plant
    creation unavailable.
17. Open account deletion and confirm it recommends cancellation when relevant
    while clearly stating cancellation is not required. Adapty unavailability
    must not block deletion after the authenticated cleanup handoff is recorded;
    SDK logout must never be described as Adapty profile deletion.

Record the build version, track, tester region, device/Android version, each
result above, dashboard evidence, and whether a real Google Play transaction
was actually completed.
