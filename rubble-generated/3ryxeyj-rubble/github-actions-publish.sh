#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

export rubble="${RUBBLE_EXECUTABLE:?RUBBLE_EXECUTABLE is required}"
tool_information="$("${rubble}" -q info --format bash --tools)"
eval "${tool_information}"
unset tool_information
script_dir="$(builtin cd -- "$(rubble-exec dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
lifecycle_relative='lifecycle.sh'
source "${script_dir}/${lifecycle_relative}"
managed_publish_script="${script_dir}/$(rubble-exec basename -- "${BASH_SOURCE[0]}")"
target_root_relative='../..'
payload_root_relative='.'
root_brick_relative='store/3r/yx/brk-3ryxeyjrp5vyhlz2viypca3phvttebmeygw5p3flfib7t3pwykwq-rubble.brick'
target_root="$(builtin cd "${script_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${script_dir}/${payload_root_relative}" && builtin pwd)"
root_brick="${script_dir}/${root_brick_relative}"
user_publish_relative='../../.rubble/publish.sh'
user_publish_script="${script_dir}/${user_publish_relative}"
root_id='3ryxeyjrp5vyhlz2viypca3phvttebmeygw5p3flfib7t3pwykwq-rubble'
root_name='rubble'
pipeline_id='a256ffa9-5ecb-48b8-a82b-c2f31b163804'
pipeline_branch="runs/${pipeline_id}"

pipeline_environment='rubble-pipeline-a256ffa9-5ecb-48b8-a82b-c2f31b163804'
environment_created=0
cleanup_repository=''

workflow_path='.github/workflows/rubble.yml'
generated_root='rubble-generated/3ryxeyj-rubble'
managed_output_paths=(

  '.github/workflows/rubble.yml'

  '.rubble/hooks/github-actions'

  '.rubble/hooks/github-actions/post-job.sh'

  '.rubble/hooks/github-actions/post-publish.sh'

  '.rubble/hooks/github-actions/post-release.sh'

  '.rubble/hooks/github-actions/pre-job.sh'

  '.rubble/hooks/github-actions/pre-publish.sh'

  '.rubble/hooks/github-actions/prepare-release.sh'

  '.rubble/publish.sh'

  'rubble-generated'

  'rubble-generated/3ryxeyj-rubble/build-brick.sh'

  'rubble-generated/3ryxeyj-rubble/cleanup-auth.sh'

  'rubble-generated/3ryxeyj-rubble/github-actions-publish.sh'

  'rubble-generated/3ryxeyj-rubble/lifecycle.sh'

  'rubble-generated/3ryxeyj-rubble/open-pipeline-auth.mjs'

  'rubble-generated/3ryxeyj-rubble/pipeline-auth.enc'

  'rubble-generated/3ryxeyj-rubble/publish-release.mjs'

  'rubble-generated/3ryxeyj-rubble/release-inventory.txt'

  'rubble-generated/3ryxeyj-rubble/release-root.sh'

  'rubble-generated/3ryxeyj-rubble/store/26/yg/brk-26yga6swuuyvk46kotxm3wfjzaeipavrk3dh4gkrk7sdexczd5eq-RubbleR.git.brick'

  'rubble-generated/3ryxeyj-rubble/store/3r/yx/brk-3ryxeyjrp5vyhlz2viypca3phvttebmeygw5p3flfib7t3pwykwq-rubble.brick'

  'rubble-generated/3ryxeyj-rubble/store/4z/45/brk-4z45nx65xw3y3yxdn5rw2qf5jwclaclnqqfhofeig6xotqxb7ajq-patchelf.brick'

  'rubble-generated/3ryxeyj-rubble/store/72/mk/brk-72mkfvxl5mmbm7vwb7lqf2zdm4fspzwzv2cmpnsrum2l4c77u5cq-coreutils.brick'

  'rubble-generated/3ryxeyj-rubble/store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'rubble-generated/3ryxeyj-rubble/store/bb/3w/brk-bb3woz66hfzaf7nxyfp5ihp6vxai7te2ymga2i65rr4rqmaipiyq-unzip.brick'

  'rubble-generated/3ryxeyj-rubble/store/bc/kp/brk-bckpkewd24sqpe6rkydj4yn3u2zzm2fpcukdzgimleqxusuefnyq-xz.brick'

  'rubble-generated/3ryxeyj-rubble/store/bn/h6/brk-bnh6a6xptku7pe37i7fyefxb3jn2eepsszqlp2xhok35cgvfhxuq-gnu-make.brick'

  'rubble-generated/3ryxeyj-rubble/store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'rubble-generated/3ryxeyj-rubble/store/dm/sg/brk-dmsgfhvob3pdpiukrljf5s3ktrdwdzr3jaerijvrtfudntru2ksa-rust-toolchain.brick'

  'rubble-generated/3ryxeyj-rubble/store/en/i6/brk-eni6622eybzafiaivzmic5h3itxj6zsfrz2e7ifzoe2zlab25wua-grep.brick'

  'rubble-generated/3ryxeyj-rubble/store/fm/yg/brk-fmygahk5j3smbzx2qm2ywzls5bqlfiq4cyopw4wb7biwzc2ygl2a-rubble-deps-cache.brick'

  'rubble-generated/3ryxeyj-rubble/store/gm/ie/brk-gmiepopf36g4nt4bgf2k6ydxwomd3eahnlg5kzfd7itw6you5ynq-gnu-sed.brick'

  'rubble-generated/3ryxeyj-rubble/store/hc/rj/brk-hcrjatds5quywu3pc6mxufpbzalclono7bxrc3aplfgzy7jkzgpq-rubble-web-assets.brick'

  'rubble-generated/3ryxeyj-rubble/store/ic/3m/brk-ic3mcp6r2byudz4wwzrzs7ld3te3lmfdcopyerhhnjybz6b4gz5q-gcc.brick'

  'rubble-generated/3ryxeyj-rubble/store/jf/ai/brk-jfai7zz72pherkoxskwv2r6de64ms2lv7eetewbbhcemhfmvu7sq-gnu-tar.brick'

  'rubble-generated/3ryxeyj-rubble/store/l5/ca/brk-l5cahjri52ofysycyibbzhr65aq4t6tyjkqtpvxk3d6oxuxjm4fa-git.brick'

  'rubble-generated/3ryxeyj-rubble/store/mo/dx/brk-modxqyxhoi2teskd4wu75p6pkquxmwjxnuq2zsjl3lm66o2dbhtq-rubble-elf-runtime.brick'

  'rubble-generated/3ryxeyj-rubble/store/n2/y6/brk-n2y6cwlexb642nzfj7px6pn7pantf4zaw6mtlfscqidlarztalxq-diffutils.brick'

  'rubble-generated/3ryxeyj-rubble/store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'rubble-generated/3ryxeyj-rubble/store/od/zc/brk-odzciqpr5fl5qqpdqnohs7qpqqwvahqodbydsv7er2ztrfnfhbuq-bootstrap-env.brick'

  'rubble-generated/3ryxeyj-rubble/store/oo/lq/brk-oolqu2vtbb4frcjavzuszx435gk62yg4qby6szr2w6rv4zzuj3zq-perl.brick'

  'rubble-generated/3ryxeyj-rubble/store/op/z3/brk-opz3r6tpol44zcnet7hgpade5bwepv4e5ahgkc2qgc3pa66ajgwq-bun-1.4.2.brick'

  'rubble-generated/3ryxeyj-rubble/store/pf/ct/brk-pfctzr6y2rty63c32st2rmmgrexbnfrdgt2iic4na3bctqmrwoea-bzip2.brick'

  'rubble-generated/3ryxeyj-rubble/store/po/br/brk-pobrsy2ju6afixohsh7wvks3aeccssrma4wwzy7ovmfg5qcucf7a-gzip.brick'

  'rubble-generated/3ryxeyj-rubble/store/rt/t7/brk-rtt7zlxbdwlqvf6xcv3ibd2j72sav5aq7a4osmz6in3hijdh67va-gpatch.brick'

  'rubble-generated/3ryxeyj-rubble/store/st/lj/brk-stljkkdnfyucz33nxoovmbhimt6ff63ihoue4xv5uddik7it2v2q-m4.brick'

  'rubble-generated/3ryxeyj-rubble/store/wk/al/brk-wkalziix43j55svwzjj2vbsjfaxxnqhhshnnfcz2v3dnih4fcqha-bison.brick'

  'rubble-generated/3ryxeyj-rubble/store/wq/ck/brk-wqckb6fysqnzuzmnm3hrgnie52iiuwqibunb222ynntml7x5lxjq-zstd.brick'

  'rubble-generated/3ryxeyj-rubble/store/wq/wq/brk-wqwqpsrxthcdyvudufgqzehhkyx6ogdt3lzcy4ush4huh5geqjoa-rubble.src-patch.brick'

  'rubble-generated/3ryxeyj-rubble/store/ws/zc/brk-wszckkjwj7owe2w6seb3pficxwimbmjwkoqsa6m46ki64ujgqz2q-findutils.brick'

  'rubble-generated/3ryxeyj-rubble/store/x5/qv/brk-x5qvjdfenrs6bc4xuttjluurx6ow3aj326m5ay6ni2ezq2u757va-gawk.brick'

  'rubble-generated/3ryxeyj-rubble/store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

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
  printf '%s' "${value}" | rubble-exec sed "s/'/'\\\\''/g"
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

publish_git() (
  local repo_root target_prefix base_branch unrelated branch index_directory tree commit
  repo_root="$(rubble-exec git -C "${target_root}" rev-parse --show-toplevel)"
  target_prefix="$(rubble-exec git -C "${target_root}" rev-parse --show-prefix)"
  base_branch="$(rubble-exec git -C "${repo_root}" branch --show-current)"
  [[ -n "${base_branch}" ]] || fail "publishing requires a named base branch"
  local -a paths=() status_pathspecs=(.) pathspecs=()
  local path tracked
  for path in "${managed_output_paths[@]}"; do
    paths+=("${target_prefix}${path}")
    status_pathspecs+=(":(exclude,literal)${target_prefix}${path}")
  done
  unrelated="$(rubble-exec git --no-optional-locks -C "${repo_root}" status --porcelain --untracked-files=all -- "${status_pathspecs[@]}")"
  [[ -z "${unrelated}" ]] || fail "repository has unrelated changes; commit or remove them before publishing"
  branch="${pipeline_branch}"
  if rubble-exec git -C "${repo_root}" show-ref --verify --quiet "refs/heads/${branch}" || \
     rubble-exec git -C "${repo_root}" ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; then
    fail "one-use pipeline branch already exists: ${branch}"
  fi

  # Build the run commit without consuming local hook edits or changing the caller's index/branch.
  index_directory="$(rubble-exec mktemp -d "$(rubble-exec git -C "${repo_root}" rev-parse --path-format=absolute --git-common-dir)/rubble-publish.XXXXXXXX")"
  trap 'rubble-exec rm -rf -- "${index_directory}"' EXIT
  export GIT_INDEX_FILE="${index_directory}/index"
  rubble-exec git -C "${repo_root}" read-tree HEAD
  for path in "${paths[@]}"; do
    # Missing optional hooks are valid. Keep tracked deletions, using the run index rather than the caller's.
    if [[ ! -e "${repo_root}/${path}" && ! -L "${repo_root}/${path}" ]]; then
      tracked="$(rubble-exec git -C "${repo_root}" ls-files -- ":(literal)${path}")"
      [[ -n "${tracked}" ]] || continue
    fi
    pathspecs+=(":(literal)${path}")
  done
  rubble-exec git -C "${repo_root}" add -A -- "${pathspecs[@]}"
  tree="$(rubble-exec git -C "${repo_root}" write-tree)"
  commit="$(rubble-exec git -C "${repo_root}" commit-tree "${tree}" -p HEAD -m "Run Rubble workflow for ${root_id}")"
  rubble-exec git -C "${repo_root}" update-ref "refs/heads/${branch}" "${commit}" ''
  rubble-exec git -C "${repo_root}" push origin "refs/heads/${branch}:refs/heads/${branch}"
  wait_run --repo "$(resolve_repository)" --branch "${branch}" --commit "${commit}"
)

resolve_repository() {
  local origin_url
  origin_url="$(rubble-exec git -C "${target_root}" remote get-url origin)"
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
  rubble-exec chmod 600 "${state_file}"
  log "consumed one-use pipeline identity ${pipeline_id}"
}

pipeline_state_file() {
  local suffix="$1"
  local git_common_dir
  local state_dir
  git_common_dir="$(rubble-exec git -C "${target_root}" rev-parse --path-format=absolute --git-common-dir)"
  state_dir="${git_common_dir}/rubble-pipelines"
  rubble-exec mkdir -p "${state_dir}" || return 1
  rubble-exec chmod 700 "${state_dir}" || return 1
  printf '%s/%s.%s\n' "${state_dir}" "${pipeline_id}" "${suffix}"
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


json_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "${value}"
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
    if run_id="$(gh api --method GET "repos/${repository}/actions/runs" \
      -f head_sha="${commit}" -f event=push -f per_page=100 \
      --jq ".workflow_runs | map(select(.head_branch == $(json_quote "${branch}") and .head_sha == $(json_quote "${commit}") and .path == $(json_quote "${workflow_path}"))) | sort_by(.run_number, .run_attempt) | last | .id // empty")"; then
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
      rubble-exec sleep 5
    fi
  done

  while true; do
    if ! response="$(gh api "repos/${repository}/actions/runs/${run_id}" --jq '[.status // "", .conclusion // "", .html_url // ""] | .[]')"; then
      log "Actions run status lookup failed; retrying"
      rubble-exec sleep 10
      continue
    fi
    local -a fields=()
    mapfile -t fields <<<"${response}"
    status="${fields[0]:-}"
    conclusion="${fields[1]:-}"
    html_url="${fields[2]:-}"
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
    rubble-exec sleep 10
  done
}

publish_context() {
  export RUBBLE_PUBLISH_TARGET_ROOT="${target_root}"
  export RUBBLE_PUBLISH_PAYLOAD_DIR="${payload_dir}"
  export RUBBLE_PUBLISH_ROOT_ID="${root_id}"
  export RUBBLE_PUBLISH_ROOT_NAME="${root_name}"
  export RUBBLE_PUBLISH_PIPELINE_ID="${pipeline_id}"

  export RUBBLE_PUBLISH_ENVIRONMENT="${pipeline_environment}"

}

publish() {
  if [[ ! -f "${user_publish_script}" || ! -s "${user_publish_script}" ]]; then
    log "user publisher is absent or empty; skipping publication"
    return 0
  fi
  publish_context
  (builtin cd -- "${target_root}" && "${rubble}" -q script --inherit-env "${user_publish_script}")
}

default_publish() {
  publish_context

  local repository
  repository="$(resolve_repository)" || fail "could not resolve target GitHub repository"
  cleanup_repository="${repository}"
  trap cleanup_environment_on_exit EXIT

  rubble_run_hook pre-publish
  consume_pipeline_identity

  create_environment "${repository}"

  publish_git
  rubble_run_hook post-publish
}

command_name="${1:-publish}"
case "${command_name}" in
  publish)
    [[ "$#" -le 1 ]] || fail "publish does not accept arguments"
    publish
    ;;
  default-publish)
    [[ "$#" -eq 1 ]] || fail "default-publish does not accept arguments"
    default_publish
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
    fail "unknown command '${command_name}'; expected publish, default-publish, local-plan, or wait-run"
    ;;
esac