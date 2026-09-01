#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && builtin pwd)"
managed_publish_script="${script_dir}/$(basename "${BASH_SOURCE[0]}")"
target_root_relative='../..'
payload_root_relative='.'
root_brick_relative='store/m3/ut/brk-m3utccwwng2uuxoa57fn3jywii377pbodzuqgwjil3zg4ktdu4mq-rubble.brick'
target_root="$(builtin cd "${script_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${script_dir}/${payload_root_relative}" && builtin pwd)"
root_brick="${script_dir}/${root_brick_relative}"
user_publish_script="${target_root}/.rubble/publish.sh"
root_id='m3utccwwng2uuxoa57fn3jywii377pbodzuqgwjil3zg4ktdu4mq-rubble'
root_name='rubble'
pipeline_id='ba6d16cc-eac2-49e7-93ee-9e1be8fab1c6'
pipeline_branch="runs/${pipeline_id}"

pipeline_environment='rubble-pipeline-ba6d16cc-eac2-49e7-93ee-9e1be8fab1c6'
environment_created=0
cleanup_repository=''

workflow_path='.github/workflows/rubble.yml'
generated_root='rubble-generated/m3utccw-rubble'
managed_output_paths=(

  '.github/workflows/rubble.yml'

  'rubble-generated/m3utccw-rubble/build-brick.sh'

  'rubble-generated/m3utccw-rubble/cleanup-auth.sh'

  'rubble-generated/m3utccw-rubble/github-actions-publish.sh'

  'rubble-generated/m3utccw-rubble/open-pipeline-auth.mjs'

  'rubble-generated/m3utccw-rubble/pipeline-auth.enc'

  'rubble-generated/m3utccw-rubble/release-bundle.sh'

  'rubble-generated/m3utccw-rubble/release-inventory.txt'

  'rubble-generated/m3utccw-rubble/release-root.sh'

  'rubble-generated/m3utccw-rubble/store/23/gf/brk-23gf67qrqop2iwql7sletwhjdnam7i6qsrz5hkcxee66bzx6ic7q-rubble-web-assets.brick'

  'rubble-generated/m3utccw-rubble/store/3l/xq/brk-3lxqkxt6w34paj3dptqfdrkud46niam2aemexrvwxohnm7obk4aa-xz.brick'

  'rubble-generated/m3utccw-rubble/store/4w/h5/brk-4wh5f46xxtkaguz3zlhoh3wnmk3j2ejzcqznqnjqijtjin6yaj3q-rubble-deps-cache.brick'

  'rubble-generated/m3utccw-rubble/store/4y/y6/brk-4yy6z5u5me3jgs3rks5hvopsmukz66lezoxurb24d4lqr6xplycq-rust-toolchain.brick'

  'rubble-generated/m3utccw-rubble/store/4z/45/brk-4z45nx65xw3y3yxdn5rw2qf5jwclaclnqqfhofeig6xotqxb7ajq-patchelf.brick'

  'rubble-generated/m3utccw-rubble/store/66/ew/brk-66ew66thgmvxvtv3y73nzs6nvo7jobr4pbla3cwgbmayfts7bncq-grep.brick'

  'rubble-generated/m3utccw-rubble/store/72/mk/brk-72mkfvxl5mmbm7vwb7lqf2zdm4fspzwzv2cmpnsrum2l4c77u5cq-coreutils.brick'

  'rubble-generated/m3utccw-rubble/store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'rubble-generated/m3utccw-rubble/store/bb/3w/brk-bb3woz66hfzaf7nxyfp5ihp6vxai7te2ymga2i65rr4rqmaipiyq-unzip.brick'

  'rubble-generated/m3utccw-rubble/store/bn/h6/brk-bnh6a6xptku7pe37i7fyefxb3jn2eepsszqlp2xhok35cgvfhxuq-gnu-make.brick'

  'rubble-generated/m3utccw-rubble/store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'rubble-generated/m3utccw-rubble/store/gm/ie/brk-gmiepopf36g4nt4bgf2k6ydxwomd3eahnlg5kzfd7itw6you5ynq-gnu-sed.brick'

  'rubble-generated/m3utccw-rubble/store/ic/3m/brk-ic3mcp6r2byudz4wwzrzs7ld3te3lmfdcopyerhhnjybz6b4gz5q-gcc.brick'

  'rubble-generated/m3utccw-rubble/store/jf/ai/brk-jfai7zz72pherkoxskwv2r6de64ms2lv7eetewbbhcemhfmvu7sq-gnu-tar.brick'

  'rubble-generated/m3utccw-rubble/store/l5/ca/brk-l5cahjri52ofysycyibbzhr65aq4t6tyjkqtpvxk3d6oxuxjm4fa-git.brick'

  'rubble-generated/m3utccw-rubble/store/li/fl/brk-lifled7ii45rfxevjn4zzhsjiduayqc3qoinypo3xoznu4pereja-bootstrap-env.brick'

  'rubble-generated/m3utccw-rubble/store/m3/ut/brk-m3utccwwng2uuxoa57fn3jywii377pbodzuqgwjil3zg4ktdu4mq-rubble.brick'

  'rubble-generated/m3utccw-rubble/store/n2/y6/brk-n2y6cwlexb642nzfj7px6pn7pantf4zaw6mtlfscqidlarztalxq-diffutils.brick'

  'rubble-generated/m3utccw-rubble/store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'rubble-generated/m3utccw-rubble/store/o3/dz/brk-o3dzojll7ltuto5ppxh4zvmemdcg5n5ngpz6h5tewrn2g62e2sua-RubbleR.git.brick'

  'rubble-generated/m3utccw-rubble/store/oo/lq/brk-oolqu2vtbb4frcjavzuszx435gk62yg4qby6szr2w6rv4zzuj3zq-perl.brick'

  'rubble-generated/m3utccw-rubble/store/pf/ct/brk-pfctzr6y2rty63c32st2rmmgrexbnfrdgt2iic4na3bctqmrwoea-bzip2.brick'

  'rubble-generated/m3utccw-rubble/store/po/br/brk-pobrsy2ju6afixohsh7wvks3aeccssrma4wwzy7ovmfg5qcucf7a-gzip.brick'

  'rubble-generated/m3utccw-rubble/store/rt/t7/brk-rtt7zlxbdwlqvf6xcv3ibd2j72sav5aq7a4osmz6in3hijdh67va-gpatch.brick'

  'rubble-generated/m3utccw-rubble/store/st/lj/brk-stljkkdnfyucz33nxoovmbhimt6ff63ihoue4xv5uddik7it2v2q-m4.brick'

  'rubble-generated/m3utccw-rubble/store/vh/c3/brk-vhc36fbohtrfn67wztkuvrxcpwpgfcaylqtl3g3xrwinmlyxayxq-rubble-elf-runtime.brick'

  'rubble-generated/m3utccw-rubble/store/wk/al/brk-wkalziix43j55svwzjj2vbsjfaxxnqhhshnnfcz2v3dnih4fcqha-bison.brick'

  'rubble-generated/m3utccw-rubble/store/wq/ck/brk-wqckb6fysqnzuzmnm3hrgnie52iiuwqibunb222ynntml7x5lxjq-zstd.brick'

  'rubble-generated/m3utccw-rubble/store/ws/zc/brk-wszckkjwj7owe2w6seb3pficxwimbmjwkoqsa6m46ki64ujgqz2q-findutils.brick'

  'rubble-generated/m3utccw-rubble/store/x5/qv/brk-x5qvjdfenrs6bc4xuttjluurx6ow3aj326m5ay6ni2ezq2u757va-gawk.brick'

  'rubble-generated/m3utccw-rubble/store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

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
  print_assignment RUBBLE_PUBLISH_SUGGESTED_BRANCH "${pipeline_branch}"
  print_assignment RUBBLE_PUBLISH_PIPELINE_ID "${pipeline_id}"

  print_assignment RUBBLE_PUBLISH_ENVIRONMENT "${pipeline_environment}"

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
if git -C "${repo_root}" show-ref --verify --quiet "refs/heads/${branch}" || \
   git -C "${repo_root}" ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; then
  fail "one-use pipeline branch already exists: ${branch}"
fi

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

resolve_repository() {
  local origin_url
  origin_url="$(git -C "${target_root}" remote get-url origin)"
  if [[ -n "${RUBBLE_PUBLISH_GITHUB_REPOSITORY:-}" ]]; then
    printf '%s\n' "${RUBBLE_PUBLISH_GITHUB_REPOSITORY}"
  else
    gh repo view "${origin_url}" --json nameWithOwner --jq .nameWithOwner
  fi
}


delete_environment() {
  local repository="$1"
  local response=""
  if response="$(gh api --method DELETE "repos/${repository}/environments/${pipeline_environment}" 2>&1)"; then
    log "deleted one-use Environment ${pipeline_environment}"
    return 0
  fi
  if [[ "${response}" == *"HTTP 404"* ]]; then
    log "one-use Environment ${pipeline_environment} is already absent"
    return 0
  fi
  log "ERROR: failed to delete one-use Environment ${pipeline_environment}"
  return 1
}

create_environment() {
  local repository="$1"
  local key="${RUBBLE_PIPELINE_AUTH_KEY:-}"
  [[ -n "${key}" ]] || fail "RUBBLE_PIPELINE_AUTH_KEY is required"
  log "creating one-use Environment ${pipeline_environment}"
  gh api --method PUT "repos/${repository}/environments/${pipeline_environment}" \
    -F 'deployment_branch_policy[protected_branches]=false' \
    -F 'deployment_branch_policy[custom_branch_policies]=true' >/dev/null
  environment_created=1
  gh api --method POST \
    "repos/${repository}/environments/${pipeline_environment}/deployment-branch-policies" \
    -f name="${pipeline_branch}" \
    -f type=branch >/dev/null
  printf '%s' "${key}" | \
    gh secret set RUBBLE_PIPELINE_AUTH_KEY --repo "${repository}" --env "${pipeline_environment}"
  unset key RUBBLE_PIPELINE_AUTH_KEY
  log "bound one-use Environment to ${pipeline_branch}"
}


consume_pipeline_identity() {
  local state_file
  state_file="$(pipeline_state_file used)"
  if ! (set -o noclobber; printf '%s\n' "${pipeline_id}" >"${state_file}") 2>/dev/null; then
    fail "pipeline identity has already been consumed; run Rubble again to create a new pipeline"
  fi
  chmod 600 "${state_file}"
  log "consumed one-use pipeline identity ${pipeline_id}"
}

seed_default_remote_store() {
  local rubble_executable="${RUBBLE_EXECUTABLE:-rubble}"
  local status
  log "seeding the default remote store from ${root_id}"
  if "${rubble_executable}" push --depth 0 --expand-opaque -r default "${root_brick}"; then
    log "seeded the default remote store from ${root_id}"
    return 0
  else
    status=$?
  fi
  log "WARNING: local remote-store seed failed with status ${status}; continuing because remote workflow jobs pull, build, and push independently"
}

pipeline_state_file() {
  local suffix="$1"
  local git_common_dir
  local state_dir
  git_common_dir="$(git -C "${target_root}" rev-parse --path-format=absolute --git-common-dir)"
  state_dir="${git_common_dir}/rubble-pipelines"
  mkdir -p "${state_dir}" || return 1
  chmod 700 "${state_dir}" || return 1
  printf '%s/%s.%s\n' "${state_dir}" "${pipeline_id}" "${suffix}"
}


prepare_local_key() {
  local key="${RUBBLE_PIPELINE_AUTH_KEY:-}"
  local key_file
  [[ -n "${key}" ]] || fail "RUBBLE_PIPELINE_AUTH_KEY is required to prepare this generated pipeline"
  key_file="$(pipeline_state_file key)"
  if ! (set -o noclobber; umask 077; printf '%s' "${key}" >"${key_file}") 2>/dev/null; then
    fail "pipeline key is already prepared; use the existing generated pipeline or run Rubble again"
  fi
  chmod 600 "${key_file}"
  unset key RUBBLE_PIPELINE_AUTH_KEY
  log "prepared local one-use key for later publication"
}

load_local_key() {
  local key_file
  key_file="$(pipeline_state_file key)"
  if [[ -z "${RUBBLE_PIPELINE_AUTH_KEY:-}" ]]; then
    [[ -f "${key_file}" && ! -L "${key_file}" ]] || \
      fail "pipeline key is unavailable; run Rubble again to create a new pipeline"
    RUBBLE_PIPELINE_AUTH_KEY="$(<"${key_file}")"
    export RUBBLE_PIPELINE_AUTH_KEY
  fi
  [[ -n "${RUBBLE_PIPELINE_AUTH_KEY}" ]] || fail "pipeline key is empty"
  rm -f -- "${key_file}"
  log "loaded and removed the local one-use key"
}

cleanup_environment_on_exit() {
  local publisher_status=$?
  local cleanup_status=0
  trap - EXIT
  set +e
  if ((environment_created == 1)); then
    delete_environment "${cleanup_repository}"
    cleanup_status=$?
  fi
  set -e
  if ((publisher_status != 0)); then
    exit "${publisher_status}"
  fi
  exit "${cleanup_status}"
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
  local registration_attempt=1
  local registration_max_attempts=60

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
    if [[ -z "${run_id}" ]]; then
      if ((registration_attempt >= registration_max_attempts)); then
        fail "workflow run was not registered after ${registration_max_attempts} attempts"
      fi
      registration_attempt=$((registration_attempt + 1))
      sleep 5
    fi
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

    prepare_local_key

    log "GitHub Actions payload generated at: ${payload_dir}"
    log "No user publisher found at: ${user_publish_script}"
    log "Review and install the following template."
    log "After installation or generated-output edits, invoke this generated publisher again without regeneration."
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
  export RUBBLE_PUBLISH_PIPELINE_ID="${pipeline_id}"

  export RUBBLE_PUBLISH_ENVIRONMENT="${pipeline_environment}"
  local repository
  repository="$(resolve_repository)" || fail "could not resolve target GitHub repository"
  cleanup_repository="${repository}"
  trap cleanup_environment_on_exit EXIT
  load_local_key

  consume_pipeline_identity
  seed_default_remote_store

  create_environment "${repository}"

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