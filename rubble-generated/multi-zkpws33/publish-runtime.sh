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
  rubble_publish_config[plan_id]='multi-zkpws33l2iioh2ar2ni6wepvdms6rockyeegmlpeqhm3dwg5j4bq'
  rubble_publish_config[pipeline_id]='f7988569-1e59-4d87-b2ed-7a346255dd5d'
  rubble_publish_config[suggested_branch]="runs/${rubble_publish_config[pipeline_id]}"
  rubble_publish_config[commit_message]="Run Rubble workflow for ${rubble_publish_config[plan_id]}"
  rubble_publish_config[remote_store]='default'
  rubble_publish_config[plan_title]='2 bricks: x86_64-linux-z6izgfd-rubble, aarch64-linux-lhmjc36-rubble'
  rubble_publish_config[generated_root]='rubble-generated/multi-zkpws33'
  __rp_relative='remote-auth.mjs'
  rubble_publish_config[remote_auth]="$__rp_directory/$__rp_relative"
  __rp_relative='../../.rubble/publish.sh'
  rubble_publish_config[user_script]="$__rp_directory/$__rp_relative"
  __rp_relative='.'
  rubble_publish_config[payload]="$(builtin cd -- "$__rp_directory/$__rp_relative" && builtin pwd)" || return $?
  declare -ga rubble_roots=(

    'z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble'

    'lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble'

  )
  declare -gA rubble_root_short_ids=() rubble_root_names=() rubble_root_platforms=() rubble_root_bricks=()

  rubble_root_short_ids['z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble']='z6izgfd-rubble'
  rubble_root_names['z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble']='rubble'

  rubble_root_platforms['z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble']='x86_64-linux'

  __rp_relative='store/z6/iz/brk-z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble.brick'
  rubble_root_bricks['z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble']="$__rp_directory/$__rp_relative"

  rubble_root_short_ids['lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble']='lhmjc36-rubble'
  rubble_root_names['lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble']='rubble'

  rubble_root_platforms['lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble']='aarch64-linux'

  __rp_relative='store/lh/mj/brk-lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble.brick'
  rubble_root_bricks['lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble']="$__rp_directory/$__rp_relative"

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

    'rubble-generated/multi-zkpws33/Dockerfile'

    'rubble-generated/multi-zkpws33/authentication.sh'

    'rubble-generated/multi-zkpws33/build-brick.sh'

    'rubble-generated/multi-zkpws33/cleanup-auth.sh'

    'rubble-generated/multi-zkpws33/github-actions-publish.sh'

    'rubble-generated/multi-zkpws33/install-image.sh'

    'rubble-generated/multi-zkpws33/lifecycle.sh'

    'rubble-generated/multi-zkpws33/open-pipeline-auth.mjs'

    'rubble-generated/multi-zkpws33/pipeline-auth.enc'

    'rubble-generated/multi-zkpws33/prepare-image.sh'

    'rubble-generated/multi-zkpws33/publish-library.sh'

    'rubble-generated/multi-zkpws33/publish-release.mjs'

    'rubble-generated/multi-zkpws33/publish-runtime.sh'

    'rubble-generated/multi-zkpws33/release-inventory.txt'

    'rubble-generated/multi-zkpws33/release-plan.sh'

    'rubble-generated/multi-zkpws33/remote-auth.mjs'

    'rubble-generated/multi-zkpws33/store/26/us/brk-26usdrtsxslcuk33dt6uqeasrdrbu32fnsrtmbpilsslh5da6jgq-xz-libs-5.8.4-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/2b/fw/brk-2bfwkovamqlgqawc2obxigc4yho4jgx6rrkc6tyhubog5tm2vhxa-nghttp2-libs-1.69.0-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/2b/to/brk-2btooo6cnofph3xjrdgy2dezt4y4xl47ygmhqslj24ropfoiscdq-bun-linux-aarch64.zip.brick'

    'rubble-generated/multi-zkpws33/store/2g/mb/brk-2gmbwm7hmynv7bo7toieqvwfon7d47sb5peqrimgmeapxwoeazla-zlib-1.4-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/2i/fu/brk-2ifucdhxoflj6anntvfsnjg5untghnzjvplj47aodaqkqpenxzyq-ca-certificates.pem.brick'

    'rubble-generated/multi-zkpws33/store/2k/he/brk-2khe7fyham7ciybnkxksiegiv56edsph55lu6pvdrik6sznbr3sa-libitm1_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/2z/yl/brk-2zylpggqvy5wrqoxp22pstx4hls2mcr4otvvtmov5ghmw4hoz7za-zlib-1.3.2-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/3b/hy/brk-3bhyjm33b3codfx4vlt4zk5ozqks4wxkaozst2xbhyy56xfrz6mq-rust-toolchain.brick'

    'rubble-generated/multi-zkpws33/store/3b/lb/brk-3blbc3vt3hw6l2yenxtxlwpfnv7432fvq4xhhkr7lbtpk7msi3pq-readline-8.2.13-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/3c/ou/brk-3cou2u4ds3iqapzjdir62kttkskmxtfz2sf36c65kpi4iby3mikq-RubbleR.git.partial.brick'

    'rubble-generated/multi-zkpws33/store/3e/xo/brk-3exo4yvcmu45p6oevi6u6v7fkppbt2fohg5gpkfvwhjykut7m3wa-linux-headers-6.6-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/3i/sl/brk-3isljfsdiufidx6nanfu323k7zozw2mkua3ht56d2dlnq6eideca-libisl23_0.27-1_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/3i/tp/brk-3itpn4hq7kjvnuxsklwvxmqulmmwqbhfai2uzpt6c4mikdvwveqa-RubbleR.git.brick'

    'rubble-generated/multi-zkpws33/store/3l/oj/brk-3lojfc4csi3u4upmameltz6l45ti2jk5uiw2rnf2ui7g7z523odq-libssl3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/3l/wx/brk-3lwxgkj4bfhbzzcj2f4ouooyvkjr2hnt4bixwahhr3jmry6lnmwq-libc6-dev_2.41-12_deb13u3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/3n/3b/brk-3n3bc5ncagillpn2mz3jicaeyjvq6myp5b2prh2kn6tllwded3qa-libgcc-s1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/3o/ot/brk-3oothg4a44icdojzlibmxrxhn2xs6hase67u2pgy4z77l7gj6kgq-libjansson4_2.14-2_b3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/3p/wy/brk-3pwyzin2s6znyulfwpta6mbiky3ksdwnmvi4k4oblrddcyccpbkq-libbinutils_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/3r/g7/brk-3rg7zno4crltlhtuwp3k5izvvdj2c6smqkw74ebwsrfv2o6grtna-libsframe1_2.44-3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/3w/m4/brk-3wm4cdhbw7rufcah5dges6g3jzapjyjpwtravjh5rclsluy3vgaq-coreutils.brick'

    'rubble-generated/multi-zkpws33/store/45/pp/brk-45ppndjvm7i5beghuemci3wjwojeswmc65z3ev4qumk53rap4l7q-python3-3.12.16-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/46/u6/brk-46u6btbnqkhim377u2w54og4tf7ipfdazvg3ezdcoxmyzbn64lca-gnu-tar.brick'

    'rubble-generated/multi-zkpws33/store/4a/kp/brk-4akp4e4shmwjpgpj3n6qt7t5wwhltqioq5nihepguyvtwn2gumaq-xz.brick'

    'rubble-generated/multi-zkpws33/store/4g/be/brk-4gbejr52ozzofmznelc52fgic4nsoasxjr6i4phtf6utztaoz6la-binutils-common_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/4j/zk/brk-4jzktrzy4eoujtgyb56yl2rwaffimfwk3g46kybwq5hl4khfnwra-rust-toolchain.brick'

    'rubble-generated/multi-zkpws33/store/4r/gc/brk-4rgcrtd62az4jvrpnqi7mo4lmi6jkafzaizl5renuatipxrg3soa-libmpfr6_4.2.2-1_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/4u/ec/brk-4uecjax2lpo5idputrmq6yayy6admss7pdzmgzf6pwomzimzj3qa-unzip-6.0-r15.apk.brick'

    'rubble-generated/multi-zkpws33/store/4x/2u/brk-4x2uexqjoqs5unyb4fxpdus3ctebmhvqnuruhalsl5rdwt3k6naa-rubble-canonical-script.brick'

    'rubble-generated/multi-zkpws33/store/5c/l2/brk-5cl2d3x6sk6fpzz2vyvzamieqdptlqxbsijlye75apvhdjupzhfq-libgomp1_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/5f/6h/brk-5f6h42fvytrovpiqc6uef6hb35eujabalgjpgxeksmjvoxwthtca-wasm-pack-v0.15.0-aarch64-unknown-linux-musl.tar.gz.brick'

    'rubble-generated/multi-zkpws33/store/5f/k2/brk-5fk2gsc2wvpikazwv7m2r2tymf23xnulpwld5ai2csmdkmwetqaa-m4.brick'

    'rubble-generated/multi-zkpws33/store/5r/ra/brk-5rraxdt2uqvx2std4xg5yfcftcbtxsv276bkqau34ywi26ngkn5a-rubble-deps-cache.brick'

    'rubble-generated/multi-zkpws33/store/5s/2g/brk-5s2guvzpcv5iov3rog7fjz2t5oa3idprxh4z7lst5ipo2mlpo2mq-binutils-x86-64-linux-gnu_2.44-3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/5t/d6/brk-5td6qvq3hkwnfc5vqh6lcuv5xlk5yh26d2esafb7byxkpwl6klua-gawk-5.3.1-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/5v/ex/brk-5vexncx3cian4rymupdaft3bwnvswvrzp6pcxohuilbll3lii53a-zstd-libs-1.5.6-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/5w/sm/brk-5wsmysbedc7wbcb22csq254i5hrsdbwpdwuzyi5seacce7a4iaoa-coreutils-sha512sum-9.5-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/5z/qz/brk-5zqzbtecxd2bwjpypfrcgfmzvuqihlmabhg5jtqztyhjc656maja-perl-5.40.4-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/6k/ut/brk-6kuteyw6z7uzh46i3kkxiy4skplazu3wicblj6iwgqoaldxr3caq-rubble-elf-runtime.brick'

    'rubble-generated/multi-zkpws33/store/6m/nz/brk-6mnzlup57yva4f25swep426asen4gktqclnqldiusl5pv2ejz22q-libasan8_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/6o/fb/brk-6ofbtcdyl2ncnjav3ntckdmw6efl7mfixfllsf2cs7377cl3pkkq-wasm-bindgen-0.2.130-aarch64-unknown-linux-gnu.tar.gz.brick'

    'rubble-generated/multi-zkpws33/store/6s/2s/brk-6s2slkwjetnkxspnsgj7j53skeupzwiedrcrjmtzhr3ydsuucjia-write-native-toolchain-env.brick'

    'rubble-generated/multi-zkpws33/store/6v/x2/brk-6vx2ce7jcj6wfra4xg2ykz6htsdkuvhh7uxbyr4gzlwvf2mlriua-rubble-src-checkout.brick'

    'rubble-generated/multi-zkpws33/store/6x/bc/brk-6xbcw7rsrgmctcyu25rzq64e42jggkhbuymzq2k4pfnyvv7a2hdq-write-exec-wrappers.brick'

    'rubble-generated/multi-zkpws33/store/6z/mh/brk-6zmhcrjjulman5kyc7bpb42rsiitpcozznio6a43um52iu6yr7jq-nodejs-runtime.brick'

    'rubble-generated/multi-zkpws33/store/76/la/brk-76lao3bnpein6f4ggp4dwci7cdyywjnb5i7by4forhkbzf6lju6a-wasm-pack-0.15.0.brick'

    'rubble-generated/multi-zkpws33/store/77/pa/brk-77pafwgzhgk3kbtyd3i5bnikedwfoif6mfaibfesmfc655t35naq-libpsl-0.21.5-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/7b/5q/brk-7b5qkq7h725rlzwyjms32eiu6becwobfozmdtl3nmob3t75vmiuq-liblsan0_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/7b/uu/brk-7buusvdtjbv3krfq34tglkiqz2x356bf2xwow5pmosrsliurop6a-libubsan1_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/7c/w7/brk-7cw7yzizlmml7slq3bpvzmdl3v3m3yi6w66fyairdsgoykvrtswa-bootstrap-env.brick'

    'rubble-generated/multi-zkpws33/store/7e/gy/brk-7egybthiifzaiwm62j7t2apybvwznrrwd5rsef5dsrhubj2qegfq-cargo-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/7g/ai/brk-7gaiswvomctprmbv5i6dhxav3urpsmceezmwy52qv42yok44lygq-bash.brick'

    'rubble-generated/multi-zkpws33/store/7g/wd/brk-7gwdsqgvkrl5q7ztjhu2z65wbjt2eywqrtwg7xc7jewdoolhnmea-acl-libs-2.3.2-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/7w/dy/brk-7wdydh7iziyaiskuhw2qb242fvaq4rin2kprwubf7fmvooc6iopa-git-2.47.3-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/a5/yl/brk-a5ylj46fppw54b2mlu7gsl74itcmmkg4u3wi3x7mzg2cyanyfaea-cargo-1.99.1-x86_64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/a7/yy/brk-a7yytixghyt2s63uxdft2bot7z5bpaqvjhhyrbwk5oek3j6whd2q-bzip2.brick'

    'rubble-generated/multi-zkpws33/store/ad/yk/brk-adykhpm55qerngmtx6ke7csou4r73gh5lnubblp7jj6ro4oeyxna-patch-2.7.6-r10.apk.brick'

    'rubble-generated/multi-zkpws33/store/ai/yr/brk-aiyroimpnp3yughgrvphjzh2bhwozk32bpze3k3y6uaeukdqjvzq-RubbleR.git.partial.brick'

    'rubble-generated/multi-zkpws33/store/b2/i5/brk-b2i5h3ipeqiico2oxqfkrpcrqndt5dys43nm7qrq5hh3e5n4gqpq-libtsan2_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/bd/t2/brk-bdt22o4d5bjqwz354evlyoovndjzdmd2rh6kmrs7iqzmis3i5viq-brotli-libs-1.1.1-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/bm/iz/brk-bmizlt5xdhghh2j45eu3hqfpshvmzoxr6vwe4oiowkuh7tldxm3q-gcc-glibc.brick'

    'rubble-generated/multi-zkpws33/store/bn/wq/brk-bnwqa6w363zd76l73ptm5u7wqthwzyxdygt5rnyztadje3hafe2a-perl.brick'

    'rubble-generated/multi-zkpws33/store/bp/yv/brk-bpyvwhm4bzve42im4kgvpmxekenmlobdxdyw65x5wz5yto3vpc3a-gzip.brick'

    'rubble-generated/multi-zkpws33/store/bq/qu/brk-bqqueq4hb5vdjgdpm5xn2bpxiay234jhkblmh6d2yjdmd2ncxb2q-libcrypto3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/bs/cz/brk-bsczck3itaibqqkhhwkkzdh3fv5i477527aika7gfcttdyn6chhq-libgcc-14.2.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/c2/7n/brk-c27nqfizbqju23t62gn5fz5at7aiszoc2jdo7rca33boiwj4rrwq-libctf0_2.44-3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/c2/db/brk-c2dbcqqoxhpuy4t5tk4nwlt5beuiii746wh6vaaeqsld525qldla-RubbleR.git.partial.brick'

    'rubble-generated/multi-zkpws33/store/c2/pb/brk-c2pb6bog4hbnzghhl2bdm4jrrqnq5e5oxiobkywqsl7p7igdtfva-libgcc-14-dev_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/cc/25/brk-cc25q3jglva6ayeaiegjq7f52i5fe3w3j2navr35izea4kmwayaq-brotli-libs-1.1.1-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/ch/ld/brk-chld5ubny35e2wbkytn4wmmjslik6k7l5x5lmqu4maumnlipe7fa-nodejs.brick'

    'rubble-generated/multi-zkpws33/store/ck/ep/brk-ckepgfvfy3zxo2mil6lzboslpe36a62fvqswiyx7jruzk4evsjrq-gcc.brick'

    'rubble-generated/multi-zkpws33/store/cm/da/brk-cmdaozrcvaymmdfw3jodg7rrc4qwmaqyx6q3jj6u6nsie32hvdxq-publish-output-directory.brick'

    'rubble-generated/multi-zkpws33/store/cn/su/brk-cnsuk57bulhj544m3skp3wwq4lsh5qegyneycg7bgfo2zzu5z7ua-coreutils-env-9.5-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/dd/z7/brk-ddz7gzhteocbfkby6xzsvpmk2hzgegwfi2stx2xcllrmqvobv6qq-cargo-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/de/fm/brk-defmfedonkfkblaqtfzjs7kvoq2u5k53xo3zzl43it7q634ax7ja-collect-shared-libraries.brick'

    'rubble-generated/multi-zkpws33/store/dh/zo/brk-dhzowymraqoa262lv45rzgrpjrqdedusoctmkao7qctbpck3qiva-patchelf.brick'

    'rubble-generated/multi-zkpws33/store/dk/ct/brk-dkctajvl2il4pypc32olxna3wh7rq2dnch3in6y6qkziz74prrka-zlib1g_1.3.dfsg_really1.3.1-1_b1_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/dk/tq/brk-dktqjk57lvhld37htakm5472rljxvc3dte5plieqdipyxzze6plq-gawk.brick'

    'rubble-generated/multi-zkpws33/store/ds/zq/brk-dszqoflekkm6ufunfjigc7qbqwgl3rezsz6y5upbarrv5rixdnjq-rubble-web-assets.brick'

    'rubble-generated/multi-zkpws33/store/dv/rl/brk-dvrllqig4vloxhgyjrmpzimbvdcatflu5xsgnfnhez77trxhzbaa-libcrypto3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/dx/bm/brk-dxbm5xbf7vkb35noka43so2duja6uw3kitmmhxbybcer6op5bcla-utmps-libs-0.1.2.3-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/e2/rz/brk-e2rzsmoh2ojatrlq7slkkltnt7z2aa2h6gmbt4gxrj5llbhymb5q-rubble-elf-runtime.brick'

    'rubble-generated/multi-zkpws33/store/e3/4p/brk-e34p6lvibc4y5cud27vutxqaoz6f7twpq5s2xbmem2nzejdzlgaq-linux-native-toolchain.brick'

    'rubble-generated/multi-zkpws33/store/e5/bi/brk-e5bidgxbvr5crgxvo3tckxld466txu5dxi674pplgncc4fifmkva-gdbm-1.24-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/e7/aw/brk-e7aw53vitgjqbosohujzxudnmbfqylyi27ehtmvbucoevvgocfoq-libsframe1_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ea/y2/brk-eay2yd76jtq2n72kafauwkofupanezwq2muobm7bjlf6mfojk4ma-linux-libc-dev_6.12.86-1_all.deb.brick'

    'rubble-generated/multi-zkpws33/store/ec/vm/brk-ecvmuhel6g64yeystzfd4xmmjjdqv4p3i57tedybq2ppazcnfvzq-zstd.brick'

    'rubble-generated/multi-zkpws33/store/ec/xk/brk-ecxkum7thkjwggmltz3jlz67amewczlvf6ybucueqawsamou6t4a-binutils-aarch64-linux-gnu_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ee/45/brk-ee45eyrziex6g7ajoch2fj62l3lh7kykt3ekkjf2obzr2athu3ka-glibc-runtime-support.brick'

    'rubble-generated/multi-zkpws33/store/eg/27/brk-eg27735m75zx7aqioqpvqjluaojdeh2kmtsizlotnmpyrir4dvcq-findutils.brick'

    'rubble-generated/multi-zkpws33/store/el/li/brk-elli4da2njhcv4aap6f2a6tueyezrnrnd7hist2qro34ttjryw5a-llvm-tools-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/em/on/brk-emonumondcre3b5pnxo4hp5dzwkoobjp7fi6ofxmqudceo4dxjnq-node-v22.22.3-linux-arm64.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/em/um/brk-emumr4qhmj3md4udqk36vvpcou3bcq2q6x47b2utro76mglanp6q-libffi-3.4.7-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/eo/66/brk-eo66u6nzusdktuggisxpvr7qmzxvwr4lxwlclvsre4irq6krhcoq-libstdc__6_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/es/h7/brk-esh7pawc46nsh5b2uuykm4qsjsoowbes5uu4nt2kcg6hocags6vq-coreutils-9.5-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

    'rubble-generated/multi-zkpws33/store/ev/ty/brk-evtymdmzbmwvbqahpv3jn3fct73m5qstjmh54f2o7msjks7krita-gcc-14-x86-64-linux-gnu_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ex/wh/brk-exwhj5vebfaduvvhd7f6xtppocqwgqam7csyi3u5434k3ypqofpq-libmpc3_1.3.1-1_b3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ez/by/brk-ezbyzyz64k4wf43cl2s55otq6rxpsgr6aopnefxba7bcqz2767ma-rust-std-1.99.1-wasm32-unknown-unknown.brick'

    'rubble-generated/multi-zkpws33/store/fa/qk/brk-faqk22fjqryqxjx6pkufmb2mttau3gwuv2qu6roi3d4melszcu7q-libunistring-1.2-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/fb/xg/brk-fbxgu4t24gr47iq2yhyaygays2hvcmyidx4tkwjmlx52pttyr6yq-libasan8_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/fc/jh/brk-fcjhtbtyxa5qk3xy5jhazosrdwgn6npaqbjmm7dmyoi756zrunca-normalize-python-runtime.brick'

    'rubble-generated/multi-zkpws33/store/fd/jo/brk-fdjot6csltdy7pfpendap6yybjo5niybzp6knbofokgq7mxbz6kq-curl.brick'

    'rubble-generated/multi-zkpws33/store/ff/pp/brk-ffppl4gr2kqvvmwgncrxlllkh6z47u6wpzeiyatswpebhvwpbvua-gzip.brick'

    'rubble-generated/multi-zkpws33/store/fg/32/brk-fg32tsmkrioagedunckpr37qz35rn4b7obxt3wsbxx56ajpxviza-mpc1-1.3.1-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/fq/ac/brk-fqacbxvzkp7aqbu5x5ibzixghwcxbmvzfqzhvgxdnq4tm7yoiavq-findutils.brick'

    'rubble-generated/multi-zkpws33/store/fu/4g/brk-fu4gjf2vujnnxzbws5i2w57yneqm7tmgiqzxodte6s6rf74vchrq-g__-14.2.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/fx/tn/brk-fxtnbjlqswwx7zuqjwvqf4azpgegrpm3fpcale6xlumvnhwvadya-rustc-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/fy/jv/brk-fyjvlznpum5cwh7apldb3sv4skrbahxa5uekyqo2eqwrcm2tzuxq-libatomic1_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/fz/so/brk-fzsocvqoawb6atzh5tfjxgahm2yualfjxwxicd55hjyf4gfjo5da-libstdc__-dev-14.2.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/g2/qq/brk-g2qqoxqlhdq4m5ptlml7rg4j2sjvm5kcal5xohzpvcxxpaxx63za-RubbleR.git.partial.brick'

    'rubble-generated/multi-zkpws33/store/g3/fx/brk-g3fxen4ug3f3g34imdsefwplwd3ulzn75tn5uxd5jqe7t23bzyna-bash-linux-aarch64.brick'

    'rubble-generated/multi-zkpws33/store/g4/eh/brk-g4ehuu5eohs4yqdiesnl7qhtyk5kmz2cewtuo2elevttzc3kmx7q-RubbleR.git.brick'

    'rubble-generated/multi-zkpws33/store/g5/r5/brk-g5r5a7z3ismvnzq5uwsre6sfoiprc6smte4xd4jcchttjjvqidtq-xz-5.8.4-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/g5/zs/brk-g5zshxvbu3styhzy6s7rga2yoofniwkfdlasmxfnt4jnls3bl3oq-gnu-make.brick'

    'rubble-generated/multi-zkpws33/store/ga/u6/brk-gau67xaz2jijhjiytsen5gewubskzpgz2u64ij32im7umuiqr6ja-bootstrap-env.brick'

    'rubble-generated/multi-zkpws33/store/gb/4d/brk-gb4dlxkuu36d4olrckbxrdwlkvocpv2amucqerzpih2nv5w3uxuq-libstdc__6_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/gg/we/brk-ggwemilbyiyu537xipp6admlfza4psuqbpstue2p5qx3negueica-rustc-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/gh/q4/brk-ghq46r5f4orvr6sszvuapmkyflimfvkwlb4hv3t3dsr4k4zwplta-unzip.brick'

    'rubble-generated/multi-zkpws33/store/gp/d7/brk-gpd75vrjncv57fv3fzdfuoagqwgyqjwuizvdth2pdg7hv2q4lv5a-rubble-script-shebang.brick'

    'rubble-generated/multi-zkpws33/store/gq/dq/brk-gqdqq5qyytt6qihsxtcwuxmg3qhdatvlrzzcciyuyu5xcrgtg6ma-bun-1.4.3.brick'

    'rubble-generated/multi-zkpws33/store/gw/gs/brk-gwgsfngkxcqjwumaewugzkfdt7v62iomled2lwur35muht72aeca-libcurl-8.14.1-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/hd/hi/brk-hdhimhaqn7bul5k67m2gmw4ea6xibuprz2mgla5obsjibs7tfnoa-make-4.4.1-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/hd/qx/brk-hdqxqr4vfc2rgc3rj5ywrpaykxqly77eix55tldf7wd7nqimpqfa-patchelf.brick'

    'rubble-generated/multi-zkpws33/store/hf/3l/brk-hf3lv5nokb6k6syr666pgjxoa57inppgaluc36pp5xrbs3qu7yia-python3.brick'

    'rubble-generated/multi-zkpws33/store/hi/gq/brk-higqpv2dmyiorfd43aypr6zeuad53wdrig2qr4q3zzgtlwhy42bq-gawk.brick'

    'rubble-generated/multi-zkpws33/store/hl/6d/brk-hl6djaj44qkp6rily6m7uf6lsksicuvyiukbsphwqzo7zhddpzna-zstd-libs-1.5.6-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/ho/55/brk-ho552ymbr5wqlkbb7xckcvqfjs5fd4ytbrf5rjp3vaqnwocxhx5q-gmp-6.3.0-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/hr/3g/brk-hr3gsmedt3iyx26xhety6rvbs2nzhv6o4oyscyt7qvuuixa7fbfa-libhwasan0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/hw/ud/brk-hwudtbqp6mtqd433zl777ixamegzf5s6pqjc3vbkw4yy7ca6rpzq-libstdc__-14.2.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/hy/7v/brk-hy7vvf7hx76tdededuy6vbt2zjw2rzd2papv6r7qm2m52vhchfna-libzstd1_1.5.7_dfsg-1_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/i3/vz/brk-i3vzwzq5ceekylzear5wrwz4teano37g32htjtcd4rma3zvjzz3a-libgmp10_6.3.0_dfsg-3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/i6/rp/brk-i6rpnovdyaumnm4dbmqheqhnimae5nyro5b25ewahcsz4tksxefq-mpdecimal-4.0.0-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/ic/c3/brk-icc3vbhzlb7dmz7zkp5cddgyeoy5jt5ykkhg6oy6nall6z2sna6a-pcre2-10.43-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/id/ub/brk-idubmhb4paho7zn732ctx2s57kvdnsus3b2cit6spi5j2ti5epza-rubble-web-node-modules.brick'

    'rubble-generated/multi-zkpws33/store/ih/kb/brk-ihkb436hgrr2ikz2jd4v5enxpqhklppqp6s5usbutl4q6fqxs3ja-g__-14-x86-64-linux-gnu_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/in/ak/brk-inakn65bjgy574fki4lz7ar4pgwugxvdjqqnierbkk3isic5spya-RubbleR.git.partial.brick'

    'rubble-generated/multi-zkpws33/store/in/kv/brk-inkvazg7bbj7b4uxzpkgnxsz2qhmoqwzmd35b3u7fi446jryzzfq-rust-web-wasm-toolchain.brick'

    'rubble-generated/multi-zkpws33/store/iq/ru/brk-iqruyywvdmkzsmzzmu7rmrnp6fqgg7e2na76j3ty3skevyvcbu4q-libquadmath0_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/is/xo/brk-isxo3o4skm7vtiqyhakx4x4uxrw7hnycm3ldwp43grskdhxl3qxq-sed-4.9-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/j6/az/brk-j6azokdcg4c72ggjyopfahoks5fxc5duku2fwhqxerrggqa4w4wq-rustc-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/j7/nd/brk-j7ndjrq7aixii7bqtdkm7kw7j6bkvkbekmoqefp3zaanznjiuitq-rust-std-1.99.1-wasm32-unknown-unknown.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/ja/26/brk-ja26s6rmlm22mwviv4hkae3mfkzkcq4tumc55qstm3p444zqmfzq-binaryen-117.brick'

    'rubble-generated/multi-zkpws33/store/ja/2g/brk-ja2gawpefozngsdbmzs5n2a66ujesjats2qcq7homnixclj6iqrq-grep-3.11-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/jd/tc/brk-jdtcafj4hys4txg5vxmtvui2dl5sovyb5lontwbsxlieat3mlila-libexpat-2.10.0-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/jo/mf/brk-jomf52m6ijsokfau3fyyvgd7elhgiiavaic5tzdw6lhugeziyhna-wasm-pack-0.15.0.brick'

    'rubble-generated/multi-zkpws33/store/jw/hf/brk-jwhfx26nkv24vmnfckbvccnpwdkzwfvxcjty7dhntghaemjlpfxq-mpfr4-4.2.1-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/k2/sq/brk-k2sq3ksyc4xg4n3byfvtc2xp2by5lw3uus2pjw4ro7y4ad54uo4q-coreutils-fmt-9.5-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/kc/xm/brk-kcxminepu2ywfwal6sveazxuz3b5emokjvaje5k6edxumr4ncr7q-c-ares-1.34.9-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/ke/tp/brk-ketpg52wdmoljath4lozmcgydwwkz4554ivzrzdnfo6blbdaan6a-wasm-bindgen-cli-0.2.130.brick'

    'rubble-generated/multi-zkpws33/store/kp/e7/brk-kpe7kma33nmt3mijbihbuzazuupuiq4ffqabvfgogzgs2rdp2rfa-libzstd1_1.5.7_dfsg-1_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/kq/oa/brk-kqoaqdowlcmrluolokiygo33evr47gordg5y3gqjf4etscxnee2a-libbz2-1.0.8-r6.apk.brick'

    'rubble-generated/multi-zkpws33/store/kr/tc/brk-krtc32gkhzcn3spc36a3ksbyjoykekcsx7bvmzj2mrxcmaxral2q-write-exec-wrappers.brick'

    'rubble-generated/multi-zkpws33/store/ks/6e/brk-ks6e3u26mzxm5dwrtt4v2y5z6hltzyyoqnn5v36ctpuvq3z5ebga-libgomp1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/kt/bd/brk-ktbdwi3xid4ywlz6il2qlgx67aclu2t5gljy527g7vdnv6h7gaha-jansson-2.14-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/l7/ht/brk-l7htuemjgonzrbgfwss2gd4oxktlvev5gqpeflfin3sibfx6gtrq-bison.brick'

    'rubble-generated/multi-zkpws33/store/lb/7v/brk-lb7vuv6w3fr43o73swpjgwfuwdhyi7l2xskuuisw3eaekunxv3ia-libc6-dev_2.41-12_deb13u3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/lh/mj/brk-lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble.brick'

    'rubble-generated/multi-zkpws33/store/li/qe/brk-liqeef25kxd6agiohfvzkme75fbbkq5cs5m7ojfifiv5y3jlosua-gpatch.brick'

    'rubble-generated/multi-zkpws33/store/lk/qd/brk-lkqdbkmu6cjb7dgotbfcy476dwa7lwntralw6tvnks4frn7y5uzq-rubble-web-node-modules.brick'

    'rubble-generated/multi-zkpws33/store/lm/bb/brk-lmbb6iujrwrlaoq65oxsi2yjh6qqs4focnkmlymfeshkdlzfosrq-unzip.brick'

    'rubble-generated/multi-zkpws33/store/lu/y4/brk-luy4bjnugq4iyxf653mduencnzaptaunhu4mph7pdata3houha5q-binutils-common_2.44-3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ly/d6/brk-lyd6koxcevhl2kkvyrgpauaaroebob4sbweio7ucqcnk5nihqgbq-rust-web-wasm-toolchain.brick'

    'rubble-generated/multi-zkpws33/store/m5/ln/brk-m5lnpllbzm555r5zuagxbaoqomumjvcwyoq7xdkffysmdvteelwa-findutils-4.10.0-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/ma/ce/brk-macey2arela2oh55r33f2l5eana2whlqb3bzvi5vlkzpmqumk5ea-rust-std-1.99.1-wasm32-unknown-unknown.brick'

    'rubble-generated/multi-zkpws33/store/mf/wk/brk-mfwkvtv3n6hvvrci2nxbilte5df2wpayqreolg3t5xnlwedydz2q-libmpfr6_4.2.2-1_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/mg/vp/brk-mgvpjsbz7sujl5qdndfmqhtclpxfhlytkeyidejyjfez5jloit7a-g__-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/mh/ux/brk-mhuxl3qogm466jjjfbxne7e5iun5rusy6qpp26aekt65vpamhjqa-gnu-make.brick'

    'rubble-generated/multi-zkpws33/store/mi/6o/brk-mi6ohmutnclicttozbnjjmgo5r6nutdophs5rgp6kru2gg7tqxqq-libunistring-1.2-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/mq/dn/brk-mqdngybmp7yej3tpsrxr3vm4epadyjafka5ojioijg4dcfip36pa-bison.brick'

    'rubble-generated/multi-zkpws33/store/mr/v3/brk-mrv3skvefohwhqxqk3loonbdoqonymgrvgcggyajysjlj44rvo6q-coreutils.brick'

    'rubble-generated/multi-zkpws33/store/n6/vt/brk-n6vtqu3bxkksa6hlrwirri6entermnuofp2sdqcfcrzxarqrr3hq-isl26-0.26-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/n7/qb/brk-n7qbevbly56oq5vdzjm2bzhl77wjewdp4k5gmoimlbiv62nbv7pa-bash.brick'

    'rubble-generated/multi-zkpws33/store/na/a2/brk-naa2ad3mxbwsl6syyyeikeu6srwar3mxn4lv6faf72kx6hjpq72q-libgomp-14.2.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/nc/3b/brk-nc3b5fnwrjhizdtqakhrmgkntigd7tkzddqwknxrlyxe6oalqhpa-m4.brick'

    'rubble-generated/multi-zkpws33/store/ng/2y/brk-ng2yhab3txqyfgtnrgwttzyliczkrx52jeu7skkoaxeu5d752ynq-libncursesw-6.5_p20241006-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/ng/fm/brk-ngfmqg7sdtevod5fupkehkz7ngg7lb4zc6hfheixgvduoprmea4a-libjansson4_2.14-2_b3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/nk/bc/brk-nkbc5fhuwgawyucceat7l2bt62mdkmrygtjkwf6uoayzdrenokvq-bun-linux-x64.zip.brick'

    'rubble-generated/multi-zkpws33/store/nq/ez/brk-nqezvr7gvu4qzj2ite3o6mk64b5foml47t6vrs2j37pggzdvnvgq-gnu-sed.brick'

    'rubble-generated/multi-zkpws33/store/nu/72/brk-nu72a7zrxgfiwzjx6xkvc7d3eorpvhltbyv6a3vxbwwuwkkhnguq-musl-1.2.5-r12.apk.brick'

    'rubble-generated/multi-zkpws33/store/nw/jn/brk-nwjntcya5bc7tfxrl5i22jo3v2rnlixwjc6ri3r4kwupxtwlaqsa-cpp-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/oc/a4/brk-oca4i4igup25hy7wsfzuzkug2rvvfu2h4d237d6syf33h4co2soq-write-native-toolchain-env.brick'

    'rubble-generated/multi-zkpws33/store/od/5x/brk-od5x4iwvfooy74347v2ihrwjcu4yxed2q26uphzbe43e54agaymq-rust-std-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/od/lz/brk-odlzblejigvixnek4zw3qpf6kdmpduizlfdol6phkrwrrltm3kdq-libc6_2.41-12_deb13u3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/oe/dx/brk-oedx42pgtkscsyrm2vn6hyrci7hw74ladlpu6f6bwgt5yguhmyqq-m4-1.4.19-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/og/3u/brk-og3uxejhmzd6gzyfx5ggid4dzkwzet7lsi5k7rhpxf5svupsrpva-diffutils.brick'

    'rubble-generated/multi-zkpws33/store/oh/zg/brk-ohzg3khe3y5zbg6it742hi63cwoz7k3vbr5jufkccupj4kcrkpwq-curl-linux-aarch64-musl-8.18.0.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/ov/g7/brk-ovg7cu6kkazcpj32mrk53yc3kb2z2mrl4yd5yzrj3uytgwcanawa-curl.brick'

    'rubble-generated/multi-zkpws33/store/ow/oy/brk-owoyhne4rlabd6ti2usbbxf5qm6px4edpaa2ixltmg55lde2ckuq-sqlite-libs-3.48.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/oy/e2/brk-oye2ypgxbkwk5tvdjf7e2cmrsr7ituchdudsw2znzjzrokjzx5fq-cargo-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/p4/37/brk-p437dghiaad2yb57qr2yhpsmwaw3z3jwfkdlsqaf6pgahrueysja-zstd-1.5.6-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/p5/eb/brk-p5ebnikkn7phl3xojq52xmdrfb2de5dldc3qfbkr3euo6kxr3ala-ca-certificates-bundle-20261020-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/p5/rx/brk-p5rxp6x26yjm6b5t2lf3kco5u2w2zko2k3ma5odcrnnmsixwhj6a-libcurl-8.14.1-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/p5/uk/brk-p5uktxyamskabu2gk3grichqlqinop3payt7ptqw6d4srcvsaz5a-libstdc__-14-dev_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/p6/4u/brk-p64ubkpmkkadsqqhidffg25atg2wgfinaacychgsfyt3outqqtdq-libc6_2.41-12_deb13u3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/p6/eq/brk-p6eqluqrei7jxrpnr2nogcmndvhzkr37f2j47nrfkscrbtnpy64q-libssl3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/pg/qc/brk-pgqciu5bf6v5rsxw2sudi6mejm4jdbxccplkyw33ylf327exabta-llvm-tools-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/pj/6o/brk-pj6ok275ispcmivb4gpez2bzug46p2ge6a7pd3dncpfzelwebihq-liblsan0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/pj/we/brk-pjwex5lrldalvupg3n7gbeibqhqmkv2nt45iyfl64qfty7texbqa-libexpat-2.10.0-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/pt/g4/brk-ptg4o4phfr2eutq2xrcoqi6zx2d2rk4nqoxdm73hvskgosibuh4a-tar-1.35-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/pv/vz/brk-pvvzoxgx7z6mmjnme5ravamtm5ce2mbexhvimkyopjclasv4dhpq-ca-certificates.pem.brick'

    'rubble-generated/multi-zkpws33/store/q6/6x/brk-q66xooc3uyetlxp6565oyihya5babf4sn3opal27qo6em5wjkuca-gcc-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/qa/hc/brk-qahczze2w5oyaxj5ledbeizlod4hco54ydowp6zvk4wryzwpqu2q-libidn2-2.3.7-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/qb/rl/brk-qbrlu376mq3m5jhng65mdeobdbrpjzv3thrthfrpvoam77zovt3q-patchelf-0.18.0-aarch64.tar.gz.brick'

    'rubble-generated/multi-zkpws33/store/qg/3g/brk-qg3g2dinqfibxj3dkbjqgp6q4vhezm2w5ayy7ibamcbqov7sunuq-git-2.47.3-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/qh/7v/brk-qh7vuwb26yoguehicnk5b2qi6cohneetobzeehlkcn4vvt6licia-git.brick'

    'rubble-generated/multi-zkpws33/store/qm/dv/brk-qmdv4se7cy5zxuxhuq6la3h562eim3kyrj3eud44s2njzmqn3mlq-libpanelw-6.5_p20241006-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/qn/3l/brk-qn3lywhoc2dno3mvjvoq3mihzjcc6yz76oy3bvxnhgrsw5ewd7xq-libtsan2_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/qs/or/brk-qsorrmuoq5ncj2yuseriaitxwpswca2an4ott5gxlritcgujxudq-perl.brick'

    'rubble-generated/multi-zkpws33/store/qv/xc/brk-qvxcj4lj5jj5mbgvpcfw5svnfaljwbkil7ghzzofovoqehagqava-diffutils-3.10-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/qw/d3/brk-qwd3quqioqiv5a7rm7s73nowdeq6xvvhyrzquhncrfn35xsh5msq-musl-dev-1.2.5-r12.apk.brick'

    'rubble-generated/multi-zkpws33/store/qw/fw/brk-qwfwhqp2o5ysc6wj72oc5qmextbjnqdockbzflpzm2nprxwvrm3a-zstd.brick'

    'rubble-generated/multi-zkpws33/store/qx/xt/brk-qxxt6f726go3553r3bhxadzrgj637yghleeivlrsywklrpcr3pnq-libitm1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/r2/rl/brk-r2rl2pbw7edcma3xcpjbnfmj5xa2l5ltff3xr3tyxxpfej5udu5a-libbinutils_2.44-3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/r4/7q/brk-r47q5tofldj4g4624jepcs5tjcxbgznhhxbwnzamfmankxyz4ewa-gcc.brick'

    'rubble-generated/multi-zkpws33/store/ra/n3/brk-ran3ty2pos5t45x5cpsmbpfi7kmuh3i2jpdbj7gk5zggwea7b2vq-gcc-glibc.brick'

    'rubble-generated/multi-zkpws33/store/re/l7/brk-rel7wcogzgat73st77jy3cxxhyth7hjpzxl6wfey5nttckhttxrq-c-ares-1.34.9-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/rg/ds/brk-rgdskue4seruek4fxopdeftkm4uf7jxa7nxjyqkhkj5yak2ebc4a-gcc-14-base_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ri/ue/brk-riuewubniwiboir5fq3jjufegmdvpfusk2fp25gcllfzgwstcwfa-nghttp2-libs-1.69.0-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/rj/pb/brk-rjpby4njkkmva5s4irocxwr6vrgusi6cn2kzmcdbf2bdcbxztgda-rubble-web-assets.brick'

    'rubble-generated/multi-zkpws33/store/rm/4z/brk-rm4zxsn5qycajrfwexlu4perkspongbyp6ae77564am5knq453wa-libgcc-14-dev_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/rr/24/brk-rr24d5jtgkkrifatmbdolj2lttqqu6g5h35w3qe536jpenad2e6q-cpp-14-x86-64-linux-gnu_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/rw/zt/brk-rwztfchzewn3b52bic5jjgvg3nn3rjix4rtqh3us57diipcxxmyq-bun-1.4.3.brick'

    'rubble-generated/multi-zkpws33/store/ry/7d/brk-ry7dxugonx43nz5l7zqafhnyf7g44osnmhejuhlt4x3bhh6x4lya-libgmp10_6.3.0_dfsg-3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/s3/pv/brk-s3pvvtqxrdzleije623ea64covxuywd4s6akx2d5lpxokyytr4ea-libidn2-2.3.7-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/s6/sl/brk-s6slrst6crbk75uftmxwwuqcx7x7m47earozfajjzsct2yvlrk2q-rustc-1.99.1-x86_64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/sa/xd/brk-saxdsta5ltm7iomdgyx3f23uma6qmu7hz674djpkjgbgi76tsisa-gcc-14.2.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/sc/of/brk-scofokclgi3ex4hzrtnmlf6lpkcpmii52orptjcupfmikihi6kxq-zlib1g_1.3.dfsg_really1.3.1-1_b1_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/sf/xf/brk-sfxfw5yxrv3hd72ixioxy6fzrfuc7kq2tg35pj2j7mi5vlrporta-rust-std-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/sg/dy/brk-sgdyuezwsbzpgusurjxb7bvquikinj455qz7q5c2emyrynor4f3q-binutils-2.43.1-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/sl/7z/brk-sl7zsbzcfjdoz6ohe72ecirudxewciohnjumdqn7bkuunn2hp5lq-libstdc__-14-dev_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/sm/gl/brk-smglbxy2qltuw55ubbydcyhowlyzyzpmmwhii6rttwdgrcn6yhwa-libisl23_0.27-1_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/so/yq/brk-soyqxtymcfjf74xui3ydngvt6so3orqonn4dzhh2gpwgcp2q6gna-libhwasan0_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/t6/xq/brk-t6xqfwfwlrrilozolb4u3zqjqyvl4ak7wbq5j6hxpicb3ycidfpa-libpsl-0.21.5-r3.apk.brick'

    'rubble-generated/multi-zkpws33/store/ta/cn/brk-tacnuufbmsgvjjdv35jnlei72ofv46gglzsjzt76wnp6nf7qphdq-binaryen-117.brick'

    'rubble-generated/multi-zkpws33/store/tb/fs/brk-tbfsz6yscqgyjhqi2s6uzd2vam65e2d2gcrfe6lnzyevowdrb5ja-grep.brick'

    'rubble-generated/multi-zkpws33/store/tf/jx/brk-tfjxrh45sf2nytjwmw6picosxhkrbtwiuke6d3wujuptb35jb55a-collect-shared-libraries.brick'

    'rubble-generated/multi-zkpws33/store/ti/4k/brk-ti4klh4xsl6vslhhl3gmasoj57eebnstumstzpwjqyej67727c7q-nodejs-build-tools.brick'

    'rubble-generated/multi-zkpws33/store/tn/7i/brk-tn7i4ngybkypz244wdsulsnk23gxd3xe5eg25ozinsunvlfb6tkq-rubble-deps-cache.brick'

    'rubble-generated/multi-zkpws33/store/tt/xo/brk-ttxoxb3lfk7t3rzpgq4m42lsl7lmgzt2e5w5pdt6rxna3q6pulra-skalibs-libs-2.14.3.0-r0.apk.brick'

    'rubble-generated/multi-zkpws33/store/tx/b6/brk-txb64vqfae7aa5nhycodgois76zpayaio6xopelsmuan5mnhhzzq-libcc1-0_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ty/qo/brk-tyqosp4fpdd7pjacveojot6m2g5ls3hqljfqp4qerplz2kuwcvua-musl-install-tools.brick'

    'rubble-generated/multi-zkpws33/store/ue/bf/brk-uebfeauaf5vguxmohlpx5swr4lvxm7unyqgo2n26asm3lenncypq-nodejs.brick'

    'rubble-generated/multi-zkpws33/store/uh/hf/brk-uhhfmqomkjkge4wvugjq2qy2uyh4nleaeh43u5ihugfyrhxriyfq-nodejs-runtime.brick'

    'rubble-generated/multi-zkpws33/store/un/xl/brk-unxlmwftoohd5ub6hgpvylolxd6zjczt462o5jf6zyb2nmexflpa-gcc-14-base_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/vd/ms/brk-vdms6yfjfyag5lkckavsys57lvbbacysv777s6ackvaavlwcky2a-python3.brick'

    'rubble-generated/multi-zkpws33/store/vq/3s/brk-vq3sirpitu5prsi2ig3ld3d7am7x6cxjxscc4qchsiecywgz3bfa-libatomic-14.2.0-r4.apk.brick'

    'rubble-generated/multi-zkpws33/store/vs/ja/brk-vsjaiiipt4nnq6yybfgc74k6mex5jlpmtk4s7glcyostfsn3h2vq-llvm-tools-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/vs/wq/brk-vswqqehwz73whpxezmbr7nf4anbs7slwoknh6pi76q7askntz5iq-libctf-nobfd0_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/w3/4r/brk-w34r6xbrp5naxtwy4i2yjuqgwtocs272gmp3wpl6jzg7tchrtjra-libgcc-s1_14.2.0-19_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/w6/64/brk-w664xv3i7l4c2vahfdto6wouwerljg7pgln6evk6d4icuwvi4xoa-rust-std-1.99.1.brick'

    'rubble-generated/multi-zkpws33/store/w7/gt/brk-w7gterx6tkmti6wv733mqag4engf5xzrpvyrazpfjb7u7cvs7hla-node-v22.22.3-linux-x64.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/wk/mp/brk-wkmpl2hwgob7qvcfpgzvx56hogur3qhmor7od77tv6hr4gd7eurq-ld-musl.so.brick'

    'rubble-generated/multi-zkpws33/store/wo/6v/brk-wo6vgn55jsmxeqnkavm4rcompkku3ssc2xyxdc4nrbbcx5ggc2ea-libmpc3_1.3.1-1_b3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ws/jd/brk-wsjd6bhyeay7o42k276g7ep5plfqmlqubqztlvbu5aw7rjjeuq2a-gzip-1.13-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/wx/52/brk-wx522xces6aeljkz5y55o6kdkgi6zgyvebi63xgqxclodxabs56q-libatomic1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/wz/ti/brk-wztibky6ancf6wplvm64kugrm37ltcirzobzg5mgf55vwnv5taca-linux-native-toolchain.brick'

    'rubble-generated/multi-zkpws33/store/x5/6j/brk-x56jkwrv5shx4duab3qg53qmnuvvtc5zubpotbtxsl7k2cellbdq-llvm-tools-1.99.1-x86_64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-zkpws33/store/x6/m3/brk-x6m3rqymxcy5i664gnpmwk7ucihlqh6ycfty4kbsjtg7mmfvb6eq-ld-musl.so.brick'

    'rubble-generated/multi-zkpws33/store/x7/pw/brk-x7pwlzkrrh3cqzsqlvdtwpqpny7mthxe75cr26axhvbzmfui6tra-pcre2-10.43-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/xa/vn/brk-xavn33v6xwtxgf7j7snhvwd5urqxswa4c2d2hxtjxjza37nizg4a-libctf0_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/xe/dv/brk-xedvxtllcofffyvvz234aetsvntfip744x5z35zlo2yr4yt3rhrq-glibc-runtime-support.brick'

    'rubble-generated/multi-zkpws33/store/xi/6o/brk-xi6olwdpuv5plotddhzff6u7glowbdw2qrtzw7hjduhk7ezoxy3q-git.brick'

    'rubble-generated/multi-zkpws33/store/xk/pw/brk-xkpwht5j77al73t57tas35u6xacltjd3sdjh6edfidlq5jbuz4ga-wasm-bindgen-cli-0.2.130.brick'

    'rubble-generated/multi-zkpws33/store/xr/ab/brk-xrabzjajmehgka3yl2q5bx4rm524tarj7rngb7myx5cl4wzjtama-gpatch.brick'

    'rubble-generated/multi-zkpws33/store/y2/gc/brk-y2gczfciw3klma4mkheml5yh6gpkn4mnakp5qr5vsjygqqy33paa-libctf-nobfd0_2.44-3_amd64.deb.brick'

    'rubble-generated/multi-zkpws33/store/yb/6t/brk-yb6tefhslyriibghffdurwb2wvapj6x3xizoboao2doaj7v7xgda-libcc1-0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

    'rubble-generated/multi-zkpws33/store/yt/5n/brk-yt5noi5764mqbnvv6n6ce2dcsh7smajtviko4wfl4bjbw7x25bia-xz.brick'

    'rubble-generated/multi-zkpws33/store/yv/ay/brk-yvayrwqg5legw6u4uqvntspm3qgizvmdz7gen65dlwmy4mjfqk2q-diffutils.brick'

    'rubble-generated/multi-zkpws33/store/yy/rj/brk-yyrjximmxz5nsy5s2674rewp6hhbuhasydtpqkwdi43ymhl26tbq-grep.brick'

    'rubble-generated/multi-zkpws33/store/z3/zu/brk-z3zu7eym3hbr2r5k2thkthyci3xqsfz6hlzevuf2dhvj5w7sxfrq-bzip2.brick'

    'rubble-generated/multi-zkpws33/store/z6/iz/brk-z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble.brick'

    'rubble-generated/multi-zkpws33/store/za/b7/brk-zab7x4pj4e4cmrnw753rp5hyl7jadtxtfddargzdbkkqoq2k7uwq-libubsan1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-zkpws33/store/zc/bn/brk-zcbnhzsvsrb2ugrvykackedb4zet6pjg7txbszo4tgwdkjokandq-gnu-sed.brick'

    'rubble-generated/multi-zkpws33/store/zf/da/brk-zfdanpwpbs2u3ar5qijrkn7nnv3aijzahufatoxxurr4e4rru7xa-nodejs-build-tools.brick'

    'rubble-generated/multi-zkpws33/store/zq/h6/brk-zqh6lunhozithbpfnbwqg5j54lg5ze77yzuwedmjltfo45ghffuq-binaryen-version_117-aarch64-linux.tar.gz.brick'

    'rubble-generated/multi-zkpws33/store/zw/da/brk-zwdawolcw4fqjnlmmwfrxjwrxcplq7t3jb73x5seskofbtj353na-libattr-2.5.2-r2.apk.brick'

    'rubble-generated/multi-zkpws33/store/zy/dn/brk-zydn5atoc2sxh2z3uf2jqbdtwctsseprwey2r7kmfze45av5arna-gnu-tar.brick'

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