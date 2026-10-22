# Source with: RUNTIME TARGET CONFIG_FILE CREDENTIALS_FILE.
# This library defines metadata/functions and performs only local read-only queries.
# Public CONFIG/RESOURCES/PATH_OUTPUT/RUN_OUTPUT arguments are variable names.
# Helpers never install traps or change the caller's cwd or shell options.

_rubble_publish_error() { printf '[remote-publish] ERROR: %s\n' "$*" >&2; return 1; }
_rubble_publish_log() { printf '[remote-publish] %s\n' "$*" >&2; }

# Each child uses the explicitly selected runtime/configuration and target checkout.
_rubble_publish_runtime() (
  local -n __rp_runtime_config="$1"
  shift
  export RUBBLE_EXECUTABLE="${__rp_runtime_config[rubble]}"
  if [[ -n "${__rp_runtime_config[config]}" ]]; then export RUBBLE_CONFIG="${__rp_runtime_config[config]}"; else unset RUBBLE_CONFIG; fi
  if [[ -n "${__rp_runtime_config[credentials]}" ]]; then export RUBBLE_CREDENTIALS="${__rp_runtime_config[credentials]}"; else unset RUBBLE_CREDENTIALS; fi
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX GIT_IMPLICIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_SHALLOW_FILE GIT_GRAFT_FILE GIT_NAMESPACE
  builtin cd -- "${__rp_runtime_config[target]}" || return $?
  "${__rp_runtime_config[rubble]}" "$@"
)

_rubble_publish_tool() (
  local __rp_tool_config="$1" __rp_tools
  shift
  __rp_tools="$(_rubble_publish_runtime "$__rp_tool_config" -q info --format bash --tools)" || return $?
  eval "$__rp_tools" || return $?
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX GIT_IMPLICIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_SHALLOW_FILE GIT_GRAFT_FILE GIT_NAMESPACE
  rubble-exec "$@"
)

# Execute exactly one subcommand; authentication is selected only for transports.
rubble_git() {
  [[ $# -ge 2 ]] || { _rubble_publish_error 'rubble_git requires CONFIG SUBCOMMAND [ARGS...]'; return 1; }
  local -n __rp_git_config="$1"
  local __rp_git_name="$1" __rp_git_command="$2"
  shift 2
  case "$__rp_git_command" in
    push|fetch|ls-remote)
      local __rp_direction=fetch
      if [[ "$__rp_git_command" == push ]]; then __rp_direction=push; fi
      _rubble_publish_runtime "$__rp_git_name" script --inherit-env "${__rp_git_config[remote_auth]}" \
        git "${__rp_git_config[repository]}" "$__rp_direction" "$__rp_git_command" "$@"
      ;;
    *) _rubble_publish_tool "$__rp_git_name" git -C "${__rp_git_config[repository]}" "$__rp_git_command" "$@" ;;
  esac
}

