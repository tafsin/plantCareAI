import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-plantcare-ai';
const rules = readFileSync('firestore.rules', 'utf8');
let testEnv;

const validPlant = (overrides = {}) => ({
  commonName: 'Monstera',
  scientificName: 'Monstera deliciosa',
  environment: 'indoor',
  growingMedium: 'pot',
  potSizeLiters: 12,
  sunlight: 'partial',
  growthStage: 'mature',
  notes: 'Near the east window',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const plantRef = (context, uid = 'alice', plantId = 'plant-1') =>
  doc(context.firestore(), `users/${uid}/plants/${plantId}`);

const validObservation = (overrides = {}) => ({
  schemaVersion: 1,
  plantVisible: true,
  imageQualityUsable: true,
  imageQualityIssues: ['blurred'],
  possibleCommonName: 'Tomato',
  possibleScientificName: 'Solanum lycopersicum',
  identificationConfidence: 0.82,
  affectedParts: ['leaf'],
  observations: [{
    type: 'yellowing',
    description: 'Yellow areas are visible between several leaf veins.',
    confidence: 0.88,
  }],
  distribution: 'Mostly visible on older lower leaves.',
  severity: 'moderate',
  followUpPhotoHelpful: true,
  followUpInstruction: 'Take a clear photo of the underside of a leaf.',
  modelName: 'gemini-2.5-flash-lite',
  createdAt: serverTimestamp(),
  source: 'firebase_ai_client',
  ...overrides,
});

const observationRef = (
  context,
  uid = 'alice',
  plantId = 'plant-1',
  observationId = 'observation-1',
) => doc(
  context.firestore(),
  `users/${uid}/plants/${plantId}/observations/${observationId}`,
);

const diagnosisRef = (
  context,
  uid = 'alice',
  plantId = 'plant-1',
  observationId = 'observation-1',
  diagnosisId = 'diagnosis-1',
) => doc(
  context.firestore(),
  `users/${uid}/plants/${plantId}/observations/${observationId}/diagnoses/${diagnosisId}`,
);

const validDiagnosis = (overrides = {}) => ({
  schemaVersion: 1,
  status: 'possible_issues_found',
  summary: 'The visible pattern may be consistent with a supported issue.',
  possibleIssues: [{
    name: 'Leaf issue',
    likelihood: 'most_likely',
    evidenceStrength: 'moderate',
    supportingObservations: ['Yellow areas are visible on older leaves.'],
    reasoning: 'The pattern may overlap with the supplied reference.',
    evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
  }],
  recommendedActions: [{
    action: 'Monitor visible changes.',
    priority: 'monitor',
    reason: 'Progression can add useful evidence.',
    evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
  }],
  avoidActions: [{
    action: 'Do not assume the cause.',
    reason: 'Several causes can overlap.',
    evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
  }],
  uncertainties: ['The leaf underside was not visible.'],
  followUp: {
    anotherPhotoHelpful: true,
    instruction: 'Photograph the underside of the affected leaf.',
    professionalHelpRecommended: false,
    professionalHelpReason: null,
  },
  canonicalPlantKey: 'tomato',
  evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
  sourceIds: ['extension_source'],
  datasetVersion: '2026-09-03-v2',
  retrievalAlgorithmVersion: 'metadata-v1',
  modelName: 'gemini-3.5-flash-lite',
  source: 'firebase_ai_client_grounded',
  createdAt: serverTimestamp(),
  ...overrides,
});

const soilCheckRef = (
  context,
  uid = 'alice',
  plantId = 'plant-1',
  soilCheckId = 'soil-check-1',
) => doc(
  context.firestore(),
  `users/${uid}/plants/${plantId}/soilChecks/${soilCheckId}`,
);

const validSoilCheck = (overrides = {}) => ({
  schemaVersion: 1,
  policyVersion: 'manual-watering-v1',
  datasetVersion: '2026-09-03-v2',
  moistureLevel: 'dry',
  method: 'manual_finger_test',
  outcome: 'water_now',
  title: 'Watering is appropriate now',
  explanation: 'Dry soil is at the supported threshold for this plant.',
  cautions: ['Recent and expected rainfall are not considered.'],
  canonicalPlantKey: 'tomato',
  evidenceChunkIds: ['tomato__watering__consistent_deep_watering'],
  suggestedCheckAt: new Date('2030-01-01T00:00:00.000Z'),
  environmentSnapshot: 'outdoor',
  growingMediumSnapshot: 'ground',
  createdAt: serverTimestamp(),
  source: 'deterministic_client_policy',
  ...overrides,
});

const careLogRef = (
  context,
  uid = 'alice',
  plantId = 'plant-1',
  careLogId = 'care-1',
) => doc(
  context.firestore(),
  `users/${uid}/plants/${plantId}/careLogs/${careLogId}`,
);

const validWateringLog = (overrides = {}) => ({
  schemaVersion: 1,
  type: 'watering',
  occurredAt: new Date(),
  notes: 'Watered after a manual check',
  createdAt: serverTimestamp(),
  source: 'user_entered',
  wateringMethod: 'top',
  amountMl: 250,
  ...overrides,
});

const validFertilizingLog = (overrides = {}) => ({
  schemaVersion: 1,
  type: 'fertilizing',
  occurredAt: new Date(),
  createdAt: serverTimestamp(),
  source: 'user_entered',
  productName: 'Houseplant feed',
  fertilizerForm: 'liquid',
  applicationNote: 'Applied as recorded on the package',
  ...overrides,
});

const fertilizerAssessmentRef = (
  context,
  uid = 'alice',
  plantId = 'plant-1',
  assessmentId = 'assessment-1',
) => doc(
  context.firestore(),
  `users/${uid}/plants/${plantId}/fertilizerAssessments/${assessmentId}`,
);

const validFertilizerAssessment = (overrides = {}) => ({
  schemaVersion: 1,
  policyVersion: 'deterministic-fertilizer-v1',
  datasetVersion: '2026-09-03-v2',
  canonicalPlantKey: 'tomato',
  growthActivity: 'active_growth',
  growthStageSnapshot: 'fruiting',
  environmentSnapshot: 'outdoor',
  outcome: 'consider_fertilizing',
  fertilizerCategory: 'vegetable_or_tomato',
  title: 'Fertilizer may be considered',
  explanation: 'Current growth and reviewed evidence support considering a broad category.',
  cautions: ['Follow the product label.'],
  evidenceChunkIds: ['tomato__nutrient_guidance__fruiting_fertilizer'],
  createdAt: serverTimestamp(),
  source: 'deterministic_client_policy',
  ...overrides,
});

const reminderRef = (
  context,
  uid = 'alice',
  plantId = 'plant-1',
  reminderId = 'reminder-1',
) => doc(
  context.firestore(),
  `users/${uid}/plants/${plantId}/reminders/${reminderId}`,
);

const validReminder = (overrides = {}) => ({
  schemaVersion: 1,
  type: 'soil_check',
  dueAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  status: 'active',
  title: 'Check soil moisture',
  source: 'user_created',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const createOwnerPlant = async (context, uid = 'alice', plantId = 'plant-1') =>
  assertSucceeds(setDoc(plantRef(context, uid, plantId), validPlant()));

const knowledgeChunkRef = (context) =>
  doc(context.firestore(), 'knowledgeChunks/tomato__identity__species_identity');

const knowledgeSourceRef = (context) =>
  doc(context.firestore(), 'knowledgeSources/umn_growing_tomatoes');

const v3ReleaseRef = (context) =>
  doc(context.firestore(), 'knowledgeDatasets/2026-09-05-v3');

const v3ChunkRef = (context) => doc(
  context.firestore(),
  'knowledgeDatasets/2026-09-05-v3/chunks/tomato__identity__species_identity',
);

const seedKnowledge = async () => testEnv.withSecurityRulesDisabled(async (context) => {
  await setDoc(knowledgeChunkRef(context), {
    schemaVersion: 1,
    canonicalPlantKey: 'tomato',
    title: 'Tomato identity',
  });
  await setDoc(knowledgeSourceRef(context), {
    schemaVersion: 1,
    title: 'Growing tomatoes in home gardens',
  });
});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

beforeEach(async () => testEnv.clearFirestore());
after(async () => testEnv.cleanup());

describe('plant ownership and validation', () => {
  test('denies unauthenticated reads and writes', async () => {
    const guest = testEnv.unauthenticatedContext();
    await assertFails(getDoc(plantRef(guest)));
    await assertFails(getDocs(collection(guest.firestore(), 'users/alice/plants')));
    await assertFails(setDoc(plantRef(guest), validPlant()));
  });

  test('allows an owner to create, read, update, and delete', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const ref = plantRef(alice);
    await assertSucceeds(setDoc(ref, validPlant()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(getDocs(collection(alice.firestore(), 'users/alice/plants')));
    await assertSucceeds(
      updateDoc(ref, { commonName: 'Swiss cheese plant', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(deleteDoc(ref));
  });

  test('denies create, read, update, and delete across owners', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    await assertFails(setDoc(plantRef(alice, 'bob'), validPlant()));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(plantRef(context, 'bob'), validPlant());
    });
    await assertFails(getDoc(plantRef(alice, 'bob')));
    await assertFails(getDocs(collection(alice.firestore(), 'users/bob/plants')));
    await assertFails(
      updateDoc(plantRef(alice, 'bob'), {
        commonName: 'Stolen plant',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(deleteDoc(plantRef(alice, 'bob')));
    assert.equal((await getDoc(plantRef(bob, 'bob'))).exists(), true);
  });

  test('rejects unknown fields, invalid enums, and missing required fields', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(plantRef(alice), validPlant({ unexpected: true })));
    await assertFails(setDoc(plantRef(alice), validPlant({ sunlight: 'shade' })));
    const missing = validPlant();
    delete missing.commonName;
    await assertFails(setDoc(plantRef(alice), missing));
  });

  test('rejects oversized or untrimmed strings', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(plantRef(alice), validPlant({ commonName: 'x'.repeat(81) })));
    await assertFails(setDoc(plantRef(alice), validPlant({ scientificName: 'x'.repeat(121) })));
    await assertFails(setDoc(plantRef(alice), validPlant({ notes: 'x'.repeat(1001) })));
    await assertFails(setDoc(plantRef(alice), validPlant({ commonName: ' Monstera' })));
  });

  test('rejects invalid pot sizes and pot size for ground plants', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(plantRef(alice), validPlant({ potSizeLiters: 0 })));
    await assertFails(setDoc(plantRef(alice), validPlant({ potSizeLiters: 10001 })));
    await assertFails(
      setDoc(
        plantRef(alice),
        validPlant({ growingMedium: 'ground', potSizeLiters: 4 }),
      ),
    );
  });

  test('prevents changing createdAt', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const ref = plantRef(alice);
    await assertSucceeds(setDoc(ref, validPlant()));
    await assertFails(
      updateDoc(ref, {
        createdAt: new Date(0),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('denies arbitrary writes directly under users', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(doc(alice.firestore(), 'users/alice'), { role: 'admin' }));
  });
});

describe('observation ownership, immutability, and validation', () => {
  test('owner can create, read, and delete a valid observation', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    const ref = observationRef(alice);
    await assertSucceeds(setDoc(ref, validObservation()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(getDocs(collection(
      alice.firestore(),
      'users/alice/plants/plant-1/observations',
    )));
    await assertSucceeds(deleteDoc(ref));
  });

  test('denies unauthenticated creation', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const guest = testEnv.unauthenticatedContext();
    await createOwnerPlant(alice);
    await assertFails(setDoc(observationRef(guest), validObservation()));
  });

  test('another user cannot create or read under the owner plant', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    await createOwnerPlant(alice);
    await assertFails(setDoc(observationRef(bob), validObservation()));
    await assertSucceeds(setDoc(observationRef(alice), validObservation()));
    await assertFails(getDoc(observationRef(bob)));
  });

  test('requires an existing parent plant', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(observationRef(alice), validObservation()));
  });

  test('denies unexpected fields and invalid enums', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertFails(setDoc(
      observationRef(alice, 'alice', 'plant-1', 'extra'),
      validObservation({ imageUrl: 'https://example.com/image.jpg' }),
    ));
    await assertFails(setDoc(
      observationRef(alice, 'alice', 'plant-1', 'enum'),
      validObservation({ severity: 'critical' }),
    ));
  });

  test('denies invalid confidence and oversized arrays or strings', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertFails(setDoc(
      observationRef(alice, 'alice', 'plant-1', 'confidence'),
      validObservation({ identificationConfidence: 1.01 }),
    ));
    await assertFails(setDoc(
      observationRef(alice, 'alice', 'plant-1', 'array'),
      validObservation({ affectedParts: Array(9).fill('leaf') }),
    ));
    await assertFails(setDoc(
      observationRef(alice, 'alice', 'plant-1', 'string'),
      validObservation({ distribution: 'x'.repeat(501) }),
    ));
  });

  test('denies invalid createdAt and all updates', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertFails(setDoc(
      observationRef(alice, 'alice', 'plant-1', 'timestamp'),
      validObservation({ createdAt: new Date(0) }),
    ));
    const ref = observationRef(alice);
    await assertSucceeds(setDoc(ref, validObservation()));
    await assertFails(updateDoc(ref, { severity: 'mild' }));
  });
});

