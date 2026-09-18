import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {
  PENDING_COLLECTION,
  SUPPORT_COLLECTION,
  isPurgeEligible,
  isValidPending,
  pendingIsOverdue,
  processPending,
} from './core.mjs';
import {parseOptions} from './options.mjs';

const {mode, projectId, apply} = parseOptions(process.argv.slice(2));

const db = getFirestore(initializeApp({credential: applicationDefault(), projectId}));
const now = new Date();

async function deleteAdaptyProfile(uid) {
  const apiKey = process.env.ADAPTY_SECRET_API_KEY;
  if (!apiKey) throw new Error('ADAPTY_SECRET_API_KEY is required for apply.');
  const response = await fetch(
    'https://api.adapty.io/api/v2/server-side-api/profile/',
    {
      method: 'DELETE',
      headers: {
        Authorization: `Api-Key ${apiKey}`,
        'adapty-customer-user-id': uid,
      },
    },
  );
  if (response.status === 204) return 'deleted';
  if (response.status === 404) return 'not_found';
  throw new Error(`Adapty deletion failed with status ${response.status}.`);
}

if (mode === 'process-pending') {
  const snapshot = await db.collection(PENDING_COLLECTION).get();
  let eligible = 0;
  let completed = 0;
  let failed = 0;
  let quarantined = 0;
  let overdue = 0;
  for (const document of snapshot.docs) {
    const data = document.data();
    if (!isValidPending(document.id, data)) {
      quarantined += 1;
      continue;
    }
    eligible += 1;
    if (pendingIsOverdue(data, now)) overdue += 1;
    if (!apply) continue;
    const outcome = await processPending({
      pending: {id: document.id, data},
      deleteAdaptyProfile,
      writeSupportRecord: (record) => db
        .collection(SUPPORT_COLLECTION)
        .doc(document.id)
        .set(record),
      deletePending: () => document.ref.delete(),
      completionDate: Timestamp.fromDate(now),
    });
    if (outcome.outcome === 'completed') completed += 1;
    if (outcome.outcome === 'provider_failed') failed += 1;
  }
  console.log(JSON.stringify({
    mode: apply ? 'apply' : 'dry-run', eligible, completed, failed,
    quarantined, overdue,
  }));
} else {
  const snapshot = await db.collection(SUPPORT_COLLECTION).get();
  const eligible = snapshot.docs.filter((document) =>
    isPurgeEligible(document.data(), now));
  if (apply) {
    for (const document of eligible) await document.ref.delete();
  }
  console.log(JSON.stringify({
    mode: apply ? 'apply' : 'dry-run',
    inspected: snapshot.size,
    eligible: eligible.length,
    purged: apply ? eligible.length : 0,
  }));
}
