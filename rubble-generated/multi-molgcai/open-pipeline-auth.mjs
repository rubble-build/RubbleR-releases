#!/usr/bin/env bun

import { webcrypto } from 'node:crypto';
import { closeSync, fsyncSync, openSync, readFileSync, rmSync, writeSync } from 'node:fs';

const ENVELOPE_MAGIC = Buffer.from('RUBBLE-AUTH\x01', 'latin1');
const AAD_PREFIX = Buffer.from('rubble-pipeline-auth-v1\x00', 'latin1');
const NONCE_BYTES = 12;
const TAG_BYTES = 16;
const CONFIG_LENGTH_BYTES = 8;

/** Fails without including key, ciphertext, or plaintext content in logs. */
function fail(message) {
  throw new Error(message);
}

/** Decodes one canonical unpadded base64 value. */
function decodeBase64(value, alphabet, description) {
  const pattern = alphabet === 'base64url' ? /^[A-Za-z0-9_-]+$/u : /^[A-Za-z0-9+/]+$/u;
  if (!pattern.test(value)) {
    fail(`${description} is not canonical base64`);
  }
  const decoded = Buffer.from(value, alphabet);
  if (decoded.toString(alphabet).replace(/=+$/u, '') !== value) {
    decoded.fill(0);
    fail(`${description} is not canonical base64`);
  }
  return decoded;
}

/** Validates the canonical lowercase pipeline UUID used as authenticated data. */
function validatePipelineId(pipelineId) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u.test(pipelineId)) {
    fail('Pipeline identity is not a canonical generated UUID');
  }
}

/** Writes a new private file without replacing an existing path. */
function writePrivateNew(path, bytes) {
  const descriptor = openSync(path, 'wx', 0o600);
  let failure;
  try {
    let offset = 0;
    while (offset < bytes.length) {
      offset += writeSync(descriptor, bytes, offset);
    }
    fsyncSync(descriptor);
  } catch (error) {
    failure = error;
  }
  try {
    closeSync(descriptor);
  } catch (error) {
    failure ??= error;
  }
  if (failure !== undefined) {
    rmSync(path, { force: true });
    throw failure;
  }
}

/** Authenticates and opens the declared one-use config and credential payload. */
async function openPipelineAuth(pipelineId, encryptedPath, configPath, credentialsPath) {
  validatePipelineId(pipelineId);
  const encodedKey = process.env.RUBBLE_PIPELINE_AUTH_KEY ?? '';
  delete process.env.RUBBLE_PIPELINE_AUTH_KEY;
  const key = decodeBase64(encodedKey, 'base64url', 'Pipeline authentication key');
  let envelope;
  let plaintext;
  try {
    if (key.length !== 32) {
      fail('Pipeline authentication key has an invalid length');
    }
    const encodedEnvelope = readFileSync(encryptedPath, 'utf8').trim();
    envelope = decodeBase64(encodedEnvelope, 'base64', 'Pipeline authentication payload');
    const headerBytes = ENVELOPE_MAGIC.length + NONCE_BYTES;
    if (envelope.length < headerBytes + TAG_BYTES + CONFIG_LENGTH_BYTES) {
      fail('Pipeline authentication payload is truncated');
    }
    if (!envelope.subarray(0, ENVELOPE_MAGIC.length).equals(ENVELOPE_MAGIC)) {
      fail('Pipeline authentication payload has an invalid envelope');
    }

    const nonce = envelope.subarray(ENVELOPE_MAGIC.length, headerBytes);
    const sealed = envelope.subarray(headerBytes);
    const aad = Buffer.concat([AAD_PREFIX, Buffer.from(pipelineId, 'utf8')]);
    const algorithm = 'ChaCha20-Poly1305';
    const cryptoKey = await webcrypto.subtle.importKey('raw-secret', key, algorithm, false, ['decrypt']);
    plaintext = Buffer.from(await webcrypto.subtle.decrypt({ name: algorithm, iv: nonce, additionalData: aad }, cryptoKey, sealed));

    const configLengthValue = plaintext.readBigUInt64BE(0);
    if (configLengthValue > BigInt(Number.MAX_SAFE_INTEGER)) {
      fail('Pipeline authentication config length is unsupported');
    }
    const configEnd = CONFIG_LENGTH_BYTES + Number(configLengthValue);
    if (configEnd > plaintext.length) {
      fail('Pipeline authentication plaintext has an invalid config length');
    }
    writePrivateNew(configPath, plaintext.subarray(CONFIG_LENGTH_BYTES, configEnd));
    try {
      writePrivateNew(credentialsPath, plaintext.subarray(configEnd));
    } catch (error) {
      rmSync(configPath, { force: true });
      throw error;
    }
  } finally {
    key.fill(0);
    envelope?.fill(0);
    plaintext?.fill(0);
  }
}

/** Materializes a complete pair supplied by platform secret bindings. */
function openSecrets(mode, configPath, credentialsPath) {
  const names = mode === 'secrets-env'
    ? ['RUBBLE_SERVER_CONFIG', 'RUBBLE_SERVER_CREDENTIALS']
    : ['RUBBLE_SERVER_CONFIG_FILE', 'RUBBLE_SERVER_CREDENTIALS_FILE'];
  const buffers = [];
  try {
    for (const name of names) {
      const value = process.env[name];
      delete process.env[name];
      if (value === undefined) fail('Both complete authentication files are required');
      buffers.push(mode === 'secrets-env' ? Buffer.from(value, 'utf8') : readFileSync(value));
    }
    writePrivateNew(configPath, buffers[0]);
    try {
      writePrivateNew(credentialsPath, buffers[1]);
    } catch (error) {
      rmSync(configPath, { force: true });
      throw error;
    }
  } finally {
    for (const buffer of buffers) buffer.fill(0);
  }
}

// Bun's process.stderr.write leaves inherited pipes nonblocking for later build tools.
try {
  const [, , mode, ...args] = process.argv;
  if (mode === 'local-files' && args.length === 4) {
    await openPipelineAuth(...args);
  } else if ((mode === 'secrets-env' || mode === 'secrets-file') && args.length === 2) {
    openSecrets(mode, ...args);
  } else {
    fail('Invalid authentication action arguments');
  }
  writeSync(2, '[builder-auth] opened complete authentication files\n');
} catch {
  writeSync(2, '[builder-auth] ERROR: authentication files could not be opened\n');
  process.exitCode = 1;
}