describe('diagnosis ownership, immutability, and validation', () => {
  const createObservation = async (context) => {
    await createOwnerPlant(context);
    await assertSucceeds(setDoc(observationRef(context), validObservation()));
  };

  test('owner can create, read, and delete a valid diagnosis', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createObservation(alice);
    const ref = diagnosisRef(alice);
    await assertSucceeds(setDoc(ref, validDiagnosis()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(getDocs(collection(
      alice.firestore(),
      'users/alice/plants/plant-1/observations/observation-1/diagnoses',
    )));
    await assertSucceeds(deleteDoc(ref));
  });

  test('guest and another user cannot create, read, or delete', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const guest = testEnv.unauthenticatedContext();
    await createObservation(alice);
    await assertFails(setDoc(diagnosisRef(guest), validDiagnosis()));
    await assertFails(setDoc(diagnosisRef(bob), validDiagnosis()));
    await assertSucceeds(setDoc(diagnosisRef(alice), validDiagnosis()));
    await assertFails(getDoc(diagnosisRef(guest)));
    await assertFails(getDoc(diagnosisRef(bob)));
    await assertFails(deleteDoc(diagnosisRef(bob)));
  });

  test('requires existing parent plant and observation', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(diagnosisRef(alice), validDiagnosis()));
    await createOwnerPlant(alice);
    await assertFails(setDoc(diagnosisRef(alice), validDiagnosis()));
  });

  test('rejects unknown fields, enums, oversized values, and nested fields', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createObservation(alice);
    await assertFails(setDoc(
      diagnosisRef(alice, 'alice', 'plant-1', 'observation-1', 'unknown'),
      validDiagnosis({ prompt: 'secret prompt' }),
    ));
    await assertFails(setDoc(
      diagnosisRef(alice, 'alice', 'plant-1', 'observation-1', 'enum'),
      validDiagnosis({ status: 'confirmed' }),
    ));
    await assertFails(setDoc(
      diagnosisRef(alice, 'alice', 'plant-1', 'observation-1', 'large'),
      validDiagnosis({ summary: 'x'.repeat(601) }),
    ));
    const nested = validDiagnosis();
    nested.possibleIssues[0].unexpected = true;
    await assertFails(setDoc(
      diagnosisRef(alice, 'alice', 'plant-1', 'observation-1', 'nested'),
      nested,
    ));
  });

  test('accepts v2 and v3 grounding while rejecting unsupported metadata', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createObservation(alice);
    await assertSucceeds(setDoc(
      diagnosisRef(alice, 'alice', 'plant-1', 'observation-1', 'v3'),
      validDiagnosis({ datasetVersion: '2026-09-05-v3' }),
    ));
    for (const [id, overrides] of [
      ['dataset', { datasetVersion: '2026-09-03-v1' }],
      ['algorithm', { retrievalAlgorithmVersion: 'vector-v1' }],
      ['plant', { canonicalPlantKey: 'monstera' }],
      ['model', { modelName: 'unconfigured-model' }],
      ['source-id', { sourceIds: ['../../other-document'] }],
    ]) {
      await assertFails(setDoc(
        diagnosisRef(alice, 'alice', 'plant-1', 'observation-1', id),
        validDiagnosis(overrides),
      ));
    }
  });

  test('rejects invalid timestamp and all updates', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createObservation(alice);
    await assertFails(setDoc(
      diagnosisRef(alice, 'alice', 'plant-1', 'observation-1', 'timestamp'),
      validDiagnosis({ createdAt: new Date(0) }),
    ));
    const ref = diagnosisRef(alice);
    await assertSucceeds(setDoc(ref, validDiagnosis()));
    await assertFails(updateDoc(ref, { summary: 'This may be changed.' }));
  });
});

