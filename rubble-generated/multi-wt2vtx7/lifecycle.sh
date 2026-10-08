export RUBBLE_CI_BUILDER='github-actions'
if [[ "${RUBBLE_CI_JOB_KIND:-}" != build ]]; then
  unset RUBBLE_BRICK_ID RUBBLE_BRICK_FILE RUBBLE_JOB_BUILD_ALLOWED
fi
# Generated lifecycle context. Source this file to use managed tools and runner commands.
export rubble="${RUBBLE_EXECUTABLE:?RUBBLE_EXECUTABLE is required}"
tool_information="$("${rubble}" -q info --format bash --tools)" || return
eval "${tool_information}" || return
unset tool_information

lifecycle_dir="$(builtin cd -- "$(rubble-exec dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
export RUBBLE_CI_RUNTIME="${lifecycle_dir}/$(rubble-exec basename -- "${BASH_SOURCE[0]}")"
repository_relative='../..'
export RUBBLE_REPOSITORY="$(builtin cd -- "${lifecycle_dir}/${repository_relative}" && builtin pwd)"
export RUBBLE_PLAN_ID='multi-wt2vtx7wyvepsxpqup54yqlf3tygan5v7pinf3lxq26whwr2xrca'
export RUBBLE_PLAN_TITLE='2 bricks: aarch64-linux-xdff5n7-rubble, x86_64-linux-3eolsvc-rubble'
export RUBBLE_PLAN_NOTES='Rubble inventory bundles for:
aarch64-linux-xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble
x86_64-linux-3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble'
declare -a rubble_roots=(

  'xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble'

  '3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble'

)
declare -A rubble_root_short_ids=() rubble_root_names=() rubble_root_platforms=() rubble_root_bricks=()

rubble_root_short_ids['xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble']='xdff5n7-rubble'
rubble_root_names['xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble']='rubble'

rubble_root_platforms['xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble']='aarch64-linux'

root_relative='store/xd/ff/brk-xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble.brick'
rubble_root_bricks['xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble']="${lifecycle_dir}/${root_relative}"

rubble_root_short_ids['3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble']='3eolsvc-rubble'
rubble_root_names['3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble']='rubble'

rubble_root_platforms['3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble']='x86_64-linux'

root_relative='store/3e/ol/brk-3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble.brick'
rubble_root_bricks['3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble']="${lifecycle_dir}/${root_relative}"

default_platform='x86_64-linux'
export RUBBLE_BUILD_PLATFORM="${RUBBLE_BUILD_PLATFORM:-${default_platform}}"
export RUBBLE_REMOTE_STORE='default'
inventory_relative='release-inventory.txt'
export RUBBLE_RELEASE_INVENTORY="${lifecycle_dir}/${inventory_relative}"
publisher_relative='github-actions-publish.sh'
export RUBBLE_PUBLISH_SCRIPT="${lifecycle_dir}/${publisher_relative}"

declare -A rubble_hooks=()

hook_relative='../../.rubble/hooks/pre-job.sh'
rubble_hooks['pre-job']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/post-job.sh'
rubble_hooks['post-job']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/prepare-release.sh'
rubble_hooks['prepare-release']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/post-release.sh'
rubble_hooks['post-release']="${lifecycle_dir}/${hook_relative}"

hook_directory_relative='../../.rubble/hooks'
export RUBBLE_HOOKS_DIR="${lifecycle_dir}/${hook_directory_relative}"

rubble_hook_present() {
  [[ -f "${rubble_hooks[$1]}" && -s "${rubble_hooks[$1]}" ]]
}

rubble_run_hook() {
  local name="$1"
  if rubble_hook_present "${name}"; then
    printf '[remote] running %s hook\n' "${name}" >&2
    (builtin cd -- "${RUBBLE_REPOSITORY}" && "${rubble}" script --inherit-env "${rubble_hooks[${name}]}")
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

    *) printf '[remote] unknown runner platform: %s\n' "${RUBBLE_BUILD_PLATFORM}" >&2; return 1 ;;
  esac
fi

# Extra commands are available to hooks that source this library.
rubble-command() {
  local name="$1"
  shift
  if [[ -n "${rubble_runner_commands[${name}]:-}" ]]; then
    local executable="${rubble_runner_commands[${name}]}"
    [[ -f "${executable}" && -x "${executable}" ]] || {
      printf '[remote] declared runner command %s is unavailable: %s\n' "${name}" "${executable}" >&2
      return 1
    }
    "${executable}" "$@"
  elif [[ "${name}" == gh ]]; then
    command gh "$@"
  else
    rubble-exec "${name}" "$@"
  fi
}


release_publisher_relative='publish-release.mjs'
export RUBBLE_RELEASE_PUBLISHER="${lifecycle_dir}/${release_publisher_relative}"
