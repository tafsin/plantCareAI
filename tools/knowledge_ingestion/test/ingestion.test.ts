import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { APPROVED_PROJECT_ID } from "../src/constants.js";
import { loadDataset } from "../src/data.js";
import { executePlan, planIngestion } from "../src/planner.js";
import { assertIngestionPolicy } from "../src/policy.js";

describe("ingestion safety policy", () => {
  test("requires an explicit project ID", () => {
    assert.throws(
      () => assertIngestionPolicy({ productionWrite: false }),
      /explicit --project/,
    );
  });

  test("rejects a wrong production project ID", () => {
    assert.throws(
      () =>
        assertIngestionPolicy({
          projectId: "wrong-project",
          productionWrite: true,
          confirmation: `ingest ${APPROVED_PROJECT_ID}`,
        }),
      /restricted/,
    );
  });

  test("production mode requires exact typed confirmation", () => {
    assert.throws(
      () =>
        assertIngestionPolicy({
          projectId: APPROVED_PROJECT_ID,
          productionWrite: true,
          confirmation: "yes",
        }),
      /exactly match/,
    );
    assert.doesNotThrow(() =>
      assertIngestionPolicy({
        projectId: APPROVED_PROJECT_ID,
        productionWrite: true,
        confirmation: `ingest ${APPROVED_PROJECT_ID}`,
      }),
    );
  });
});

describe("idempotent planning and execution", () => {
  test("dry-run performs no writes", async () => {
    const dataset = await loadDataset();
    const plan = planIngestion(dataset);
    let writeCalls = 0;
    const result = await executePlan(
      plan,
      async () => {
        writeCalls++;
      },
      false,
    );
    assert.equal(writeCalls, 0);
    assert.equal(
      result.created,
      dataset.chunks.length + Object.keys(dataset.sources).length,
    );
    assert.equal(result.failed, 0);
  });

  test("identifies unchanged records on an idempotent rerun", async () => {
    const dataset = await loadDataset();
    const sourceMap = new Map(Object.entries(dataset.sources));
    const firstChunk = dataset.chunks[0]!;
    const chunkMap = new Map([
      [
        `${firstChunk.canonicalPlantKey}__${firstChunk.category}__${firstChunk.issueKey}`,
        firstChunk,
      ],
    ]);
    const plan = planIngestion(dataset, sourceMap, chunkMap);
    assert.equal(plan.unchanged, sourceMap.size + 1);
    assert.equal(plan.updated, 0);
  });

  test("reports stale records without scheduling deletion", async () => {
    const dataset = await loadDataset();
    const plan = planIngestion(
      dataset,
      new Map([["stale_source", { value: true }]]),
      new Map([["stale_chunk", { value: true }]]),
    );
    assert.deepEqual(plan.staleSourceIds, ["stale_source"]);
    assert.deepEqual(plan.staleChunkIds, ["stale_chunk"]);
    assert.ok(
      plan.writes.every(
        (write) => write.kind === "create" || write.kind === "update",
      ),
    );
  });
});
