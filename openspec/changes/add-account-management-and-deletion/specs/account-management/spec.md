## ADDED Requirements

### Requirement: Account is the fourth authenticated destination
The system SHALL provide Account as destination index 3 in narrow bottom navigation and wide navigation rail while preserving Home, My Plants, and Reminders at indices 0 through 2. Account SHALL contain a discoverable Privacy and data destination with Privacy Policy, Terms, and Delete account and data actions.

#### Scenario: Authenticated user opens Account on mobile
- **WHEN** an authenticated Android or iOS user selects Account
- **THEN** the system selects the fourth destination and exposes `Privacy and data -> Delete account and data`

#### Scenario: Existing shell actions remain available
- **WHEN** Account navigation is added
- **THEN** the established top-bar Premium, Privacy & Safety, and Sign out actions remain available

### Requirement: A public deletion resource works without authentication
The system SHALL expose `/account-deletion` outside authentication guards. It SHALL identify PlantCare AI prominently, work through direct Firebase Hosting navigation and refresh, and remain responsive and accessible on mobile and desktop browsers. It SHALL provide a signed-in self-service path and a signed-out support-request path without requiring app download or reinstallation.

#### Scenario: Signed-out direct navigation
- **WHEN** a signed-out visitor directly loads or refreshes `/account-deletion`
- **THEN** the page loads without redirecting to Sign in and displays both sign-in and support-request options

#### Scenario: Session changes on the public route
- **WHEN** a visitor signs in from `/account-deletion`
- **THEN** the route remains open and changes to the authenticated deletion state instead of redirecting to Home

#### Scenario: Public route is accessible
- **WHEN** the page is used on a narrow browser, desktop browser, large text setting, or assistive technology
- **THEN** its controls, headings, warnings, status, and legal links remain understandable and operable

### Requirement: Public support requests use validated configuration
The system SHALL derive the support mailto destination from `ACCOUNT_DELETION_SUPPORT_EMAIL`. It SHALL validate a single safe mailbox address and construct the fixed subject `PlantCare AI account deletion request` and approved suggested body with correct URI encoding. Missing or invalid configuration SHALL show a clear configuration error rather than an invented or broken address.

#### Scenario: Configured support request
- **WHEN** a signed-out visitor chooses the support option and the email is valid
- **THEN** the system opens a mailto draft with the fixed subject and approved body warning the user not to send passwords, authentication tokens, payment details, or other credentials

#### Scenario: Missing or invalid support email
- **WHEN** `ACCOUNT_DELETION_SUPPORT_EMAIL` is missing, malformed, contains control characters, or attempts multiple recipients or query injection
- **THEN** the system shows a configuration error and does not expose a fake or unsafe destination

#### Scenario: Support messaging is neutral
- **WHEN** a visitor initiates or discusses a support request
- **THEN** the system says only that the request starts an ownership-verification process and does not reveal whether an email address is registered

### Requirement: Deletion and retention disclosures are accurate
The public page, Privacy & Safety content, and support documentation SHALL consistently state that requests are acknowledged promptly; a verified request is completed within 30 calendar days after successful ownership verification; PlantCare retains no listed account or application content after completed deletion; a minimal completed support record may be retained for at most 90 days; and unverifiable correspondence is deleted no later than 30 days after the last verification attempt.

#### Scenario: Visitor reviews deletion scope
- **WHEN** deletion information is displayed
- **THEN** it lists Firebase Authentication identity, plants, observations, diagnoses, soil checks, care logs, fertilizer assessments, reminders, account-scoped notification metadata, and locally stored images accessible to the requesting device

#### Scenario: Visitor reviews retained records
- **WHEN** retention information is displayed
- **THEN** it distinguishes the minimal PlantCare support record from provider-controlled records and states the 90-day permanent purge limit

#### Scenario: Ownership cannot be verified
- **WHEN** support cannot verify account ownership
- **THEN** correspondence is retained for no more than 30 days after the last verification attempt, then deleted, and the person may submit a new request later

#### Scenario: Local-only data is inaccessible
- **WHEN** data remains only on another device PlantCare cannot access
- **THEN** the disclosure explains that the user must clear application data or uninstall PlantCare AI on that device

### Requirement: Subscription cancellation is separate and non-blocking
The system SHALL explain that deleting PlantCare AI does not cancel a Google Play subscription and that deleting or uninstalling the app alone does not cancel it. It SHALL provide `https://play.google.com/store/account/subscriptions`, recommend cancellation when relevant, require acknowledgement of the warning, and never require cancellation or proof of cancellation before deletion.

#### Scenario: Android Premium is known active
- **WHEN** an optional Android-only lookup confirms active Premium
- **THEN** the system shows a prominent tailored warning and management link but still permits deletion after acknowledgement

