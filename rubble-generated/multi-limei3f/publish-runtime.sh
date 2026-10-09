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
  rubble_publish_config[plan_id]='multi-limei3fwurpsoguq26f3qxmcn2vahvnjsiwguuieys5ipvuhn3bq'
  rubble_publish_config[pipeline_id]='501cb4f4-a9d6-4dd4-adfe-9d2c25d010d9'
  rubble_publish_config[suggested_branch]="runs/${rubble_publish_config[pipeline_id]}"
  rubble_publish_config[commit_message]="Run Rubble workflow for ${rubble_publish_config[plan_id]}"
  rubble_publish_config[remote_store]='default'
  rubble_publish_config[plan_title]='2 bricks: x86_64-linux-sdw7yo6-rubble, aarch64-linux-azziirp-rubble'
  rubble_publish_config[generated_root]='rubble-generated/multi-limei3f'
  __rp_relative='remote-auth.mjs'
  rubble_publish_config[remote_auth]="$__rp_directory/$__rp_relative"
  __rp_relative='../../.rubble/publish.sh'
  rubble_publish_config[user_script]="$__rp_directory/$__rp_relative"
  __rp_relative='.'
  rubble_publish_config[payload]="$(builtin cd -- "$__rp_directory/$__rp_relative" && builtin pwd)" || return $?
  declare -ga rubble_roots=(

    'sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble'

    'azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble'

  )
  declare -gA rubble_root_short_ids=() rubble_root_names=() rubble_root_platforms=() rubble_root_bricks=()

  rubble_root_short_ids['sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble']='sdw7yo6-rubble'
  rubble_root_names['sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble']='rubble'

  rubble_root_platforms['sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble']='x86_64-linux'

  __rp_relative='store/sd/w7/brk-sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble.brick'
  rubble_root_bricks['sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble']="$__rp_directory/$__rp_relative"

  rubble_root_short_ids['azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble']='azziirp-rubble'
  rubble_root_names['azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble']='rubble'

  rubble_root_platforms['azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble']='aarch64-linux'

  __rp_relative='store/az/zi/brk-azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble.brick'
  rubble_root_bricks['azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble']="$__rp_directory/$__rp_relative"

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

    'rubble-generated/multi-limei3f/Dockerfile'

    'rubble-generated/multi-limei3f/authentication.sh'

    'rubble-generated/multi-limei3f/build-brick.sh'

    'rubble-generated/multi-limei3f/cleanup-auth.sh'

    'rubble-generated/multi-limei3f/github-actions-publish.sh'

    'rubble-generated/multi-limei3f/install-image.sh'

    'rubble-generated/multi-limei3f/lifecycle.sh'

    'rubble-generated/multi-limei3f/open-pipeline-auth.mjs'

    'rubble-generated/multi-limei3f/pipeline-auth.enc'

    'rubble-generated/multi-limei3f/prepare-image.sh'

    'rubble-generated/multi-limei3f/publish-library.sh'

    'rubble-generated/multi-limei3f/publish-release.mjs'

    'rubble-generated/multi-limei3f/publish-runtime.sh'

    'rubble-generated/multi-limei3f/release-inventory.txt'

    'rubble-generated/multi-limei3f/release-plan.sh'

    'rubble-generated/multi-limei3f/remote-auth.mjs'

    'rubble-generated/multi-limei3f/store/2k/rb/brk-2krbwasdoc6c4z33nejq23ttapdik5szjed24s65ouy5mxviosdq-rubble-elf-runtime.brick'

    'rubble-generated/multi-limei3f/store/2x/aq/brk-2xaqevxoue23okhcyevnonaeyau647anq5qe4nd272iofalgp2ya-xz.brick'

    'rubble-generated/multi-limei3f/store/3h/qb/brk-3hqbd5my4lsezw5edxdjy7lnkixedhp7g2b7ximmx77pgqohveyq-coreutils.brick'

    'rubble-generated/multi-limei3f/store/46/xw/brk-46xwv4ctgwq2n2jt7ex4x7bsznc55f2z7yykja7yhdzegknpnkaq-findutils.brick'

    'rubble-generated/multi-limei3f/store/5f/ud/brk-5fudmucn3hvy3icb6e3k4a6cvdqzpewlgzjqfojsvrpkytuy5nna-zstd.brick'

    'rubble-generated/multi-limei3f/store/65/xn/brk-65xn763kfhf7ye2ax5rr3hjotrij3qjagkddvfhqarwrt2a7mnha-ld-musl.so.brick'

    'rubble-generated/multi-limei3f/store/6a/re/brk-6areo7hfvce3oyvinqgwiubiidhaf3ibtu674cgk3nkt7kw2tywa-gcc.brick'

    'rubble-generated/multi-limei3f/store/7q/4l/brk-7q4ljuzbhcvgmwtdlgcqloabbwtmonqipwuxkpv7kej5e5bung2a-m4.brick'

    'rubble-generated/multi-limei3f/store/a6/uz/brk-a6uzfq4xc5o7bs5l4bv2dqotrldkrqvw56woauy3hxekzxzj64dq-perl.brick'

    'rubble-generated/multi-limei3f/store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

    'rubble-generated/multi-limei3f/store/am/qc/brk-amqckkhxkcqzeshkrzwtpd5ny2nhtivvgoh33f2lpnviovscyrkq-bison.brick'

    'rubble-generated/multi-limei3f/store/az/zi/brk-azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble.brick'

    'rubble-generated/multi-limei3f/store/bg/yp/brk-bgypnnermvrmj657kbamz6dhvtc7ic743c3tlooizg54udk3ocka-curl.brick'

    'rubble-generated/multi-limei3f/store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

    'rubble-generated/multi-limei3f/store/cd/dm/brk-cddmxlrjnyk4c4674ocfikhwnpqfj3kab7ke3lzcwiubazae7vra-diffutils.brick'

    'rubble-generated/multi-limei3f/store/cr/nw/brk-crnwqzb6rvjywhycjdmnlxwfinfzgr2nqpfu4o5xxvn7n55lmqva-xz.brick'

    'rubble-generated/multi-limei3f/store/dc/fo/brk-dcfonqabj4jd3dagsbk255cb7kxxytkebvc4yq7t6ts3c2qqsoma-bun-1.4.2.brick'

    'rubble-generated/multi-limei3f/store/dg/fg/brk-dgfg3arw3up6lbm5g4sarffhzl2gc4nlqp4inr4ry74xdwbabp7q-gnu-tar.brick'

    'rubble-generated/multi-limei3f/store/du/so/brk-dusoct55bmpgvm2ldpmeths6hggdhr33vyflycel7kjgjw3ts6ha-ca-certificates.pem.brick'

    'rubble-generated/multi-limei3f/store/eo/2o/brk-eo2opoxn4hmzc3qxtlydlbszxwcv7gibdkulpfmkfziybocjbeba-gnu-make.brick'

    'rubble-generated/multi-limei3f/store/ey/hj/brk-eyhj3p4imbapumokkpl7wjkijfuhzw22wnkvzm4qnngbrqw6gzga-glibc-runtime-support.brick'

    'rubble-generated/multi-limei3f/store/f6/a7/brk-f6a7sajqali7f47k3swxnxmsq3peovl5ykpvzt33zpf5t52t6g5a-gnu-make.brick'

    'rubble-generated/multi-limei3f/store/fc/6s/brk-fc6scnw3v4skjlzaemleq3stlcqba3ppvs7n453zymkdiexbucwa-bun-1.4.2.brick'

    'rubble-generated/multi-limei3f/store/fx/ry/brk-fxryxn436wjuxw65ie7fbuhrasf7o4qinnx6ahmezla4gx52hboq-bzip2.brick'

    'rubble-generated/multi-limei3f/store/fx/wo/brk-fxwo6gh42pwxkmohkpzzx7epy4c7sqp5nb7wdjn37xjoexk72qva-glibc-runtime-support.brick'

    'rubble-generated/multi-limei3f/store/gh/7s/brk-gh7s5ubsyy5hq7tz2nxnqk63nkltvxmgsmqvaiz7dflj2bthgxgq-unzip.brick'

    'rubble-generated/multi-limei3f/store/gm/62/brk-gm62dcc7oanvf6pvef6m5lcyzxdbp5b3qe57rb3js7sss4vukjka-gpatch.brick'

    'rubble-generated/multi-limei3f/store/gn/tb/brk-gntbxyq2xxjk3o5toyw47h7binmliq5w22u4zs72wxnxcpern7la-perl.brick'

    'rubble-generated/multi-limei3f/store/is/qs/brk-isqs4s7jt5knyrl7rm3ynm2n7ct37bn22zwmfmz7jkw3dhdezhwa-coreutils.brick'

    'rubble-generated/multi-limei3f/store/ja/nu/brk-januf7wm3extpkf3foovevbxyhxkwu2dgvlag6z2ptfeqex2nttq-gnu-tar.brick'

    'rubble-generated/multi-limei3f/store/mc/eh/brk-mcehjsnd6c44hkh6aybb3fcusdfxwcu2mmzmhuyvhg6qhec5yapa-gpatch.brick'

    'rubble-generated/multi-limei3f/store/mh/sb/brk-mhsbjq6wbipec4zus2wvgplxt2yl4q25natgh2c6k625ywz6o4ta-git.brick'

    'rubble-generated/multi-limei3f/store/mn/tw/brk-mntwl3ijgyyni3rz7tnm25uavccs64wnoqxi6tswq6v3v4enc4bq-gzip.brick'

    'rubble-generated/multi-limei3f/store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

    'rubble-generated/multi-limei3f/store/nq/to/brk-nqtotecghxwzh3rn6cj4syyu3ary6z7gvpommrcygayky7yerbiq-m4.brick'

    'rubble-generated/multi-limei3f/store/ny/m5/brk-nym5rumztuo443j6jodlaz243b7rifksbzmicvlqaageqnfrppva-grep.brick'

    'rubble-generated/multi-limei3f/store/o7/cz/brk-o7czghgecqaqhg2yqjwcdbzkpzbu5rtk6sambsubjyzpedg5bskq-diffutils.brick'

    'rubble-generated/multi-limei3f/store/qh/rz/brk-qhrzxrzpshk7wssuicwdv5uyvtrlzx2zi373o7esjgbpedtcmtnq-bootstrap-env.brick'

    'rubble-generated/multi-limei3f/store/qs/xv/brk-qsxvdk3agpg6ikdoivzkz2bs2aqqxoyjclqwdbl7vrkse363dofq-gawk.brick'

    'rubble-generated/multi-limei3f/store/ra/4g/brk-ra4gv7ib6y4ulchvtczh5wnhli33mvem74j54eapirukl5af5twq-findutils.brick'

    'rubble-generated/multi-limei3f/store/rr/hx/brk-rrhxxra6xutre4dcfvy2p6qwehi5jcv5wpzsy56cuav2r7fdov2a-bootstrap-env.brick'

    'rubble-generated/multi-limei3f/store/s7/pe/brk-s7pepykzvm4rodcuz2lqdnnti25ivmyn6hvaualljcja4pmqrjkq-gawk.brick'

    'rubble-generated/multi-limei3f/store/sd/w7/brk-sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble.brick'

    'rubble-generated/multi-limei3f/store/t7/bv/brk-t7bvgar26dma4k36sqzty54u7xkqkr4kmrzxvtppvl74ckyuypwa-gcc.brick'

    'rubble-generated/multi-limei3f/store/tv/nr/brk-tvnruh4farfdymxw4stifghd6gpm6absnwfi3ys2slpz3hj2diwq-bzip2.brick'

    'rubble-generated/multi-limei3f/store/v4/3b/brk-v43bd3czplropwap7voojb6bv3uw6cx5nbhblbnpod5rkxjhuebq-gnu-sed.brick'

    'rubble-generated/multi-limei3f/store/vc/z7/brk-vcz7e4ij2tgurzqbobaw2ij2k3eayjbgc6vdglinxqcdcle6urma-git.brick'

    'rubble-generated/multi-limei3f/store/vd/fc/brk-vdfcpqjosulvutdbkkg6j2dd4y3np4gyyzgcgn76q4ereaajq4yq-rubble-elf-runtime.brick'

    'rubble-generated/multi-limei3f/store/wk/vm/brk-wkvmcan7p2iuhnys5jhmvjhwje2gexvx37ept4kun7td6dt2jp4q-grep.brick'

    'rubble-generated/multi-limei3f/store/xb/bg/brk-xbbg4ulvsd2dh6qx5bzoguv2tlozc36v62to7h5grf6pfblx75ta-bison.brick'

    'rubble-generated/multi-limei3f/store/ye/cb/brk-yecbppbe2hram3gythftkgn6mwelxq6l42vejdrjy3czbotcwmoq-bash.brick'

    'rubble-generated/multi-limei3f/store/yj/p2/brk-yjp24zdh4gi64ec4qz232quwujkbijecntx37fvj5spvlkuqvn2a-gzip.brick'

    'rubble-generated/multi-limei3f/store/yl/jj/brk-yljjczaoyyqoq3m3kpsb4qnstspo3tycxc2fpba2gy4nc6ce65jq-zstd.brick'

    'rubble-generated/multi-limei3f/store/zb/oo/brk-zboovzrp3boiy63gwm32ibubobt4wvehbe4rt4yqzftypyvxetla-unzip.brick'

    'rubble-generated/multi-limei3f/store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

    'rubble-generated/multi-limei3f/store/zs/in/brk-zsinhazapn2veaih52jxuezaslxcjtrt6nafubyxjqz3joee57ca-gnu-sed.brick'

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