describe('soil-check ownership, immutability, and validation', () => {
  test('owner can create, read, and delete a valid soil check', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    const ref = soilCheckRef(alice);
    await assertSucceeds(setDoc(ref, validSoilCheck()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(getDocs(collection(
      alice.firestore(),
      'users/alice/plants/plant-1/soilChecks',
    )));
    await assertSucceeds(deleteDoc(ref));
  });

  test('guest and another user cannot create, read, or delete', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const guest = testEnv.unauthenticatedContext();
    await createOwnerPlant(alice);
    await assertFails(setDoc(soilCheckRef(guest), validSoilCheck()));
    await assertFails(setDoc(soilCheckRef(bob, 'alice'), validSoilCheck()));
    await assertSucceeds(setDoc(soilCheckRef(alice), validSoilCheck()));
    await assertFails(getDoc(soilCheckRef(guest)));
    await assertFails(getDoc(soilCheckRef(bob, 'alice')));
    await assertFails(deleteDoc(soilCheckRef(bob, 'alice')));
  });

  test('rejects invalid enums, versions, method, and source', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    for (const [id, overrides] of [
      ['moisture', { moistureLevel: '42_percent' }],
      ['outcome', { outcome: 'definitely_water' }],
      ['schema', { schemaVersion: 2 }],
      ['policy', { policyVersion: 'future-v2' }],
      ['method', { method: 'sensor' }],
      ['source', { source: 'ai' }],
    ]) {
      await assertFails(setDoc(soilCheckRef(alice, 'alice', 'plant-1', id), validSoilCheck(overrides)));
    }
  });

  test('rejects unknown and oversized fields', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertFails(setDoc(soilCheckRef(alice, 'alice', 'plant-1', 'unknown'), validSoilCheck({ moisturePercent: 25 })));
    await assertFails(setDoc(soilCheckRef(alice, 'alice', 'plant-1', 'title'), validSoilCheck({ title: 'x'.repeat(161) })));
    await assertFails(setDoc(soilCheckRef(alice, 'alice', 'plant-1', 'array'), validSoilCheck({ cautions: Array(9).fill('caution') })));
  });

  test('rejects invalid timestamps and all updates', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertFails(setDoc(soilCheckRef(alice, 'alice', 'plant-1', 'created'), validSoilCheck({ createdAt: new Date(0) })));
    await assertFails(setDoc(soilCheckRef(alice, 'alice', 'plant-1', 'suggested'), validSoilCheck({ suggestedCheckAt: new Date(0) })));
    const ref = soilCheckRef(alice);
    await assertSucceeds(setDoc(ref, validSoilCheck()));
    await assertFails(updateDoc(ref, { outcome: 'wait' }));
  });

  test('requires an existing parent plant', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(soilCheckRef(alice), validSoilCheck()));
  });
});

