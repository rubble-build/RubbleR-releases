publication_dir="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
# Shared local publication context and lifecycle. Sourced by a service adapter.
lifecycle_relative='lifecycle.sh'
source "${publication_dir}/${lifecycle_relative}"
target_root_relative='../..'
payload_root_relative='.'
root_brick_relative='store/j4/l4/brk-j4l43hvomqceu6rngdrgg43uep7uauaurxl7ihnetu3jj3hlaucq-rubble.brick'
target_root="$(builtin cd "${publication_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${publication_dir}/${payload_root_relative}" && builtin pwd)"
root_brick="${publication_dir}/${root_brick_relative}"
user_publish_relative='../../.rubble/publish.sh'
user_publish_script="${publication_dir}/${user_publish_relative}"
root_id='j4l43hvomqceu6rngdrgg43uep7uauaurxl7ihnetu3jj3hlaucq-rubble'
root_name='rubble'
pipeline_id='7594f705-ed1f-4442-a3f6-f6adad1fd1f9'
pipeline_branch="runs/${pipeline_id}"
generated_root='rubble-generated/j4l43hv-rubble'
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

  'rubble-generated/j4l43hv-rubble/Dockerfile'

  'rubble-generated/j4l43hv-rubble/authentication.sh'

  'rubble-generated/j4l43hv-rubble/build-brick.sh'

  'rubble-generated/j4l43hv-rubble/cleanup-auth.sh'

  'rubble-generated/j4l43hv-rubble/github-actions-publish.sh'

  'rubble-generated/j4l43hv-rubble/install-image.sh'

  'rubble-generated/j4l43hv-rubble/lifecycle.sh'

  'rubble-generated/j4l43hv-rubble/open-pipeline-auth.mjs'

  'rubble-generated/j4l43hv-rubble/pipeline-auth.enc'

  'rubble-generated/j4l43hv-rubble/prepare-image.sh'

  'rubble-generated/j4l43hv-rubble/publish-release.mjs'

  'rubble-generated/j4l43hv-rubble/publish-runtime.sh'

  'rubble-generated/j4l43hv-rubble/release-inventory.txt'

  'rubble-generated/j4l43hv-rubble/release-root.sh'

  'rubble-generated/j4l43hv-rubble/store/2h/d6/brk-2hd6u265z3wib6gwseiazg3zwct4omkjbc5ntlurpklgilzjjadq-nodejs.brick'

  'rubble-generated/j4l43hv-rubble/store/3w/tm/brk-3wtmg3emr45kij2bqxsu26sgurjr2qhzvlbflvo2jbonsy27ky7a-gcc-glibc.brick'

  'rubble-generated/j4l43hv-rubble/store/5h/6c/brk-5h6cchin5lidxx4alu3objrowtlsbqblhb27i6svhihosmwda3ja-gzip.brick'

  'rubble-generated/j4l43hv-rubble/store/5p/zr/brk-5pzrau5ndljrzmkds5h2bs34mrf5nle5j3u4itfclyubfi4ub2ba-rubble-elf-runtime.brick'

  'rubble-generated/j4l43hv-rubble/store/65/xn/brk-65xn763kfhf7ye2ax5rr3hjotrij3qjagkddvfhqarwrt2a7mnha-ld-musl.so.brick'

  'rubble-generated/j4l43hv-rubble/store/6l/p4/brk-6lp456cvhb7ckx65h7yhuzgup3uli5rrlhgesi7cgtyuqcgbwp3q-zstd.brick'

  'rubble-generated/j4l43hv-rubble/store/7f/cr/brk-7fcrm7iiq4agepnnbu46kixt3exop6fqy2ylv34zgifmrjjckczq-bzip2.brick'

  'rubble-generated/j4l43hv-rubble/store/7h/vr/brk-7hvrra6ygcaaeexgncdv3uasq6xy65zzagujucn6atyplqhhviua-wasm-pack-0.15.0.brick'

  'rubble-generated/j4l43hv-rubble/store/7s/4o/brk-7s4o767a44rz37525ykn7eadrhimstjjvdts2segihab4tqgk3yq-llvm-tools-1.94.0.brick'

  'rubble-generated/j4l43hv-rubble/store/a7/ud/brk-a7ud4y2emz4jysev4e5p275gywgintjlenar2fsfrjokko6cdclq-bootstrap-env.brick'

  'rubble-generated/j4l43hv-rubble/store/ar/ds/brk-ardstcgczrhdaibp6jmdzypxykeymbity6aut4wr3ijnqozjrcxq-git.brick'

  'rubble-generated/j4l43hv-rubble/store/bg/yp/brk-bgypnnermvrmj657kbamz6dhvtc7ic743c3tlooizg54udk3ocka-curl.brick'

  'rubble-generated/j4l43hv-rubble/store/c5/wb/brk-c5wbg5jn3pylcmup7sbxmniucuw6dzpkte46m6h7buk2xbxyxtsq-python3.brick'

  'rubble-generated/j4l43hv-rubble/store/cn/de/brk-cndex52rgwiybhxcbkpry2isc55dz3hrc5lblmzr3xyeilghixda-patchelf.brick'

  'rubble-generated/j4l43hv-rubble/store/du/so/brk-dusoct55bmpgvm2ldpmeths6hggdhr33vyflycel7kjgjw3ts6ha-ca-certificates.pem.brick'

  'rubble-generated/j4l43hv-rubble/store/e7/dd/brk-e7ddcesxg2zmvb5wamzn6k6wq77wdqf5jxs3cow4m64xubmstluq-gnu-make.brick'

  'rubble-generated/j4l43hv-rubble/store/fd/vb/brk-fdvblu7ednc2u5nevmdvxyvycn4fejjclnyaqzg6itd54yacupcq-xz.brick'

  'rubble-generated/j4l43hv-rubble/store/ia/nt/brk-iantrfpk2ym7cs3gogddteqf55vid2cqroar3baw24nbvg7dxu3q-cargo-1.94.0.brick'

  'rubble-generated/j4l43hv-rubble/store/ib/kn/brk-ibknsfta5hwy3yipkynoqj6cflte22cxtj6h4qw6g2z2vwioy22a-bun-1.4.2.brick'

  'rubble-generated/j4l43hv-rubble/store/iu/rp/brk-iurpgonnj2ueak3ta44zihvtdksmjx5j62dy7n2ebbd7pdb3lfja-bison.brick'

  'rubble-generated/j4l43hv-rubble/store/iw/xf/brk-iwxfog3m6w6osk73jf7h77lycjwgis2khdcwgi5vp2bngilpq5qa-gnu-sed.brick'

  'rubble-generated/j4l43hv-rubble/store/j4/l4/brk-j4l43hvomqceu6rngdrgg43uep7uauaurxl7ihnetu3jj3hlaucq-rubble.brick'

  'rubble-generated/j4l43hv-rubble/store/jz/sb/brk-jzsbx4e7xjrjybgzigm2xnhrpc6rldvgwpqlhvca7vjzks7fzunq-gcc.brick'

  'rubble-generated/j4l43hv-rubble/store/k5/fr/brk-k5frhmbdkv7cwqivkkbpn54wsufwddmytey446lzvulwfj7ggc4q-gpatch.brick'

  'rubble-generated/j4l43hv-rubble/store/ks/tm/brk-kstm375tcxoylrqngxkxmxplapgizkd4nwsmw6mv7ol26pqbdj4a-RubbleR.git.brick'

  'rubble-generated/j4l43hv-rubble/store/nh/57/brk-nh577btyfes2xq2gotqnt6ur4vqq6qojz4kmf7xbewchtdzrmyzq-gnu-tar.brick'

  'rubble-generated/j4l43hv-rubble/store/nl/af/brk-nlafddbuq7viz5x57zx4vgca2kuueiv4gr372nbwqfntb5buta2a-rubble-web-assets.brick'

  'rubble-generated/j4l43hv-rubble/store/og/dq/brk-ogdqjl6v7umf45svfgxqm7myx3aq4lyg634c5mm6lf3r777mlkba-rubble-deps-cache.brick'

  'rubble-generated/j4l43hv-rubble/store/ok/3n/brk-ok3nzhwwjno635puiomjcgab4zs3do2lodekydllpb3hw3h3pkqq-rust-toolchain.brick'

  'rubble-generated/j4l43hv-rubble/store/p2/th/brk-p2thxjrt4enoru7wjpubhfnj6xs7f2c2ig3eitngr7jdcneqsiqa-RubbleR.git.partial.brick'

  'rubble-generated/j4l43hv-rubble/store/pc/6e/brk-pc6egjgq2ba3z3wnas2zd4lygye7s6qa34rdem6tqt2oxizk3kfa-gawk.brick'

  'rubble-generated/j4l43hv-rubble/store/pl/ir/brk-plirr2s7hgoniokenfwlknvmhw6nz2unh5nrlaazae3sn5kwvkhq-rust-web-wasm-toolchain.brick'

  'rubble-generated/j4l43hv-rubble/store/pu/u3/brk-puu36hrkbbnfc3pjiyvtfpejz7bbtp4towjhci2zkc3nklh7qiaa-rustc-1.94.0.brick'

  'rubble-generated/j4l43hv-rubble/store/q4/fu/brk-q4fupy6ofwyh2j5rnst4z47nr5lp3jsee4gdi6y4jiybfwincczq-nodejs-runtime.brick'

  'rubble-generated/j4l43hv-rubble/store/qj/7s/brk-qj7s4kfeu7lleafbwujkfsjkts575oc7v5agukewx2ic3y6b6mdq-coreutils.brick'

  'rubble-generated/j4l43hv-rubble/store/qv/l2/brk-qvl2rmykqyiei7tbqvllz6gdcbfmq57dgzlns3lydcsgzy4qpxia-rubble-web-node-modules.brick'

  'rubble-generated/j4l43hv-rubble/store/ry/jw/brk-ryjwb6a3ynqdajbncvpdzwephlmhpxe56zvtgfs4cv4x5lvdguca-rubble-src-checkout.brick'

  'rubble-generated/j4l43hv-rubble/store/s4/36/brk-s436fi4eiqcbgfl3sxxy6qiehrwo3ytnrcmp3s4u5meq6dlhmola-m4.brick'

  'rubble-generated/j4l43hv-rubble/store/si/63/brk-si63kbjoeh5l76hedrmuxjzzuolovggsbkabc2fqnwt7ujic7ajq-binaryen-117.brick'

  'rubble-generated/j4l43hv-rubble/store/t5/am/brk-t5amqprssgcztj7qgv4d7bqmtbtagdixvn4hvjtycdm44t4gtrda-diffutils.brick'

  'rubble-generated/j4l43hv-rubble/store/te/dz/brk-tedz642cat5wbxa5xk2cl6gbj4rmqaj6r64ivlzc6wu4bg4iolla-grep.brick'

  'rubble-generated/j4l43hv-rubble/store/tn/qp/brk-tnqpv7axhecqr2tjhs2hmryfrd44wqwv77le6kdgqihbvohqtyxa-linux-native-toolchain.brick'

  'rubble-generated/j4l43hv-rubble/store/vi/sd/brk-visdzgzf627yppudc7znj4basgcbxhgmqwjn2nyiugitptyaitea-glibc-runtime-support.brick'

  'rubble-generated/j4l43hv-rubble/store/vx/wg/brk-vxwgaxdchz7bshf2frb2nciw5fvmchcygr76c7nstnwaithr3t2q-unzip.brick'

  'rubble-generated/j4l43hv-rubble/store/w5/uo/brk-w5uonp27enqbgfgnn5iej5bxy46h4wsarwscbtt44xyjcvswteaq-wasm-bindgen-cli-0.2.115.brick'

  'rubble-generated/j4l43hv-rubble/store/xp/4n/brk-xp4ng2csk5hs2jlwyfptf7imm4gd3jifcoxvhghuz7b7qf5nidla-findutils.brick'

  'rubble-generated/j4l43hv-rubble/store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'rubble-generated/j4l43hv-rubble/store/ye/cb/brk-yecbppbe2hram3gythftkgn6mwelxq6l42vejdrjy3czbotcwmoq-bash.brick'

  'rubble-generated/j4l43hv-rubble/store/zn/wh/brk-znwhzlmuwlllrzalgrnpvastzcrjizp6j6uko2ijyvss5ycuwr6q-perl.brick'

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