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

download_file() {
  local description="$1"
  local source_url="$2"
  local destination="$3"
  local partial="${destination}.part"
  local attempt=1
  local max_attempts=6
  local retry_delay=1

  rm -f -- "${destination}" "${partial}"
  while ((attempt <= max_attempts)); do
    log "downloading ${description} (attempt ${attempt}/${max_attempts})"
    if curl --fail --location --output "${partial}" "${source_url}"; then
      mv -- "${partial}" "${destination}"
      log "downloaded ${description}"
      return 0
    fi

    rm -f -- "${partial}"
    if ((attempt >= max_attempts)); then
      fail "failed to download ${description} after ${max_attempts} attempts"
    fi
    log "download of ${description} failed on attempt ${attempt}; retrying in ${retry_delay}s"
    sleep "${retry_delay}"
    attempt=$((attempt + 1))
    retry_delay=$((retry_delay * 2))
  done
}

if [[ "${1:-}" != --run-job ]]; then
[[ "$#" -ge 1 ]] || fail "usage: $0 <brick-file> [prerequisite-brick-file ...]"
brick_file="$1"
shift
prerequisite_brick_files=("$@")
[[ -f "${brick_file}" ]] || fail "Brick file not found: ${brick_file}"
for prerequisite_brick_file in "${prerequisite_brick_files[@]}"; do
  [[ -f "${prerequisite_brick_file}" ]] || \
    fail "Prerequisite Brick file not found: ${prerequisite_brick_file}"
done

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
pipeline_id="$(required_env RUBBLE_PIPELINE_ID)"

bootstrap_dir="${runner_temp}/rubble-bootstrap"
bootstrap_home="${runner_temp}/rubble-bootstrap-home"
rubble_home="${runner_temp}/rubble-home-${task_id}"
build_dir="${runner_temp}/rubble-build-${task_id}"
auth_dir="${runner_temp}/rubble-pipeline-auth"
importer="${bootstrap_dir}/rubble-inventory-bundle-import"
bundle="${bootstrap_dir}/rubble.tar"
mkdir -p "${bootstrap_dir}" "${auth_dir}"
chmod 700 "${auth_dir}"

download_file "Rubble bundle" "${rubble_bundle_url}" "${bundle}"
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
  log "Rubble ${root_full} is not installed"
  download_file "Rubble importer" "${importer_url}" "${importer}"
  [[ -s "${importer}" ]] || fail "downloaded importer is empty"
  log "importing Rubble bundle root ${root_short}"
  RUBBLE_HOME="${bootstrap_home}" \
  RUBBLE_INVENTORY_BUNDLE_USE_ORIGINAL=1 \
    /bin/sh "${importer}" import "${bundle}"
fi
[[ -x "${rubble}" ]] || fail "imported Rubble executable not found: ${rubble}"

export RUBBLE_EXECUTABLE="${rubble}"
export RUBBLE_HOME="${rubble_home}"
export RUBBLE_JOB_BUILD_DIR="${build_dir}"
exec "${rubble}" -q script --inherit-env --language bash "${BASH_SOURCE[0]}" \
  --run-job "${brick_file}" "${prerequisite_brick_files[@]}"
fi

shift
brick_file="${1:?Brick file is required}"
shift
prerequisite_brick_files=("$@")
export RUBBLE_BRICK_FILE="${brick_file}"
lifecycle_relative='rubble-generated/eetwolr-rubble/lifecycle.sh'
source "${GITHUB_WORKSPACE:?}/${lifecycle_relative}"
runner_temp="$(required_env RUNNER_TEMP)"
github_env="$(required_env GITHUB_ENV)"
rubble_home="$(required_env RUBBLE_HOME)"
build_dir="$(required_env RUBBLE_JOB_BUILD_DIR)"
auth_dir="${runner_temp}/rubble-pipeline-auth"
pipeline_id="$(required_env RUBBLE_PIPELINE_ID)"
rubble-exec mkdir -p -- "${auth_dir}"
rubble-exec chmod 700 "${auth_dir}"