rubble_publish_check_worktree() {
  [[ $# -ge 1 ]] || { _rubble_publish_error 'check_worktree requires CONFIG [MANAGED_PATHS...]'; return 1; }
  local -n __rp_check_config="$1"
  local __rp_check_name="$1" __rp_path __rp_unrelated
  shift
  local -a __rp_status_paths=(.)
  for __rp_path in "$@"; do __rp_status_paths+=(":(exclude,literal)${__rp_check_config[target_prefix]}${__rp_path}"); done
  __rp_unrelated="$(_rubble_publish_tool "$__rp_check_name" git -C "${__rp_check_config[repository]}" \
    --no-optional-locks status --porcelain --untracked-files=all --ignore-submodules=none -- "${__rp_status_paths[@]}")" || return $?
  [[ -z "$__rp_unrelated" ]] || { _rubble_publish_error 'repository has unrelated changes; commit or remove them before publishing'; return 1; }
}

_rubble_publish_state_directory() {
  local __rp_state_common
  __rp_state_common="$(rubble_git "$1" rev-parse --path-format=absolute --git-common-dir)" || return $?
  printf '%s/rubble-pipelines\n' "$__rp_state_common"
}

rubble_publish_check_identity() {
  [[ $# -eq 1 ]] || { _rubble_publish_error 'check_identity requires CONFIG'; return 1; }
  local -n __rp_identity_config="$1"
  local __rp_identity_state __rp_identity_marker
  __rp_identity_state="$(_rubble_publish_state_directory "$1")" || return $?
  __rp_identity_marker="$__rp_identity_state/${__rp_identity_config[pipeline_id]}.used"
  if [[ -e "$__rp_identity_marker" || -L "$__rp_identity_marker" ]]; then
    _rubble_publish_error 'pipeline identity has already been consumed; run Rubble again to create a new pipeline'
    return 1
  fi
}

_rubble_publish_service() {
  local __rp_operation="$1"
  local -n __rp_service_config="$2"
  shift
  case "${__rp_service_config[adapter]}" in
    github) "_rubble_github_${__rp_operation}" "$@" ;;
    gitlab) "_rubble_gitlab_${__rp_operation}" "$@" ;;
    jenkins) "_rubble_jenkins_${__rp_operation}" "$@" ;;
    *) _rubble_publish_error 'unknown publication adapter' ;;
  esac
}

