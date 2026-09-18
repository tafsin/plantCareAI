import test from 'node:test';
import assert from 'node:assert/strict';
import {
  isPurgeEligible,
  isValidPending,
  pendingIsOverdue,
  processPending,
} from '../src/core.mjs';

const timestamp = (date) => ({toDate: () => date});
const pending = (overrides = {}) => ({
  id: 'uid-1',
  data: {
    schemaVersion: 1,
    requestedAt: timestamp(new Date('2026-01-01T00:00:00Z')),
    providerCleanup: ['adapty'],
    source: 'self_service_web',
    ...overrides,
  },
});

test('pending request accepts only the exact approved schema', () => {
  assert.equal(isValidPending(pending().id, pending().data), true);
  assert.equal(isValidPending('uid-1', {...pending().data, email: 'x@y.z'}), false);
  assert.equal(isValidPending('uid-1', {...pending().data, providerCleanup: []}), false);
});

test('90 day boundary is eligible and newer records are preserved', () => {
  const now = new Date('2026-04-01T00:00:00Z');
  const record = {
    requestIdentifier: 'request-1',
    accountIdentifier: 'uid-1',
    verificationStatus: 'self_service_authenticated',
    requestDate: timestamp(new Date('2026-01-01T00:00:00Z')),
    completionDate: timestamp(new Date('2026-01-01T00:00:00Z')),
    status: 'completed',
  };
  assert.equal(isPurgeEligible(record, now), true);
  assert.equal(isPurgeEligible({...record, completionDate: timestamp(new Date('2026-01-02T00:00:00Z'))}, now), false);
  assert.equal(isPurgeEligible({...record, token: 'forbidden'}, now), false);
  assert.equal(isPurgeEligible({...record, completionDate: undefined}, now), false);
  assert.equal(isPurgeEligible({...record, status: 'pending'}, now), false);
  assert.equal(isPurgeEligible(record, now), true);
  assert.equal(isPurgeEligible(record, now), true);
});

test('30 day pending boundary is overdue and newer requests are not', () => {
  const now = new Date('2026-01-31T00:00:00Z');
  assert.equal(pendingIsOverdue(pending().data, now), true);
  assert.equal(
    pendingIsOverdue(
      pending({requestedAt: timestamp(new Date('2026-01-02T00:00:00Z'))}).data,
      now,
    ),
    false,
  );
});

test('pending monitoring distinguishes age from completed provider deletion', () => {
  const now = new Date('2026-02-01T00:00:00Z');
  assert.equal(pendingIsOverdue(pending().data, now), true);
  assert.equal(isValidPending(pending().id, pending().data), true);
  assert.equal(
    Object.prototype.hasOwnProperty.call(pending().data, 'completionDate'),
    false,
  );
  assert.equal(
    Object.prototype.hasOwnProperty.call(pending().data, 'status'),
    false,
  );
});

test('success writes minimal audit before deleting pending', async () => {
  const calls = [];
  const result = await processPending({
    pending: pending(),
    deleteAdaptyProfile: async () => { calls.push('provider'); return 'deleted'; },
    writeSupportRecord: async (record) => { calls.push('audit'); assert.deepEqual(Object.keys(record).sort(), ['accountIdentifier', 'completionDate', 'requestDate', 'requestIdentifier', 'status', 'verificationStatus']); },
    deletePending: async () => calls.push('pending'),
    completionDate: timestamp(new Date('2026-01-02T00:00:00Z')),
  });
  assert.equal(result.outcome, 'completed');
  assert.deepEqual(calls, ['provider', 'audit', 'pending']);
});

test('not found is idempotent; provider failure writes failure audit and preserves pending', async () => {
  let deleted = 0;
  const notFound = await processPending({
    pending: pending(),
    deleteAdaptyProfile: async () => 'not_found',
    writeSupportRecord: async () => {},
    deletePending: async () => { deleted += 1; },
    completionDate: timestamp(new Date()),
  });
  assert.equal(notFound.outcome, 'completed');
  assert.equal(deleted, 1);

  let status;
  const failed = await processPending({
    pending: pending(),
    deleteAdaptyProfile: async () => { throw new Error('no'); },
    writeSupportRecord: async (record) => { status = record.status; },
    deletePending: async () => { deleted += 1; },
    completionDate: timestamp(new Date()),
  });
  assert.equal(failed.outcome, 'provider_failed');
  assert.equal(status, 'failed');
  assert.equal(deleted, 1);
});

test('audit failure preserves pending', async () => {
  let deleted = false;
  await assert.rejects(() => processPending({
    pending: pending(),
    deleteAdaptyProfile: async () => 'deleted',
    writeSupportRecord: async () => { throw new Error('write failed'); },
    deletePending: async () => { deleted = true; },
    completionDate: timestamp(new Date()),
  }));
  assert.equal(deleted, false);
});

test('pending-delete failure is safe to retry after idempotent provider result', async () => {
  const calls = [];
  await assert.rejects(() => processPending({
    pending: pending(),
    deleteAdaptyProfile: async () => { calls.push('provider:deleted'); return 'deleted'; },
    writeSupportRecord: async () => calls.push('audit:completed'),
    deletePending: async () => { calls.push('pending:failed'); throw new Error('delete failed'); },
    completionDate: timestamp(new Date()),
  }));

  const retried = await processPending({
    pending: pending(),
    deleteAdaptyProfile: async () => { calls.push('provider:not_found'); return 'not_found'; },
    writeSupportRecord: async () => calls.push('audit:completed'),
    deletePending: async () => calls.push('pending:deleted'),
    completionDate: timestamp(new Date()),
  });

  assert.equal(retried.outcome, 'completed');
  assert.deepEqual(calls, [
    'provider:deleted',
    'audit:completed',
    'pending:failed',
    'provider:not_found',
    'audit:completed',
    'pending:deleted',
  ]);
});

test('malformed pending request is quarantined without side effects', async () => {
  const calls = [];
  const result = await processPending({
    pending: pending({email: 'forbidden@example.com'}),
    deleteAdaptyProfile: async () => calls.push('provider'),
    writeSupportRecord: async () => calls.push('audit'),
    deletePending: async () => calls.push('pending'),
    completionDate: timestamp(new Date()),
  });
  assert.equal(result.outcome, 'quarantined');
  assert.deepEqual(calls, []);
});
