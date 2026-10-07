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
export RUBBLE_PLAN_ID='multi-j4a7h7frirtcbxoqkaiyl7rnx74jgrp2bwpfhjekxbfaj4nhbr3a'
export RUBBLE_PLAN_TITLE='2 bricks: x86_64-linux-wbkp2hw-rubble, aarch64-linux-ioiby6c-rubble'
export RUBBLE_PLAN_NOTES='Rubble inventory bundles for:
x86_64-linux-wbkp2hwj345gzywkplnslzbr2gsaggdaswhmjbf6ekbrccadyzpa-rubble
aarch64-linux-ioiby6cxbbr3jf3d2nvsoxh7zbcialrnjugxysfyk23eneoeeina-rubble'
declare -a rubble_roots=(

  'wbkp2hwj345gzywkplnslzbr2gsaggdaswhmjbf6ekbrccadyzpa-rubble'

  'ioiby6cxbbr3jf3d2nvsoxh7zbcialrnjugxysfyk23eneoeeina-rubble'

)
declare -A rubble_root_short_ids=() rubble_root_names=() rubble_root_platforms=() rubble_root_bricks=()

rubble_root_short_ids['wbkp2hwj345gzywkplnslzbr2gsaggdaswhmjbf6ekbrccadyzpa-rubble']='wbkp2hw-rubble'
rubble_root_names['wbkp2hwj345gzywkplnslzbr2gsaggdaswhmjbf6ekbrccadyzpa-rubble']='rubble'

rubble_root_platforms['wbkp2hwj345gzywkplnslzbr2gsaggdaswhmjbf6ekbrccadyzpa-rubble']='x86_64-linux'

root_relative='store/wb/kp/brk-wbkp2hwj345gzywkplnslzbr2gsaggdaswhmjbf6ekbrccadyzpa-rubble.brick'
rubble_root_bricks['wbkp2hwj345gzywkplnslzbr2gsaggdaswhmjbf6ekbrccadyzpa-rubble']="${lifecycle_dir}/${root_relative}"

rubble_root_short_ids['ioiby6cxbbr3jf3d2nvsoxh7zbcialrnjugxysfyk23eneoeeina-rubble']='ioiby6c-rubble'
rubble_root_names['ioiby6cxbbr3jf3d2nvsoxh7zbcialrnjugxysfyk23eneoeeina-rubble']='rubble'

rubble_root_platforms['ioiby6cxbbr3jf3d2nvsoxh7zbcialrnjugxysfyk23eneoeeina-rubble']='aarch64-linux'

root_relative='store/io/ib/brk-ioiby6cxbbr3jf3d2nvsoxh7zbcialrnjugxysfyk23eneoeeina-rubble.brick'
rubble_root_bricks['ioiby6cxbbr3jf3d2nvsoxh7zbcialrnjugxysfyk23eneoeeina-rubble']="${lifecycle_dir}/${root_relative}"

default_platform='x86_64-linux'
export RUBBLE_BUILD_PLATFORM="${RUBBLE_BUILD_PLATFORM:-${default_platform}}"
export RUBBLE_REMOTE_STORE='default'
inventory_relative='release-inventory.txt'
export RUBBLE_RELEASE_INVENTORY="${lifecycle_dir}/${inventory_relative}"
publisher_relative='github-actions-publish.sh'
export RUBBLE_PUBLISH_SCRIPT="${lifecycle_dir}/${publisher_relative}"

declare -A rubble_hooks=()

hook_relative='../../.rubble/hooks/pre-publish.sh'
rubble_hooks['pre-publish']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/post-publish.sh'
rubble_hooks['post-publish']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/pre-job.sh'
rubble_hooks['pre-job']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/post-job.sh'
rubble_hooks['post-job']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/prepare-release.sh'
rubble_hooks['prepare-release']="${lifecycle_dir}/${hook_relative}"

hook_relative='../../.rubble/hooks/post-release.sh'
rubble_hooks['post-release']="${lifecycle_dir}/${hook_relative}"

export RUBBLE_HOOKS_DIR="$(rubble-exec dirname -- "${rubble_hooks[pre-publish]}")"

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
