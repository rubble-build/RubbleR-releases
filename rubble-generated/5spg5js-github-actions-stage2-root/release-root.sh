#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log() {
  printf '[github-actions-release] %s\n' "$1" >&2
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

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && builtin pwd)"
root_id='5spg5jsxjdotb5mswro3qxm2kbcmepajlsvrnytvz4oxys7pu57a-github-actions-stage2-root'
root_name='github-actions-stage2-root'
root_brick_relative='store/5s/pg/brk-5spg5jsxjdotb5mswro3qxm2kbcmepajlsvrnytvz4oxys7pu57a-github-actions-stage2-root.brick'
root_brick="${script_dir}/${root_brick_relative}"
root_hash="${root_id%%-*}"
rubble="$(required_env RUBBLE_EXECUTABLE)"
config_file="$(required_env RUBBLE_CONFIG)"
rubble_home="$(required_env RUBBLE_HOME)"
runner_temp="$(required_env RUNNER_TEMP)"
repository="$(required_env GITHUB_REPOSITORY)"
run_id="$(required_env GITHUB_RUN_ID)"
run_attempt="$(required_env GITHUB_RUN_ATTEMPT)"
required_env GH_TOKEN >/dev/null
[[ -x "${rubble}" ]] || fail "Rubble executable not found: ${rubble}"
[[ -f "${root_brick}" ]] || fail "root Brick file not found: ${root_brick}"

release_dir="${runner_temp}/rubble-release"
bundle="${release_dir}/${root_hash:0:7}-${root_name}.tar"
mkdir -p "${release_dir}"

log "exporting root inventory bundle ${root_id}"
"${rubble}" -q \
  --config "${config_file}" \
  --rubble-home "${rubble_home}" \
  script rubble-inventory-bundle export \
  --output "${bundle}" \
  --depth 0 \
  "${root_brick}"
[[ -s "${bundle}" ]] || fail "exported root inventory bundle is empty: ${bundle}"

release_name="$(date -u +'%Y%m%d%H%M%S')"
release_tag="${release_name}-${run_id}-${run_attempt}"
log "creating GitHub release ${release_name} for ${root_id}"
gh release create "${release_tag}" \
  --repo "${repository}" \
  --title "${release_name}" \
  --notes "Rubble inventory bundle for ${root_id}" \
  "${bundle}"
log "GitHub release ${release_name} created with asset $(basename "${bundle}")"