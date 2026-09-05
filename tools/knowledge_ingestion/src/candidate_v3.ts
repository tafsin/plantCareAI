import { readFile } from "node:fs/promises";

import { z } from "zod";

import { DATASET_VERSION } from "./constants.js";
import { loadDataset } from "./data.js";
import { chunkDocumentId } from "./ids.js";
import { executePlan, planIngestion } from "./planner.js";
import {
  validateDataset,
  type KnowledgeChunk,
  type KnowledgeDataset,
  type KnowledgeSource,
} from "./schema.js";

export const CANDIDATE_DATASET_VERSION = "2026-09-05-v3-candidate" as const;
export const PROMOTED_DATASET_VERSION = "2026-09-05-v3" as const;

export type CandidateKnowledgeSource = Omit<
  KnowledgeSource,
  "datasetVersion"
> & {
  readonly datasetVersion: typeof CANDIDATE_DATASET_VERSION;
};
export type CandidateKnowledgeChunk = Omit<KnowledgeChunk, "datasetVersion"> & {
  readonly datasetVersion: typeof CANDIDATE_DATASET_VERSION;
};
export interface CandidateKnowledgeDataset {
  readonly sources: Readonly<Record<string, CandidateKnowledgeSource>>;
  readonly chunks: readonly CandidateKnowledgeChunk[];
}

const manifestSchema = z
  .object({
    schemaVersion: z.literal(1),
    datasetVersion: z.literal(CANDIDATE_DATASET_VERSION),
    baseDatasetVersion: z.literal(DATASET_VERSION),
    sources: z.record(z.string(), z.unknown()),
    chunks: z.array(z.unknown()).min(1),
  })
  .strict();

const dataUrl = new URL("../data/candidate_v3.json", import.meta.url);

const withDatasetVersion = (
  value: Readonly<Record<string, unknown>>,
  datasetVersion: string,
): Record<string, unknown> => ({ ...value, datasetVersion });

const assertCandidateVersion = (
  values: readonly Readonly<Record<string, unknown>>[],
): void => {
  for (const value of values) {
    if (value.datasetVersion !== CANDIDATE_DATASET_VERSION) {
      throw new Error(
        `Candidate record has dataset version ${String(value.datasetVersion)}.`,
      );
    }
  }
};

/**
 * Builds the candidate as an in-memory overlay. Production files and constants
 * remain on v2, so the normal ingestion CLI cannot select this candidate.
 */
export async function loadCandidateV3(): Promise<CandidateKnowledgeDataset> {
  const [base, candidateText] = await Promise.all([
    loadDataset(),
    readFile(dataUrl, "utf8"),
  ]);
  const manifest = manifestSchema.parse(JSON.parse(candidateText));
  const candidateSources = Object.values(manifest.sources) as Readonly<
    Record<string, unknown>
  >[];
  const candidateChunks = manifest.chunks as Readonly<
    Record<string, unknown>
  >[];
  assertCandidateVersion([...candidateSources, ...candidateChunks]);

  const promotedSources = Object.fromEntries(
    Object.entries(base.sources).map(([id, source]) => [
      id,
      withDatasetVersion(source, DATASET_VERSION),
    ]),
  );
  for (const [id, source] of Object.entries(manifest.sources)) {
    if (id in promotedSources) {
      throw new Error(
        `Candidate source ID duplicates production source ${id}.`,
      );
    }
    promotedSources[id] = withDatasetVersion(
      source as Readonly<Record<string, unknown>>,
      DATASET_VERSION,
    );
  }

  const promotedChunks = [
    ...base.chunks.map((chunk) => withDatasetVersion(chunk, DATASET_VERSION)),
    ...candidateChunks.map((chunk) =>
      withDatasetVersion(chunk, DATASET_VERSION),
    ),
  ];
  const structurallyValidated = validateDataset(
    promotedSources,
    promotedChunks,
  );

  return {
    sources: Object.fromEntries(
      Object.entries(structurallyValidated.sources).map(([id, source]) => [
        id,
        withDatasetVersion(source, CANDIDATE_DATASET_VERSION),
      ]),
    ),
    chunks: structurallyValidated.chunks.map((chunk) =>
      withDatasetVersion(chunk, CANDIDATE_DATASET_VERSION),
    ),
  } as unknown as CandidateKnowledgeDataset;
}

export async function validateCandidateV3DryRun(): Promise<{
  readonly sources: number;
  readonly chunks: number;
  readonly plannedCreates: number;
  readonly productionWrites: 0;
}> {
  const dataset = await loadCandidateV3();
  const plan = planIngestion(dataset as unknown as KnowledgeDataset);
  let productionWrites = 0;
  const result = await executePlan(
    plan,
    async () => {
      productionWrites++;
    },
    false,
  );
  if (productionWrites !== 0) {
    throw new Error("Candidate dry-run attempted a production write.");
  }
  return {
    sources: Object.keys(dataset.sources).length,
    chunks: dataset.chunks.length,
    plannedCreates: result.created,
    productionWrites: 0,
  };
}

export async function compareCandidateV3ToProduction(): Promise<{
  readonly updatedIds: readonly string[];
  readonly newIds: readonly string[];
  readonly staleIds: readonly string[];
}> {
  const [production, candidate] = await Promise.all([
    loadDataset(),
    loadCandidateV3(),
  ]);
  const promoted = {
    sources: Object.fromEntries(
      Object.entries(candidate.sources).map(([id, source]) => [
        id,
        withDatasetVersion(source, PROMOTED_DATASET_VERSION),
      ]),
    ),
    chunks: candidate.chunks.map((chunk) =>
      withDatasetVersion(chunk, PROMOTED_DATASET_VERSION),
    ),
  } as unknown as KnowledgeDataset;
  const plan = planIngestion(
    promoted,
    new Map(Object.entries(production.sources)),
    new Map(production.chunks.map((chunk) => [chunkDocumentId(chunk), chunk])),
  );
  const qualified = (collection: string, id: string) => `${collection}/${id}`;
  return {
    updatedIds: plan.writes
      .filter((write) => write.kind === "update")
      .map((write) => qualified(write.collection, write.id))
      .sort(),
    newIds: plan.writes
      .filter((write) => write.kind === "create")
      .map((write) => qualified(write.collection, write.id))
      .sort(),
    staleIds: [
      ...plan.staleSourceIds.map((id) => qualified("knowledgeSources", id)),
      ...plan.staleChunkIds.map((id) => qualified("knowledgeChunks", id)),
    ].sort(),
  };
}
