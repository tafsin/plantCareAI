import { APPROVED_PROJECT_ID } from "./constants.js";

export interface ProductionPolicyInput {
  readonly projectId?: string | undefined;
  readonly productionWrite: boolean;
  readonly confirmation?: string | undefined;
}

export function assertIngestionPolicy(input: ProductionPolicyInput): void {
  if (!input.projectId)
    throw new Error("An explicit --project ID is required.");
  if (!input.productionWrite) return;
  if (input.projectId !== APPROVED_PROJECT_ID) {
    throw new Error(
      `Production writes are restricted to ${APPROVED_PROJECT_ID}.`,
    );
  }
  if (input.confirmation !== `ingest ${APPROVED_PROJECT_ID}`) {
    throw new Error(
      `Production confirmation must exactly match: ingest ${APPROVED_PROJECT_ID}`,
    );
  }
}
