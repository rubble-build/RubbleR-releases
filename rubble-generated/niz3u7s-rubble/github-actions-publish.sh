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
root_brick_relative='store/ni/z3/brk-niz3u7s37ltlvvoqqlcs4r7bbhp2prlm34bzeccnlxg3krzcahda-rubble.brick'
target_root="$(builtin cd "${script_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${script_dir}/${payload_root_relative}" && builtin pwd)"
root_brick="${script_dir}/${root_brick_relative}"
user_publish_relative='../../.rubble/publish.sh'
user_publish_script="${script_dir}/${user_publish_relative}"
root_id='niz3u7s37ltlvvoqqlcs4r7bbhp2prlm34bzeccnlxg3krzcahda-rubble'
root_name='rubble'
pipeline_id='413a7f90-9aea-4d16-a9ac-d6d9ac287502'
pipeline_branch="runs/${pipeline_id}"

pipeline_environment='rubble-pipeline-413a7f90-9aea-4d16-a9ac-d6d9ac287502'
environment_created=0
cleanup_repository=''

workflow_path='.github/workflows/rubble.yml'
generated_root='rubble-generated/niz3u7s-rubble'
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

  'rubble-generated/niz3u7s-rubble/build-brick.sh'

  'rubble-generated/niz3u7s-rubble/cleanup-auth.sh'

  'rubble-generated/niz3u7s-rubble/github-actions-publish.sh'

  'rubble-generated/niz3u7s-rubble/lifecycle.sh'

  'rubble-generated/niz3u7s-rubble/open-pipeline-auth.mjs'

  'rubble-generated/niz3u7s-rubble/pipeline-auth.enc'

  'rubble-generated/niz3u7s-rubble/publish-release.mjs'

  'rubble-generated/niz3u7s-rubble/release-inventory.txt'

  'rubble-generated/niz3u7s-rubble/release-root.sh'

  'rubble-generated/niz3u7s-rubble/store/26/tn/brk-26tn2yq4ryvlust5j46r2gfdg7ew7zg7gpth4bowtw5vxvj5xeiq-findutils.brick'

  'rubble-generated/niz3u7s-rubble/store/34/l3/brk-34l3qhyt32cnsp3szqfcgmezrrqek6sxp6c3jr7uwnve67swunqq-RubbleR.git.brick'

  'rubble-generated/niz3u7s-rubble/store/3y/ms/brk-3ymsqx4irog2cwz3opdekqpw4otufpn5qdjdmbgzswfjrt23imbq-zstd.brick'

  'rubble-generated/niz3u7s-rubble/store/46/lf/brk-46lfnhiwl7xwedh2m5nqmsiz53zc3vcpqiox4v4mctm56nzwlz6a-bootstrap-env.brick'

  'rubble-generated/niz3u7s-rubble/store/5n/ra/brk-5nrap7vermuhdkqtamy653bdcnwr6ehk5a6anm7j63reercotpxq-rubble-deps-cache.brick'

  'rubble-generated/niz3u7s-rubble/store/5w/5f/brk-5w5ft5y3hkcueupk46bozqrdd7fwxp52ook5odjixgomzioqvuia-rust-toolchain.brick'

  'rubble-generated/niz3u7s-rubble/store/6f/yi/brk-6fyi5giuhq2rktxlfg2epgwit5rqik345vr2o25yognyocmskspq-gnu-tar.brick'

  'rubble-generated/niz3u7s-rubble/store/6i/tb/brk-6itbkpqgk46i34vxf2bxe2jjugitys6463c73qfk5fhiipwku4ha-gnu-sed.brick'

  'rubble-generated/niz3u7s-rubble/store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'rubble-generated/niz3u7s-rubble/store/b6/du/brk-b6du7m4wvh6hhvuzjxtbgjxv3kmgap4w2jh2mjw7ztfs2mbseida-gzip.brick'

  'rubble-generated/niz3u7s-rubble/store/bt/u4/brk-btu4wdeflhf6iv4rk4awpoj4h3ke6bdsgsdmdj6icerqhprab2zq-bison.brick'

  'rubble-generated/niz3u7s-rubble/store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'rubble-generated/niz3u7s-rubble/store/cc/a6/brk-cca6hpdxtvtjn3hkbljrizdlu2cpldgeodds67hxlcf2nhclfc5a-m4.brick'

  'rubble-generated/niz3u7s-rubble/store/cd/gy/brk-cdgy6susoq245z4mch7qbgfzwfyqzywqchtfoveem66yiwhb4qba-gnu-make.brick'

  'rubble-generated/niz3u7s-rubble/store/it/xg/brk-itxgxgppoxlnoqfhav4tgvdmsqhkb6xraelfh5my4ex6t6asd6jq-bzip2.brick'

  'rubble-generated/niz3u7s-rubble/store/jo/ll/brk-jollno6o4uloupgitupgjbfxgunhmm5hx3hdhvl7kbmw47dj4dpq-glibc-runtime-support.brick'

  'rubble-generated/niz3u7s-rubble/store/jz/ib/brk-jzib76o6jwvszofr4g7p5ceo7li2szw2zm25pt6bwpu4plo7wdwq-rubble-src-checkout.brick'

  'rubble-generated/niz3u7s-rubble/store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'rubble-generated/niz3u7s-rubble/store/ni/z3/brk-niz3u7s37ltlvvoqqlcs4r7bbhp2prlm34bzeccnlxg3krzcahda-rubble.brick'

  'rubble-generated/niz3u7s-rubble/store/pp/dg/brk-ppdghkityovkxogtghygvs2mls7qza646xifdh4qt3pdr7enpi2a-coreutils.brick'

  'rubble-generated/niz3u7s-rubble/store/pw/37/brk-pw37lfr3ixpwcll66ytcwfkezsbh2smxf77zdjlx6ox6vwlifwxa-gawk.brick'

  'rubble-generated/niz3u7s-rubble/store/re/go/brk-regoxzdjco6l24wacxv6igyyaqk7nfks2okct3g7rcat33gzh7ba-rubble-web-assets.brick'

  'rubble-generated/niz3u7s-rubble/store/sh/tk/brk-shtksgz5dfwxl3a2qy5gazbufvz5d3jrp3yghyt6kfoysejsxr7q-bun-1.4.2.brick'

  'rubble-generated/niz3u7s-rubble/store/st/7k/brk-st7kemdq4iesmpfx4kbo4q2b3rtuoelmqtgfzzrpzs7hukebga5q-rubble-elf-runtime.brick'

  'rubble-generated/niz3u7s-rubble/store/te/ie/brk-teieaxxyjdoyw4gqby5r4ywgrstjp3t6ui4dxasa6j7ba34arziq-patchelf.brick'

  'rubble-generated/niz3u7s-rubble/store/to/yy/brk-toyyhmevribb7khuvecg75ctwezy43ob5us3fe232gwncayr5hkq-gpatch.brick'

  'rubble-generated/niz3u7s-rubble/store/vj/kf/brk-vjkfcfgkm77x6m2ulurl7euwz2rnspl5pijijlqq5wmu4fcyn6la-unzip.brick'

  'rubble-generated/niz3u7s-rubble/store/vv/yh/brk-vvyhmuysr2vjsftzfyed3zekunsonl6t34mrh55zkb3mmepagjsa-diffutils.brick'

  'rubble-generated/niz3u7s-rubble/store/wl/uw/brk-wluwjucbrlkece4f3oq2qk6uxprq3t7h2ogids4ymiz4nsvjqmwa-xz.brick'

  'rubble-generated/niz3u7s-rubble/store/x6/3s/brk-x63s7v4qom7r4x7j6vg6y7p2sofdrxxj3dgw7fqdqftwwhjpixaq-perl.brick'

  'rubble-generated/niz3u7s-rubble/store/xp/q3/brk-xpq3y53udiwojwu3cmwsgbqn7pkk6y74expqaf4ss6goibdgypuq-grep.brick'

  'rubble-generated/niz3u7s-rubble/store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'rubble-generated/niz3u7s-rubble/store/xt/64/brk-xt64bpkydygjzezkokdv36klu36dn4cnhm762iasa23j2g4qwyoq-gcc.brick'

  'rubble-generated/niz3u7s-rubble/store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

  'rubble-generated/niz3u7s-rubble/store/zy/6b/brk-zy6bvkew2exlrwyg3zjlgc47llzncsko4l6kssqxbtdjpcoe4wbq-git.brick'

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