// Local publication authentication. Policy is interpreted only by Rubble's typed resolver.
import { spawnSync } from 'node:child_process';

export class CredentialError extends Error {
  constructor(message) {
    super(message); this.status = 'failed'; this.target = 'Credential configuration';
    this.evidence = []; this.cleanup = [];
    Object.defineProperty(this, 'message', { value: message, enumerable: true });
  }
}
export function resolveCredential(resource, protocol = 'http', { env = process.env, cwd, invoke = spawnSync } = {}) {
  if (!env.RUBBLE_EXECUTABLE) throw new CredentialError('Run through rubble script --inherit-env to select credentials.');
  const response = invoke(env.RUBBLE_EXECUTABLE, ['-q', 'credential', 'resolve', '--protocol', protocol,
    '--format', 'json', '--reveal', '--resource-stdin'], { env, cwd, encoding: 'utf8', input: resource });
  // Resolver diagnostics/output can contain sensitive material; expose only a repair command.
  if (response.error || response.status !== 0) throw new CredentialError(`Selected ${protocol} credential lookup failed; use rubble credential explain --protocol ${protocol} URL with the same configuration.`);
  const document = JSON.parse(response.stdout);
  if (document.schema !== 'rubble.credential.resolve/v1' || document.protocol !== protocol) {
    throw new CredentialError('Unsupported Rubble credential resolution format.');
  }
  return document;
}

function field(credential, name) {
  const entry = credential.fields[name];
  if (entry?.state !== 'present' || entry.encoding !== 'utf8' || typeof entry.value !== 'string') {
    throw new CredentialError(`Credential field ${name} requires a revealed UTF-8 value.`);
  }
  return entry.value;
}
export function apiToken(credential) {
  if (credential.state === 'default') return undefined;
  const token = credential.kind === 'bearer' ? field(credential, 'http.bearer.token')
    : credential.kind === 'basic' ? field(credential, 'http.basic.password') : undefined;
  if (token === undefined) throw new CredentialError('GitHub/GitLab API credentials require bearer or basic (password is the PAT).');
  if (!token || /\s/.test(token)) throw new CredentialError('API authentication requires a nonempty PAT without whitespace.');
  return token;
}
export function jenkinsAuthentication(credential) {
  if (credential.state === 'default') return undefined;
  if (credential.kind !== 'basic') throw new CredentialError('Jenkins API credentials require basic username and API token.');
  const token = field(credential, 'http.basic.password');
  if (!token.trim()) throw new CredentialError('Jenkins API credentials require a nonempty API token.');
  return { user: field(credential, 'http.basic.username'), token, 'token-source': 'credentials' };
}
export function serviceBase(value) {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) {
    throw new CredentialError('API service entry must be an HTTP(S) URL without credentials, query or fragment.');
  }
  url.pathname = `${url.pathname.replace(/\/+$/, '')}/`;
  return url.href;
}
export const gitlabApiBase = target => `${target.protocol}://${target.host}${target.subfolder ? `/${target.subfolder}` : ''}/api/v4/`;
export function gitlabEnvironment(target, credential, inherited = process.env) {
  const env = { ...inherited, GLAB_NO_PROMPT: '1', NO_COLOR: '1', GITLAB_API_HOST: target.host,
    GLAB_API_PROTOCOL: target.protocol, GITLAB_SUBFOLDER: target.subfolder };
  delete env.RUBBLE_PIPELINE_AUTH_KEY;
  delete env.RUBBLE_AUTH_CLEANUP_TOKEN;
  const token = apiToken(credential);
  if (token !== undefined) {
    delete env.GLAB_TOKEN; delete env.OAUTH_TOKEN; delete env.CI_JOB_TOKEN; delete env.GLAB_DEBUG;
    env.GITLAB_TOKEN = token;
  }
  return env;
}
export function githubTarget(origin, repositoryOverride, defaultHost = process.env.GH_HOST || 'github.com') {
  const network = /^(?:https?|ssh):\/\//i.test(origin) || /^[^/]+@[^:]+:/.test(origin);
  const remote = !network ? undefined : origin.includes('://') ? new URL(origin) : new URL(`ssh://${origin.replace(':', '/')}`);
  let host = remote ? (remote.protocol === 'ssh:' ? remote.hostname : remote.host) : defaultHost;
  if (remote?.protocol === 'ssh:' && host === 'ssh.github.com') host = 'github.com';
  let repository = remote ? remote.pathname.replace(/^\/+|\.git$/g, '') : '';
  if (repositoryOverride) repository = repositoryOverride;
  if (!host || repository && repository.split('/').length !== 2) throw new CredentialError('Cannot resolve GitHub service and owner/repository from origin.');
  const cloud = host === 'github.com' || host.endsWith('.ghe.com');
  const base = host === 'github.com' ? 'https://api.github.com/'
    : cloud ? `https://api.${host}/` : `https://${host}/api/v3/`;
  return { host, repository, base, cloud };
}
export function githubEnvironment(target, credential, inherited = process.env) {
  const env = { ...inherited, GH_HOST: target.host, GH_PROMPT_DISABLED: '1' };
  const token = apiToken(credential);
  if (token !== undefined) {
    for (const key of ['GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GITHUB_ENTERPRISE_TOKEN', 'GH_DEBUG']) delete env[key];
    env[target.cloud ? 'GH_TOKEN' : 'GH_ENTERPRISE_TOKEN'] = token;
  }
  return env;
}

