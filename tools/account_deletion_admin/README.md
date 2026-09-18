# Account deletion admin tool

This trusted local operator tool uses Application Default Credentials. It never
belongs in the Flutter client and contains no service-account or Adapty secret.
It defaults to dry-run, requires matching `--project` and `--confirm-project`,
and refuses a non-demo apply unless the separately approved
`--allow-production` flag is present.

```sh
npm --prefix tools/account_deletion_admin install
npm --prefix tools/account_deletion_admin test
npm --prefix tools/account_deletion_admin run process -- --project=demo-plantcare-ai --confirm-project=demo-plantcare-ai
npm --prefix tools/account_deletion_admin run purge -- --project=demo-plantcare-ai --confirm-project=demo-plantcare-ai
```

After separate production approval, an authorized operator supplies
`ADAPTY_SECRET_API_KEY` only in the process environment and adds `--apply`.
The tool calls Adapty's server-side `DELETE /api/v2/server-side-api/profile/`
using the Firebase UID as `adapty-customer-user-id`. A `204` or `404` is
idempotent success. It writes only the six approved support-record fields and
then deletes the pending request. Provider or audit failures preserve the
pending request for retry. SDK logout is only identity reset and is not profile
deletion.

Run `process-pending` at least daily. Any request at 30 days is reported as
overdue and must be escalated. Run `purge` at least weekly; completed records at
90 days are eligible, and deletion requires `--apply`. Output contains counts,
not UIDs, emails, tokens, or document content.
