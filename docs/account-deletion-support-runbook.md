# Account deletion support runbook

Owner before release: **[ASSIGN NAMED OPERATOR]**
Backup owner: **[ASSIGN BACKUP OPERATOR]**
Support mailbox: configured outside source with
`ACCOUNT_DELETION_SUPPORT_EMAIL`.

## Policy and deadlines

Acknowledge requests promptly. Use neutral language and do not disclose whether
an address has a PlantCare AI account. The 30-calendar-day completion clock
starts only after successful ownership verification. If ownership cannot be
verified, delete the correspondence no later than 30 days after the last
verification attempt, including mailbox trash where the provider permits, and
record that the mailbox retention setting was checked. The person may submit a
new request later.

Verified deletion removes Firebase Authentication and all PlantCare-controlled
plants, observations, diagnoses, soil checks, care logs, fertilizer
assessments, reminders, account notification metadata, and local images a
requesting device can access. Another inaccessible device must be cleared or
the app uninstalled by its user. Subscription cancellation is recommended when
relevant but is not required. Google Play and Adapty may retain their own
billing, transaction, fraud-prevention, tax, or legally required records.

## Self-service handoff

The client creates only `accountDeletionCleanupRequests/{uid}` with exactly:

```text
schemaVersion: 1
requestedAt: server timestamp
providerCleanup: ["adapty"]
source: "self_service_mobile" | "self_service_web"
```

It stores no email, entitlement, purchase history, plant content, image,
diagnosis, credential, token, or Firebase configuration. Rules allow only the
matching authenticated UID to create and deny all client reads, updates, and
deletes. A repeated acknowledged write in the same active client run is treated
as complete in memory. Any other repeat or uncertain acknowledgement stops
destructive work and directs the user to retry or support. Once acknowledged,
Firebase application and Authentication deletion does not wait for Adapty.

## Daily operator procedure

1. Confirm the intended Google Cloud/Firebase project and authorized operator
   credentials. Never use a checked-in service-account key.
2. Run the admin tool in dry-run and review only aggregate counts:

   ```sh
   npm --prefix tools/account_deletion_admin install
   npm --prefix tools/account_deletion_admin test
   npm --prefix tools/account_deletion_admin run process -- \
     --project=PROJECT_ID --confirm-project=PROJECT_ID
   ```

3. Escalate any pending request approaching or reaching 30 days.
4. After separate production approval, supply `ADAPTY_SECRET_API_KEY` in the
   operator environment and add `--apply --allow-production`. The tool uses the
   Adapty server-side API with the UID, writes the minimal audit, then removes
   the pending request. A provider or audit failure preserves the pending item.
   A provider `404` is safe idempotent completion. SDK logout is not deletion.
5. For support-managed Firebase deletion, verify ownership, record the request
   date, erase all known data child-first, verify empty server-side, delete Auth
   last, and record completion/failure. Escalate partial deletion; never claim
   completion from a client log alone.

The six allowed support-record fields are `requestIdentifier`,
`accountIdentifier` (or the minimally necessary verified-email reference),
`verificationStatus`, `requestDate`, `completionDate`, and `status`. Do not add
plant content, images, diagnoses, AI output, care history, subscription data,
credentials, tokens, or raw Firestore documents.

## Weekly 90-day purge

Run dry-run first. After separate production approval, repeat with `--apply
--allow-production`:

```sh
npm --prefix tools/account_deletion_admin run purge -- \
  --project=PROJECT_ID --confirm-project=PROJECT_ID
```

Only exact-schema completed records at least 90 days old are eligible. Malformed
or newer records are preserved for investigation. Store evidence containing
aggregate counts, timestamps, command version, operator name, and project name;
never store UIDs, email, tokens, or user content.

## Evidence and production hold

For every run, record operator, project, dry-run/apply mode, aggregate result,
pending deadline review, audit-before-pending-delete confirmation, purge cutoff,
and mailbox trash/retention check. The following remain prohibited without
separate owner approval: Hosting or Rules deployment, Play Console changes,
production admin-tool apply, production mailbox deletion, real-user processing,
credential creation, and repository push.
