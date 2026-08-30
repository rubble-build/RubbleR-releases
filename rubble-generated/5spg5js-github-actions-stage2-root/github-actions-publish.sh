#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && builtin pwd)"
target_root="$(builtin cd "${script_dir}/../.." && builtin pwd)"
payload_dir="${script_dir}"
user_publish_script="${target_root}/.rubble/publish.sh"
root_id='5spg5jsxjdotb5mswro3qxm2kbcmepajlsvrnytvz4oxys7pu57a-github-actions-stage2-root'
root_name='github-actions-stage2-root'
root_hash="${root_id%%-*}"
root_short="${root_hash:0:7}-${root_name}"
workflow_path=".github/workflows/rubble.yml"
generated_root="rubble-generated/${root_short}"

log() {
  printf '[github-actions-publish] %s\n' "$1" >&2
}

fail() {
  log "ERROR: $1"
  exit 1
}

shell_quote() {
  local value="$1"
  printf "'"
  printf '%s' "${value}" | sed "s/'/'\\\\''/g"
  printf "'"
}

print_assignment() {
  printf '%s=%s\n' "$1" "$(shell_quote "$2")"
}

local_plan() {
  local timestamp
  timestamp="$(date -u +'%Y%m%d%H%M%S')"
  print_assignment RUBBLE_PUBLISH_SUGGESTED_BRANCH "runs/${timestamp}-${root_hash:0:7}"
  print_assignment RUBBLE_PUBLISH_GENERATED_ROOT "${generated_root}"
  print_assignment RUBBLE_PUBLISH_WORKFLOW_PATH "${workflow_path}"
}

