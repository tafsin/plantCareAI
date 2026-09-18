import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {parseOptions} from '../src/options.mjs';

const cli = fileURLToPath(new URL('../src/cli.mjs', import.meta.url));

test('commands are dry-run by default and require exact project confirmation', () => {
  assert.deepEqual(
    parseOptions([
      'process-pending',
      '--project=demo-verification',
      '--confirm-project=demo-verification',
    ]),
    {
      mode: 'process-pending',
      projectId: 'demo-verification',
      apply: false,
      allowProduction: false,
      executionMode: 'dry-run',
    },
  );
  assert.throws(
    () => parseOptions([
      'purge',
      '--project=demo-one',
      '--confirm-project=demo-two',
    ]),
    /matching --project and --confirm-project/,
  );
});

test('production apply requires an explicit production override', () => {
  assert.throws(
    () => parseOptions([
      'purge',
      '--project=plantcare-production',
      '--confirm-project=plantcare-production',
      '--apply',
    ]),
    /separate approval and --allow-production/,
  );
  assert.equal(
    parseOptions([
      'purge',
      '--project=plantcare-production',
      '--confirm-project=plantcare-production',
      '--apply',
      '--allow-production',
    ]).executionMode,
    'apply',
  );
});

test('CLI refuses an unconfirmed project before loading credentials', () => {
  const result = spawnSync(process.execPath, [
    cli,
    'purge',
    '--project=demo-one',
    '--confirm-project=demo-two',
  ], {encoding: 'utf8'});

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /matching --project and --confirm-project/);
  assert.doesNotMatch(result.stderr, /credential|token|private key/i);
});

test('CLI refuses production apply without the explicit override', () => {
  const result = spawnSync(process.execPath, [
    cli,
    'purge',
    '--project=plantcare-production',
    '--confirm-project=plantcare-production',
    '--apply',
  ], {encoding: 'utf8'});

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /separate approval and --allow-production/);
  assert.doesNotMatch(result.stderr, /credential|token|private key/i);
});

test('CLI validation never prints environment secrets or private user data', () => {
  const privateValues = [
    'adapty-secret-value',
    'private-user@example.test',
    'private-plant-content',
    'token-value',
  ];
  const result = spawnSync(
    process.execPath,
    [cli, 'purge', '--project=demo-one', '--confirm-project=demo-two'],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        ADAPTY_SECRET_API_KEY: privateValues[0],
        PRIVATE_TEST_EMAIL: privateValues[1],
        PRIVATE_TEST_CONTENT: privateValues[2],
        PRIVATE_TEST_TOKEN: privateValues[3],
      },
    },
  );
  const output = `${result.stdout}\n${result.stderr}`;
  for (const value of privateValues) assert.doesNotMatch(output, new RegExp(value));
});