#### Scenario: Subscription status is unknown
- **WHEN** Adapty fails, times out, is unavailable, is unconfigured, or returns unknown entitlement
- **THEN** the system shows the generic warning and permits deletion after acknowledgement

#### Scenario: Web or iOS displays deletion
- **WHEN** deletion UI runs on web or iOS
- **THEN** the system makes no Adapty call, shows the generic warning to every user, and permits deletion after acknowledgement

#### Scenario: Provider retention is disclosed
- **WHEN** retention information is displayed
- **THEN** the system explains that Google Play and Adapty may retain billing, transaction, fraud-prevention, tax, or legally required records under their policies and that those records are not PlantCare application data

### Requirement: Destructive confirmation is explicit
The system SHALL explain permanence, list deleted data, show and require acknowledgement of the subscription warning, and require the user to type exactly case-sensitive `DELETE` before reauthentication can begin. Destructive actions SHALL use clear destructive styling and accessible labels.

#### Scenario: Confirmation text does not match
- **WHEN** the user enters any value other than exact `DELETE` or has not acknowledged the warning
- **THEN** the destructive continuation remains disabled

#### Scenario: Confirmation is complete
- **WHEN** the warning is acknowledged and the user enters exact `DELETE`
- **THEN** the system permits provider-aware reauthentication but has not yet deleted data

### Requirement: Recent authentication matches a linked provider
The system SHALL inspect the current Firebase user's linked providers and obtain recent authentication before erasing data. Email/password accounts SHALL use the current Firebase email with the entered current password. Google accounts SHALL use Google provider reauthentication and SHALL never request a Google password. Accounts with both methods SHALL allow either linked method.

#### Scenario: Email/password reauthentication succeeds
- **WHEN** a linked password user enters correct credentials
- **THEN** Firebase recent authentication is established and deletion may begin

#### Scenario: Google reauthentication succeeds
- **WHEN** a linked Google user explicitly selects and verifies the same Firebase-linked Google identity
- **THEN** recent authentication is established without collecting a Google password

#### Scenario: Reauthentication is cancelled or fails
- **WHEN** provider selection is cancelled, credentials are wrong, the selected provider is unlinked, recent login is still required, or the network fails
- **THEN** no destructive work begins and the system presents a nontechnical retry path

### Requirement: The deletion repository derives the active identity
The domain account-deletion contract and Firebase implementation SHALL derive UID and provider information from the current authenticated Firebase session at every privileged stage. UI and BLoC APIs SHALL NOT select an arbitrary UID, and identity change during the flow SHALL stop deletion safely.

#### Scenario: Caller attempts cross-user selection
- **WHEN** a caller possesses another user's identifier
- **THEN** the repository still operates only on the authenticated Firebase user's namespace

#### Scenario: Active identity changes
- **WHEN** the authenticated UID changes between confirmation and a destructive stage
- **THEN** the workflow stops without operating on the new or prior user's remaining data

### Requirement: Self-service deletion records an authenticated provider-cleanup handoff
After successful recent reauthentication and before deleting any Firestore application data or Firebase Authentication identity, the system SHALL create `accountDeletionCleanupRequests/{uid}`, where the document ID is the authenticated Firebase UID derived by the repository. The document SHALL contain exactly `schemaVersion`, `requestedAt`, `providerCleanup`, and `source`. `schemaVersion` SHALL be `1`, `requestedAt` SHALL be the server request timestamp, `providerCleanup` SHALL be exactly `["adapty"]`, and `source` SHALL be `self_service_mobile` or `self_service_web` according to the initiating surface.

The request SHALL NOT contain email, entitlement or subscription status, purchase information or history, plant data, images, diagnoses, credentials, tokens, Firebase configuration, or any additional field. A successfully recorded handoff SHALL allow Firebase application-data and Authentication deletion to continue without waiting for Adapty API completion.

#### Scenario: Mobile handoff is recorded
- **WHEN** an authenticated Android or iOS user successfully reauthenticates for self-service deletion
- **THEN** the system records the exact UID-keyed request with source `self_service_mobile` before deleting application data

#### Scenario: Web handoff is recorded without Adapty SDK use
- **WHEN** an authenticated web user successfully reauthenticates for self-service deletion
- **THEN** the system records the exact UID-keyed request with source `self_service_web` without initializing or calling the Adapty SDK

#### Scenario: Request creation succeeds
- **WHEN** Firestore acknowledges creation of the provider-cleanup request
- **THEN** the workflow may begin application-data erasure and does not wait for the trusted Adapty API operation

#### Scenario: Request creation fails or is unconfirmed
- **WHEN** the active workflow does not observe an acknowledged create
- **THEN** no Firestore application data or Firebase Authentication identity is deleted, the UI does not claim Adapty cleanup is queued or complete, and retry plus the configured support-email path are offered

