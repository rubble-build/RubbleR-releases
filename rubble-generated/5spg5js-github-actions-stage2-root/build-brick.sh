#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log() {
  printf '[github-actions-build] %s\n' "$1" >&2
}

fail() {
  log "ERROR: $1"
  exit 1
}

required_env() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "${value}" ]] || fail "${name} is required"
  printf '%s\n' "${value}"
}

[[ "$#" -eq 1 ]] || fail "usage: $0 <brick-file>"
brick_file="$1"
[[ -f "${brick_file}" ]] || fail "Brick file not found: ${brick_file}"

expected_runner_os="$(required_env RUBBLE_EXPECTED_RUNNER_OS)"
expected_runner_arch="$(required_env RUBBLE_EXPECTED_RUNNER_ARCH)"
runner_os="$(required_env RUNNER_OS)"
runner_arch="$(required_env RUNNER_ARCH)"
[[ "${runner_os}" == "${expected_runner_os}" ]] || \
  fail "runner OS mismatch: expected ${expected_runner_os}, got ${runner_os}"
[[ "${runner_arch}" == "${expected_runner_arch}" ]] || \
  fail "runner architecture mismatch: expected ${expected_runner_arch}, got ${runner_arch}"
log "runner capability verified: os=${runner_os} arch=${runner_arch}"

runner_temp="$(required_env RUNNER_TEMP)"
github_env="$(required_env GITHUB_ENV)"
task_id="${GITHUB_JOB:-job}"
rubble_bundle_url="$(required_env RUBBLE_BUNDLE_URL)"
required_env R2_ENDPOINT >/dev/null
required_env R2_BUCKET >/dev/null
required_env R2_ACCESS_KEY_ID >/dev/null
required_env R2_SECRET_ACCESS_KEY >/dev/null

bootstrap_dir="${runner_temp}/rubble-bootstrap"
bootstrap_home="${runner_temp}/rubble-bootstrap-home"
rubble_home="${runner_temp}/rubble-home-${task_id}"
build_dir="${runner_temp}/rubble-build-${task_id}"
config_dir="${runner_temp}/rubble-config-${task_id}"
importer="${bootstrap_dir}/rubble-inventory-bundle-import"
bundle="${bootstrap_dir}/rubble.tar"
mkdir -p "${bootstrap_dir}" "${config_dir}"

log "downloading Rubble bundle"
curl --fail --location --retry 5 --output "${bundle}" "${rubble_bundle_url}"
[[ -s "${bundle}" ]] || fail "downloaded Rubble bundle is empty"

manifest="$(tar -xOf "${bundle}" manifest.rbm)"
root_short="$(awk -F '\t' '$1 == "root" { print $2; exit }' <<<"${manifest}")"
root_full="$(awk -F '\t' -v root="${root_short}" '$1 == "brick" && $3 == root { print $4; exit }' <<<"${manifest}")"
[[ -n "${root_short}" && -n "${root_full}" ]] || fail "Rubble bundle manifest has no resolvable root"
root_hash="${root_full%%-*}"
[[ "${#root_hash}" -eq 52 ]] || fail "Rubble bundle root has an invalid hash: ${root_full}"
rubble="/var/lib/rubble/store/${root_hash:0:2}/${root_hash:2:2}/out-${root_full}"

if [[ -x "${rubble}" ]]; then
  log "reusing installed Rubble ${root_full}"
else
  importer_url="$(required_env RUBBLE_IMPORTER_URL)"
  log "Rubble ${root_full} is not installed; downloading importer"
  curl --fail --location --retry 5 --output "${importer}" "${importer_url}"
  [[ -s "${importer}" ]] || fail "downloaded importer is empty"
  log "importing Rubble bundle root ${root_short}"
  RUBBLE_HOME="${bootstrap_home}" \
  RUBBLE_INVENTORY_BUNDLE_USE_ORIGINAL=1 \
    /bin/sh "${importer}" import "${bundle}"
fi
[[ -x "${rubble}" ]] || fail "imported Rubble executable not found: ${rubble}"

config_file="${config_dir}/config.yaml"
cat >"${config_file}" <<CONFIG
build:
  build-dir: ${build_dir}
  clean-on-success: false
remote_store:
  - type: s3
    alias: default
    endpoint: ${R2_ENDPOINT}
    bucket: ${R2_BUCKET}
    region: us-east-1
    api: S3v4
    path: path
    auth:
      type: access_key
      access_key_id:
        env: R2_ACCESS_KEY_ID
      secret_access_key:
        env: R2_SECRET_ACCESS_KEY
CONFIG
chmod 600 "${config_file}"
export RUBBLE_CONFIG="${config_file}"

log "pulling available Brick outputs from remote store"
"${rubble}" -q pull --rubble-home "${rubble_home}" --depth 0 -r default "${brick_file}"
log "building missing outputs for ${brick_file}"
"${rubble}" -q build \
  --builder make \
  --rubble-home "${rubble_home}" \
  --build-dir "${build_dir}" \
  --build-scope missing \
  "${brick_file}"
log "pushing current Brick output to remote store"
"${rubble}" -q push --rubble-home "${rubble_home}" --depth 1 -r default "${brick_file}"

log "publishing Rubble runtime paths for later workflow steps"
{
  printf 'RUBBLE_EXECUTABLE=%s\n' "${rubble}"
  printf 'RUBBLE_CONFIG=%s\n' "${config_file}"
  printf 'RUBBLE_HOME=%s\n' "${rubble_home}"
} >> "${github_env}"