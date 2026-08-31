#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && builtin pwd)"
managed_publish_script="${script_dir}/$(basename "${BASH_SOURCE[0]}")"
target_root_relative='../..'
payload_root_relative='.'
target_root="$(builtin cd "${script_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${script_dir}/${payload_root_relative}" && builtin pwd)"
user_publish_script="${target_root}/.rubble/publish.sh"
root_id='5spg5jsxjdotb5mswro3qxm2kbcmepajlsvrnytvz4oxys7pu57a-github-actions-stage2-root'
root_name='github-actions-stage2-root'
root_hash="${root_id%%-*}"
workflow_path='.github/workflows/rubble.yml'
generated_root='rubble-generated/5spg5js-github-actions-stage2-root'
managed_output_paths=(

  '.github/workflows/rubble.yml'

  'rubble-generated/5spg5js-github-actions-stage2-root/build-brick.sh'

  'rubble-generated/5spg5js-github-actions-stage2-root/github-actions-publish.sh'

  'rubble-generated/5spg5js-github-actions-stage2-root/release-root.sh'

  'rubble-generated/5spg5js-github-actions-stage2-root/store/5s/pg/brk-5spg5jsxjdotb5mswro3qxm2kbcmepajlsvrnytvz4oxys7pu57a-github-actions-stage2-root.brick'

  'rubble-generated/5spg5js-github-actions-stage2-root/store/j4/wv/brk-j4wv4qsmpu3hsuqo76rzfbhq3jqecxctxozpsg2rtmvmg3b7wz5a-github-actions-stage2-merge-right.brick'

  'rubble-generated/5spg5js-github-actions-stage2-root/store/vv/id/brk-vvidum5gqlzozgzt3m23oadbyvfnvq6klg64zjvxhzh5bsw5fdcq-github-actions-stage2-merge-left.brick'

)

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
  print_assignment RUBBLE_PUBLISH_OUTPUT_COUNT "${#managed_output_paths[@]}"
  local index
  for index in "${!managed_output_paths[@]}"; do
    print_assignment "RUBBLE_PUBLISH_OUTPUT_${index}" "${managed_output_paths[$index]}"
  done
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
repo_user_publish_script="${target_prefix}.rubble/publish.sh"
managed_output_paths=()
for ((index = 0; index < RUBBLE_PUBLISH_OUTPUT_COUNT; index++)); do
  managed_output_variable="RUBBLE_PUBLISH_OUTPUT_${index}"
  managed_output_paths+=("${target_prefix}${!managed_output_variable}")
done
[[ "${#managed_output_paths[@]}" -gt 0 ]] || fail "publisher plan contains no managed outputs"

status_pathspecs=(.)
for managed_output_path in "${managed_output_paths[@]}"; do
  status_pathspecs+=(":(exclude,literal)${managed_output_path}")
done
status_pathspecs+=(":(exclude,literal)${repo_user_publish_script}")
unrelated="$(git -C "${repo_root}" status --porcelain --untracked-files=all -- "${status_pathspecs[@]}")"
[[ -z "${unrelated}" ]] || fail "repository has unrelated changes; commit or remove them before publishing"

branch="${RUBBLE_PUBLISH_SUGGESTED_BRANCH}"
suffix=1
while git -C "${repo_root}" show-ref --verify --quiet "refs/heads/${branch}" || \
      git -C "${repo_root}" ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; do
  branch="${RUBBLE_PUBLISH_SUGGESTED_BRANCH}-${suffix}"
  suffix=$((suffix + 1))
done

git -C "${repo_root}" switch -c "${branch}" "${base_branch}"
restore_base_on_exit() {
  local publisher_status=$?
  local restore_status=0
  trap - EXIT
  set +e
  git -C "${repo_root}" switch "${base_branch}" >/dev/null
  restore_status=$?
  set -e
  if (( restore_status != 0 )); then
    printf '[rubble-publish] ERROR: failed to restore base branch %s (publisher status %s; restore status %s)\n' \
      "${base_branch}" "${publisher_status}" "${restore_status}" >&2
    exit 1
  fi
  exit "${publisher_status}"
}
trap restore_base_on_exit EXIT
managed_output_pathspecs=()
for managed_output_path in "${managed_output_paths[@]}"; do
  managed_output_pathspecs+=(":(literal)${managed_output_path}")
done
git -C "${repo_root}" add -- "${managed_output_pathspecs[@]}"
git -C "${repo_root}" commit --only -m "Run Rubble workflow for ${RUBBLE_PUBLISH_ROOT_ID}" -- "${managed_output_pathspecs[@]}"
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
  if [[ ! -e "${user_publish_script}" && ! -L "${user_publish_script}" ]]; then
    log "GitHub Actions payload generated at: ${payload_dir}"
    log "No user publisher found at: ${user_publish_script}"
    log "Review and install the following template."
    log "Rerun the Rubble build only for an unmodified plan."
    log "After editing generated outputs, invoke this generated publisher again without regeneration."
    printf 'mkdir -p %s\n' "$(shell_quote "${target_root}/.rubble")"
    printf 'cat > %s <<'"'"'RUBBLE_PUBLISH_SH'"'"'\n' "$(shell_quote "${user_publish_script}")"
    print_template
    printf 'RUBBLE_PUBLISH_SH\n'
    printf 'chmod 755 %s\n' "$(shell_quote "${user_publish_script}")"
    return 0
  fi

  if [[ ! -f "${user_publish_script}" || ! -x "${user_publish_script}" ]]; then
    fail "user publisher exists but is not executable: ${user_publish_script}"
  fi

  export RUBBLE_PUBLISH_SCRIPT="${managed_publish_script}"
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