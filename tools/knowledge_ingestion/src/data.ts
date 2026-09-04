import { readFile } from "node:fs/promises";

import { validateDataset, type KnowledgeDataset } from "./schema.js";

const dataUrl = (filename: string) =>
  new URL(`../data/${filename}`, import.meta.url);

export async function loadDataset(): Promise<KnowledgeDataset> {
  const [sourceText, chunkText] = await Promise.all([
    readFile(dataUrl("sources.json"), "utf8"),
    readFile(dataUrl("knowledge_chunks.json"), "utf8"),
  ]);
  return validateDataset(JSON.parse(sourceText), JSON.parse(chunkText));
}
