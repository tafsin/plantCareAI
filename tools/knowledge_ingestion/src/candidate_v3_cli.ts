import {
  CANDIDATE_DATASET_VERSION,
  validateCandidateV3DryRun,
} from "./candidate_v3.js";
import { DATASET_VERSION } from "./constants.js";

async function main(): Promise<void> {
  const result = await validateCandidateV3DryRun();
  console.log(`Production dataset remains: ${DATASET_VERSION}`);
  console.log(`Candidate dataset: ${CANDIDATE_DATASET_VERSION}`);
  console.log("Mode: VALIDATION / DRY RUN ONLY");
  console.log(
    `Validated ${result.sources} sources and ${result.chunks} chunks; planned creates=${result.plannedCreates}.`,
  );
  console.log(`Production writes: ${result.productionWrites}`);
}

main().catch((error: unknown) => {
  console.error(
    error instanceof Error ? error.message : "Candidate validation failed.",
  );
  process.exitCode = 1;
});
