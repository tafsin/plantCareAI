import type { KnowledgeChunk } from "./schema.js";

export function chunkDocumentId(
  chunk: Pick<KnowledgeChunk, "canonicalPlantKey" | "category" | "issueKey">,
): string {
  if (!chunk.issueKey) {
    throw new Error(
      "A stable issueKey is required to derive a chunk document ID.",
    );
  }
  return `${chunk.canonicalPlantKey}__${chunk.category}__${chunk.issueKey}`;
}