pipeline_auth_file_relative="$(required_env RUBBLE_PIPELINE_AUTH_FILE)"
required_env RUBBLE_PIPELINE_AUTH_KEY >/dev/null


config_file="${auth_dir}/config.yaml"
credentials_file="${auth_dir}/credentials.yaml"

pipeline_auth_relative='rubble-generated/eetwolr-rubble/pipeline-auth.enc'
[[ "${pipeline_auth_file_relative}" == "${pipeline_auth_relative}" ]] || \
  fail "pipeline authentication path does not match the declared payload"
pipeline_auth_file="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/${pipeline_auth_file_relative}"
open_auth_script_relative='rubble-generated/eetwolr-rubble/open-pipeline-auth.mjs'
open_auth_script="${GITHUB_WORKSPACE}/${open_auth_script_relative}"
[[ -f "${open_auth_script}" ]] || fail "declared pipeline authentication action is missing"
log "opening one-use pipeline authentication files"
"${rubble}" -q script --inherit-env "${open_auth_script}" \
  "${pipeline_id}" \
  "${pipeline_auth_file}" \
  "${config_file}" \
  "${credentials_file}"
unset RUBBLE_PIPELINE_AUTH_KEY

export RUBBLE_CONFIG="${config_file}"
export RUBBLE_CREDENTIALS="${credentials_file}"

rubble_run_hook pre-job

for prerequisite_brick_file in "${prerequisite_brick_files[@]}"; do
  log "pulling and unpacking prerequisite Brick outputs from remote store at depth 1: ${prerequisite_brick_file}"
  "${rubble}" -q pull \
    --rubble-home "${rubble_home}" \
    --depth 1 \
    --unpack \
    -r "${RUBBLE_REMOTE_STORE}" \
    "${prerequisite_brick_file}"
done

log "pulling and unpacking available Brick outputs from remote store at depth 1"
"${rubble}" -q pull --rubble-home "${rubble_home}" --depth 1 --unpack -r "${RUBBLE_REMOTE_STORE}" "${brick_file}"

inventory_script="$("${rubble}" -q list --rubble-home "${rubble_home}" --format bash --depth 1 "${brick_file}")"
eval "${inventory_script}"
outputs_present=false
for inventory_key in "${!brick_inventory[@]}"; do
  case "${inventory_key}" in
    *::status)
      case "${brick_inventory[${inventory_key}]}" in
        present|present+packed) outputs_present=true ;;
        *) outputs_present=false; break ;;
      esac
      ;;
  esac
done

if [[ "${outputs_present}" == true ]]; then
  log "Brick outputs are already present; skipping build and push"
else
  log "building missing outputs for ${brick_file}"
  "${rubble}" -q build \
    --builder make \
    --rubble-home "${rubble_home}" \
    --build-dir "${build_dir}" \
    --build-scope missing \
    "${brick_file}"

  log "pushing the complete Brick graph to remote store"
  "${rubble}" -q push \
    --rubble-home "${rubble_home}" \
    --depth 0 \
    --expand-opaque \
    -r "${RUBBLE_REMOTE_STORE}" \
    "${brick_file}"
fi

rubble_run_hook post-job

log "publishing Rubble runtime paths for later workflow steps"
{
  printf 'RUBBLE_EXECUTABLE=%s\n' "${rubble}"
  printf 'RUBBLE_CONFIG=%s\n' "${config_file}"
  printf 'RUBBLE_CREDENTIALS=%s\n' "${credentials_file}"
  printf 'RUBBLE_HOME=%s\n' "${rubble_home}"
  printf 'RUBBLE_GITHUB_ACTIONS_RUNTIME=%s\n' "${RUBBLE_GITHUB_ACTIONS_RUNTIME}"
} >> "${github_env}"