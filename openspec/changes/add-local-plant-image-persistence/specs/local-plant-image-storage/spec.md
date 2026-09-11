## Purpose

Provide automatic, device-only retention of submitted processed plant images while preserving account isolation, original-image protections, transparent privacy disclosure, and the rule that image bytes never enter Firestore.

## ADDED Requirements

### Requirement: Submitted images are analyzed and retained automatically

The system SHALL NOT show a local-save toggle or require a pre-analysis consent checkbox. When a signed-in user submits a processed plant-identification or health-check photo, the system SHALL send it to Firebase AI for analysis and SHALL retain it locally after the associated successful persistence boundary defined for its flow.

#### Scenario: User submits an identification photo

- **WHEN** a signed-in user submits a processed plant-identification photo
- **THEN** the system sends it to Firebase AI without an additional confirmation step and retains it locally after the plant is created successfully

#### Scenario: User submits a health-check photo

- **WHEN** a signed-in user submits a processed health-check photo
- **THEN** the system sends it to Firebase AI without an additional confirmation step and retains it locally after the structured observation is saved successfully

#### Scenario: User cancels before submission

- **WHEN** a user selects a photo but cancels or removes it before submitting
- **THEN** the system neither sends the photo to Firebase AI nor retains it locally

### Requirement: Only the processed image may be retained

The system SHALL retain only the image produced by the existing processing pipeline: corrected orientation, existing maximum dimensions, existing JPEG quality or compression limits, and removed metadata. It SHALL NOT retain the untouched source image, Base64 representation, user-selected filename, or image bytes in Firestore.

#### Scenario: Processed image is saved

- **WHEN** local saving succeeds
- **THEN** the stored bytes are the processed JPEG bytes supplied by the image-processing boundary and contain no persisted source filename or image metadata record beyond local management metadata

#### Scenario: Firestore record is inspected

- **WHEN** a plant, observation, or diagnosis record is written or read
- **THEN** it contains no local image bytes, Base64 image data, absolute path, relative path, browser object URL, or local image URL

### Requirement: Platform storage is private and platform-appropriate

On Android and iOS, the system SHALL store retained images under an application-private support or documents directory, SHALL use generated opaque filenames, and SHALL expose no public-gallery copy by default. On web, the system SHALL keep retained images session-only and SHALL label them temporary; it SHALL NOT use browser localStorage or SharedPreferences to store image bytes.

#### Scenario: Native image is retained

- **WHEN** an Android or iOS image is saved locally
- **THEN** it is stored in application-private storage under an account-isolated namespace and is not automatically added to the public photo gallery

#### Scenario: Web image is retained

- **WHEN** a web image is saved locally
- **THEN** it remains available only for the current browser session and the UI identifies it as temporary

#### Scenario: App data is removed

- **WHEN** the operating system, user, browser, or app removes application data
- **THEN** local images MAY disappear and the UI handles that loss without treating the Firestore plant or observation record as invalid

### Requirement: Identification and health-check associations use successful persistence boundaries

The system SHALL associate each submitted identification image with its newly created plant as the local cover image only after plant creation succeeds. It SHALL associate each submitted health-check image with both `plantId` and the successfully saved `observationId` only after structured observation persistence succeeds. A failed preceding persistence operation SHALL NOT leave an orphan image.

#### Scenario: Identification plant creation succeeds

- **WHEN** a user confirms an identified plant and the plant profile is created successfully
- **THEN** the submitted processed image is saved as that plant's local cover image

#### Scenario: Identification plant creation fails

- **WHEN** plant creation fails after an image was selected for local saving
- **THEN** no local image file or metadata record is left for that attempted plant

#### Scenario: Health observation saves

- **WHEN** a health-check observation is accepted and its structured observation is saved successfully
- **THEN** the submitted processed image is saved with the returned plant and observation identifiers

#### Scenario: Health observation save fails

- **WHEN** the structured health-check observation cannot be saved
- **THEN** no local image is created for that attempted observation

#### Scenario: Diagnosis is retried

- **WHEN** a saved health-check observation is used for a diagnosis retry
- **THEN** the retry uses the structured saved observation and does not require, resend, or regenerate the local image

### Requirement: Local images can be viewed and managed without affecting cloud records

The system SHALL provide local-image previews, replace or delete actions, a missing-image placeholder, account-scoped storage-used information, and a confirmation-protected **Delete all local plant images** action. Deleting a local image SHALL NOT delete or modify its Firestore plant, observation, or diagnosis record.

#### Scenario: Local image exists

- **WHEN** a retained local image is available for a plant or observation
- **THEN** the relevant UI can preview it and offer a delete action without requiring a Firebase image URL

#### Scenario: Local image is missing or corrupt

- **WHEN** local metadata references a file that is missing or cannot be decoded
- **THEN** the UI shows a missing-image placeholder, the invalid local reference is safely handled or cleaned up, and the cloud history remains readable

#### Scenario: User deletes one image

- **WHEN** a user confirms deletion of one local image
- **THEN** that local image and its local metadata are removed while its associated Firestore records remain unchanged

#### Scenario: User deletes a plant

- **WHEN** a user deletes a plant
- **THEN** the system offers to remove that plant's local images and honors the user's choice without changing the cloud deletion semantics

#### Scenario: User deletes all local images

- **WHEN** a user confirms **Delete all local plant images**
- **THEN** all local images for the active account are removed and the account's storage-used value becomes zero or reflects only successfully retained entries

### Requirement: Local image data is isolated by account and lifecycle

The system SHALL prevent one signed-in account from viewing or managing another account's local images. Signing out SHALL hide the previous account's images, account deletion SHALL remove that account's local images through an account-scoped cleanup operation, and interrupted temporary files or orphaned metadata SHALL be detected and removed safely.

#### Scenario: Account changes on one device

- **WHEN** one account signs out and another account signs in on the same device
- **THEN** the second account cannot list, preview, calculate storage for, or delete the first account's local images

#### Scenario: Account deletion cleanup is invoked

- **WHEN** the account-scoped local-image cleanup operation is invoked for a deleted account
- **THEN** that account's local files and metadata are removed without affecting another account's namespace

#### Scenario: Interrupted write is discovered

- **WHEN** startup or lifecycle reconciliation finds temporary write files, metadata for missing files, or unindexed image files
- **THEN** those temporary or orphaned entries are removed without deleting valid indexed images from another account

### Requirement: Privacy disclosures describe local persistence accurately

The system SHALL explain before image submission and in Privacy & Safety that submitting sends the processed image to Firebase AI and automatically stores it on the device, does not synchronize it across devices, may lose it after uninstall or data clearing, removes image metadata, and does not copy the original image.

#### Scenario: User reviews the submission disclosure

- **WHEN** the user is shown the photo-submission screen
- **THEN** informational disclosure explains automatic Firebase AI processing, automatic device-only storage, no cross-device synchronization, possible permanent loss, and processed-image-only retention without presenting a consent checkbox or save toggle

#### Scenario: User opens Privacy & Safety

- **WHEN** the user opens Privacy & Safety
- **THEN** the page does not claim that PlantCare AI never saves images and instead describes automatic platform-specific local retention and Firebase AI processing
