#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log() {
  printf '[remote-build] %s\n' "$1" >&2
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

absolute_payload() {
  [[ -f "$1" ]] || fail "Brick file not found: $1"
  printf '%s/%s\n' "$(builtin cd -- "$(dirname -- "$1")" && builtin pwd)" "$(basename -- "$1")"
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

script_dir="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
job_temp="$(required_env RUBBLE_JOB_TEMP)"
context_file="${job_temp}/context.sh"

save_context() {
  mkdir -p -- "${job_temp}"
  local name
  for name in RUBBLE_EXECUTABLE RUBBLE_HOME RUBBLE_JOB_BUILD_DIR RUBBLE_CONFIG RUBBLE_CREDENTIALS RUBBLE_CI_RUNTIME RUBBLE_AUTH_OWNED_DIR; do
    if [[ -v "${name}" ]]; then
      printf 'export %s=%q\n' "${name}" "${!name}"
    else
      printf 'unset %s\n' "${name}"
    fi
  done > "${context_file}"
}

case "${1:-}" in
  cleanup)
    [[ -f "${context_file}" ]] || exit 0
    source "${context_file}"
    if [[ -n "${RUBBLE_AUTH_OWNED_DIR:-}" && -d "${RUBBLE_AUTH_OWNED_DIR}" ]]; then
      cleanup_relative='cleanup-auth.sh'
      (unset RUBBLE_CONFIG RUBBLE_CREDENTIALS
       "${RUBBLE_EXECUTABLE}" script --inherit-env --language bash "${script_dir}/${cleanup_relative}" "${RUBBLE_AUTH_OWNED_DIR}")
    fi
    rm -f -- "${context_file}"
    exit 0
    ;;
  release)
    [[ -f "${context_file}" ]] || fail "successful build context is required for release"
    source "${context_file}"
    release_relative='release-root.sh'
    exec "${RUBBLE_EXECUTABLE}" script --inherit-env --language bash "${script_dir}/${release_relative}"
    ;;
  build) shift ;;
esac

if [[ "${1:-}" != --run-job ]]; then
[[ "$#" -ge 1 ]] || fail "usage: $0 <brick-file> [prerequisite-brick-file ...]"
brick_file="$(absolute_payload "$1")"
shift
prerequisite_brick_files=()
for prerequisite_brick_file in "$@"; do
  prerequisite_brick_files+=("$(absolute_payload "${prerequisite_brick_file}")")
done

runner_os="$(required_env RUBBLE_RUNNER_OS)"
runner_arch="$(required_env RUBBLE_RUNNER_ARCH)"
case "${runner_os}" in Linux) os=linux ;; Darwin|macOS) os=macos ;; Windows|MINGW*|MSYS*) os=windows ;; *) fail "unknown runner OS: ${runner_os}" ;; esac
case "${runner_arch}" in x86_64|X64|AMD64) arch=x86_64 ;; aarch64|arm64|ARM64) arch=aarch64 ;; *) fail "unknown runner architecture: ${runner_arch}" ;; esac
[[ "${arch}-${os}" == "${RUBBLE_BUILD_PLATFORM:?}" ]] || fail "runner platform mismatch: expected ${RUBBLE_BUILD_PLATFORM}, got ${arch}-${os}"
log "runner capability verified: os=${runner_os} arch=${runner_arch}"
# Platform bootstrapping is separate from the neutral job lifecycle. Linux is the first implementation.
[[ "${os}" == linux ]] || fail "bundle bootstrap for ${RUBBLE_BUILD_PLATFORM} is not implemented yet"
rubble_bundle_url="$(required_env RUBBLE_BUNDLE_URL)"
runner_temp="${job_temp}"

bootstrap_dir="${runner_temp}/rubble-bootstrap"
bootstrap_home="${runner_temp}/rubble-bootstrap-home"
rubble_home="${runner_temp}/home"
build_dir="${runner_temp}/build"
auth_dir="${runner_temp}/authentication"
importer="${bootstrap_dir}/rubble-inventory-bundle-import"
bundle="${bootstrap_dir}/rubble.tar"
mkdir -p "${bootstrap_dir}"

# Both VM and container jobs use the same trusted PATH lookup.
rubble=''
expected_runtime_id="${RUBBLE_EXPECTED_RUNTIME_ID:-}"
if [[ -n "${expected_runtime_id}" ]] && candidate="$(command -v rubble)"; then
  candidate="$(readlink -f -- "${candidate}")"
  candidate_name="${candidate##*/}"
  candidate_id="${candidate_name#out-}"
  candidate_short="${candidate_id:0:7}-${candidate_id#*-}"
  if [[ "${candidate_id}" == "${expected_runtime_id}" || "${candidate_short}" == "${expected_runtime_id}" ]]; then
    rubble="${candidate}"
    log "reusing PATH Rubble ${candidate_id}"
  fi
fi

if [[ -z "${rubble}" ]]; then
download_file "Rubble bundle" "${rubble_bundle_url}" "${bundle}"
[[ -s "${bundle}" ]] || fail "downloaded Rubble bundle is empty"