#### Scenario: A request already exists
- **WHEN** creation is repeated for the same authenticated UID
- **THEN** no duplicate is created and the existing request is not read, updated, deleted, or assigned a new timestamp; the workflow continues only if it already observed the successful creation in the active run, otherwise it uses the unconfirmed-request fallback

### Requirement: Remote erasure is bounded, child-first, and verified
After recent authentication and acknowledged provider-cleanup request creation, the system SHALL delete every known PlantCare-controlled Firestore application record in bounded, repeatable work before Auth deletion. The pending provider-cleanup request is an approved limited support/admin handoff and SHALL NOT be removed by the client deletion engine. Diagnoses SHALL be deleted before observations; all descendant collections SHALL be deleted before plants. Production reads SHALL be server-backed, batches SHALL remain below Firestore's limit, and every known application-data path SHALL be verified empty before continuing. Curated knowledge SHALL never be read for deletion or mutated.

#### Scenario: Complete account history is erased
- **WHEN** an account contains plants, observations, diagnoses, soil checks, care logs, fertilizer assessments, and reminders
- **THEN** every descendant is deleted before its parent and all known user-owned paths verify empty

#### Scenario: Work exceeds one page or batch
- **WHEN** a collection has more records than one query page or safe write batch
- **THEN** the system continues bounded pagination and acknowledged commits until the collection is empty

#### Scenario: Retry finds missing documents
- **WHEN** a prior attempt already removed some documents
- **THEN** missing documents count as completed work and retry continues without recreating anything

#### Scenario: Remote erasure or verification fails
- **WHEN** a query, commit, or final verification fails
- **THEN** Firebase Auth remains intact and the system reports incomplete deletion with retry

#### Scenario: Curated knowledge exists
- **WHEN** account deletion runs
- **THEN** knowledge chunks, sources, datasets, and release documents remain untouched

### Requirement: Security Rules permit only owner erasure
Firestore Rules SHALL allow an authenticated owner to delete every supported user-owned descendant needed by the child-first sequence, including reminders while their plant exists. Rules SHALL allow only `request.auth.uid == uid` to create `accountDeletionCleanupRequests/{uid}` with the exact approved fields and values, including `requestedAt == request.time`. Clients SHALL NOT read, list, update, or delete cleanup requests. Rules SHALL reject unauthenticated and cross-user creation, keep curated knowledge client-unwritable, and deny all client access to admin completion/support records.

#### Scenario: Owner deletes reminder before plant
- **WHEN** the authenticated owner deletes a reminder whose parent plant exists
- **THEN** Rules allow the delete

#### Scenario: Cross-user or unauthenticated delete is attempted
- **WHEN** a different or signed-out client attempts to delete user data
- **THEN** Rules deny the operation

#### Scenario: Owner creates an exact cleanup request
- **WHEN** an authenticated user creates `accountDeletionCleanupRequests/{theirUid}` with the exact approved schema, server timestamp, provider list, and source
- **THEN** Rules allow the create

#### Scenario: Cleanup request shape or owner is invalid
- **WHEN** a signed-out user, different UID, extra or missing field, non-server timestamp, unsupported provider list, or unsupported source attempts creation
- **THEN** Rules deny the create

#### Scenario: Client accesses an existing cleanup or support record
- **WHEN** any client attempts to read, list, update, or delete a cleanup request, or create, read, update, or delete an admin completion/support record
- **THEN** Rules deny the operation

#### Scenario: Client mutates curated knowledge
- **WHEN** any client attempts to create, update, or delete curated knowledge
- **THEN** Rules deny the operation

### Requirement: Current-device cleanup precedes Auth deletion
After remote verification, the system SHALL remove account-scoped local images, notification identifiers, pending local notifications, and other identified user-specific caches accessible on the current device. Cleanup SHALL be UID-scoped and idempotent. Unsupported scheduling SHALL not prevent removal of stored notification metadata.

#### Scenario: Current-device cleanup succeeds
- **WHEN** remote deletion completes
- **THEN** local images, notification metadata, scheduled notifications, and identified caches for the deleting UID are cleared before Auth deletion

#### Scenario: Local cleanup fails
- **WHEN** required cleanup cannot finish
- **THEN** Firebase Auth remains intact, another account's namespace remains untouched, and retry is available

#### Scenario: Web session images exist
- **WHEN** authenticated web deletion completes remote erasure
- **THEN** the current user's session-only image memory is cleared before Auth deletion

### Requirement: Firebase Authentication is deleted last
The system SHALL delete the current Firebase Authentication user only after recent authentication, acknowledged provider-cleanup request creation, remote application-data erasure, remote verification, and required current-device cleanup succeed. Completion SHALL be reported only after Auth deletion succeeds and the session becomes signed out. It SHALL NOT wait for trusted Adapty API completion after the handoff has been recorded.