print_template() {
  cat <<'RUBBLE_PUBLISH_SH'
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

fail() {
  printf '[rubble-publish] ERROR: %s\n' "$1" >&2
  exit 1
}

source <("${RUBBLE_PUBLISH_SCRIPT}" local-plan)
repo_root="$(git -C "${RUBBLE_PUBLISH_TARGET_ROOT}" rev-parse --show-toplevel)"
target_prefix="$(git -C "${RUBBLE_PUBLISH_TARGET_ROOT}" rev-parse --show-prefix)"
base_branch="$(git -C "${repo_root}" branch --show-current)"
[[ -n "${base_branch}" ]] || fail "publishing requires a named base branch"
repo_workflow_path="${target_prefix}${RUBBLE_PUBLISH_WORKFLOW_PATH}"
repo_generated_root="${target_prefix}${RUBBLE_PUBLISH_GENERATED_ROOT}"

unrelated="$(git -C "${repo_root}" status --porcelain --untracked-files=all -- . \
  ":(exclude)${repo_workflow_path}" \
  ":(exclude)${repo_generated_root}" \
  ":(exclude)${repo_generated_root}/**")"
[[ -z "${unrelated}" ]] || fail "repository has unrelated changes; commit or remove them before publishing"

branch="${RUBBLE_PUBLISH_SUGGESTED_BRANCH}"
suffix=1
while git -C "${repo_root}" show-ref --verify --quiet "refs/heads/${branch}" || \
      git -C "${repo_root}" ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; do
  branch="${RUBBLE_PUBLISH_SUGGESTED_BRANCH}-${suffix}"
  suffix=$((suffix + 1))
done

git -C "${repo_root}" switch -c "${branch}" "${base_branch}"
restore_base() {
  git -C "${repo_root}" switch "${base_branch}" >/dev/null 2>&1 || true
}
trap restore_base EXIT
git -C "${repo_root}" add -- "${repo_workflow_path}" "${repo_generated_root}"
git -C "${repo_root}" commit -m "Run Rubble workflow for ${RUBBLE_PUBLISH_ROOT_ID}"
git -C "${repo_root}" push origin "HEAD:refs/heads/${branch}"
commit="$(git -C "${repo_root}" rev-parse HEAD)"
origin_url="$(git -C "${repo_root}" remote get-url origin)"
repository="${RUBBLE_PUBLISH_GITHUB_REPOSITORY:-$(gh repo view "${origin_url}" --json nameWithOwner --jq .nameWithOwner)}"

set +e
"${RUBBLE_PUBLISH_SCRIPT}" wait-run \
  --repo "${repository}" \
  --branch "${branch}" \
  --commit "${commit}"
status=$?
set -e
restore_base
trap - EXIT
exit "${status}"
RUBBLE_PUBLISH_SH
}

wait_run() {
  local repository=""
  local branch=""
  local commit=""
  local response=""
  local run_id=""
  local status=""
  local conclusion=""
  local html_url=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --repo)
        [[ "$#" -ge 2 ]] || fail "--repo requires a value"
        repository="$2"
        shift 2
        ;;
      --branch)
        [[ "$#" -ge 2 ]] || fail "--branch requires a value"
        branch="$2"
        shift 2
        ;;
      --commit)
        [[ "$#" -ge 2 ]] || fail "--commit requires a value"
        commit="$2"
        shift 2
        ;;
      *)
        fail "unknown wait-run argument: $1"
        ;;
    esac
  done
  [[ -n "${repository}" ]] || fail "wait-run requires --repo"
  [[ -n "${branch}" ]] || fail "wait-run requires --branch"
  [[ -n "${commit}" ]] || fail "wait-run requires --commit"

  log "waiting for workflow registration at commit ${commit}"
  while [[ -z "${run_id}" ]]; do
    if response="$(gh api --method GET "repos/${repository}/actions/runs" \
      -f head_sha="${commit}" -f event=push -f per_page=100)"; then
      run_id="$(jq -r \
        --arg branch "${branch}" \
        --arg commit "${commit}" \
        --arg path "${workflow_path}" \
        '.workflow_runs | map(select(.head_branch == $branch and .head_sha == $commit and .path == $path)) | sort_by(.run_number, .run_attempt) | last | .id // empty' \
        <<<"${response}")"
      if [[ -z "${run_id}" ]]; then
        log "workflow run is not registered yet; retrying"
      else
        log "found workflow run ${run_id}"
      fi
    else
      log "Actions run lookup failed; retrying"
    fi
    [[ -n "${run_id}" ]] || sleep 5
  done

  while true; do
    if ! response="$(gh api "repos/${repository}/actions/runs/${run_id}")"; then
      log "Actions run status lookup failed; retrying"
      sleep 10
      continue
    fi
    status="$(jq -r '.status // empty' <<<"${response}")"
    conclusion="$(jq -r '.conclusion // empty' <<<"${response}")"
    html_url="$(jq -r '.html_url // empty' <<<"${response}")"
    case "${status}" in
      completed)
        if [[ "${conclusion}" == success ]]; then
          log "workflow run ${run_id} succeeded: ${html_url}"
          return 0
        fi
        log "workflow run ${run_id} completed with conclusion '${conclusion}': ${html_url}"
        gh run view "${run_id}" --repo "${repository}" --log-failed || true
        return 1
        ;;
      queued|in_progress|requested|waiting|pending)
        log "workflow run ${run_id} status=${status}; waiting"
        ;;
      *)
        log "workflow run ${run_id} returned status='${status}'; waiting"
        ;;
    esac
    sleep 10
  done
}

publish() {
  if [[ ! -x "${user_publish_script}" ]]; then
    log "GitHub Actions payload generated at: ${payload_dir}"
    log "No executable user publisher found at: ${user_publish_script}"
    log "Review and install the following template, then rerun the Rubble build command."
    printf 'mkdir -p %s\n' "$(shell_quote "${target_root}/.rubble")"
    printf 'cat > %s <<'"'"'RUBBLE_PUBLISH_SH'"'"'\n' "$(shell_quote "${user_publish_script}")"
    print_template
    printf 'RUBBLE_PUBLISH_SH\n'
    printf 'chmod 755 %s\n' "$(shell_quote "${user_publish_script}")"
    return 0
  fi

  export RUBBLE_PUBLISH_SCRIPT="${payload_dir}/github-actions-publish.sh"
  export RUBBLE_PUBLISH_TARGET_ROOT="${target_root}"
  export RUBBLE_PUBLISH_PAYLOAD_DIR="${payload_dir}"
  export RUBBLE_PUBLISH_ROOT_ID="${root_id}"
  export RUBBLE_PUBLISH_ROOT_NAME="${root_name}"
  log "running user publisher: ${user_publish_script}"
  "${user_publish_script}"
}

command_name="${1:-publish}"
case "${command_name}" in
  publish)
    [[ "$#" -le 1 ]] || fail "publish does not accept arguments"
    publish
    ;;
  print-template)
    [[ "$#" -eq 1 ]] || fail "print-template does not accept arguments"
    print_template
    ;;
  local-plan)
    [[ "$#" -eq 1 ]] || fail "local-plan does not accept arguments"
    local_plan
    ;;
  wait-run)
    shift
    wait_run "$@"
    ;;
  *)
    fail "unknown command '${command_name}'; expected publish, print-template, local-plan, or wait-run"
    ;;
esac