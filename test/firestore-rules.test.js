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

const createOwnerPlant = async (context, uid = 'alice', plantId = 'plant-1') =>
  assertSucceeds(setDoc(plantRef(context, uid, plantId), validPlant()));

const knowledgeChunkRef = (context) =>
  doc(context.firestore(), 'knowledgeChunks/tomato__identity__species_identity');

const knowledgeSourceRef = (context) =>
  doc(context.firestore(), 'knowledgeSources/umn_growing_tomatoes');

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
});
