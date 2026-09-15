# Plant workflow verification report

Date: 2026-09-14

## Environment

- Device: Pixel 4 API 34 Android emulator (`emulator-5554`)
- Runtime: `qemu-system-aarch64`, Android 14, ARM64
- App: Flutter debug build with Marionette binding
- Backend: local Firebase Authentication and Firestore emulators
- Firebase app project namespace: `plantcare-ai-dev-tasnimalam`
- Test account: `qa.plants.20260914.1555@example.com`
- Test UID: `vHemHvVA3Ql04lcRe09yLFStiG98`

All UI actions were driven through Marionette MCP. Firestore assertions were made through authenticated Firestore emulator REST reads.

## Results

### Scenario 1 — View an empty plant collection: PASS

The authenticated user opened My Plants with no saved documents. The “No plants yet” empty state was displayed. Selecting Add plant opened the creation chooser with “Identify from photo,” “Take a photo,” and “Add manually.”

- [Empty My Plants state](scenario-1-empty-plant-collection.png)
- [Manual and photo creation options](scenario-1-creation-options.png)

### Scenario 2 — Add a plant manually: PASS

Marionette opened manual creation and supplied:

- Common name: Patio Tomato
- Scientific name: Solanum lycopersicum
- Environment: Outdoor
- Growing medium: Pot
- Pot size: 12.5 L
- Sunlight: Full sun
- Growth stage: Flowering

After submission, Plant Details opened and the plant appeared in My Plants. An authenticated emulator read found exactly one document at:

`users/vHemHvVA3Ql04lcRe09yLFStiG98/plants/yBwikWqTD38CBsyxkASM`

The document contained Firestore timestamp values for both `createdAt` and `updatedAt`, initially `2026-09-14T21:58:56.693Z`.

- [Valid form — names](scenario-2-valid-plant-form-names.png)
- [Valid form — growing profile](scenario-2-valid-plant-form.png)
- [Plant Details — header](scenario-2-plant-details-top.png)
- [Plant Details — saved profile](scenario-2-plant-details-profile.png)
- [Saved plant in My Plants](scenario-2-my-plants-saved.png)

### Scenario 3 — Reject an invalid plant form: PASS

The form was submitted with the required common name missing and pot size set to `-1`. Inline validation displayed:

- “Enter a common name.”
- “Enter a number greater than 0 and no more than 10,000.”

The scenario was replayed after the valid plant was deleted. An authenticated Firestore collection read returned zero documents, proving the invalid submission did not save a document.

- [Inline validation errors](scenario-3-invalid-plant-validation.png)

### Scenario 4 — Edit an existing plant: PASS

Marionette edited the saved plant:

- Common name: Patio Tomato Updated
- Pot size: 15 L
- Sunlight: Partial sun
- Growth stage: Fruiting

Plant Details displayed the updated name. Firestore retained the same document path and original `createdAt` value (`2026-09-14T21:58:56.693Z`) while `updatedAt` advanced to `2026-09-14T22:01:44.705Z`.

- [Edit form — changed name](scenario-4-edit-form-name.png)
- [Edit form — changed profile](scenario-4-edit-form-profile.png)
- [Plant Details after update](scenario-4-plant-details-updated.png)

### Scenario 5 — Delete an existing plant: PASS

Requesting deletion displayed a confirmation dialog with Cancel, delete while keeping local images, and delete with local images options. Marionette confirmed “Delete, keep local images.” The app returned safely to the empty My Plants state.

An authenticated Firestore read returned `NOT_FOUND` for the former document and the plant collection contained zero documents.

- [Delete confirmation dialog](scenario-5-delete-confirmation-dialog.png)
- [Safe empty My Plants destination after deletion](scenario-5-after-delete-safe-empty.png)

## Backend evidence

The captured document path, create/edit timestamps, preservation checks, invalid-submit count, and post-delete checks are recorded in [backend-evidence.json](backend-evidence.json).

## Conclusion

All requested scenarios were proven. No remediation plan is required.

This verification used local emulators and did not create or modify data in the live Firebase project. No production source code was changed.
