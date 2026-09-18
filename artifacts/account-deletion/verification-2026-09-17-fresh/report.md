# Fresh account-deletion verification

Date: 2026-09-17
Change: `add-account-management-and-deletion`
Scope: local Android debug app, Chrome, and Firebase emulators only

## Outcome

Android's primary email/password deletion path passed end to end with a disposable emulator account. The clean public route passed signed-out direct-load and refresh checks, and the public page displayed Privacy Policy and Terms of Service controls both visually and in its accessibility tree. The definitive fresh-origin web build on port 5003 also passed the full disposable registration and deletion flow: return-route preservation, generic subscription warning, exact confirmation gate, password reauthentication, exact `self_service_web` handoff, Auth deletion, and signed-out completion. Earlier port 5002 failures are retained only as stale-service-worker regression evidence. All disposable Auth fixtures were removed; cleanup handoffs remain intentionally retained for the trusted admin process.

## Passed observations

- Android showed Account as navigation destination 4, preserving Home, My Plants, and Reminders as destinations 1-3.
- Android exposed `Account -> Privacy and data -> Delete account and data`, with Privacy Policy and Terms on Privacy and data.
- Android displayed permanence, the complete deleted-data list, 30-day verified-processing window, 90-day minimal-record retention limit, 30-day unverifiable-correspondence limit, provider-controlled retention, and inaccessible-device language.
- Android displayed the generic subscription warning, stated cancellation was recommended but not required, and exposed the Google Play management action. Premium/Adapty status was not required to proceed.
- The Android destructive button remained disabled for lowercase `delete`; acknowledgement plus exact case-sensitive `DELETE` enabled it.
- Android displayed a current-password field for the password-linked account. A wrong password stopped before deletion and showed a nontechnical retry state plus support/legal actions.
- A fresh disposable Android account completed reauthentication, cleanup-handoff recording, deletion, and signed-out completion.
- Local emulator inspection after Android completion found the fake Auth user absent and a retained cleanup request containing exactly four fields: `schemaVersion: 1`, `providerCleanup: ["adapty"]`, `source: "self_service_mobile"`, and a Firestore Timestamp.
- After the Hosting rebuild, `http://127.0.0.1:5002/account-deletion` loaded signed out at the clean URL and stayed there after direct refresh; it did not redirect to Sign in.
- The clean signed-out web page prominently identified PlantCare AI and showed both sign-in and configured support-request actions with neutral ownership and credential/payment warnings.
- Follow-up regression retest confirmed visible and accessible Privacy Policy and Terms of Service buttons on the signed-out clean route, before and after direct refresh.
- The final web target visibly displayed the non-production emulator-mode warning.
- On the fresh port 5003 origin, registration initiated from `/account-deletion` used `register?redirect=/account-deletion`, returned to the clean deletion route, and stayed there through completion.
- The authenticated web page showed the generic subscription warning without an Adapty status requirement. Lowercase `delete` kept deletion disabled; acknowledgement plus exact `DELETE` enabled the destructive action.
- The port 5003 disposable account completed password reauthentication, deletion, and signed-out completion.
- Local emulator inspection found the fake web Auth user absent and a retained exact four-field `self_service_web` cleanup handoff.
- Chrome's observed scripts/console contained no Adapty script or Adapty activity. The page loaded the local Flutter bundle plus the Google Identity Services client; no Google Play purchase endpoint was opened.
- Android runtime logs showed no App Check provider installed and placeholder-token behavior. No App Check debug token/provider was requested or used.

## Findings and unverified scenarios

1. **Fixed regression: public web legal controls.** The first signed-out accessibility audit found no Privacy Policy or Terms controls. After the follow-up fix and Hosting rebuild, both controls were visible and exposed as accessibility buttons; clean-route refresh preserved them.
2. **Fixed regression: authenticated web return route and deletion.** Port 5002 repeatedly served a stale service-worker bundle that failed emulator sign-in or redirected successful registration to Home. On the fresh port 5003 origin, registration preserved `/account-deletion`, the generic warning and exact gate behaved correctly, the exact `self_service_web` handoff was retained, the Auth fixture was absent after deletion, and signed-out completion was shown. Port 5002 screenshots remain regression evidence and are not the final result.
3. **Support mailto encoding unverified.** The configured support action was visible, but opening an external mail client was not required for this pass, so the exact generated subject/body encoding was not observed.
4. **Google reauthentication unverified.** No real Google identity was used; only email/password against emulator users was exercised.
5. **Failure injection unverified.** Cleanup-request failure/support fallback, remote-delete partial failure/retry, local-cleanup failure/retry, and Auth-delete failure after cleanup require controlled fakes or emulator fault injection not exposed by this running build.
6. **Deletion ordering/data isolation not runtime-proven.** The successful disposable account had no seeded plant descendants. Child-first ordering, cross-user isolation, curated-knowledge non-mutation, and local image/notification cleanup were not directly observable in this pass.
7. **No complete network capture.** Emulator Hub and local Admin verification prove the observed fixture operations were in local emulator namespaces. Browser script/console and Android logs showed no live Adapty/Google Play purchase activity, but a packet-level trace was not collected.
8. **Project-namespace warning.** Firestore emulator logs reported requests using configured namespace `plantcare-ai-dev-tasnimalam` while the emulator process was started for `demo-plantcare-ai`. Requests still went to the loopback emulator, but the mismatch should be removed for clearer non-production evidence.

## Screenshot evidence

- `android-account-fourth-destination.png` — Account selected as destination 4.
- `android-privacy-and-data.png` — Privacy Policy, Terms, and Delete account and data entry.
- `android-subscription-warning.png` — generic subscription warning and acknowledgement.
- `android-delete-gate-and-reauth.png` — exact `DELETE` gate plus password reauthentication UI.
- `android-reauthentication-failure-retry.png` — honest reauthentication failure, retry, support, and legal actions.
- `android-signed-out-completion.png` — fixed signed-out completion message.
- `web-signed-out-clean-route-refresh.jpg` — passing clean-route signed-out direct refresh after rebuild.
- `web-signed-out-clean-route-refresh-final.jpg` — final emulator-enabled clean-route page showing visible Privacy Policy and Terms of Service controls plus the non-production warning.
- `web-signed-out-direct-route-failure.jpg` — retained pre-fix regression evidence showing the earlier erroneous sign-in route.
- `web-signed-out-hash-route-disclosures.jpg` — pre-fix hash-route disclosure rendering used to diagnose the routing problem.
- `web-registration-route-preservation-failure.jpg` — stale port 5002 regression evidence showing Home after registration initiated from `/account-deletion`; superseded by the passing port 5003 result.
- `web-authenticated-generic-warning-gate-disabled.jpg` — passing port 5003 authenticated generic warning with the destructive action disabled.
- `web-exact-delete-gate-enabled.jpg` — passing port 5003 acknowledgement plus exact `DELETE` gate with password reauthentication.
- `web-signed-out-completion-port5003.jpg` — passing port 5003 signed-out completion after full deletion.

`runtime-evidence.txt` contains the redacted observation summary. `commands.txt` lists the safe checks used. No implementation source was edited by this verifier.
