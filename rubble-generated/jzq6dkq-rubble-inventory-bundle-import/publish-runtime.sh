publication_dir="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
# Shared local publication context and lifecycle. Sourced by a service adapter.
lifecycle_relative='lifecycle.sh'
source "${publication_dir}/${lifecycle_relative}"
target_root_relative='../..'
payload_root_relative='.'
root_brick_relative='store/jz/q6/brk-jzq6dkqaybcddwep3g2qsgce45u2wxjlx4kaxgi5r4bhex6zlqna-rubble-inventory-bundle-import.brick'
target_root="$(builtin cd "${publication_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${publication_dir}/${payload_root_relative}" && builtin pwd)"
root_brick="${publication_dir}/${root_brick_relative}"
user_publish_relative='../../.rubble/publish.sh'
user_publish_script="${publication_dir}/${user_publish_relative}"
root_id='jzq6dkqaybcddwep3g2qsgce45u2wxjlx4kaxgi5r4bhex6zlqna-rubble-inventory-bundle-import'
root_name='rubble-inventory-bundle-import'
pipeline_id='7837bf86-32e0-4042-8155-5a90a0f3b511'
pipeline_branch="runs/${pipeline_id}"
generated_root='rubble-generated/jzq6dkq-rubble-inventory-bundle-import'
managed_output_paths=(

  '.github/workflows/rubble.yml'

  '.rubble/hooks'

  '.rubble/hooks/post-job.sh'

  '.rubble/hooks/post-publish.sh'

  '.rubble/hooks/post-release.sh'

  '.rubble/hooks/pre-job.sh'

  '.rubble/hooks/pre-publish.sh'

  '.rubble/hooks/prepare-release.sh'

  '.rubble/publish.sh'

  '.rubble/release.sh'

  'rubble-generated'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/Dockerfile'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/authentication.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/build-brick.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/cleanup-auth.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/github-actions-publish.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/install-image.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/lifecycle.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/open-pipeline-auth.mjs'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/pipeline-auth.enc'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/prepare-image.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/publish-release.mjs'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/publish-runtime.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/release-inventory.txt'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/release-root.sh'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/3y/ms/brk-3ymsqx4irog2cwz3opdekqpw4otufpn5qdjdmbgzswfjrt23imbq-zstd.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/6f/yi/brk-6fyi5giuhq2rktxlfg2epgwit5rqik345vr2o25yognyocmskspq-gnu-tar.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/c4/z3/brk-c4z3a4b2hbskg4bwur5ixof6tnr2ilowwp654vc7gc6hsuujzsqq-RubbleR.git.partial.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/jz/q6/brk-jzq6dkqaybcddwep3g2qsgce45u2wxjlx4kaxgi5r4bhex6zlqna-rubble-inventory-bundle-import.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/pp/dg/brk-ppdghkityovkxogtghygvs2mls7qza646xifdh4qt3pdr7enpi2a-coreutils.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/ry/jw/brk-ryjwb6a3ynqdajbncvpdzwephlmhpxe56zvtgfs4cv4x5lvdguca-rubble-src-checkout.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'rubble-generated/jzq6dkq-rubble-inventory-bundle-import/store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

)

log() {
  printf '[remote-publish] %s\n' "$1" >&2
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

rubble_local_plan() {
  print_assignment RUBBLE_PUBLISH_SUGGESTED_BRANCH "${pipeline_branch}"
  print_assignment RUBBLE_PUBLISH_PIPELINE_ID "${pipeline_id}"
  print_assignment RUBBLE_PUBLISH_GENERATED_ROOT "${generated_root}"
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
  local original_index="${GIT_INDEX_FILE-}" original_index_set="${GIT_INDEX_FILE+x}"
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
  # Service adapters and user hooks retain the caller's Git context.
  if [[ "${original_index_set}" == x ]]; then
    export GIT_INDEX_FILE="${original_index}"
  else
    unset GIT_INDEX_FILE
  fi
  rubble_publish_remote "${repo_root}" "${target_prefix}" "${branch}" "${commit}"
  if [[ "${RUBBLE_PUBLISH_WAITED}" == true ]]; then rubble_run_hook post-publish; fi
)

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


publish_context() {
  export RUBBLE_PUBLISH_TARGET_ROOT="${target_root}"
  export RUBBLE_PUBLISH_PAYLOAD_DIR="${payload_dir}"
  export RUBBLE_PUBLISH_ROOT_ID="${root_id}"
  export RUBBLE_PUBLISH_ROOT_NAME="${root_name}"
  export RUBBLE_PUBLISH_PIPELINE_ID="${pipeline_id}"
}

publish() {
  if [[ ! -f "${user_publish_script}" || ! -s "${user_publish_script}" ]]; then
    log "user publisher is absent or empty; skipping publication"
    return 0
  fi
  publish_context
  (builtin cd -- "${target_root}" && "${rubble}" script --inherit-env "${user_publish_script}")
}

default_publish() {
  publish_context
  rubble_run_hook pre-publish
  consume_pipeline_identity
  rubble_prepare_publication
  publish_git
}