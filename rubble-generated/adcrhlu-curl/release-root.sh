#!/usr/bin/bash
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

required_command_file() {
  local name="$1"
  local path="$2"
  [[ -f "${path}" && -x "${path}" ]] || \
    fail "declared runner command '${name}' is unavailable or not an executable regular file: ${path}"
  log "runner command verified: ${name}=${path}"
}

runner_bash='/usr/bin/bash'
runner_date='/usr/bin/date'
runner_dirname='/usr/bin/dirname'
runner_gh='/usr/bin/gh'
runner_mkdir='/usr/bin/mkdir'
required_command_file 'bash' "${runner_bash}"
required_command_file 'date' "${runner_date}"
required_command_file 'dirname' "${runner_dirname}"
required_command_file 'gh' "${runner_gh}"
required_command_file 'mkdir' "${runner_mkdir}"

script_dir="$(builtin cd "$("${runner_dirname}" "${BASH_SOURCE[0]}")" && builtin pwd)"
root_id='adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl'
root_name='curl'
root_brick_relative='store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'
release_inventory_relative='release-inventory.txt'
release_bundle_relative='release-bundle.sh'
release_brick_files=(

  'store/5n/72/brk-5n72uhvu5cptapfmuhaql6u7gekif3s7rsavzqfspcxoyrwoybmq-curl-linux-x86_64-musl-8.18.0.tar.xz.brick'

  'store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

)
root_brick="${script_dir}/${root_brick_relative}"
release_inventory="${script_dir}/${release_inventory_relative}"
release_bundle="${script_dir}/${release_bundle_relative}"
root_hash="${root_id%%-*}"
rubble="$(required_env RUBBLE_EXECUTABLE)"
config_file="$(required_env RUBBLE_CONFIG)"
rubble_home="$(required_env RUBBLE_HOME)"
runner_temp="$(required_env RUNNER_TEMP)"
repository="$(required_env GITHUB_REPOSITORY)"
run_id="$(required_env GITHUB_RUN_ID)"
run_attempt="$(required_env GITHUB_RUN_ATTEMPT)"
required_env GH_TOKEN >/dev/null
[[ -f "${rubble}" && -x "${rubble}" ]] || fail "Rubble executable not found: ${rubble}"
[[ -f "${root_brick}" ]] || fail "root Brick file not found: ${root_brick}"
[[ -f "${release_inventory}" ]] || fail "release inventory not found: ${release_inventory}"
[[ -f "${release_bundle}" ]] || fail "release bundle script not found: ${release_bundle}"

for release_brick_relative in "${release_brick_files[@]}"; do
  release_brick="${script_dir}/${release_brick_relative}"
  [[ -f "${release_brick}" ]] || fail "selected release Brick file not found: ${release_brick}"
  log "pulling and unpacking selected release Brick outputs at depth 1: ${release_brick}"
  "${rubble}" -q pull \
    --rubble-home "${rubble_home}" \
    --depth 1 \
    --unpack \
    -r default \
    "${release_brick}"
done

release_dir="${runner_temp}/rubble-release"
bundle="${release_dir}/${root_hash:0:7}-${root_name}.tar"
"${runner_mkdir}" -p "${release_dir}"

log "exporting root inventory bundle ${root_id}"
RUBBLE_EXECUTABLE="${rubble}" \
RUBBLE_CONFIG="${config_file}" \
RUBBLE_HOME="${rubble_home}" \
"${runner_bash}" "${release_bundle}" export \
  --output "${bundle}" \
  --depth 0 \
  --inventory-file "${release_inventory}" \
  "${root_brick}"
[[ -s "${bundle}" ]] || fail "exported root inventory bundle is empty: ${bundle}"

release_name="$("${runner_date}" -u +'%Y%m%d%H%M%S')"
release_tag="${release_name}-${run_id}-${run_attempt}"
log "creating GitHub release ${release_name} for ${root_id}"
"${runner_gh}" release create "${release_tag}" \
  --repo "${repository}" \
  --title "${release_name}" \
  --notes "Rubble inventory bundle for ${root_id}" \
  "${bundle}"
log "GitHub release ${release_name} created with asset ${bundle##*/}"