// Scope headers/helpers to each actual remote URL; never change the caller's Git config.
export function gitAuthentication(urls, credential, inherited = process.env) {
  const env = { ...inherited }, args = [];
  let socket, nativeSsh = false, managed = false;
  for (const [index, resource] of urls.entries()) {
    const protocol = /^https?:\/\//i.test(resource) ? 'http'
      : /^ssh:\/\//i.test(resource) || /^[^/]+@[^:]+:/.test(resource) ? 'ssh' : undefined;
    if (!protocol) continue;
    const selected = credential(resource, protocol);
    if (selected.state === 'default') continue;
    managed = true;
    env.GIT_TERMINAL_PROMPT = '0';
    if (protocol === 'ssh') {
      const entry = selected.fields['ssh.agent.socket'];
      const next = `${entry.encoding}:${entry.value}`;
      if (socket !== undefined && socket !== next) throw new CredentialError('One Git invocation cannot use different SSH agents; publish to each remote separately.');
      socket = next;
      if (entry.encoding === 'unix-bytes-base64' && process.platform !== 'win32') {
        env.RUBBLE_REMOTE_SSH_SOCKET_BASE64 = entry.value; nativeSsh = true;
      } else env.SSH_AUTH_SOCK = field(selected, 'ssh.agent.socket');
      env.GIT_SSH_VARIANT = 'ssh';
      env.GIT_SSH_COMMAND = 'ssh -o IdentityAgent=SSH_AUTH_SOCK -o BatchMode=yes';
    } else {
      const header = selected.kind === 'bearer' ? `Authorization: Bearer ${field(selected, 'http.bearer.token')}`
        : selected.kind === 'basic' ? `Authorization: Basic ${Buffer.from(`${field(selected, 'http.basic.username')}:${field(selected, 'http.basic.password')}`).toString('base64')}`
        : selected.kind === 'header' ? `${field(selected, 'http.header.name')}${field(selected, 'http.header.value') === '' ? ';' : `: ${field(selected, 'http.header.value')}`}` : undefined;
      if (header === undefined) throw new CredentialError('Unsupported Git HTTP credential type.');
      const variable = `RUBBLE_REMOTE_GIT_HTTP_HEADER_${index}`;
      env[variable] = header;
      const target = httpTransportUrl(resource);
      args.push('-c', `http.${target}.extraHeader=`, `--config-env=http.${target}.extraHeader=${variable}`,
        '-c', `credential.${target}.helper=`);
      env.GIT_ASKPASS = ''; env.GCM_INTERACTIVE = 'Never';
    }
    for (const key of Object.keys(env)) if (key.startsWith('GIT_TRACE') || key === 'GIT_CURL_VERBOSE') delete env[key];
  }
  return { env, args, nativeSsh, managed };
}