#### Scenario: Full self-service deletion succeeds
- **WHEN** every required stage completes
- **THEN** the system enters signed-out state, shows a fixed completion notice, and does not automatically invoke Google or recreate the account

#### Scenario: Auth deletion fails after data cleanup
- **WHEN** Firebase Auth deletion fails after remote and local data are gone
- **THEN** the user remains authenticated, sees an honest partial-failure state, can reauthenticate and retry Auth deletion, and is not shown completion

### Requirement: Destructive progress is singular and accessible
The system SHALL expose initial explanation, awaiting confirmation, subscription warning, reauthentication required, reauthentication in progress, provider-cleanup request recording, cleanup-request failure with retry/support fallback, deletion in progress, partial failure with retry, complete, support request, invalid support configuration, offline/network failure, signed-out public, and authenticated public states. It SHALL prevent duplicate submission and expose status semantics on narrow, wide, and large-text layouts.

#### Scenario: User submits twice
- **WHEN** a deletion sequence is busy and the action is activated again
- **THEN** the duplicate is ignored and at most one sequence operates on the account

#### Scenario: User attempts to leave during deletion
- **WHEN** destructive work has begun
- **THEN** the UI keeps progress visible or presents an interruption warning without implying already completed work was cancelled

#### Scenario: Assistive technology observes state changes
- **WHEN** the workflow moves between reauthentication, deletion, partial failure, and completion
- **THEN** meaningful semantic status announcements are exposed

### Requirement: Sensitive information is never logged or persisted in support records
The system SHALL NOT log passwords, tokens, image bytes, Firebase configuration, prompts, private document contents, raw Firestore documents, or payment details. The pending cleanup request SHALL contain only its approved four fields. The minimal completion/support record SHALL contain only the approved identifiers, verification state, request/completion dates, and completion/failure status.

#### Scenario: A deletion operation fails
- **WHEN** an implementation logs diagnostic information
- **THEN** it records only safe operation names, error codes or categories, and non-sensitive identifiers necessary for support

### Requirement: Verified support deletion follows enforceable deadlines
Support SHALL acknowledge requests promptly and complete verified deletion within 30 calendar days after successful ownership verification. Each pending provider-cleanup request SHALL be processed within 30 days. The trusted admin tool SHALL use the Adapty server API for the UID, record the approved minimal completion status, and remove the pending request after recording the outcome. Firebase account/application deletion SHALL not wait for Adapty API completion after successful handoff creation, and SDK logout SHALL never be represented as profile deletion.

#### Scenario: Ownership is verified
- **WHEN** support successfully verifies a requester
- **THEN** the operator records the verification date and completes PlantCare-controlled deletion no later than 30 calendar days afterward

#### Scenario: Adapty cleanup is delayed or fails
- **WHEN** the trusted Adapty operation cannot complete immediately
- **THEN** Firebase account/application deletion still proceeds after the recorded handoff and Adapty cleanup remains tracked within the 30-day support deadline

#### Scenario: Admin completes pending provider cleanup
- **WHEN** the trusted admin tool processes a pending cleanup request
- **THEN** it calls the Adapty server API without exposing its secret to a client, records minimal completion/failure status, and removes the pending request only after that status is recorded

### Requirement: Minimal support records are purged
The admin process SHALL retain only an opaque request identifier, account identifier or minimally necessary verified-email reference, verification status, request date, completion date, and completion/failure status. Completed records SHALL be permanently deleted after at most 90 days. The purge operation SHALL default to dry-run, validate record shape and cutoff eligibility, require an explicit apply action, and report its results without private content.

#### Scenario: Completed record reaches 90 days
- **WHEN** a completed support record is at or beyond the approved cutoff
- **THEN** the purge process identifies it in dry-run and permanently removes it only after explicit application

#### Scenario: Record is too new or incomplete
- **WHEN** a record has not reached its retention cutoff or lacks safe eligibility evidence
- **THEN** the purge process leaves it untouched and reports why without exposing sensitive content

#### Scenario: Unverified correspondence reaches its cutoff
- **WHEN** 30 days have passed since the last failed verification attempt
- **THEN** the documented operator procedure permanently removes the correspondence from the support mailbox and verifies the provider's trash/retention behavior

### Requirement: Legal destinations remain available
The Account and public deletion pages SHALL expose the configured Privacy Policy and Terms as validated absolute HTTPS destinations. Missing, malformed, or failed destinations SHALL produce visible nontechnical errors rather than hidden actions.

#### Scenario: Legal URL is configured
- **WHEN** a user chooses Privacy Policy or Terms
- **THEN** the approved HTTPS destination opens externally

#### Scenario: Legal URL is unavailable
- **WHEN** configuration or launching fails
- **THEN** the page stays usable and reports that the selected legal document is unavailable for this build