describe('fertilizer-assessment ownership, immutability, and validation', () => {
  test('owner can create, read, list, and delete a valid assessment', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    const ref = fertilizerAssessmentRef(alice);
    await assertSucceeds(setDoc(ref, validFertilizerAssessment()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(getDocs(collection(
      alice.firestore(),
      'users/alice/plants/plant-1/fertilizerAssessments',
    )));
    await assertSucceeds(deleteDoc(ref));
  });

  test('guest and another user cannot create, read, or delete', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const guest = testEnv.unauthenticatedContext();
    await createOwnerPlant(alice);
    await assertFails(setDoc(fertilizerAssessmentRef(guest), validFertilizerAssessment()));
    await assertFails(setDoc(fertilizerAssessmentRef(bob, 'alice'), validFertilizerAssessment()));
    await assertSucceeds(setDoc(fertilizerAssessmentRef(alice), validFertilizerAssessment()));
    await assertFails(getDoc(fertilizerAssessmentRef(guest)));
    await assertFails(getDoc(fertilizerAssessmentRef(bob, 'alice')));
    await assertFails(deleteDoc(fertilizerAssessmentRef(bob, 'alice')));
  });

  test('requires parent and rejects invalid version, enum, fields, and category coupling', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(fertilizerAssessmentRef(alice), validFertilizerAssessment()));
    await createOwnerPlant(alice);
    for (const [id, overrides] of [
      ['dataset', { datasetVersion: '2026-09-03-v1' }],
      ['policy', { policyVersion: 'ai-fertilizer-v1' }],
      ['activity', { growthActivity: 'probably_growing' }],
      ['category', { fertilizerCategory: 'brand_x' }],
      ['unknown', { exactDosage: '10 ml' }],
      ['title', { title: 'x'.repeat(161) }],
      ['cautions', { cautions: Array(9).fill('caution') }],
      ['wait-category', { outcome: 'wait' }],
    ]) {
      await assertFails(setDoc(
        fertilizerAssessmentRef(alice, 'alice', 'plant-1', id),
        validFertilizerAssessment(overrides),
      ));
    }
    const wait = validFertilizerAssessment({ outcome: 'wait' });
    delete wait.fertilizerCategory;
    await assertSucceeds(setDoc(
      fertilizerAssessmentRef(alice, 'alice', 'plant-1', 'wait-valid'),
      wait,
    ));
  });

  test('rejects invalid timestamps and all updates', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertFails(setDoc(
      fertilizerAssessmentRef(alice, 'alice', 'plant-1', 'created'),
      validFertilizerAssessment({ createdAt: new Date(0) }),
    ));
    await assertFails(setDoc(
      fertilizerAssessmentRef(alice, 'alice', 'plant-1', 'review'),
      validFertilizerAssessment({ suggestedReviewAt: new Date(0) }),
    ));
    const ref = fertilizerAssessmentRef(alice);
    await assertSucceeds(setDoc(ref, validFertilizerAssessment()));
    await assertFails(updateDoc(ref, { outcome: 'wait' }));
  });
});