function httpTransportUrl(resource) {
  if (!/^https?:\/\//i.test(resource)) return resource;
  const url = new URL(resource);
  url.username = ''; url.password = '';
  return url.href;
}

// Our publication/probe commands name origin and supply explicit refspecs.
// Keep native origin handling when all URLs select Default. Otherwise isolate
// each push URL so its process-global authentication cannot affect another one.
export function gitInvocations(urls, argv, credential, inherited = process.env) {
  const authentications = urls.map(url => gitAuthentication([url], credential, inherited));
  if (authentications.every(auth => !auth.managed)) {
    return [{ ...authentications[0], argv }];
  }
  const destination = argv.lastIndexOf('origin');
  return authentications.map((auth, index) => {
    const command = [...argv];
    command[destination] = auth.managed ? httpTransportUrl(urls[index]) : urls[index];
    return { ...auth, argv: command };
  });
}

// Bash preserves native Unix socket bytes which JavaScript environment strings cannot.
export function gitExecution(git, argv, authentication, tools) {
  if (!authentication.nativeSsh) return { program: git, argv, env: authentication.env };
  return { program: tools.bash, argv: ['--noprofile', '--norc', '-c',
    'set -eo pipefail; SSH_AUTH_SOCK="$(printf %s "$RUBBLE_REMOTE_SSH_SOCKET_BASE64" | "$RUBBLE_REMOTE_BASE64" --decode || exit 1; printf .)"; SSH_AUTH_SOCK="${SSH_AUTH_SOCK%.}"; export SSH_AUTH_SOCK; unset RUBBLE_REMOTE_SSH_SOCKET_BASE64 RUBBLE_REMOTE_BASE64; exec "$@"',
    'rubble-auth-git', git, ...argv],
    env: { ...authentication.env, RUBBLE_REMOTE_BASE64: tools.base64 },
  };
}

// Generated Bash publishers invoke this wrapper without putting tokens in shell variables.
if (import.meta.main) {
  try {
    const [mode, cwd, ...args] = process.argv.slice(2);
    const invoke = (program, argv, options = {}) => spawnSync(program, argv, { cwd, encoding: 'utf8', ...options });
    const tools = invoke(process.env.RUBBLE_EXECUTABLE, ['-q', 'info', '--tools', '--format', 'json']);
    if (tools.status !== 0) throw new CredentialError('Cannot resolve managed publication tools.');
    const managedTools = JSON.parse(tools.stdout).tools;
    const git = managedTools.git;
    let operations;
    if (mode === 'git') {
      const direction = args.shift();
      const remote = invoke(git, ['remote', 'get-url', ...(direction === 'push' ? ['--push'] : []), '--all', 'origin']);
      if (remote.status !== 0) throw new CredentialError('Cannot resolve publication origin URL.');
      const urls = remote.stdout.trim().split(/\r?\n/);
      operations = gitInvocations(direction === 'push' ? urls : urls.slice(0, 1), args,
        (url, protocol) => resolveCredential(url, protocol, { cwd }))
        .map(auth => gitExecution(git, [...auth.args, ...auth.argv], auth, managedTools));
    } else if (mode === 'gh') {
      const remote = invoke(git, ['remote', 'get-url', 'origin']);
      const target = githubTarget(remote.status === 0 ? remote.stdout.trim() : '', process.env.RUBBLE_PUBLISH_GITHUB_REPOSITORY);
      const env = githubEnvironment(target, resolveCredential(target.base, 'http', { cwd }));
      operations = [{ program: 'gh', argv: args, env }];
    } else throw new CredentialError('Unknown publication authentication adapter.');
    process.exitCode = 0;
    for (const { program, argv, env } of operations) {
      const result = invoke(program, argv, { env, stdio: 'inherit' });
      if (result.error) throw new CredentialError('Cannot execute authenticated publication tool.');
      if (result.status !== 0) process.exitCode = result.status ?? 1;
    }
  } catch (error) {
    console.error(error instanceof CredentialError ? error.message : 'Publication credential preparation failed; verify the selected configuration.');
    process.exitCode = 1;
  }
}
