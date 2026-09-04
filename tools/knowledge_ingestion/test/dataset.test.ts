import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { DATASET_VERSION, SCHEMA_VERSION } from "../src/constants.js";
import { loadDataset } from "../src/data.js";
import { chunkDocumentId } from "../src/ids.js";
import { canonicalPlantKeyFor, normalizePlantName } from "../src/normalize.js";
import { validateDataset } from "../src/schema.js";

const copy = <T>(value: T): T => structuredClone(value);

describe("production knowledge dataset", () => {
  test("is complete, valid, versioned, and source-backed", async () => {
    const dataset = await loadDataset();
    assert.equal(SCHEMA_VERSION, 1);
    assert.equal(DATASET_VERSION, "2026-09-03-v1");
    assert.equal(dataset.chunks.length, 41);
    assert.equal(Object.keys(dataset.sources).length, 10);
    assert.deepEqual(
      Object.fromEntries(
        ["tomato", "pumpkin", "pothos", "snake_plant", "peace_lily"].map(
          (key) => [
            key,
            dataset.chunks.filter((chunk) => chunk.canonicalPlantKey === key)
              .length,
          ],
        ),
      ),
      { tomato: 8, pumpkin: 9, pothos: 8, snake_plant: 8, peace_lily: 8 },
    );
    for (const chunk of dataset.chunks) {
      assert.ok(chunk.sourceIds.length > 0);
      assert.match(
        chunkDocumentId(chunk),
        /^[a-z0-9_]+__[a-z0-9_]+__[a-z0-9_]+$/,
      );
    }
  });

  test("rejects a missing required field", async () => {
    const dataset = await loadDataset();
    const chunks = copy(dataset.chunks) as unknown as Record<string, unknown>[];
    delete chunks[0]?.title;
    assert.throws(() => validateDataset(dataset.sources, chunks));
  });

  test("rejects an unknown field", async () => {
    const dataset = await loadDataset();
    const chunks = copy(dataset.chunks) as unknown as Record<string, unknown>[];
    chunks[0]!.unexpected = true;
    assert.throws(() => validateDataset(dataset.sources, chunks));
  });

  test("rejects invalid canonical keys and enums", async () => {
    const dataset = await loadDataset();
    const badKey = copy(dataset.chunks) as unknown as Record<string, unknown>[];
    badKey[0]!.canonicalPlantKey = "potato";
    assert.throws(() => validateDataset(dataset.sources, badKey));
    const badEnum = copy(dataset.chunks) as unknown as Record<
      string,
      unknown
    >[];
    badEnum[0]!.category = "magic_cure";
    assert.throws(() => validateDataset(dataset.sources, badEnum));
  });

  test("rejects padded strings, duplicate array values, and oversized text", async () => {
    const dataset = await loadDataset();
    const padded = copy(dataset.chunks) as unknown as Record<string, unknown>[];
    padded[0]!.title = " padded";
    assert.throws(() => validateDataset(dataset.sources, padded));
    const duplicate = copy(dataset.chunks) as unknown as Record<
      string,
      unknown
    >[];
    duplicate[0]!.aliases = ["Tomato", "Tomato"];
    assert.throws(() => validateDataset(dataset.sources, duplicate));
    const oversized = copy(dataset.chunks) as unknown as Record<
      string,
      unknown
    >[];
    oversized[0]!.title = "x".repeat(141);
    assert.throws(() => validateDataset(dataset.sources, oversized));
  });

  test("rejects missing source references and invalid source URLs", async () => {
    const dataset = await loadDataset();
    const missing = copy(dataset.chunks) as unknown as Record<
      string,
      unknown
    >[];
    missing[0]!.sourceIds = ["missing_source"];
    assert.throws(
      () => validateDataset(dataset.sources, missing),
      /missing source/,
    );
    const sources = copy(dataset.sources) as Record<
      string,
      Record<string, unknown>
    >;
    sources.umn_growing_tomatoes!.url = "http://example.com";
    assert.throws(() => validateDataset(sources, dataset.chunks));
  });

  test("rejects duplicate deterministic IDs", async () => {
    const dataset = await loadDataset();
    const chunks = [...copy(dataset.chunks), copy(dataset.chunks[0]!)];
    assert.throws(
      () => validateDataset(dataset.sources, chunks),
      /Duplicate deterministic/,
    );
  });

  test("rejects unsupported schema and dataset versions", async () => {
    const dataset = await loadDataset();
    const schema = copy(dataset.chunks) as unknown as Record<string, unknown>[];
    schema[0]!.schemaVersion = 2;
    assert.throws(() => validateDataset(dataset.sources, schema));
    const version = copy(dataset.chunks) as unknown as Record<
      string,
      unknown
    >[];
    version[0]!.datasetVersion = "2099-v1";
    assert.throws(() => validateDataset(dataset.sources, version));
  });
});

describe("plant-name normalization", () => {
  test("maps canonical names, aliases, punctuation, apostrophes, and surrounding whitespace", () => {
    const cases = new Map([
      [" tomato ", "tomato"],
      ["SOLANUM LYCOPERSICUM", "tomato"],
      ["Cucurbita pepo", "pumpkin"],
      ["golden pothos", "pothos"],
      ["devil’s ivy", "pothos"],
      ["mother-in-law’s tongue", "snake_plant"],
      ["Sansevieria trifasciata", "snake_plant"],
      ["Spathiphyllum wallisii", "peace_lily"],
    ]);
    for (const [name, expected] of cases)
      assert.equal(canonicalPlantKeyFor(name), expected);
    assert.equal(normalizePlantName("  Peace.Lily!  "), "peace lily");
  });
});