describe('care-log ownership, immutability, and validation', () => {
  test('owner can create watering and fertilizing logs, read, and delete', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    const watering = careLogRef(alice, 'alice', 'plant-1', 'watering');
    const fertilizing = careLogRef(alice, 'alice', 'plant-1', 'fertilizing');
    await assertSucceeds(setDoc(watering, validWateringLog()));
    await assertSucceeds(setDoc(fertilizing, validFertilizingLog()));
    await assertSucceeds(getDoc(watering));
    await assertSucceeds(getDocs(collection(
      alice.firestore(),
      'users/alice/plants/plant-1/careLogs',
    )));
    await assertSucceeds(deleteDoc(watering));
  });

  test('guest and another user cannot create, read, or delete', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const guest = testEnv.unauthenticatedContext();
    await createOwnerPlant(alice);
    await assertFails(setDoc(careLogRef(guest), validWateringLog()));
    await assertFails(setDoc(careLogRef(bob, 'alice'), validWateringLog()));
    await assertSucceeds(setDoc(careLogRef(alice), validWateringLog()));
    await assertFails(getDoc(careLogRef(guest)));
    await assertFails(getDoc(careLogRef(bob, 'alice')));
    await assertFails(deleteDoc(careLogRef(bob, 'alice')));
  });

  test('requires a parent plant and rejects cross-type and unknown fields', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(careLogRef(alice), validWateringLog()));
    await createOwnerPlant(alice);
    await assertFails(setDoc(
      careLogRef(alice, 'alice', 'plant-1', 'water-cross'),
      validWateringLog({ fertilizerForm: 'liquid' }),
    ));
    await assertFails(setDoc(
      careLogRef(alice, 'alice', 'plant-1', 'feed-cross'),
      validFertilizingLog({ wateringMethod: 'top' }),
    ));
    await assertFails(setDoc(
      careLogRef(alice, 'alice', 'plant-1', 'unknown'),
      validWateringLog({ recommendation: 'water now' }),
    ));
  });

  test('rejects invalid enums, amount, source, and schema version', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    for (const [id, value] of [
      ['method', validWateringLog({ wateringMethod: 'spray' })],
      ['form', validFertilizingLog({ fertilizerForm: 'powder' })],
      ['zero', validWateringLog({ amountMl: 0 })],
      ['large', validWateringLog({ amountMl: 100001 })],
      ['source', validWateringLog({ source: 'soil_engine' })],
      ['schema', validWateringLog({ schemaVersion: 2 })],
    ]) {
      await assertFails(setDoc(careLogRef(alice, 'alice', 'plant-1', id), value));
    }
  });

  test('rejects empty, padded, and oversized optional strings', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    for (const [id, value] of [
      ['empty', validWateringLog({ notes: '' })],
      ['padded', validWateringLog({ notes: ' padded ' })],
      ['notes', validWateringLog({ notes: 'x'.repeat(501) })],
      ['product', validFertilizingLog({ productName: 'x'.repeat(121) })],
      ['application', validFertilizingLog({ applicationNote: 'x'.repeat(501) })],
    ]) {
      await assertFails(setDoc(careLogRef(alice, 'alice', 'plant-1', id), value));
    }
  });

  test('rejects invalid occurredAt and createdAt timestamps', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertFails(setDoc(
      careLogRef(alice, 'alice', 'plant-1', 'future'),
      validWateringLog({ occurredAt: new Date(Date.now() + 6 * 60 * 1000) }),
    ));
    await assertFails(setDoc(
      careLogRef(alice, 'alice', 'plant-1', 'old'),
      validWateringLog({ occurredAt: new Date(Date.now() - 366 * 24 * 60 * 60 * 1000) }),
    ));
    await assertFails(setDoc(
      careLogRef(alice, 'alice', 'plant-1', 'created'),
      validWateringLog({ createdAt: new Date(0) }),
    ));
  });

  test('denies all updates', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    const ref = careLogRef(alice);
    await assertSucceeds(setDoc(ref, validWateringLog()));
    await assertFails(updateDoc(ref, { amountMl: 300 }));
  });
});

