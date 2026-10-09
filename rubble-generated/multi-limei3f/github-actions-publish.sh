#!/usr/bin/env bash
set -euo pipefail
rubble="${RUBBLE_EXECUTABLE:?RUBBLE_EXECUTABLE is required}"
tool_information="$("$rubble" -q info --format bash --tools)"
eval "$tool_information"
script_dir="$(builtin cd -- "$(rubble-exec dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
target_relative='../..'
export RUBBLE_PUBLISH_TARGET_ROOT="$(builtin cd -- "$script_dir/$target_relative" && builtin pwd)"
library_relative='publish-library.sh'
export RUBBLE_PUBLISH_LIBRARY="$script_dir/$library_relative"
user_relative='../../.rubble/publish.sh'
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX GIT_IMPLICIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_SHALLOW_FILE GIT_GRAFT_FILE GIT_NAMESPACE
case "${1:-publish}" in
  publish)
    [[ $# -le 1 ]] || { printf 'publish does not accept arguments\n' >&2; exit 1; }
    [[ -s "$script_dir/$user_relative" ]] || exit 0
    builtin cd -- "$RUBBLE_PUBLISH_TARGET_ROOT"
    exec "$rubble" script --inherit-env "$script_dir/$user_relative"
    ;;
  local-plan|wait-run)
    action="$1"; shift
    source "$RUBBLE_PUBLISH_LIBRARY" "$rubble" "$RUBBLE_PUBLISH_TARGET_ROOT" "${RUBBLE_CONFIG:-}" "${RUBBLE_CREDENTIALS:-}"
    rubble_publish_config[github_repository]="${RUBBLE_PUBLISH_GITHUB_REPOSITORY:-}"
    rubble_publish_config[github_host]="${GH_HOST:-github.com}"
    if [[ "$action" == local-plan ]]; then
      [[ $# -eq 0 ]] || exit 1
      printf 'RUBBLE_PUBLISH_SUGGESTED_BRANCH=%q\nRUBBLE_PUBLISH_PIPELINE_ID=%q\nRUBBLE_PUBLISH_GENERATED_ROOT=%q\nRUBBLE_PUBLISH_WORKFLOW_PATH=%q\n' \
        "${rubble_publish_config[suggested_branch]}" "${rubble_publish_config[pipeline_id]}" "${rubble_publish_config[generated_root]}" "${rubble_publish_config[workflow]}"
      exit 0
    fi
    repository='' branch='' commit=''
    while [[ $# -gt 0 ]]; do
      [[ $# -ge 2 ]] || { _rubble_publish_error "$1 requires a value"; exit 1; }
      case "$1" in --repo) repository="$2" ;; --branch) branch="$2" ;; --commit) commit="$2" ;; *) _rubble_publish_error "unknown wait-run argument: $1"; exit 1 ;; esac
      shift 2
    done
    [[ -n "$repository" && -n "$branch" && -n "$commit" ]] || { _rubble_publish_error 'wait-run requires --repo, --branch and --commit'; exit 1; }
    rubble_publish_config[github_repository]="$repository"
    run_url="$(rubble_publish_find_run rubble_publish_config "$branch" "$commit" '')"
    rubble_publish_wait rubble_publish_config "$run_url"
    ;;
  *) printf "unknown command '%s'; expected publish, local-plan, or wait-run\n" "$1" >&2; exit 1 ;;
esac