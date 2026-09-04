import { readFile } from "node:fs/promises";
import { createInterface } from "node:readline/promises";
import { resolve, sep } from "node:path";
import { stdin, stdout } from "node:process";

import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import {
  APPROVED_PROJECT_ID,
  DATASET_VERSION,
  SCHEMA_VERSION,
} from "./constants.js";
import { loadDataset } from "./data.js";
import { executePlan, planIngestion, type DocumentData } from "./planner.js";
import { assertIngestionPolicy } from "./policy.js";

interface Options {
  projectId: string | undefined;
  productionWrite: boolean;
  nonInteractiveConfirmation: string | undefined;
  credentialPath: string | undefined;
  reportStale: boolean;
}

function parseOptions(args: readonly string[]): Options {
  const options: Options = {
    projectId: undefined,
    productionWrite: false,
    nonInteractiveConfirmation: undefined,
    credentialPath: undefined,
    reportStale: false,
  };
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === "--project") options.projectId = args[++index];
    else if (arg === "--write-production") options.productionWrite = true;
    else if (arg === "--non-interactive-confirm")
      options.nonInteractiveConfirmation = args[++index];
    else if (arg === "--credential") options.credentialPath = args[++index];
    else if (arg === "--report-stale") options.reportStale = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return options;
}

async function interactiveConfirmation(): Promise<string | undefined> {
  if (!stdin.isTTY) return undefined;
  const readline = createInterface({ input: stdin, output: stdout });
  try {
    return await readline.question(
      `Type "ingest ${APPROVED_PROJECT_ID}" to continue: `,
    );
  } finally {
    readline.close();
  }
}

const firestoreData = (data: DocumentData): DocumentData =>
  Object.fromEntries(
    Object.entries(data).map(([key, value]) => [
      key,
      key === "createdAt" || key === "updatedAt" || key === "accessedAt"
        ? Timestamp.fromDate(new Date(String(value)))
        : value,
    ]),
  );

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const dataset = await loadDataset();
  let confirmation = options.nonInteractiveConfirmation;
  if (options.productionWrite && !confirmation)
    confirmation = await interactiveConfirmation();
  assertIngestionPolicy({
    projectId: options.projectId,
    productionWrite: options.productionWrite,
    ...(confirmation ? { confirmation } : {}),
  });
  const projectId = options.projectId;
  if (!projectId) throw new Error("An explicit --project ID is required.");

  console.log(`Target project: ${projectId}`);
  console.log(
    `Dataset version: ${DATASET_VERSION}; schema version: ${SCHEMA_VERSION}`,
  );
  console.log(
    `Mode: ${options.productionWrite ? "PRODUCTION WRITE" : "DRY RUN"}`,
  );

  if (!options.productionWrite && !options.reportStale) {
    const plan = planIngestion(dataset);
    const result = await executePlan(plan, async () => {}, false);
    console.log(
      `Validated ${Object.keys(dataset.sources).length} sources and ${dataset.chunks.length} chunks.`,
    );
    console.log(
      `Planned: created=${result.created}, updated=${result.updated}, unchanged=${result.unchanged}, failed=${result.failed}.`,
    );
    return;
  }

  let credential = applicationDefault();
  if (options.credentialPath) {
    const credentialPath = resolve(options.credentialPath);
    const repositoryRoot = resolve(
      new URL("../../..", import.meta.url).pathname,
    );
    if (
      credentialPath === repositoryRoot ||
      credentialPath.startsWith(`${repositoryRoot}${sep}`)
    ) {
      throw new Error(
        "The service-account credential must be stored outside the repository.",
      );
    }
    credential = cert(JSON.parse(await readFile(credentialPath, "utf8")));
  }
  const app = getApps()[0] ?? initializeApp({ credential, projectId });
  const firestore = getFirestore(app);
  const [sourcesSnapshot, chunksSnapshot] = await Promise.all([
    firestore.collection("knowledgeSources").get(),
    firestore.collection("knowledgeChunks").get(),
  ]);
  const existingSources = new Map(
    sourcesSnapshot.docs.map(
      (document) => [document.id, document.data()] as const,
    ),
  );
  const existingChunks = new Map(
    chunksSnapshot.docs.map(
      (document) => [document.id, document.data()] as const,
    ),
  );
  const plan = planIngestion(dataset, existingSources, existingChunks);

  if (options.reportStale) {
    console.log(
      `Stale knowledgeSources (${plan.staleSourceIds.length}): ${plan.staleSourceIds.join(", ") || "none"}`,
    );
    console.log(
      `Stale knowledgeChunks (${plan.staleChunkIds.length}): ${plan.staleChunkIds.join(", ") || "none"}`,
    );
    console.log("No stale documents were deleted.");
  }
  if (!options.productionWrite) return;

  const result = await executePlan(
    plan,
    async (writes) => {
      const batch = firestore.batch();
      for (const write of writes) {
        batch.set(
          firestore.collection(write.collection).doc(write.id),
          firestoreData(write.data),
        );
      }
      await batch.commit();
    },
    true,
  );
  console.log(
    `Completed: created=${result.created}, updated=${result.updated}, unchanged=${result.unchanged}, failed=${result.failed}.`,
  );
  if (result.failed > 0) process.exitCode = 1;
}

main().catch((error: unknown) => {
  console.error(
    error instanceof Error ? error.message : "Knowledge ingestion failed.",
  );
  process.exitCode = 1;
});
