import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
  CANDIDATE_DATASET_VERSION,
  compareCandidateV3ToProduction,
  loadCandidateV3,
  validateCandidateV3DryRun,
} from "../src/candidate_v3.js";
import { CANONICAL_PLANT_KEYS, DATASET_VERSION } from "../src/constants.js";
import { loadDataset } from "../src/data.js";

describe("adaptive-watering candidate v3", () => {
  test("validates as a full source-backed overlay without changing production v2", async () => {
    const [production, candidate] = await Promise.all([
      loadDataset(),
      loadCandidateV3(),
    ]);

    assert.equal(DATASET_VERSION, "2026-09-03-v2");
    assert.equal(production.chunks.length, 50);
    assert.equal(Object.keys(production.sources).length, 15);
    assert.equal(candidate.chunks.length, 60);
    assert.equal(Object.keys(candidate.sources).length, 19);
    assert.ok(
      Object.values(candidate.sources).every(
        (source) => source.datasetVersion === CANDIDATE_DATASET_VERSION,
      ),
    );
    assert.ok(
      candidate.chunks.every(
        (chunk) => chunk.datasetVersion === CANDIDATE_DATASET_VERSION,
      ),
    );
  });

  test("covers both adaptive claims for every supported plant", async () => {
    const candidate = await loadCandidateV3();
    const requiredIssueKeys = [
      "adaptive_recheck_context",
      "container_drying_modifiers",
    ];

    for (const plantKey of CANONICAL_PLANT_KEYS) {
      for (const issueKey of requiredIssueKeys) {
        const chunk = candidate.chunks.find(
          (item) =>
            item.canonicalPlantKey === plantKey && item.issueKey === issueKey,
        );
        assert.ok(chunk, `${plantKey} is missing ${issueKey}`);
        assert.equal(chunk.category, "watering");
        assert.equal(chunk.reviewStatus, "reviewed");
        assert.ok(chunk.sourceIds.length >= 2);
        assert.ok(
          chunk.sourceIds.every((sourceId) => sourceId in candidate.sources),
        );
      }
    }
  });

  test("keeps bounded timing as a recheck cadence and current soil as controlling", async () => {
    const candidate = await loadCandidateV3();
    const chunks = candidate.chunks.filter((chunk) =>
      ["adaptive_recheck_context", "container_drying_modifiers"].includes(
        chunk.issueKey ?? "",
      ),
    );
    const combined = chunks
      .flatMap((chunk) => [chunk.title, chunk.content, ...chunk.cautions])
      .join(" ");

    assert.match(combined, /current (?:below-surface soil check|finger test)/i);
    assert.match(combined, /context only|can explain context/i);
    assert.match(combined, /one or two days|one-to-two-day/i);
    assert.match(combined, /about every two days/i);
    assert.match(combined, /checked daily/i);
    assert.doesNotMatch(combined, /water every/i);
    assert.match(
      combined,
      /do not convert that recheck window into an automatic watering date/i,
    );
    assert.match(combined, /never to bypass.+schedule watering automatically/i);
  });

  test("contains no fabricated quantities or clock precision", async () => {
    const candidate = await loadCandidateV3();
    const chunks = candidate.chunks.filter((chunk) =>
      ["adaptive_recheck_context", "container_drying_modifiers"].includes(
        chunk.issueKey ?? "",
      ),
    );
    const combined = chunks
      .flatMap((chunk) => [chunk.title, chunk.content, ...chunk.cautions])
      .join(" ");

    assert.doesNotMatch(
      combined,
      /\b\d+(?:\.\d+)?\s*(?:ml|liters?|gallons?|ounces?)\b/i,
    );
    assert.doesNotMatch(combined, /\b\d{1,2}:\d{2}\b/);
    assert.doesNotMatch(combined, /\b\d+\s*(?:minutes?|hours?)\b/i);
    assert.doesNotMatch(combined, /\bexactly\s+\d+\s+days?\b/i);
  });

  test("dry-run plans the full candidate and performs zero writes", async () => {
    const result = await validateCandidateV3DryRun();
    assert.deepEqual(result, {
      sources: 19,
      chunks: 60,
      plannedCreates: 79,
      productionWrites: 0,
    });
  });

  test("reports the unsafe flat-collection update plan read-only", async () => {
    const comparison = await compareCandidateV3ToProduction();
    assert.equal(comparison.updatedIds.length, 65);
    assert.equal(comparison.newIds.length, 14);
    assert.deepEqual(comparison.staleIds, []);
    assert.ok(
      comparison.newIds.includes(
        "knowledgeChunks/tomato__watering__adaptive_recheck_context",
      ),
    );
    assert.ok(
      comparison.newIds.includes("knowledgeSources/iowa_container_plant_care"),
    );
  });
});
