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

build_mode="$(required_env RUBBLE_BUILD_MODE)"
case "${build_mode}" in
  build)
    pull_depth=0
    ;;
  verify_only)
    pull_depth=1
    ;;
  *)
    fail "unsupported RUBBLE_BUILD_MODE: ${build_mode}"
    ;;
esac
log "declared execution mode: ${build_mode}"

runner_temp="$(required_env RUNNER_TEMP)"
github_env="$(required_env GITHUB_ENV)"
task_id="${GITHUB_JOB:-job}"
rubble_bundle_url="$(required_env RUBBLE_BUNDLE_URL)"
pipeline_id="$(required_env RUBBLE_PIPELINE_ID)"

pipeline_auth_file_relative="$(required_env RUBBLE_PIPELINE_AUTH_FILE)"
required_env RUBBLE_PIPELINE_AUTH_KEY >/dev/null
runner_node="$(required_env RUBBLE_NODE)"


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

config_file="${auth_dir}/config.yaml"
credentials_file="${auth_dir}/credentials.yaml"

pipeline_auth_relative='rubble-generated/adcrhlu-curl/pipeline-auth.enc'
[[ "${pipeline_auth_file_relative}" == "${pipeline_auth_relative}" ]] || \
  fail "pipeline authentication path does not match the declared payload"
pipeline_auth_file="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/${pipeline_auth_file_relative}"
open_auth_script_relative='rubble-generated/adcrhlu-curl/open-pipeline-auth.mjs'
open_auth_script="${GITHUB_WORKSPACE}/${open_auth_script_relative}"
[[ -f "${open_auth_script}" ]] || fail "declared pipeline authentication action is missing"
log "opening one-use pipeline authentication files"
"${runner_node}" "${open_auth_script}" \
  "${pipeline_id}" \
  "${pipeline_auth_file}" \
  "${config_file}" \
  "${credentials_file}"
unset RUBBLE_PIPELINE_AUTH_KEY

export RUBBLE_CONFIG="${config_file}"
export RUBBLE_CREDENTIALS="${credentials_file}"

log "pulling declared Brick outputs from remote store at depth ${pull_depth}"
"${rubble}" -q pull --rubble-home "${rubble_home}" --depth "${pull_depth}" -r default "${brick_file}"

if [[ "${build_mode}" == 'verify_only' ]]; then
  inventory_payload=''
  list_succeeded=0
  if inventory_payload="$("${rubble}" -q list --rubble-home "${rubble_home}" --depth 1 --format bash -- "${brick_file}")"; then
    list_succeeded=1
  fi
  [[ -n "${inventory_payload}" ]] || fail "Rubble list produced no Bash inventory for boundary verification"
  unset brick_inventory
  builtin eval "${inventory_payload}" || fail "failed to evaluate trusted Rubble inventory"
  inventory_declaration="$(builtin declare -p brick_inventory 2>/dev/null)" || \
    fail "Rubble list did not provide brick_inventory"
  [[ "${inventory_declaration}" == 'declare -A '* ]] || \
    fail "Rubble list returned an invalid brick_inventory declaration"
  ((list_succeeded == 1)) || fail "Rubble list failed while inspecting boundary artifacts"

  root_short="${brick_inventory['::root']:-}"
  [[ -n "${root_short}" ]] || fail "Rubble list returned no boundary root"
  root_id_key="${root_short}::id"
  root_brk_key="${root_short}:brk"
  root_outputs_key="${root_short}::outputs"
  [[ ${brick_inventory[$root_id_key]+present} ]] || fail "Rubble list omitted the boundary root ID"
  [[ ${brick_inventory[$root_brk_key]+present} ]] || fail "Rubble list omitted boundary metadata"
  [[ ${brick_inventory[$root_outputs_key]+present} ]] || fail "Rubble list omitted boundary outputs"

  artifact_descriptor=("${brick_inventory[$root_id_key]}" "${brick_inventory[$root_brk_key]}")
  output_names=()
  IFS=' ' builtin read -r -a output_names <<<"${brick_inventory[$root_outputs_key]}"
  for output_name in "${output_names[@]}"; do
    output_path_key="${root_short}:${output_name}"
    [[ ${brick_inventory[$output_path_key]+present} ]] || \
      fail "Rubble list omitted boundary output ${output_name}"
    artifact_descriptor+=("${output_name}" "${brick_inventory[$output_path_key]}")
  done
  if "${rubble}" -q api verify_artifacts "${artifact_descriptor[@]}"; then
    log "verified declared boundary artifacts for ${brick_file}"
  else
    fail "declared boundary artifacts are missing or corrupt for ${brick_file}"
  fi
else
  log "building missing outputs for ${brick_file}"
  "${rubble}" -q build \
    --builder make \
    --rubble-home "${rubble_home}" \
    --build-dir "${build_dir}" \
    --build-scope missing \
    "${brick_file}"
  log "pushing current Brick output to remote store"
  "${rubble}" -q push --rubble-home "${rubble_home}" --depth 1 -r default "${brick_file}"
fi

log "publishing Rubble runtime paths for later workflow steps"
{
  printf 'RUBBLE_EXECUTABLE=%s\n' "${rubble}"
  printf 'RUBBLE_CONFIG=%s\n' "${config_file}"
  printf 'RUBBLE_CREDENTIALS=%s\n' "${credentials_file}"
  printf 'RUBBLE_HOME=%s\n' "${rubble_home}"
} >> "${github_env}"