describe('reminder ownership, validation, and controlled transitions', () => {
  test('owner can create and read; guest and other users are denied', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const guest = testEnv.unauthenticatedContext();
    await createOwnerPlant(alice);
    await assertSucceeds(setDoc(reminderRef(alice), validReminder()));
    await assertSucceeds(getDoc(reminderRef(alice)));
    await assertFails(setDoc(reminderRef(guest), validReminder()));
    await assertFails(setDoc(reminderRef(bob, 'alice'), validReminder()));
    await assertFails(getDoc(reminderRef(bob, 'alice')));
    await assertFails(deleteDoc(reminderRef(alice)));
  });

  test('rejects invalid enums, timestamps, unknown fields, and oversized text', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    for (const [id, value] of [
      ['type', validReminder({ type: 'watering' })],
      ['status', validReminder({ status: 'dismissed' })],
      ['source', validReminder({ source: 'ai' })],
      ['past', validReminder({ dueAt: new Date(0) })],
      ['created', validReminder({ createdAt: new Date(0) })],
      ['unknown', validReminder({ notificationId: 42 })],
      ['title', validReminder({ title: 'x'.repeat(121) })],
      ['note', validReminder({ note: 'x'.repeat(501) })],
    ]) {
      await assertFails(setDoc(reminderRef(alice, 'alice', 'plant-1', id), value));
    }
  });

  test('enforces suggestion references and rejects cross-type fields', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    await assertSucceeds(setDoc(soilCheckRef(alice), validSoilCheck()));
    await assertSucceeds(setDoc(fertilizerAssessmentRef(alice), validFertilizerAssessment()));
    await assertSucceeds(setDoc(
      reminderRef(alice, 'alice', 'plant-1', 'soil'),
      validReminder({ source: 'soil_check_suggestion', soilCheckId: 'soil-check-1' }),
    ));
    await assertSucceeds(setDoc(
      reminderRef(alice, 'alice', 'plant-1', 'fertilizer'),
      validReminder({ type: 'fertilizer_review', title: 'Review fertilizer guidance',
        source: 'fertilizer_assessment_suggestion', fertilizerAssessmentId: 'assessment-1' }),
    ));
    await assertFails(setDoc(
      reminderRef(alice, 'alice', 'plant-1', 'cross'),
      validReminder({ source: 'soil_check_suggestion', soilCheckId: 'soil-check-1',
        fertilizerAssessmentId: 'assessment-1' }),
    ));
    await assertFails(setDoc(
      reminderRef(alice, 'alice', 'plant-1', 'missing'),
      validReminder({ source: 'soil_check_suggestion', soilCheckId: 'missing' }),
    ));
    await assertFails(setDoc(
      reminderRef(alice, 'alice', 'plant-1', 'slash'),
      validReminder({ source: 'soil_check_suggestion', soilCheckId: '../soil-check-1' }),
    ));
  });

  test('allows controlled completion, cancellation, and future reactivation', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    const completed = reminderRef(alice, 'alice', 'plant-1', 'completed');
    await assertSucceeds(setDoc(completed, validReminder()));
    await assertSucceeds(updateDoc(completed, { status: 'completed', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(completed, { status: 'active', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(completed, { status: 'active', dueAt: new Date(0), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(completed, { status: 'active',
      dueAt: new Date(Date.now() + 48 * 60 * 60 * 1000), updatedAt: serverTimestamp() }));
    const cancelled = reminderRef(alice, 'alice', 'plant-1', 'cancelled');
    await assertSucceeds(setDoc(cancelled, validReminder()));
    await assertSucceeds(updateDoc(cancelled, { status: 'cancelled', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(cancelled, { status: 'completed', updatedAt: serverTimestamp() }));
  });

  test('preserves createdAt and rejects unrelated updates', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await createOwnerPlant(alice);
    const ref = reminderRef(alice);
    await assertSucceeds(setDoc(ref, validReminder()));
    await assertFails(updateDoc(ref, { createdAt: new Date(0), status: 'completed', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { title: 'Water now', updatedAt: serverTimestamp() }));
  });
});

describe('curated knowledge is authenticated-read-only', () => {
  test('authenticated users can read knowledge chunks and sources', async () => {
    await seedKnowledge();
    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(getDoc(knowledgeChunkRef(alice)));
    await assertSucceeds(getDoc(knowledgeSourceRef(alice)));
    await assertSucceeds(getDocs(collection(alice.firestore(), 'knowledgeChunks')));
    await assertSucceeds(getDocs(collection(alice.firestore(), 'knowledgeSources')));
  });

  test('unauthenticated users cannot read either knowledge collection', async () => {
    await seedKnowledge();
    const guest = testEnv.unauthenticatedContext();
    await assertFails(getDoc(knowledgeChunkRef(guest)));
    await assertFails(getDoc(knowledgeSourceRef(guest)));
    await assertFails(getDocs(collection(guest.firestore(), 'knowledgeChunks')));
    await assertFails(getDocs(collection(guest.firestore(), 'knowledgeSources')));
  });

  test('authenticated clients cannot create knowledge', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(setDoc(knowledgeChunkRef(alice), { schemaVersion: 1 }));
    await assertFails(setDoc(knowledgeSourceRef(alice), { schemaVersion: 1 }));
  });

  test('authenticated clients cannot update knowledge', async () => {
    await seedKnowledge();
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(updateDoc(knowledgeChunkRef(alice), { title: 'Changed' }));
    await assertFails(updateDoc(knowledgeSourceRef(alice), { title: 'Changed' }));
  });

  test('authenticated clients cannot delete knowledge', async () => {
    await seedKnowledge();
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(deleteDoc(knowledgeChunkRef(alice)));
    await assertFails(deleteDoc(knowledgeSourceRef(alice)));
  });

  test('v3 release metadata and documents are authenticated-read-only', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(v3ReleaseRef(context), {
        schemaVersion: 1,
        datasetVersion: '2026-09-05-v3',
        status: 'complete',
      });
      await setDoc(v3ChunkRef(context), {
        schemaVersion: 1,
        datasetVersion: '2026-09-05-v3',
      });
    });
    const alice = testEnv.authenticatedContext('alice');
    const guest = testEnv.unauthenticatedContext();
    await assertSucceeds(getDoc(v3ReleaseRef(alice)));
    await assertSucceeds(getDoc(v3ChunkRef(alice)));
    await assertFails(getDoc(v3ReleaseRef(guest)));
    await assertFails(getDoc(v3ChunkRef(guest)));
    await assertFails(setDoc(v3ReleaseRef(alice), { status: 'complete' }));
    await assertFails(setDoc(v3ChunkRef(alice), { schemaVersion: 1 }));
    await assertFails(deleteDoc(v3ChunkRef(alice)));
  });
});