manifest="$(tar -xOf "${bundle}" manifest.rbm)"
root_short="$(awk -F '\t' '$1 == "root" { print $2; exit }' <<<"${manifest}")"
root_full="$(awk -F '\t' -v root="${root_short}" '$1 == "brick" && $3 == root { print $4; exit }' <<<"${manifest}")"
[[ -n "${root_short}" && -n "${root_full}" ]] || fail "Rubble bundle manifest has no resolvable root"
root_hash="${root_full%%-*}"
[[ "${#root_hash}" -eq 52 ]] || fail "Rubble bundle root has an invalid hash: ${root_full}"
rubble="/var/lib/rubble/store/${root_hash:0:2}/${root_hash:2:2}/out-${root_full}"

# Different runtime bundles can contain the same artifacts, so coordinate on the
# shared store. The descriptor lock is released on exit, including failed imports.
command -v flock >/dev/null 2>&1 || fail "Linux bootstrap requires util-linux flock"
mkdir -p /var/lib/rubble/store
(
flock --exclusive --timeout 300 9 || fail "could not acquire the shared bootstrap lock within 300 seconds"
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
) 9>/var/lib/rubble/store/.rubble-bootstrap.lock

fi

export RUBBLE_EXECUTABLE="${rubble}"
export RUBBLE_HOME="${rubble_home}"
export RUBBLE_JOB_BUILD_DIR="${build_dir}"
exec "${rubble}" script --inherit-env --language bash "${BASH_SOURCE[0]}" \
  --run-job "${brick_file}" "${prerequisite_brick_files[@]}"
fi

shift
brick_file="${1:?Brick file is required}"
shift
prerequisite_brick_files=("$@")
export RUBBLE_BRICK_FILE="${brick_file}"
lifecycle_relative='lifecycle.sh'
source "${script_dir}/${lifecycle_relative}"
runner_temp="${job_temp}"
rubble_home="$(required_env RUBBLE_HOME)"
build_dir="$(required_env RUBBLE_JOB_BUILD_DIR)"
auth_dir="${runner_temp}/authentication"
authentication_relative='authentication.sh'
source "${script_dir}/${authentication_relative}"
# Record the owned path before activation so orchestration cleanup also covers interruption.
export RUBBLE_AUTH_OWNED_DIR="${auth_dir}"
save_context
rubble_auth_activate "${rubble}" "${auth_dir}"
save_context

rubble_run_hook pre-job

log "checking remote Brick outputs at depth 1"
if "${rubble}" --no-banner exists --fast --rubble-home "${rubble_home}" --depth 1 -r "${RUBBLE_REMOTE_STORE}" "${brick_file}"; then
  log "Brick outputs are already present remotely; skipping pull, build and push"
else
  exists_status=$?
  if [[ "${exists_status}" -ne 1 ]]; then
    log "remote Brick output check failed with status ${exists_status}"
    exit "${exists_status}"
  fi

  if [[ "${RUBBLE_JOB_BUILD_ALLOWED:-true}" != true ]]; then
    fail "required cached outputs are unavailable for preparation-only task ${brick_file}; refresh the store and regenerate the plan"
  fi

  for prerequisite_brick_file in "${prerequisite_brick_files[@]}"; do
    log "pulling and unpacking prerequisite Brick outputs from remote store at depth 1: ${prerequisite_brick_file}"
    "${rubble}" --no-banner pull \
      --rubble-home "${rubble_home}" \
      --depth 1 \
      --unpack \
      -r "${RUBBLE_REMOTE_STORE}" \
      "${prerequisite_brick_file}"
    prerequisite_inventory="${RUBBLE_JOB_TEMP:?}/prerequisite-inventory.sh"
    "${rubble}" --no-banner list --rubble-home "${rubble_home}" --depth 1 --format bash "${prerequisite_brick_file}" > "${prerequisite_inventory}"
    source "${prerequisite_inventory}"
    for inventory_key in "${!brick_inventory[@]}"; do
      if [[ "${inventory_key}" == *::status ]]; then
        case "${brick_inventory[${inventory_key}]}" in
          present|present+packed) ;;
          *) fail "required prerequisite outputs are unavailable: ${prerequisite_brick_file}; refusing to build excluded dependencies" ;;
        esac
      fi
    done
  done

  log "pulling and unpacking available Brick outputs from remote store at depth 1"
  "${rubble}" --no-banner pull --rubble-home "${rubble_home}" --depth 1 --unpack -r "${RUBBLE_REMOTE_STORE}" "${brick_file}"

  log "building missing outputs for ${brick_file}"
  clean_args=()
  if [[ "${RUBBLE_CLEAN_ON_SUCCESS:-false}" == true ]]; then clean_args+=(--clean-on-success); fi
  "${rubble}" --no-banner build \
    --builder make \
    --rubble-home "${rubble_home}" \
    --build-dir "${build_dir}" \
    --build-scope missing \
    "${clean_args[@]}" \
    "${brick_file}"

  log "pushing the complete Brick graph to remote store"
  "${rubble}" --no-banner push \
    --rubble-home "${rubble_home}" \
    --depth 0 \
    --expand-opaque \
    -r "${RUBBLE_REMOTE_STORE}" \
    "${brick_file}"
fi

rubble_run_hook post-job

save_context