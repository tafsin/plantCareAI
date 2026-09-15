# Authentication verification report

Date: 2026-09-14

## Environment

- Device: Pixel 4 API 34 Android emulator (`emulator-5554`)
- Runtime: `qemu-system-aarch64`, Android 14 (API 34), ARM64
- App: Flutter debug build with Marionette binding
- Backend: local Firebase Authentication and Firestore emulators, project `demo-plantcare-ai`
- Firebase emulator flag: `USE_FIREBASE_EMULATOR=true`
- Test account: `qa.auth.20260914.1538@example.com`

## Results

### Scenario 1 — Register using email and password: PASS

Marionette opened registration, entered the test email and a policy-compliant password (8 characters containing letters and numbers), confirmed it, and submitted the form. The app navigated automatically to the protected Home page. A direct Firebase Auth emulator sign-in check reported the account as registered, and Scenario 2 authenticated the same credentials after an explicit sign-out.

- [Registration form](scenario-1-registration-form.png)
- [Protected Home after registration](scenario-1-registration-home.png)

### Scenario 2 — Sign in using email and password: PASS

Marionette signed out, reopened email sign-in, entered the credentials created in Scenario 1, and submitted the form. The app returned to the protected Home page.

- [Sign-in form](scenario-2-sign-in-form.png)
- [Protected Home after sign-in](scenario-2-sign-in-home.png)

### Scenario 3 — Request a password reset: PASS

Marionette opened the password-reset page while signed out and submitted the registered address. The app returned to sign-in and displayed the neutral confirmation: “If an account exists for that email, a reset link has been sent.”

The flow was repeated with the unregistered address `qa.auth.unknown.20260914@example.com`. The visible confirmation was identical. The two confirmation PNGs are byte-identical and share SHA-256 `e1b5bea486fa242b013903c3e82ac8474a62774e81d9d14c1a020907118b1e8c`, confirming the UI does not disclose whether the account exists. The Firebase Auth emulator emitted a reset action only for the registered test account, as expected.

- [Password-reset form](scenario-3-password-reset-form.png)
- [Confirmation after registered email](scenario-3-reset-confirmation-registered.png)
- [Confirmation after unregistered email](scenario-3-reset-confirmation-unregistered.png)

## Notes

This verification used local emulators and did not create or modify accounts in the live Firebase project. No production source code was changed.
