# Source with explicit RUNTIME TARGET CONFIG_FILE CREDENTIALS_FILE.
_rubble_github_directory="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)" || return $?
_rubble_github_runtime='publish-runtime.sh'
source "$_rubble_github_directory/$_rubble_github_runtime" "$@" || return $?
unset _rubble_github_directory _rubble_github_runtime
rubble_publish_config[adapter]=github
rubble_publish_config[wait]=true
rubble_publish_config[workflow]='.github/workflows/rubble.yml'
rubble_publish_config[environment]='rubble-pipeline-39be7e68-f924-4316-b937-ae31c8296b74'
rubble_publish_config[local_files]=true
rubble_publish_config[github_repository]=''
rubble_publish_config[github_host]=github.com

_rubble_github_gh() {
  local -n __gh_config="$1"
  local __gh_name="$1"
  shift
  GH_HOST="${__gh_config[github_host]}" RUBBLE_PUBLISH_GITHUB_REPOSITORY="${__gh_config[github_repository]}" \
    _rubble_publish_runtime "$__gh_name" script --inherit-env "${__gh_config[remote_auth]}" gh "${__gh_config[repository]}" "$@"
}
_rubble_github_repository() {
  local -n __gh_repository_config="$1"
  if [[ -n "${__gh_repository_config[github_repository]}" ]]; then
    printf '%s\n' "${__gh_repository_config[github_repository]}"
  else
    local __gh_origin
    __gh_origin="$(rubble_git "$1" remote get-url origin)" || return $?
    _rubble_github_gh "$1" repo view "$__gh_origin" --json nameWithOwner --jq .nameWithOwner
  fi
}
_rubble_github_prepare() {
  local -n __gh_prepare_config="$1" __gh_resources="$2"
  [[ "${__gh_prepare_config[local_files]}" == true ]] || return 0
  [[ -n "${RUBBLE_PIPELINE_AUTH_KEY:-}" ]] || { _rubble_publish_error 'RUBBLE_PIPELINE_AUTH_KEY is required'; return 1; }
  local __gh_repository
  __gh_repository="$(_rubble_github_repository "$1")" || return $?
  _rubble_github_gh "$1" api --method PUT "repos/$__gh_repository/environments/${__gh_prepare_config[environment]}" \
    -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true' >/dev/null || return $?
  # Record ownership before either subsequent request can fail.
  __gh_resources[github_repository]="$__gh_repository"
  __gh_resources[github_environment]="${__gh_prepare_config[environment]}"
  _rubble_github_gh "$1" api --method POST "repos/$__gh_repository/environments/${__gh_prepare_config[environment]}/deployment-branch-policies" \
    -f "name=$3" -f type=branch >/dev/null || return $?
  printf '%s' "$RUBBLE_PIPELINE_AUTH_KEY" | _rubble_github_gh "$1" secret set RUBBLE_PIPELINE_AUTH_KEY \
    --repo "$__gh_repository" --env "${__gh_prepare_config[environment]}" || return $?
}
_rubble_github_trigger() { local -n __gh_run_output="$3"; __gh_run_output=''; }
_rubble_github_json_quote() {
  local __gh_value="$1"
  __gh_value="${__gh_value//\\/\\\\}"; __gh_value="${__gh_value//\"/\\\"}"
  __gh_value="${__gh_value//$'\n'/\\n}"; __gh_value="${__gh_value//$'\r'/\\r}"; __gh_value="${__gh_value//$'\t'/\\t}"
  printf '"%s"' "$__gh_value"
}
_rubble_github_find() {
  local -n __gh_find_config="$1"
  local __gh_repository __gh_url='' __gh_attempt
  __gh_repository="$(_rubble_github_repository "$1")" || return $?
  for ((__gh_attempt=1; __gh_attempt<=60; __gh_attempt++)); do
    if __gh_url="$(_rubble_github_gh "$1" api --method GET "repos/$__gh_repository/actions/runs" \
      -f "head_sha=$3" -f event=push -f per_page=100 \
      --jq ".workflow_runs | map(select(.head_branch == $(_rubble_github_json_quote "$2") and .head_sha == $(_rubble_github_json_quote "$3") and .path == $(_rubble_github_json_quote "${__gh_find_config[workflow]}"))) | sort_by(.run_number, .run_attempt) | last | .html_url // empty")" && [[ -n "$__gh_url" ]]; then
      printf '%s\n' "$__gh_url"
      return 0
    fi
    _rubble_publish_log 'workflow run is not registered yet; retrying'
    if [[ "$__gh_attempt" -lt 60 ]]; then _rubble_publish_tool "$1" sleep 5 || return $?; fi
  done
  _rubble_publish_error 'workflow run was not registered after 60 attempts'
}
_rubble_github_wait() {
  # The URL identifies its own repository and run; no previous find call is needed.
  local __gh_url="$2" __gh_repository __gh_run __gh_response __gh_status __gh_conclusion
  if [[ "$__gh_url" =~ ^https?://[^/]+/([^/]+/[^/]+)/actions/runs/([0-9]+)/?$ ]]; then
    __gh_repository="${BASH_REMATCH[1]}"; __gh_run="${BASH_REMATCH[2]}"
  else
    _rubble_publish_error "invalid GitHub Actions run URL: $__gh_url"; return 1
  fi
  while true; do
    if ! __gh_response="$(_rubble_github_gh "$1" api "repos/$__gh_repository/actions/runs/$__gh_run" --jq '[.status // "", .conclusion // "", .html_url // ""] | .[]')"; then
      _rubble_publish_log 'Actions run status lookup failed; retrying'
      _rubble_publish_tool "$1" sleep 10 || return $?
      continue
    fi
    local -a __gh_fields=()
    mapfile -t __gh_fields <<<"$__gh_response"
    __gh_status="${__gh_fields[0]:-}"; __gh_conclusion="${__gh_fields[1]:-}"
    if [[ "${__gh_fields[2]:-}" != "$__gh_url" ]]; then
      _rubble_publish_error 'GitHub Actions returned a different run URL for the selected service'
      return 1
    fi
    if [[ "$__gh_status" == completed ]]; then
      if [[ "$__gh_conclusion" == success ]]; then _rubble_publish_log "workflow run $__gh_run succeeded: $__gh_url"; return 0; fi
      _rubble_publish_log "workflow run $__gh_run completed with conclusion '$__gh_conclusion': $__gh_url"
      _rubble_github_gh "$1" run view "$__gh_run" --repo "$__gh_repository" --log-failed || true
      return 1
    fi
    _rubble_publish_log "workflow run $__gh_run status=$__gh_status; waiting"
    _rubble_publish_tool "$1" sleep 10 || return $?
  done
}
_rubble_github_cleanup() {
  local -n __gh_cleanup_resources="$2"
  [[ -n "${__gh_cleanup_resources[github_environment]:-}" ]] || return 0
  local __gh_response
  if __gh_response="$(_rubble_github_gh "$1" api --method DELETE "repos/${__gh_cleanup_resources[github_repository]}/environments/${__gh_cleanup_resources[github_environment]}" 2>&1)"; then
    _rubble_publish_log "deleted one-use Environment ${__gh_cleanup_resources[github_environment]}"
  elif [[ "$__gh_response" == *'HTTP 404'* ]]; then
    _rubble_publish_log "one-use Environment ${__gh_cleanup_resources[github_environment]} is already absent"
  else
    _rubble_publish_error "failed to delete one-use Environment ${__gh_cleanup_resources[github_environment]}"; return 1
  fi
  unset '__gh_cleanup_resources[github_environment]' '__gh_cleanup_resources[github_repository]'
}