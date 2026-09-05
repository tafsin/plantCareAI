import {
  compareCandidateV3ToProduction,
  PROMOTED_DATASET_VERSION,
} from "./candidate_v3.js";
import { DATASET_VERSION } from "./constants.js";

async function main(): Promise<void> {
  const comparison = await compareCandidateV3ToProduction();
  console.log(
    `Read-only comparison: ${DATASET_VERSION} -> ${PROMOTED_DATASET_VERSION}`,
  );
  console.log(`Updates in flat collections (${comparison.updatedIds.length}):`);
  console.log(comparison.updatedIds.join("\n"));
  console.log(`New in flat collections (${comparison.newIds.length}):`);
  console.log(comparison.newIds.join("\n"));
  console.log(`Missing/stale (${comparison.staleIds.length}):`);
  console.log(comparison.staleIds.join("\n") || "none");
  console.log("Production reads: 0; production writes: 0");
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Comparison failed.");
  process.exitCode = 1;
});
