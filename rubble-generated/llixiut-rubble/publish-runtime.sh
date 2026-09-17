publication_dir="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
# Shared local publication context and lifecycle. Sourced by a service adapter.
lifecycle_relative='lifecycle.sh'
source "${publication_dir}/${lifecycle_relative}"
target_root_relative='../..'
payload_root_relative='.'
root_brick_relative='store/ll/ix/brk-llixiutsyvwwkstd5pdculrtr6erjco5raj5uaxmrqhmsgud34uq-rubble.brick'
target_root="$(builtin cd "${publication_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${publication_dir}/${payload_root_relative}" && builtin pwd)"
root_brick="${publication_dir}/${root_brick_relative}"
user_publish_relative='../../.rubble/publish.sh'
user_publish_script="${publication_dir}/${user_publish_relative}"
root_id='llixiutsyvwwkstd5pdculrtr6erjco5raj5uaxmrqhmsgud34uq-rubble'
root_name='rubble'
pipeline_id='33183e91-ec23-4764-820e-8530fa137e0f'
pipeline_branch="runs/${pipeline_id}"
generated_root='rubble-generated/llixiut-rubble'
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

  'rubble-generated/llixiut-rubble/Dockerfile'

  'rubble-generated/llixiut-rubble/authentication.sh'

  'rubble-generated/llixiut-rubble/build-brick.sh'

  'rubble-generated/llixiut-rubble/cleanup-auth.sh'

  'rubble-generated/llixiut-rubble/github-actions-publish.sh'

  'rubble-generated/llixiut-rubble/install-image.sh'

  'rubble-generated/llixiut-rubble/lifecycle.sh'

  'rubble-generated/llixiut-rubble/open-pipeline-auth.mjs'

  'rubble-generated/llixiut-rubble/pipeline-auth.enc'

  'rubble-generated/llixiut-rubble/prepare-image.sh'

  'rubble-generated/llixiut-rubble/publish-release.mjs'

  'rubble-generated/llixiut-rubble/publish-runtime.sh'

  'rubble-generated/llixiut-rubble/release-inventory.txt'

  'rubble-generated/llixiut-rubble/release-root.sh'

  'rubble-generated/llixiut-rubble/store/26/tn/brk-26tn2yq4ryvlust5j46r2gfdg7ew7zg7gpth4bowtw5vxvj5xeiq-findutils.brick'

  'rubble-generated/llixiut-rubble/store/3y/ms/brk-3ymsqx4irog2cwz3opdekqpw4otufpn5qdjdmbgzswfjrt23imbq-zstd.brick'

  'rubble-generated/llixiut-rubble/store/46/lf/brk-46lfnhiwl7xwedh2m5nqmsiz53zc3vcpqiox4v4mctm56nzwlz6a-bootstrap-env.brick'

  'rubble-generated/llixiut-rubble/store/6f/yi/brk-6fyi5giuhq2rktxlfg2epgwit5rqik345vr2o25yognyocmskspq-gnu-tar.brick'

  'rubble-generated/llixiut-rubble/store/6i/tb/brk-6itbkpqgk46i34vxf2bxe2jjugitys6463c73qfk5fhiipwku4ha-gnu-sed.brick'

  'rubble-generated/llixiut-rubble/store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'rubble-generated/llixiut-rubble/store/b6/du/brk-b6du7m4wvh6hhvuzjxtbgjxv3kmgap4w2jh2mjw7ztfs2mbseida-gzip.brick'

  'rubble-generated/llixiut-rubble/store/bt/u4/brk-btu4wdeflhf6iv4rk4awpoj4h3ke6bdsgsdmdj6icerqhprab2zq-bison.brick'

  'rubble-generated/llixiut-rubble/store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'rubble-generated/llixiut-rubble/store/cc/a6/brk-cca6hpdxtvtjn3hkbljrizdlu2cpldgeodds67hxlcf2nhclfc5a-m4.brick'

  'rubble-generated/llixiut-rubble/store/cd/gy/brk-cdgy6susoq245z4mch7qbgfzwfyqzywqchtfoveem66yiwhb4qba-gnu-make.brick'

  'rubble-generated/llixiut-rubble/store/it/xg/brk-itxgxgppoxlnoqfhav4tgvdmsqhkb6xraelfh5my4ex6t6asd6jq-bzip2.brick'

  'rubble-generated/llixiut-rubble/store/ll/ix/brk-llixiutsyvwwkstd5pdculrtr6erjco5raj5uaxmrqhmsgud34uq-rubble.brick'

  'rubble-generated/llixiut-rubble/store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'rubble-generated/llixiut-rubble/store/pk/tw/brk-pktwewtwfe5eg3k5tr4cbfakejnkwk4vmnxyqfb3zkwum2rxpxfq-glibc-runtime-support.brick'

  'rubble-generated/llixiut-rubble/store/pp/dg/brk-ppdghkityovkxogtghygvs2mls7qza646xifdh4qt3pdr7enpi2a-coreutils.brick'

  'rubble-generated/llixiut-rubble/store/pw/37/brk-pw37lfr3ixpwcll66ytcwfkezsbh2smxf77zdjlx6ox6vwlifwxa-gawk.brick'

  'rubble-generated/llixiut-rubble/store/sh/id/brk-shidbibgptsswa33nbpjwlsxa3kcz7mxtobh33lkji6l2bz7pgka-bun-1.4.2.brick'

  'rubble-generated/llixiut-rubble/store/to/yy/brk-toyyhmevribb7khuvecg75ctwezy43ob5us3fe232gwncayr5hkq-gpatch.brick'

  'rubble-generated/llixiut-rubble/store/tv/ix/brk-tvixmybabsgwepyqt72yuhquuoeqcckd2i27zucfmmuz4af4byxa-rubble-elf-runtime.brick'

  'rubble-generated/llixiut-rubble/store/vj/kf/brk-vjkfcfgkm77x6m2ulurl7euwz2rnspl5pijijlqq5wmu4fcyn6la-unzip.brick'

  'rubble-generated/llixiut-rubble/store/vv/yh/brk-vvyhmuysr2vjsftzfyed3zekunsonl6t34mrh55zkb3mmepagjsa-diffutils.brick'

  'rubble-generated/llixiut-rubble/store/wl/uw/brk-wluwjucbrlkece4f3oq2qk6uxprq3t7h2ogids4ymiz4nsvjqmwa-xz.brick'

  'rubble-generated/llixiut-rubble/store/x6/3s/brk-x63s7v4qom7r4x7j6vg6y7p2sofdrxxj3dgw7fqdqftwwhjpixaq-perl.brick'

  'rubble-generated/llixiut-rubble/store/xp/q3/brk-xpq3y53udiwojwu3cmwsgbqn7pkk6y74expqaf4ss6goibdgypuq-grep.brick'

  'rubble-generated/llixiut-rubble/store/xt/64/brk-xt64bpkydygjzezkokdv36klu36dn4cnhm762iasa23j2g4qwyoq-gcc.brick'

  'rubble-generated/llixiut-rubble/store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

  'rubble-generated/llixiut-rubble/store/zy/6b/brk-zy6bvkew2exlrwyg3zjlgc47llzncsko4l6kssqxbtdjpcoe4wbq-git.brick'

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