import { z } from "zod";

import {
  AFFECTED_PARTS,
  CANONICAL_PLANT_KEYS,
  DATASET_VERSION,
  ENVIRONMENTS,
  GROWTH_STAGES,
  KNOWLEDGE_CATEGORIES,
  SCHEMA_VERSION,
  SOURCE_TYPES,
} from "./constants.js";
import { chunkDocumentId } from "./ids.js";

const trimmedString = z
  .string()
  .min(1)
  .refine(
    (value) => value.trim() === value,
    "must not have surrounding whitespace",
  );
const boundedString = (maximum: number) => trimmedString.max(maximum);
const snakeCaseKey = trimmedString.regex(
  /^[a-z0-9]+(?:_[a-z0-9]+)*$/,
  "must be lowercase snake_case",
);
const uniqueArray = <T extends z.ZodType>(item: T, maximum: number) =>
  z
    .array(item)
    .max(maximum)
    .refine(
      (values) => new Set(values).size === values.length,
      "must contain unique values",
    );
const timestampString = trimmedString.refine(
  (value) => Number.isFinite(Date.parse(value)),
  "must be a valid date-time",
);
const httpsUrl = trimmedString
  .url()
  .refine((value) => new URL(value).protocol === "https:", "must use HTTPS");

export const sourceSchema = z
  .object({
    schemaVersion: z.literal(SCHEMA_VERSION),
    title: boundedString(240),
    publisher: boundedString(160),
    url: httpsUrl,
    accessedAt: timestampString,
    sourceType: z.enum(SOURCE_TYPES),
    datasetVersion: z.literal(DATASET_VERSION),
  })
  .strict();

export const chunkSchema = z
  .object({
    schemaVersion: z.literal(SCHEMA_VERSION),
    canonicalPlantKey: z.enum(CANONICAL_PLANT_KEYS),
    commonName: boundedString(80),
    scientificName: boundedString(120),
    aliases: uniqueArray(boundedString(120), 12),
    category: z.enum(KNOWLEDGE_CATEGORIES),
    issueKey: snakeCaseKey.optional(),
    environment: uniqueArray(z.enum(ENVIRONMENTS), 2).min(1),
    affectedParts: uniqueArray(z.enum(AFFECTED_PARTS), 7),
    growthStages: uniqueArray(z.enum(GROWTH_STAGES), 5).min(1),
    symptomKeywords: uniqueArray(snakeCaseKey, 15),
    title: boundedString(140),
    content: trimmedString.min(100).max(900),
    cautions: uniqueArray(boundedString(300), 8),
    sourceIds: uniqueArray(snakeCaseKey, 5).min(1),
    reviewStatus: z.literal("reviewed"),
    datasetVersion: z.literal(DATASET_VERSION),
    createdAt: timestampString,
    updatedAt: timestampString,
  })
  .strict();

export type KnowledgeSource = z.infer<typeof sourceSchema>;
export type KnowledgeChunk = z.infer<typeof chunkSchema>;

export interface KnowledgeDataset {
  readonly sources: Readonly<Record<string, KnowledgeSource>>;
  readonly chunks: readonly KnowledgeChunk[];
}

export function validateDataset(
  rawSources: unknown,
  rawChunks: unknown,
): KnowledgeDataset {
  const sourceRecord = z.record(snakeCaseKey, sourceSchema).parse(rawSources);
  const chunks = z.array(chunkSchema).min(1).parse(rawChunks);
  const ids = new Set<string>();

  for (const chunk of chunks) {
    for (const sourceId of chunk.sourceIds) {
      if (!(sourceId in sourceRecord)) {
        throw new Error(
          `Chunk ${chunk.title} references missing source ${sourceId}.`,
        );
      }
    }
    const id = chunkDocumentId(chunk);
    if (ids.has(id)) {
      throw new Error(`Duplicate deterministic chunk ID: ${id}.`);
    }
    ids.add(id);
  }

  return { sources: sourceRecord, chunks };
}
