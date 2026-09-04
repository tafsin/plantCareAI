# PlantCare AI knowledge ingestion

This standalone TypeScript tool validates and optionally writes the curated
PlantCare AI knowledge dataset. It uses the Firebase Admin SDK only here; no
Admin dependency or credential is included in the Flutter application.

## Dataset and schema

`data/sources.json` is a manifest keyed by stable source ID.
`data/knowledge_chunks.json` contains focused paraphrased chunks. The single
authoritative Zod implementation in `src/schema.ts` rejects unknown fields and
enforces schema version 1 and dataset version `2026-09-03-v1`.

Chunk constraints include:

- one of the five allowlisted canonical plant keys and knowledge categories;
- an optional schema-level `issueKey` that is required by the deterministic ID
  function for this production dataset;
- `indoor` and/or `outdoor` environments plus allowlisted affected parts and
  growth stages;
- at most 12 unique aliases, 15 normalized symptom keywords, 8 cautions, and 5
  existing source IDs;
- a title of at most 140 characters and content from 100 through 900
  characters;
- trimmed non-empty text, unique arrays, HTTPS source URLs, parseable dates,
  reviewed status, and no extra fields.

Chunk document IDs are
`canonicalPlantKey__category__issueKey`. Wording changes therefore update the
same logical Firestore record instead of creating a content-hash duplicate.
Source IDs are the manifest keys. JSON timestamps are validated ISO date-times
and converted to Firestore timestamps during writes.

## Review workflow

Before changing production content:

1. Open and read every proposed authoritative source page.
2. Add its exact title, publisher, HTTPS URL, and current access timestamp to
   `sources.json`.
3. Paraphrase focused facts; do not copy passages, tables, dosage instructions,
   or marketing claims.
4. Reference every supporting source ID and include uncertainty or safety
   cautions where appropriate.
5. Increment the dataset version for a reviewed release and update the literal
   in `src/constants.ts`, every data record, and tests.
6. Run every check below and review the dry-run counts before any write.

## Install and verify

Requires a maintained Node.js LTS release and Firebase CLI Java runtime for the
repository-level rules suite.

```sh
cd tools/knowledge_ingestion
npm install
npm run format:check
npm run build
npm test
npm run validate
npm run dry-run
```

Both `validate` and `dry-run` explicitly target the approved development
project but make no network request and perform no write. To test client access
rules, return to the repository root and run:

```sh
npm install
npm run test:rules
```

Rules Unit Testing seeds knowledge through its administrative context. The
tests prove authenticated reads, denied guest reads, denied client writes, and
continued plant and observation ownership behavior.

## Authentication

Application Default Credentials are recommended:

```sh
gcloud auth application-default login
```

Alternatively, manually download a narrowly controlled service-account JSON,
store it outside this repository, and pass its absolute path with
`--credential`. The tool rejects credential paths inside the repository. It
never downloads a key, embeds credentials, or prints credential contents.
The Admin principal must have only the Firestore permissions required by your
organization's ingestion process.

## Production ingestion

Interactive write to the only approved project:

```sh
npm exec tsx src/cli.ts -- \
  --project plantcare-ai-dev-tasnimalam \
  --write-production
```

Type the complete prompt value exactly:

```text
ingest plantcare-ai-dev-tasnimalam
```

With a credential file outside the repository:

```sh
npm exec tsx src/cli.ts -- \
  --project plantcare-ai-dev-tasnimalam \
  --credential /absolute/outside/repository/service-account.json \
  --write-production
```

For deliberate noninteractive automation only:

```sh
npm exec tsx src/cli.ts -- \
  --project plantcare-ai-dev-tasnimalam \
  --write-production \
  --non-interactive-confirm "ingest plantcare-ai-dev-tasnimalam"
```

The command validates the complete dataset before Firebase initialization,
prints the target project and versions, compares deterministic IDs, and writes
creates/updates in batches of at most 400. Re-running identical data reports it
as unchanged. It reports created, updated, unchanged, and failed counts.

To report documents present in Firestore but absent from the current dataset:

```sh
npm exec tsx src/cli.ts -- \
  --project plantcare-ai-dev-tasnimalam \
  --report-stale
```

This requires credentials because it reads Firestore. It reports IDs only and
never deletes anything. Curated knowledge can only be changed through an
authorized Admin workflow because client Security Rules deny all writes.
