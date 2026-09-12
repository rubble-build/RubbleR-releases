# Generated lifecycle context. Source this file to use managed tools and runner commands.
export rubble="${RUBBLE_EXECUTABLE:?RUBBLE_EXECUTABLE is required}"
tool_information="$("${rubble}" -q info --format bash --tools)" || return
eval "${tool_information}" || return
unset tool_information

lifecycle_dir="$(builtin cd -- "$(rubble-exec dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
export RUBBLE_GITHUB_ACTIONS_RUNTIME="${lifecycle_dir}/$(rubble-exec basename -- "${BASH_SOURCE[0]}")"
repository_relative='../..'
export RUBBLE_REPOSITORY="$(builtin cd -- "${lifecycle_dir}/${repository_relative}" && builtin pwd)"
root_brick_relative='store/gg/em/brk-ggem3s3ueu6ucbqpc5vd2en4qrxvtvm6xb473xozlwo2actjojxq-rubble.brick'
export RUBBLE_ROOT_BRICK="${lifecycle_dir}/${root_brick_relative}"
export RUBBLE_ROOT_ID='ggem3s3ueu6ucbqpc5vd2en4qrxvtvm6xb473xozlwo2actjojxq-rubble'
export RUBBLE_ROOT_NAME='rubble'
export RUBBLE_BRICK_FILE="${RUBBLE_BRICK_FILE:-${RUBBLE_ROOT_BRICK}}"
export RUBBLE_BRICK_ID="${RUBBLE_BRICK_ID:-${RUBBLE_ROOT_ID}}"
root_platform='x86_64-linux'
export RUBBLE_BUILD_PLATFORM="${RUBBLE_BUILD_PLATFORM:-${root_platform}}"
export RUBBLE_REMOTE_STORE='default'
inventory_relative='release-inventory.txt'
export RUBBLE_RELEASE_INVENTORY="${lifecycle_dir}/${inventory_relative}"
publisher_relative='github-actions-publish.sh'
export RUBBLE_PUBLISH_SCRIPT="${lifecycle_dir}/${publisher_relative}"

declare -A rubble_hooks=()

hook_relative='../../.rubble/hooks/github-actions/pre-publish.sh'
rubble_hooks['pre-publish']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/github-actions/post-publish.sh'
rubble_hooks['post-publish']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/github-actions/pre-job.sh'
rubble_hooks['pre-job']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/github-actions/post-job.sh'
rubble_hooks['post-job']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/github-actions/prepare-release.sh'
rubble_hooks['prepare-release']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/github-actions/post-release.sh'
rubble_hooks['post-release']="${lifecycle_dir}/${hook_relative}"

export RUBBLE_HOOKS_DIR="$(rubble-exec dirname -- "${rubble_hooks[pre-publish]}")"

rubble_hook_present() {
  [[ -f "${rubble_hooks[$1]}" && -s "${rubble_hooks[$1]}" ]]
}

rubble_run_hook() {
  local name="$1"
  if rubble_hook_present "${name}"; then
    printf '[github-actions] running %s hook\n' "${name}" >&2
    (builtin cd -- "${RUBBLE_REPOSITORY}" && "${rubble}" -q script --inherit-env "${rubble_hooks[${name}]}")
  fi
}

# Only runner invocations use runner paths. Local hooks retain local tool selection.
declare -A rubble_runner_commands=()
if [[ "${RUBBLE_ON_RUNNER:-}" == 1 ]]; then
  case "${RUBBLE_BUILD_PLATFORM}" in

    'aarch64-linux')

      rubble_runner_commands['gh']='/usr/bin/gh'

      ;;

    'x86_64-linux')

      rubble_runner_commands['gh']='/usr/bin/gh'

      ;;

    *) printf '[github-actions] unknown runner platform: %s\n' "${RUBBLE_BUILD_PLATFORM}" >&2; return 1 ;;
  esac
fi

# Extra commands are available to hooks that source this library.
rubble-command() {
  local name="$1"
  shift
  if [[ -n "${rubble_runner_commands[${name}]:-}" ]]; then
    local executable="${rubble_runner_commands[${name}]}"
    [[ -f "${executable}" && -x "${executable}" ]] || {
      printf '[github-actions] declared runner command %s is unavailable: %s\n' "${name}" "${executable}" >&2
      return 1
    }
    "${executable}" "$@"
  elif [[ "${name}" == gh ]]; then
    command gh "$@"
  else
    rubble-exec "${name}" "$@"
  fi
}