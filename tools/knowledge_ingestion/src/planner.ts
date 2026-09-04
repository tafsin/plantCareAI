import { chunkDocumentId } from "./ids.js";
import type { KnowledgeDataset } from "./schema.js";

export type DocumentData = Readonly<Record<string, unknown>>;
export interface PlannedWrite {
  readonly collection: "knowledgeSources" | "knowledgeChunks";
  readonly id: string;
  readonly data: DocumentData;
  readonly kind: "create" | "update";
}
export interface IngestionPlan {
  readonly writes: readonly PlannedWrite[];
  readonly created: number;
  readonly updated: number;
  readonly unchanged: number;
  readonly staleSourceIds: readonly string[];
  readonly staleChunkIds: readonly string[];
}

const comparable = (value: unknown): unknown => {
  if (value instanceof Date) return value.toISOString();
  if (value && typeof value === "object" && "toDate" in value) {
    const candidate = value as { toDate: () => Date };
    return candidate.toDate().toISOString();
  }
  if (Array.isArray(value)) return value.map(comparable);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, item]) => [key, comparable(item)]),
    );
  }
  return value;
};

const equalDocuments = (left: DocumentData, right: DocumentData): boolean =>
  JSON.stringify(comparable(left)) === JSON.stringify(comparable(right));

export function planIngestion(
  dataset: KnowledgeDataset,
  existingSources: ReadonlyMap<string, DocumentData> = new Map(),
  existingChunks: ReadonlyMap<string, DocumentData> = new Map(),
): IngestionPlan {
  const desiredSources = new Map(Object.entries(dataset.sources));
  const desiredChunks = new Map(
    dataset.chunks.map((chunk) => [chunkDocumentId(chunk), chunk] as const),
  );
  const writes: PlannedWrite[] = [];
  let created = 0;
  let updated = 0;
  let unchanged = 0;

  const addPlans = (
    collection: PlannedWrite["collection"],
    desired: ReadonlyMap<string, DocumentData>,
    existing: ReadonlyMap<string, DocumentData>,
  ) => {
    for (const [id, data] of desired) {
      const current = existing.get(id);
      if (!current) {
        writes.push({ collection, id, data, kind: "create" });
        created++;
      } else if (equalDocuments(current, data)) {
        unchanged++;
      } else {
        writes.push({ collection, id, data, kind: "update" });
        updated++;
      }
    }
  };

  addPlans("knowledgeSources", desiredSources, existingSources);
  addPlans("knowledgeChunks", desiredChunks, existingChunks);

  return {
    writes,
    created,
    updated,
    unchanged,
    staleSourceIds: [...existingSources.keys()]
      .filter((id) => !desiredSources.has(id))
      .sort(),
    staleChunkIds: [...existingChunks.keys()]
      .filter((id) => !desiredChunks.has(id))
      .sort(),
  };
}

export async function executePlan(
  plan: IngestionPlan,
  writeBatch: (writes: readonly PlannedWrite[]) => Promise<void>,
  productionWrite: boolean,
): Promise<{
  created: number;
  updated: number;
  unchanged: number;
  failed: number;
}> {
  if (!productionWrite) {
    return {
      created: plan.created,
      updated: plan.updated,
      unchanged: plan.unchanged,
      failed: 0,
    };
  }

  let created = 0;
  let updated = 0;
  let failed = 0;
  for (let start = 0; start < plan.writes.length; start += 400) {
    const batch = plan.writes.slice(start, start + 400);
    try {
      await writeBatch(batch);
      created += batch.filter((write) => write.kind === "create").length;
      updated += batch.filter((write) => write.kind === "update").length;
    } catch {
      failed += batch.length;
    }
  }
  return {
    created,
    updated,
    unchanged: plan.unchanged,
    failed,
  };
}
