// GitHub operations consume the prepared files; user hooks never need this protocol.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function metadata(directory, name, fallback) {
  try {
    return readFileSync(join(directory, name), 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') return fallback;
    throw error;
  }
}

function run(gh, args, input) {
  const result = spawnSync(gh, args, { input, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || `gh failed with status ${result.status}`);
  }
  return result.stdout;
}

function view(gh, repository, tag) {
  const [owner, name] = repository.split('/');
  // A successful null lookup confirms absence for both published and pending draft tags.
  const response = JSON.parse(run(gh, ['api', 'graphql', '--input', '-'], JSON.stringify({
    query: `query($owner: String!, $name: String!, $tag: String!) {
      repository(owner: $owner, name: $name) { release(tagName: $tag) { databaseId } }
    }`,
    variables: { owner, name, tag },
  })));
  const release = response.data.repository.release;
  if (release === null) return null;
  if (!Number.isInteger(release?.databaseId)) throw new Error('release lookup returned no database ID');
  const details = JSON.parse(run(gh, ['api', `repos/${repository}/releases/${release.databaseId}`]));
  if (typeof details?.draft !== 'boolean' || typeof details?.url !== 'string' || typeof details?.upload_url !== 'string') {
    throw new Error('release lookup returned invalid release details');
  }
  return details;
}

try {
  const directory = required('RUBBLE_RELEASE_DIR');
  const assets = readdirSync(join(directory, 'assets'), { withFileTypes: true })
    .filter(entry => entry.isFile()).map(entry => entry.name).sort();
  if (assets.length === 0) process.exit(0);
  const gh = required('RUBBLE_GITHUB_CLI');
  const repository = required('GITHUB_REPOSITORY');
  const timestamp = new Date().toISOString().replace(/\D/g, '').slice(0, 14);
  const title = metadata(directory, 'title', timestamp).trimEnd();
  const tag = metadata(directory, 'tag', `${timestamp}-${required('GITHUB_RUN_ID')}-${required('GITHUB_RUN_ATTEMPT')}`).trimEnd();
  const notes = metadata(directory, 'notes.md', `Rubble inventory bundle for ${required('RUBBLE_ROOT_ID')}`);
  if (!tag || /[\r\n]/.test(tag)) throw new Error('release tag must be one non-empty line');
  const endpoint = `repos/${repository}/releases`;
  let release = view(gh, repository, tag);
  if (release === null) {
    // A published release establishes tag uniqueness. Drafts can share a pending tag.
    try {
      release = JSON.parse(run(gh, ['api', '--method', 'POST', endpoint, '--input', '-'], JSON.stringify({
        tag_name: tag, target_commitish: required('GITHUB_SHA'), name: title, body: notes, draft: false,
      })));
    } catch (createError) {
      try {
        release = view(gh, repository, tag);
        if (release === null) throw createError;
      } catch {
        throw createError;
      }
    }
  }
  if (release.draft) {
    try {
      run(gh, ['api', '--method', 'PATCH', release.url, '--input', '-'], JSON.stringify({ draft: false }));
    } catch (publishError) {
      // Another pipeline may have published a different draft for this tag.
      try {
        const winner = view(gh, repository, tag);
        if (winner === null || winner.draft) throw publishError;
        release = winner;
      } catch {
        throw publishError;
      }
    }
  }
  for (const name of assets) {
    const upload = new URL(release.upload_url.replace(/\{.*$/, ''));
    upload.searchParams.set('name', name);
    // GitHub rejects duplicate names. Never clobber, skip, or delete another upload.
    run(gh, ['api', '--method', 'POST', upload.toString(), '--header', 'Content-Type: application/octet-stream',
      '--input', join(directory, 'assets', name)]);
    console.error(`[github-actions-release] uploaded ${name} to ${tag}`);
  }
} catch (error) {
  console.error(`[github-actions-release] ERROR: ${error.message}`);
  process.exitCode = 1;
}
