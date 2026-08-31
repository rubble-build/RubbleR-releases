#!/usr/bin/env node

import { createDecipheriv } from 'node:crypto';
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
function openPipelineAuth(pipelineId, encryptedPath, configPath, credentialsPath) {
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
    const ciphertext = sealed.subarray(0, sealed.length - TAG_BYTES);
    const tag = sealed.subarray(sealed.length - TAG_BYTES);
    const aad = Buffer.concat([AAD_PREFIX, Buffer.from(pipelineId, 'utf8')]);
    const decipher = createDecipheriv('chacha20-poly1305', key, nonce, { authTagLength: TAG_BYTES });
    decipher.setAAD(aad);
    decipher.setAuthTag(tag);
    plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

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

if (process.argv.length !== 6) {
  process.stderr.write('[github-actions-auth] ERROR: invalid authentication action arguments\n');
  process.exitCode = 1;
} else {
  const [, , pipelineId, encryptedPath, configPath, credentialsPath] = process.argv;
  try {
    openPipelineAuth(pipelineId, encryptedPath, configPath, credentialsPath);
    process.stderr.write('[github-actions-auth] opened one-use pipeline authentication files\n');
  } catch {
    process.stderr.write('[github-actions-auth] ERROR: pipeline authentication could not be opened\n');
    process.exitCode = 1;
  }
}