rubble_publish_prepare() {
  [[ $# -ge 4 ]] || { _rubble_publish_error 'prepare requires CONFIG RESOURCES PATH_OUTPUT BRANCH [MANAGED_PATHS...]'; return 1; }
  local -n __rp_prepare_config="$1" __rp_prepare_resources="$2" __rp_prepare_paths="$3"
  local __rp_prepare_name="$1" __rp_resources_name="$2" __rp_branch="$4"
  shift 4
  local __rp_state __rp_path __rp_literal __rp_tracked
  __rp_state="$(_rubble_publish_state_directory "$__rp_prepare_name")" || return $?
  _rubble_publish_tool "$__rp_prepare_name" mkdir -p "$__rp_state" || return $?
  _rubble_publish_tool "$__rp_prepare_name" chmod 700 "$__rp_state" || return $?
  if ! (set -o noclobber; printf '%s\n' "${__rp_prepare_config[pipeline_id]}" > "$__rp_state/${__rp_prepare_config[pipeline_id]}.used") 2>/dev/null; then
    _rubble_publish_error 'pipeline identity has already been consumed; run Rubble again to create a new pipeline'
    return 1
  fi
  _rubble_publish_tool "$__rp_prepare_name" chmod 600 "$__rp_state/${__rp_prepare_config[pipeline_id]}.used" || return $?
  _rubble_publish_log "consumed one-use pipeline identity ${__rp_prepare_config[pipeline_id]}"
  _rubble_publish_service prepare "$__rp_prepare_name" "$__rp_resources_name" "$__rp_branch" || return $?
  rubble_publish_check_worktree "$__rp_prepare_name" "$@" || return $?
  __rp_prepare_paths=()
  for __rp_path in "$@"; do
    __rp_literal=":(literal)${__rp_prepare_config[target_prefix]}${__rp_path}"
    if [[ ! -e "${__rp_prepare_config[target]}/$__rp_path" && ! -L "${__rp_prepare_config[target]}/$__rp_path" ]]; then
      __rp_tracked="$(rubble_git "$__rp_prepare_name" ls-files -- "$__rp_literal")" || return $?
      [[ -n "$__rp_tracked" ]] || continue
    fi
    __rp_prepare_paths+=("$__rp_literal")
  done
  if rubble_git "$__rp_prepare_name" ls-remote --exit-code --heads origin "refs/heads/$__rp_branch" >/dev/null 2>&1; then
    _rubble_publish_error "one-use pipeline branch already exists remotely: $__rp_branch"
    return 1
  fi
}

rubble_publish_trigger() {
  [[ $# -eq 5 ]] || { _rubble_publish_error 'trigger requires CONFIG RESOURCES RUN_OUTPUT BRANCH COMMIT'; return 1; }
  _rubble_publish_service trigger "$@"
}
rubble_publish_find_run() {
  [[ $# -eq 4 ]] || { _rubble_publish_error 'find_run requires CONFIG BRANCH COMMIT RUN_HINT'; return 1; }
  _rubble_publish_service find "$@"
}
rubble_publish_wait() {
  [[ $# -eq 2 && -n "$2" ]] || { _rubble_publish_error 'wait requires CONFIG RUN_URL'; return 1; }
  _rubble_publish_service wait "$@"
}

# Clean owned resources first; always attempt the explicitly supplied next command.
rubble_publish_cleanup() {
  [[ $# -ge 4 && "$4" == -- ]] || { _rubble_publish_error 'cleanup requires STATUS CONFIG RESOURCES -- [COMMAND ARGS...]'; return 1; }
  local __rp_status="$1" __rp_cleanup_status=0 __rp_followup_status=0
  _rubble_publish_service cleanup "$2" "$3" || __rp_cleanup_status=$?
  shift 4
  if [[ $# -gt 0 ]]; then
    "$@" || __rp_followup_status=$?
    if [[ "$__rp_followup_status" -ne 0 ]]; then _rubble_publish_log "ERROR: cleanup follow-up command failed (exit $__rp_followup_status)"; fi
  fi
  if [[ "$__rp_status" -ne 0 ]]; then return "$__rp_status"; fi
  if [[ "$__rp_cleanup_status" -ne 0 ]]; then return "$__rp_cleanup_status"; fi
  return "$__rp_followup_status"
}

_rubble_publish_initialize() {
  [[ $# -eq 4 && -n "$1" && -n "$2" ]] || { _rubble_publish_error 'source the publication library with RUNTIME TARGET CONFIG_FILE CREDENTIALS_FILE'; return 1; }
  declare -gA rubble_publish_config=([rubble]="$1" [target]="$2" [config]="$3" [credentials]="$4")
  local __rp_directory __rp_relative __rp_reference __rp_original
  __rp_directory="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)" || return $?
  rubble_publish_config[repository]="$(_rubble_publish_tool rubble_publish_config git -C "$2" rev-parse --show-toplevel)" || return $?
  rubble_publish_config[target_prefix]="$(_rubble_publish_tool rubble_publish_config git -C "$2" rev-parse --show-prefix)" || return $?
  rubble_publish_config[plan_id]='multi-422ko74uks7nntbyq2ytjzmk2x2a7gza4ji2eibv6w2tllfg6jzq'
  rubble_publish_config[pipeline_id]='3460b9ea-efc4-4329-9e53-f7e3cfb8703e'
  rubble_publish_config[suggested_branch]="runs/${rubble_publish_config[pipeline_id]}"
  rubble_publish_config[commit_message]="Run Rubble workflow for ${rubble_publish_config[plan_id]}"
  rubble_publish_config[remote_store]='default'
  rubble_publish_config[plan_title]='2 bricks: aarch64-linux-ajdc5dv-rubble, x86_64-linux-6jnhpyn-rubble'
  rubble_publish_config[generated_root]='rubble-generated/multi-422ko74'
  __rp_relative='remote-auth.mjs'
  rubble_publish_config[remote_auth]="$__rp_directory/$__rp_relative"
  __rp_relative='../../.rubble/publish.sh'
  rubble_publish_config[user_script]="$__rp_directory/$__rp_relative"
  __rp_relative='.'
  rubble_publish_config[payload]="$(builtin cd -- "$__rp_directory/$__rp_relative" && builtin pwd)" || return $?
  declare -ga rubble_roots=(

    'ajdc5dvnu677rnq2f7dajpfn6jj5s2u5n7mzkerr242vjmaffr3a-rubble'

    '6jnhpyn5w3wwitaqh2zqkuf4onh5ubxnt62enzx626q4q4xetgfa-rubble'

  )
  declare -gA rubble_root_short_ids=() rubble_root_names=() rubble_root_platforms=() rubble_root_bricks=()

  rubble_root_short_ids['ajdc5dvnu677rnq2f7dajpfn6jj5s2u5n7mzkerr242vjmaffr3a-rubble']='ajdc5dv-rubble'
  rubble_root_names['ajdc5dvnu677rnq2f7dajpfn6jj5s2u5n7mzkerr242vjmaffr3a-rubble']='rubble'

  rubble_root_platforms['ajdc5dvnu677rnq2f7dajpfn6jj5s2u5n7mzkerr242vjmaffr3a-rubble']='aarch64-linux'

  __rp_relative='store/aj/dc/brk-ajdc5dvnu677rnq2f7dajpfn6jj5s2u5n7mzkerr242vjmaffr3a-rubble.brick'
  rubble_root_bricks['ajdc5dvnu677rnq2f7dajpfn6jj5s2u5n7mzkerr242vjmaffr3a-rubble']="$__rp_directory/$__rp_relative"

  rubble_root_short_ids['6jnhpyn5w3wwitaqh2zqkuf4onh5ubxnt62enzx626q4q4xetgfa-rubble']='6jnhpyn-rubble'
  rubble_root_names['6jnhpyn5w3wwitaqh2zqkuf4onh5ubxnt62enzx626q4q4xetgfa-rubble']='rubble'

  rubble_root_platforms['6jnhpyn5w3wwitaqh2zqkuf4onh5ubxnt62enzx626q4q4xetgfa-rubble']='x86_64-linux'

  __rp_relative='store/6j/nh/brk-6jnhpyn5w3wwitaqh2zqkuf4onh5ubxnt62enzx626q4q4xetgfa-rubble.brick'
  rubble_root_bricks['6jnhpyn5w3wwitaqh2zqkuf4onh5ubxnt62enzx626q4q4xetgfa-rubble']="$__rp_directory/$__rp_relative"

  declare -ga rubble_managed_paths=(

    '.github/workflows/rubble.yml'

    '.rubble/hooks'

    '.rubble/hooks/post-job.sh'

    '.rubble/hooks/post-release.sh'

    '.rubble/hooks/pre-job.sh'

    '.rubble/hooks/prepare-release.sh'

    '.rubble/publish.sh'

    '.rubble/release.sh'

    'rubble-generated'

    'rubble-generated/multi-422ko74/Dockerfile'

    'rubble-generated/multi-422ko74/authentication.sh'

    'rubble-generated/multi-422ko74/build-brick.sh'

    'rubble-generated/multi-422ko74/cleanup-auth.sh'

    'rubble-generated/multi-422ko74/github-actions-publish.sh'

    'rubble-generated/multi-422ko74/install-image.sh'

    'rubble-generated/multi-422ko74/lifecycle.sh'

    'rubble-generated/multi-422ko74/open-pipeline-auth.mjs'

    'rubble-generated/multi-422ko74/pipeline-auth.enc'

    'rubble-generated/multi-422ko74/prepare-image.sh'

    'rubble-generated/multi-422ko74/publish-library.sh'

    'rubble-generated/multi-422ko74/publish-release.mjs'

    'rubble-generated/multi-422ko74/publish-runtime.sh'

    'rubble-generated/multi-422ko74/release-inventory.txt'

    'rubble-generated/multi-422ko74/release-plan.sh'

    'rubble-generated/multi-422ko74/remote-auth.mjs'

    'rubble-generated/multi-422ko74/store/2n/gu/brk-2nguimja3ijn67ppduw4iymx3l63awsvfm3aeolh4huxhrtlelzq-xz.brick'

    'rubble-generated/multi-422ko74/store/2n/wj/brk-2nwjk6y7a53lxi3iwzujxebrd3wp45eqr2sdhyc2c6xolptn3p3q-gnu-tar.brick'

    'rubble-generated/multi-422ko74/store/2r/sa/brk-2rsatquz5uzw7dilqg64g74l2vtvruaziu5jjhpcqjhmi4rw2cbq-bzip2.brick'

    'rubble-generated/multi-422ko74/store/35/lu/brk-35lunc52cnmxhsxgrbztpvoejb6h2oewsxbihfsqsdo2bifm7kmq-perl.brick'

    'rubble-generated/multi-422ko74/store/3g/4w/brk-3g4wslkvcdeh4prfpoamkoxdrefgts365qssdt5hsdlvxrqmze7a-grep.brick'

    'rubble-generated/multi-422ko74/store/47/zo/brk-47zokkngsfutphq4c75jyibgp4htgwdbxcrgh5ufuwkgilcj7gyq-unzip.brick'

    'rubble-generated/multi-422ko74/store/4r/ml/brk-4rml266dvj3lfnykptfshuossktxpdkis26uwp2ebjffjlgcmmra-coreutils.brick'

    'rubble-generated/multi-422ko74/store/62/pd/brk-62pd2iqc5djuyptrefmfnoyqs2h7sixqjxbe4j7def3if3gwm2aa-m4.brick'

    'rubble-generated/multi-422ko74/store/6j/nh/brk-6jnhpyn5w3wwitaqh2zqkuf4onh5ubxnt62enzx626q4q4xetgfa-rubble.brick'

    'rubble-generated/multi-422ko74/store/6p/rv/brk-6prv4ap5h2cndbif6hlymbvxvg3p2g3qtpdl7vdmyiwyxxp65kfq-m4.brick'

    'rubble-generated/multi-422ko74/store/6v/64/brk-6v64oxmhrixfku2kgw6taolvksk3cur6mm3anu6lhbjirbgfggxa-gzip.brick'

    'rubble-generated/multi-422ko74/store/7g/ai/brk-7gaiswvomctprmbv5i6dhxav3urpsmceezmwy52qv42yok44lygq-bash.brick'

    'rubble-generated/multi-422ko74/store/7n/gd/brk-7ngde34g6fsmdbt57au7543vtzv75pt7ff3xnmx5a6oubzevfoba-glibc-runtime-support.brick'

    'rubble-generated/multi-422ko74/store/7t/7h/brk-7t7hvndnqng7fsb5phlfjcn7fnp2t53gucm7iaoownjbavgdimha-xz.brick'

    'rubble-generated/multi-422ko74/store/ab/ax/brk-abax7ryl2uma2r3kh4v4srra3jnisjuuivmrvttb2cg35q7lrdgq-gpatch.brick'

    'rubble-generated/multi-422ko74/store/aj/dc/brk-ajdc5dvnu677rnq2f7dajpfn6jj5s2u5n7mzkerr242vjmaffr3a-rubble.brick'

    'rubble-generated/multi-422ko74/store/ca/tp/brk-catpfdrg7xd6pcsylgw2dzmolmqrqux6crkx64inuc42ioy4szfa-findutils.brick'

    'rubble-generated/multi-422ko74/store/cw/qg/brk-cwqgfsd3etn6cjqpyys6jv6v3xtif5qovlpujqolrd6kwhnevi5a-rubble-elf-runtime.brick'

    'rubble-generated/multi-422ko74/store/d4/oa/brk-d4oam742ndjdswucg5txv67tvctcjxom6yt2e26fii37al2wmzra-gawk.brick'

    'rubble-generated/multi-422ko74/store/eb/zn/brk-ebznmwxxmhegjnbtc25szhhelhtux4cplgjscwjux4zxx7eekxea-diffutils.brick'

    'rubble-generated/multi-422ko74/store/ev/cm/brk-evcmryzqpefcunpqoyutqjscwvwtbvogsntb5n47lbpuaohw6m6q-gcc.brick'

    'rubble-generated/multi-422ko74/store/ex/gd/brk-exgdn46eagyxc5npgu2ktpyluirdd44myaua6gnfodk5ei35shxq-gnu-sed.brick'

    'rubble-generated/multi-422ko74/store/f4/kc/brk-f4kctu2x45xjvktknpp7soicl6epvx5dy4vtdrxagpbkhp44rkaa-bun-1.4.3.brick'

    'rubble-generated/multi-422ko74/store/fd/jo/brk-fdjot6csltdy7pfpendap6yybjo5niybzp6knbofokgq7mxbz6kq-curl.brick'

    'rubble-generated/multi-422ko74/store/i7/om/brk-i7omhhjzayh7bxlnhyvcs4274b2uaunsyh76pixjh7ixvnpcrp2a-bison.brick'

    'rubble-generated/multi-422ko74/store/jx/55/brk-jx55n3p7uiv65atde62sfdnrktfey2co5qtqasgnglrc4qytpgtq-gzip.brick'

    'rubble-generated/multi-422ko74/store/k5/za/brk-k5zazg3iqlzgpeegvrj4ovmwfucggksuxzbuhl6kyduei2qq4xuq-gnu-make.brick'

    'rubble-generated/multi-422ko74/store/kl/zk/brk-klzkfeewgdals54pcgp3sytbcfc46yua4g3vq23ijqq4cou4almq-diffutils.brick'

    'rubble-generated/multi-422ko74/store/ks/s6/brk-kss6ejcy6cuctp6chi5snjxtw3wmrkdee4rorg3y3x227hqdxe4a-rubble-elf-runtime.brick'

    'rubble-generated/multi-422ko74/store/l4/jt/brk-l4jt55j5qqsfscqsfwk2ckk7iyj2hrv2kjpqf66rjw3ilg2psx7q-grep.brick'

    'rubble-generated/multi-422ko74/store/mb/g4/brk-mbg4lwvhanztnjrvjyh36j4j7ojysmtv2cjoshzw6xj5dzztiluq-unzip.brick'

    'rubble-generated/multi-422ko74/store/mg/7b/brk-mg7bty4vjnnybn7lxd3p5q2g2hgzp6szy5r5j3r3u5n6irldveoa-gnu-sed.brick'

    'rubble-generated/multi-422ko74/store/mv/w4/brk-mvw4balnruevggsruaxcd7m3dye6dlbrsjshobcplnic3svvd4rq-ld-musl.so.brick'

    'rubble-generated/multi-422ko74/store/n7/qb/brk-n7qbevbly56oq5vdzjm2bzhl77wjewdp4k5gmoimlbiv62nbv7pa-bash.brick'

    'rubble-generated/multi-422ko74/store/nf/vs/brk-nfvskclt3cgimqtrw2eazstdf454q3p2r7hoevkjczb56ozzmtpq-gpatch.brick'

    'rubble-generated/multi-422ko74/store/np/t4/brk-npt4pmjgvneqxtb3xvqge7ptntgjmjfz6vkendkmbfzspxpabvia-bzip2.brick'

    'rubble-generated/multi-422ko74/store/nx/7a/brk-nx7a5qmymqncddkt6verfvnhlg64g2q2iupe3xoh2pianzay2ela-gawk.brick'

    'rubble-generated/multi-422ko74/store/ny/xv/brk-nyxvd2fuotdmxjktenzudif5x5zq2d5ohtbciy4t5ztyf7b7x2fq-ca-certificates.pem.brick'

    'rubble-generated/multi-422ko74/store/ov/g7/brk-ovg7cu6kkazcpj32mrk53yc3kb2z2mrl4yd5yzrj3uytgwcanawa-curl.brick'

    'rubble-generated/multi-422ko74/store/ps/mh/brk-psmhk3rswggelskf3qvnkd7itd3bwmik75jdyyje4nh7jdmi3j4q-bootstrap-env.brick'

    'rubble-generated/multi-422ko74/store/r2/ag/brk-r2agl7x5h3nujgwasxf2d2vcopngkncwb6ronredz5n7o6va5s3a-coreutils.brick'

    'rubble-generated/multi-422ko74/store/re/6w/brk-re6wlad2vnmfnf4nrcravillaiaut6pzebyaadwgkkgh5g7tuvka-git.brick'

    'rubble-generated/multi-422ko74/store/rw/ce/brk-rwceoiocqfcgioh4rb3u5w5k2kie6ntmoie2c3bwv6yexxrfgkxq-perl.brick'

    'rubble-generated/multi-422ko74/store/sc/ly/brk-sclybv3wsmgo7lnvjs4ywxykwvbpkwzeezn3l3sbg4f6xpksw63a-zstd.brick'

    'rubble-generated/multi-422ko74/store/sr/o2/brk-sro23mxtsmdqo6q6qnqjxue3aqpsmh44eskp6ftagjfnkxrfewuq-bison.brick'

    'rubble-generated/multi-422ko74/store/sz/7s/brk-sz7scme2he4n477gpccq6kdizt6dbkntlfh3ddo67dypl7ksxtda-gnu-make.brick'

    'rubble-generated/multi-422ko74/store/t4/s5/brk-t4s5x7vx7ortfirmkczsv7ajjipmwf5sbggptpzkx6sude7mdweq-gcc.brick'

    'rubble-generated/multi-422ko74/store/u6/gp/brk-u6gpy6gfub4xlqrvjvqq4dtfafufxauxuste7lkmoc6vvpkuzp2q-gnu-tar.brick'

    'rubble-generated/multi-422ko74/store/vf/th/brk-vfthpdhrrixmo7ewqosxes2hbagrr4iuhtp3x5ax4vrohm65ynba-bootstrap-env.brick'

    'rubble-generated/multi-422ko74/store/vg/lf/brk-vglfgcy37uamsfveaktm245pbgrv7l4hyq2ea46ttxagtpeoucpq-bun-1.4.3.brick'

    'rubble-generated/multi-422ko74/store/vj/xl/brk-vjxlzrn6lje7peb2wiyior57it6egawfge3hoos2ctnlggkofvra-zstd.brick'

    'rubble-generated/multi-422ko74/store/wx/bp/brk-wxbpprly4rrpd6sqhki7cdf6pwaau5axfok4bzaehx2hpdvsudlq-git.brick'

    'rubble-generated/multi-422ko74/store/xu/sx/brk-xusxkpuh7w545vzs7pihbqmmndx52nymd5tqatmphbfm3l4zkziq-findutils.brick'

    'rubble-generated/multi-422ko74/store/z3/xh/brk-z3xhjdr5it75lq5iwals4toaklhutksbdphbucgwhtgqhxz32k6q-ld-musl.so.brick'

    'rubble-generated/multi-422ko74/store/zc/wd/brk-zcwdi25y3x7przyuhrgamgk3zvpum44ipsw2e4kvyyp5xkh47ifq-glibc-runtime-support.brick'

    'rubble-generated/multi-422ko74/store/zj/i5/brk-zji5om2su2ddkysxsg3xzzbvx7uvgespdsko7wze2bovygtgnuzq-ca-certificates.pem.brick'

  )
  declare -ga rubble_publish_push_options=() rubble_publish_return_args=()
  __rp_original="$(rubble_git rubble_publish_config rev-parse --verify 'HEAD^{commit}')" || return $?
  __rp_reference="$(rubble_git rubble_publish_config rev-parse --symbolic-full-name HEAD)" || return $?
  if [[ "$__rp_reference" == refs/heads/* ]]; then
    rubble_publish_return_args=(-- "${__rp_reference#refs/heads/}")
  else
    rubble_publish_return_args=(--detach -- "$__rp_original")
  fi
}
_rubble_publish_initialize "$@"