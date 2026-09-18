export const PENDING_COLLECTION = 'accountDeletionCleanupRequests';
export const SUPPORT_COLLECTION = 'accountDeletionSupportRecords';
export const RETENTION_DAYS = 90;
export const PENDING_DEADLINE_DAYS = 30;

const exactKeys = (value, expected) => {
  if (!value || typeof value !== 'object') return false;
  const keys = Object.keys(value).sort();
  return keys.length === expected.length &&
    keys.every((key, index) => key === [...expected].sort()[index]);
};

const isTimestamp = (value) => value && typeof value.toDate === 'function';

export function isValidPending(uid, data) {
  return Boolean(uid) && exactKeys(data, [
    'schemaVersion',
    'requestedAt',
    'providerCleanup',
    'source',
  ]) && data.schemaVersion === 1 &&
    isTimestamp(data.requestedAt) &&
    Array.isArray(data.providerCleanup) &&
    data.providerCleanup.length === 1 &&
    data.providerCleanup[0] === 'adapty' &&
    ['self_service_mobile', 'self_service_web'].includes(data.source);
}

export function isValidSupportRecord(data) {
  return exactKeys(data, [
    'requestIdentifier',
    'accountIdentifier',
    'verificationStatus',
    'requestDate',
    'completionDate',
    'status',
  ]) && typeof data.requestIdentifier === 'string' &&
    data.requestIdentifier.length > 0 &&
    typeof data.accountIdentifier === 'string' &&
    data.accountIdentifier.length > 0 &&
    ['self_service_authenticated', 'support_verified'].includes(
      data.verificationStatus,
    ) && isTimestamp(data.requestDate) && isTimestamp(data.completionDate) &&
    ['completed', 'failed'].includes(data.status);
}

export function isPurgeEligible(data, now) {
  if (!isValidSupportRecord(data)) return false;
  const cutoff = new Date(now.getTime() - RETENTION_DAYS * 86400000);
  return data.completionDate.toDate() <= cutoff;
}

export function pendingIsOverdue(data, now) {
  if (!data || !isTimestamp(data.requestedAt)) return false;
  const cutoff = new Date(now.getTime() - PENDING_DEADLINE_DAYS * 86400000);
  return data.requestedAt.toDate() <= cutoff;
}

export function supportRecord({uid, requestedAt, completionDate, status}) {
  return {
    requestIdentifier: uid,
    accountIdentifier: uid,
    verificationStatus: 'self_service_authenticated',
    requestDate: requestedAt,
    completionDate,
    status,
  };
}

export async function processPending({
  pending,
  deleteAdaptyProfile,
  writeSupportRecord,
  deletePending,
  completionDate,
}) {
  if (!isValidPending(pending.id, pending.data)) {
    return {outcome: 'quarantined'};
  }
  let status = 'completed';
  try {
    const result = await deleteAdaptyProfile(pending.id);
    if (result !== 'deleted' && result !== 'not_found') {
      throw new Error('provider_failure');
    }
  } catch {
    status = 'failed';
  }
  await writeSupportRecord(
    supportRecord({
      uid: pending.id,
      requestedAt: pending.data.requestedAt,
      completionDate,
      status,
    }),
  );
  if (status === 'failed') return {outcome: 'provider_failed'};
  await deletePending();
  return {outcome: 'completed'};
}
