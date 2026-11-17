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
  local -n __rp_selected_runtime="$1"
  export RUBBLE_EXECUTABLE="${__rp_selected_runtime[rubble]}"
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
  rubble_publish_config[plan_id]='multi-molgcaitrqcdkkvulppl5eac5tjxyoo4mmy5lrqm3qilzinhi7wq'
  rubble_publish_config[pipeline_id]='43c97af8-fabe-4247-9bad-8610c2a24352'
  rubble_publish_config[suggested_branch]="runs/${rubble_publish_config[pipeline_id]}"
  rubble_publish_config[commit_message]="Run Rubble workflow for ${rubble_publish_config[plan_id]}"
  rubble_publish_config[remote_store]='default'
  rubble_publish_config[plan_title]='2 bricks: x86_64-linux-mf6ojse-rubble, aarch64-linux-dtq653f-rubble'
  rubble_publish_config[generated_root]='rubble-generated/multi-molgcai'
  __rp_relative='remote-auth.mjs'
  rubble_publish_config[remote_auth]="$__rp_directory/$__rp_relative"
  __rp_relative='../../.rubble/publish.sh'
  rubble_publish_config[user_script]="$__rp_directory/$__rp_relative"
  __rp_relative='.'
  rubble_publish_config[payload]="$(builtin cd -- "$__rp_directory/$__rp_relative" && builtin pwd)" || return $?
  declare -ga rubble_roots=(

    'mf6ojsery4icegsr6oyx2h6sfvywokrcudxxmbod4evgnnwqiufa-rubble'

    'dtq653ffngjy5jemvyw3visyxf6fctmgw4n5uf4gpt7vd4aqqjaq-rubble'

  )
  declare -gA rubble_root_short_ids=() rubble_root_names=() rubble_root_platforms=() rubble_root_bricks=()

  rubble_root_short_ids['mf6ojsery4icegsr6oyx2h6sfvywokrcudxxmbod4evgnnwqiufa-rubble']='mf6ojse-rubble'
  rubble_root_names['mf6ojsery4icegsr6oyx2h6sfvywokrcudxxmbod4evgnnwqiufa-rubble']='rubble'

  rubble_root_platforms['mf6ojsery4icegsr6oyx2h6sfvywokrcudxxmbod4evgnnwqiufa-rubble']='x86_64-linux'

  __rp_relative='store/mf/6o/brk-mf6ojsery4icegsr6oyx2h6sfvywokrcudxxmbod4evgnnwqiufa-rubble.brick'
  rubble_root_bricks['mf6ojsery4icegsr6oyx2h6sfvywokrcudxxmbod4evgnnwqiufa-rubble']="$__rp_directory/$__rp_relative"

  rubble_root_short_ids['dtq653ffngjy5jemvyw3visyxf6fctmgw4n5uf4gpt7vd4aqqjaq-rubble']='dtq653f-rubble'
  rubble_root_names['dtq653ffngjy5jemvyw3visyxf6fctmgw4n5uf4gpt7vd4aqqjaq-rubble']='rubble'

  rubble_root_platforms['dtq653ffngjy5jemvyw3visyxf6fctmgw4n5uf4gpt7vd4aqqjaq-rubble']='aarch64-linux'

  __rp_relative='store/dt/q6/brk-dtq653ffngjy5jemvyw3visyxf6fctmgw4n5uf4gpt7vd4aqqjaq-rubble.brick'
  rubble_root_bricks['dtq653ffngjy5jemvyw3visyxf6fctmgw4n5uf4gpt7vd4aqqjaq-rubble']="$__rp_directory/$__rp_relative"

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

    'rubble-generated/multi-molgcai/Dockerfile'

    'rubble-generated/multi-molgcai/authentication.sh'

    'rubble-generated/multi-molgcai/build-brick.sh'

    'rubble-generated/multi-molgcai/cleanup-auth.sh'

    'rubble-generated/multi-molgcai/github-actions-publish.sh'

    'rubble-generated/multi-molgcai/install-image.sh'

    'rubble-generated/multi-molgcai/lifecycle.sh'

    'rubble-generated/multi-molgcai/open-pipeline-auth.mjs'

    'rubble-generated/multi-molgcai/pipeline-auth.enc'

    'rubble-generated/multi-molgcai/prepare-image.sh'

    'rubble-generated/multi-molgcai/publish-library.sh'

    'rubble-generated/multi-molgcai/publish-release.mjs'

    'rubble-generated/multi-molgcai/publish-runtime.sh'

    'rubble-generated/multi-molgcai/release-inventory.txt'

    'rubble-generated/multi-molgcai/release-plan.sh'

    'rubble-generated/multi-molgcai/remote-auth.mjs'

    'rubble-generated/multi-molgcai/store/23/dt/brk-23dtrr2y5pu7frbbxm6frj3y3c4nms65mx774swxq4uujwmbi35a-rust-toolchain.brick'

    'rubble-generated/multi-molgcai/store/26/us/brk-26usdrtsxslcuk33dt6uqeasrdrbu32fnsrtmbpilsslh5da6jgq-xz-libs-5.8.4-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/2b/fw/brk-2bfwkovamqlgqawc2obxigc4yho4jgx6rrkc6tyhubog5tm2vhxa-nghttp2-libs-1.69.0-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/2b/to/brk-2btooo6cnofph3xjrdgy2dezt4y4xl47ygmhqslj24ropfoiscdq-bun-linux-aarch64.zip.brick'

    'rubble-generated/multi-molgcai/store/2g/mb/brk-2gmbwm7hmynv7bo7toieqvwfon7d47sb5peqrimgmeapxwoeazla-zlib-1.4-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/2i/fu/brk-2ifucdhxoflj6anntvfsnjg5untghnzjvplj47aodaqkqpenxzyq-ca-certificates.pem.brick'

    'rubble-generated/multi-molgcai/store/2x/vb/brk-2xvb3r54evrsdi35e7g53c457cahrcrjp6yky4nkngo5whirxsja-rubble-web-assets.brick'

    'rubble-generated/multi-molgcai/store/35/ta/brk-35tafn5y5bx52c7p4nupnlbivoesughkhptcruj3xzmsigtpwo7q-gcc.brick'

    'rubble-generated/multi-molgcai/store/3b/lb/brk-3blbc3vt3hw6l2yenxtxlwpfnv7432fvq4xhhkr7lbtpk7msi3pq-readline-8.2.13-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/3e/lu/brk-3elu433ocjff5eywxs6r4wbr6rjnxrpytvt73bkxzeccy5wbp4ya-rubble-web-node-modules.brick'

    'rubble-generated/multi-molgcai/store/3e/xo/brk-3exo4yvcmu45p6oevi6u6v7fkppbt2fohg5gpkfvwhjykut7m3wa-linux-headers-6.6-r1.apk.brick'

    'rubble-generated/multi-molgcai/store/3i/sl/brk-3isljfsdiufidx6nanfu323k7zozw2mkua3ht56d2dlnq6eideca-libisl23_0.27-1_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/3l/ak/brk-3lakszb4t3ztto3lstnsusy4wqatkmqyhbyfihrfz7uoh45ikvzq-rubble-elf-runtime.brick'

    'rubble-generated/multi-molgcai/store/3n/3b/brk-3n3bc5ncagillpn2mz3jicaeyjvq6myp5b2prh2kn6tllwded3qa-libgcc-s1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/3o/ot/brk-3oothg4a44icdojzlibmxrxhn2xs6hase67u2pgy4z77l7gj6kgq-libjansson4_2.14-2_b3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/3p/wy/brk-3pwyzin2s6znyulfwpta6mbiky3ksdwnmvi4k4oblrddcyccpbkq-libbinutils_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/3t/a5/brk-3ta5iynktsdt52s25vtvityobd7g6ej7bsbbop6zwlsjavx2lw7a-linux-native-toolchain.brick'

    'rubble-generated/multi-molgcai/store/3w/c6/brk-3wc66h2jnag7f2y7nh3xanfzcbe73bsjv4g2ugqhhdffmk63rppq-rust-toolchain.brick'

    'rubble-generated/multi-molgcai/store/3w/m4/brk-3wm4cdhbw7rufcah5dges6g3jzapjyjpwtravjh5rclsluy3vgaq-coreutils.brick'

    'rubble-generated/multi-molgcai/store/44/fb/brk-44fbtqdwjg4hxe3f2yznqahdlkie4ph2szpad73h5bsqptqg3rmq-llvm-tools-1.99.1.brick'

    'rubble-generated/multi-molgcai/store/45/pp/brk-45ppndjvm7i5beghuemci3wjwojeswmc65z3ev4qumk53rap4l7q-python3-3.12.16-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/46/u6/brk-46u6btbnqkhim377u2w54og4tf7ipfdazvg3ezdcoxmyzbn64lca-gnu-tar.brick'

    'rubble-generated/multi-molgcai/store/4a/kp/brk-4akp4e4shmwjpgpj3n6qt7t5wwhltqioq5nihepguyvtwn2gumaq-xz.brick'

    'rubble-generated/multi-molgcai/store/4g/be/brk-4gbejr52ozzofmznelc52fgic4nsoasxjr6i4phtf6utztaoz6la-binutils-common_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/4u/7i/brk-4u7ipxlga2iovzbrxks2yehlngktjp7jsmlsxdhlnqj3k6p65vmq-gcc-glibc.brick'

    'rubble-generated/multi-molgcai/store/4u/ec/brk-4uecjax2lpo5idputrmq6yayy6admss7pdzmgzf6pwomzimzj3qa-unzip-6.0-r15.apk.brick'

    'rubble-generated/multi-molgcai/store/5f/6h/brk-5f6h42fvytrovpiqc6uef6hb35eujabalgjpgxeksmjvoxwthtca-wasm-pack-v0.15.0-aarch64-unknown-linux-musl.tar.gz.brick'

    'rubble-generated/multi-molgcai/store/5f/k2/brk-5fk2gsc2wvpikazwv7m2r2tymf23xnulpwld5ai2csmdkmwetqaa-m4.brick'

    'rubble-generated/multi-molgcai/store/5s/7g/brk-5s7gs2ums6dnwmfl775fd3igctpuc6r6jvmqveeuo7tfqpl5jgna-gcc.brick'

    'rubble-generated/multi-molgcai/store/5t/d6/brk-5td6qvq3hkwnfc5vqh6lcuv5xlk5yh26d2esafb7byxkpwl6klua-gawk-5.3.1-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/5v/ex/brk-5vexncx3cian4rymupdaft3bwnvswvrzp6pcxohuilbll3lii53a-zstd-libs-1.5.6-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/5w/sm/brk-5wsmysbedc7wbcb22csq254i5hrsdbwpdwuzyi5seacce7a4iaoa-coreutils-sha512sum-9.5-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/5z/qz/brk-5zqzbtecxd2bwjpypfrcgfmzvuqihlmabhg5jtqztyhjc656maja-perl-5.40.4-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/64/3b/brk-643bz5kh4yxhnqyc73ks7q46g3lwvxzrupppt5obavsi3ix4ri7a-rubble-web-assets.brick'

    'rubble-generated/multi-molgcai/store/65/tk/brk-65tk5pseuj37atpxc7fyjfylydn4es5jaedcsl7pnrgji7rro7zq-RubbleR.git.partial.brick'

    'rubble-generated/multi-molgcai/store/6o/4w/brk-6o4wm66qnadsqlllvxr5j7elb4cbrtze23xd2cjolcomfpvpmhcq-rubble-script-shebang.brick'

    'rubble-generated/multi-molgcai/store/6o/fb/brk-6ofbtcdyl2ncnjav3ntckdmw6efl7mfixfllsf2cs7377cl3pkkq-wasm-bindgen-0.2.130-aarch64-unknown-linux-gnu.tar.gz.brick'

    'rubble-generated/multi-molgcai/store/6x/57/brk-6x57czsjykkquqvimx4tp6fnnaeg5tdgt2czbzblqpfw2mafxgjq-bun-1.4.3.brick'

    'rubble-generated/multi-molgcai/store/76/la/brk-76lao3bnpein6f4ggp4dwci7cdyywjnb5i7by4forhkbzf6lju6a-wasm-pack-0.15.0.brick'

    'rubble-generated/multi-molgcai/store/77/pa/brk-77pafwgzhgk3kbtyd3i5bnikedwfoif6mfaibfesmfc655t35naq-libpsl-0.21.5-r3.apk.brick'

    'rubble-generated/multi-molgcai/store/7b/dr/brk-7bdre6qesl2nyrssafqowwjx6n34nhhs4ynft55plkrw7wxehsoa-glibc-runtime-support.brick'

    'rubble-generated/multi-molgcai/store/7g/ai/brk-7gaiswvomctprmbv5i6dhxav3urpsmceezmwy52qv42yok44lygq-bash.brick'

    'rubble-generated/multi-molgcai/store/7g/wd/brk-7gwdsqgvkrl5q7ztjhu2z65wbjt2eywqrtwg7xc7jewdoolhnmea-acl-libs-2.3.2-r1.apk.brick'

    'rubble-generated/multi-molgcai/store/7n/ip/brk-7nipxvz7ubrmxqemwaotz2gtqtduifejmmruqx4bevzgqxdw4wea-RubbleR.git.partial.brick'

    'rubble-generated/multi-molgcai/store/a7/yy/brk-a7yytixghyt2s63uxdft2bot7z5bpaqvjhhyrbwk5oek3j6whd2q-bzip2.brick'

    'rubble-generated/multi-molgcai/store/ad/yk/brk-adykhpm55qerngmtx6ke7csou4r73gh5lnubblp7jj6ro4oeyxna-patch-2.7.6-r10.apk.brick'

    'rubble-generated/multi-molgcai/store/bd/u5/brk-bdu5sreukj6dzyvd4fmoxrdlw2argk3s5k2fhz67me5cy4hdpncq-nodejs-runtime.brick'

    'rubble-generated/multi-molgcai/store/bn/wq/brk-bnwqa6w363zd76l73ptm5u7wqthwzyxdygt5rnyztadje3hafe2a-perl.brick'

    'rubble-generated/multi-molgcai/store/bp/yv/brk-bpyvwhm4bzve42im4kgvpmxekenmlobdxdyw65x5wz5yto3vpc3a-gzip.brick'

    'rubble-generated/multi-molgcai/store/bs/cz/brk-bsczck3itaibqqkhhwkkzdh3fv5i477527aika7gfcttdyn6chhq-libgcc-14.2.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/c3/mx/brk-c3mx4enfz3mavjcdvvrvgesx2mp63rndptl2he7dzmbfslsaz5gq-linux-native-toolchain.brick'

    'rubble-generated/multi-molgcai/store/cc/25/brk-cc25q3jglva6ayeaiegjq7f52i5fe3w3j2navr35izea4kmwayaq-brotli-libs-1.1.1-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/cm/da/brk-cmdaozrcvaymmdfw3jodg7rrc4qwmaqyx6q3jj6u6nsie32hvdxq-publish-output-directory.brick'

    'rubble-generated/multi-molgcai/store/cn/su/brk-cnsuk57bulhj544m3skp3wwq4lsh5qegyneycg7bgfo2zzu5z7ua-coreutils-env-9.5-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/de/fm/brk-defmfedonkfkblaqtfzjs7kvoq2u5k53xo3zzl43it7q634ax7ja-collect-shared-libraries.brick'

    'rubble-generated/multi-molgcai/store/dh/zo/brk-dhzowymraqoa262lv45rzgrpjrqdedusoctmkao7qctbpck3qiva-patchelf.brick'

    'rubble-generated/multi-molgcai/store/dj/23/brk-dj23vhvm5zsel7c4x7ahffll2hf5tnkjr4qen4vxi2vnuvhdgxba-git.brick'

    'rubble-generated/multi-molgcai/store/dk/ct/brk-dkctajvl2il4pypc32olxna3wh7rq2dnch3in6y6qkziz74prrka-zlib1g_1.3.dfsg_really1.3.1-1_b1_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/dk/tq/brk-dktqjk57lvhld37htakm5472rljxvc3dte5plieqdipyxzze6plq-gawk.brick'

    'rubble-generated/multi-molgcai/store/ds/om/brk-dsomt7lhqc7ncamrr6uzioycozr2lw6bfe4ee66zl3s3mqpabvra-nodejs.brick'

    'rubble-generated/multi-molgcai/store/dt/q6/brk-dtq653ffngjy5jemvyw3visyxf6fctmgw4n5uf4gpt7vd4aqqjaq-rubble.brick'

    'rubble-generated/multi-molgcai/store/dv/rl/brk-dvrllqig4vloxhgyjrmpzimbvdcatflu5xsgnfnhez77trxhzbaa-libcrypto3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/dx/bm/brk-dxbm5xbf7vkb35noka43so2duja6uw3kitmmhxbybcer6op5bcla-utmps-libs-0.1.2.3-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/e4/tb/brk-e4tbfbflokd3vtbdkfugznkc74azek6ki3xosyz7hvxzdlafydmq-rubble-deps-cache.brick'

    'rubble-generated/multi-molgcai/store/e5/bi/brk-e5bidgxbvr5crgxvo3tckxld466txu5dxi674pplgncc4fifmkva-gdbm-1.24-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/e7/aw/brk-e7aw53vitgjqbosohujzxudnmbfqylyi27ehtmvbucoevvgocfoq-libsframe1_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/ea/y2/brk-eay2yd76jtq2n72kafauwkofupanezwq2muobm7bjlf6mfojk4ma-linux-libc-dev_6.12.86-1_all.deb.brick'

    'rubble-generated/multi-molgcai/store/ec/vm/brk-ecvmuhel6g64yeystzfd4xmmjjdqv4p3i57tedybq2ppazcnfvzq-zstd.brick'

    'rubble-generated/multi-molgcai/store/ec/xk/brk-ecxkum7thkjwggmltz3jlz67amewczlvf6ybucueqawsamou6t4a-binutils-aarch64-linux-gnu_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/eg/27/brk-eg27735m75zx7aqioqpvqjluaojdeh2kmtsizlotnmpyrir4dvcq-findutils.brick'

    'rubble-generated/multi-molgcai/store/ek/2i/brk-ek2ilgp6au3mle7j3tvveddlp6xohfqlj4rzfazou7r5ahfoqmxq-wasm-bindgen-cli-0.2.130.brick'

    'rubble-generated/multi-molgcai/store/el/li/brk-elli4da2njhcv4aap6f2a6tueyezrnrnd7hist2qro34ttjryw5a-llvm-tools-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-molgcai/store/em/on/brk-emonumondcre3b5pnxo4hp5dzwkoobjp7fi6ofxmqudceo4dxjnq-node-v22.22.3-linux-arm64.tar.xz.brick'

    'rubble-generated/multi-molgcai/store/em/um/brk-emumr4qhmj3md4udqk36vvpcou3bcq2q6x47b2utro76mglanp6q-libffi-3.4.7-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/es/h7/brk-esh7pawc46nsh5b2uuykm4qsjsoowbes5uu4nt2kcg6hocags6vq-coreutils-9.5-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

    'rubble-generated/multi-molgcai/store/ex/wh/brk-exwhj5vebfaduvvhd7f6xtppocqwgqam7csyi3u5434k3ypqofpq-libmpc3_1.3.1-1_b3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/fa/qk/brk-faqk22fjqryqxjx6pkufmb2mttau3gwuv2qu6roi3d4melszcu7q-libunistring-1.2-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/fb/xg/brk-fbxgu4t24gr47iq2yhyaygays2hvcmyidx4tkwjmlx52pttyr6yq-libasan8_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/fc/jh/brk-fcjhtbtyxa5qk3xy5jhazosrdwgn6npaqbjmm7dmyoi756zrunca-normalize-python-runtime.brick'

    'rubble-generated/multi-molgcai/store/fd/jo/brk-fdjot6csltdy7pfpendap6yybjo5niybzp6knbofokgq7mxbz6kq-curl.brick'

    'rubble-generated/multi-molgcai/store/ff/pp/brk-ffppl4gr2kqvvmwgncrxlllkh6z47u6wpzeiyatswpebhvwpbvua-gzip.brick'

    'rubble-generated/multi-molgcai/store/fg/32/brk-fg32tsmkrioagedunckpr37qz35rn4b7obxt3wsbxx56ajpxviza-mpc1-1.3.1-r1.apk.brick'

    'rubble-generated/multi-molgcai/store/fq/ac/brk-fqacbxvzkp7aqbu5x5ibzixghwcxbmvzfqzhvgxdnq4tm7yoiavq-findutils.brick'

    'rubble-generated/multi-molgcai/store/fu/4g/brk-fu4gjf2vujnnxzbws5i2w57yneqm7tmgiqzxodte6s6rf74vchrq-g__-14.2.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/fz/so/brk-fzsocvqoawb6atzh5tfjxgahm2yualfjxwxicd55hjyf4gfjo5da-libstdc__-dev-14.2.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/g3/fx/brk-g3fxen4ug3f3g34imdsefwplwd3ulzn75tn5uxd5jqe7t23bzyna-bash-linux-aarch64.brick'

    'rubble-generated/multi-molgcai/store/g5/mj/brk-g5mj7ye65ol2eqscjqmkpwcvoxihq2xqxshrjgkk7r2nk3khnuvq-RubbleR.git.partial.brick'

    'rubble-generated/multi-molgcai/store/g5/r5/brk-g5r5a7z3ismvnzq5uwsre6sfoiprc6smte4xd4jcchttjjvqidtq-xz-5.8.4-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/g5/zs/brk-g5zshxvbu3styhzy6s7rga2yoofniwkfdlasmxfnt4jnls3bl3oq-gnu-make.brick'

    'rubble-generated/multi-molgcai/store/gb/4d/brk-gb4dlxkuu36d4olrckbxrdwlkvocpv2amucqerzpih2nv5w3uxuq-libstdc__6_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/gh/q4/brk-ghq46r5f4orvr6sszvuapmkyflimfvkwlb4hv3t3dsr4k4zwplta-unzip.brick'

    'rubble-generated/multi-molgcai/store/hd/hi/brk-hdhimhaqn7bul5k67m2gmw4ea6xibuprz2mgla5obsjibs7tfnoa-make-4.4.1-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/hd/qx/brk-hdqxqr4vfc2rgc3rj5ywrpaykxqly77eix55tldf7wd7nqimpqfa-patchelf.brick'

    'rubble-generated/multi-molgcai/store/hi/gq/brk-higqpv2dmyiorfd43aypr6zeuad53wdrig2qr4q3zzgtlwhy42bq-gawk.brick'

    'rubble-generated/multi-molgcai/store/ho/55/brk-ho552ymbr5wqlkbb7xckcvqfjs5fd4ytbrf5rjp3vaqnwocxhx5q-gmp-6.3.0-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/hr/3g/brk-hr3gsmedt3iyx26xhety6rvbs2nzhv6o4oyscyt7qvuuixa7fbfa-libhwasan0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/hw/l2/brk-hwl24putkcshns72klsuon3lx3awi6xp2abud6qix4essgak6aca-gcc-glibc.brick'

    'rubble-generated/multi-molgcai/store/hw/ud/brk-hwudtbqp6mtqd433zl777ixamegzf5s6pqjc3vbkw4yy7ca6rpzq-libstdc__-14.2.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/i3/vz/brk-i3vzwzq5ceekylzear5wrwz4teano37g32htjtcd4rma3zvjzz3a-libgmp10_6.3.0_dfsg-3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/i6/rp/brk-i6rpnovdyaumnm4dbmqheqhnimae5nyro5b25ewahcsz4tksxefq-mpdecimal-4.0.0-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/if/rs/brk-ifrsgpixmxcpnu4jxydtx5mxvpk7l4hwwd6jwezmensopli2mmhq-python3.brick'

    'rubble-generated/multi-molgcai/store/is/xo/brk-isxo3o4skm7vtiqyhakx4x4uxrw7hnycm3ldwp43grskdhxl3qxq-sed-4.9-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/j4/lh/brk-j4lhi22vhrul2t5yhwaw4hx76b4llbqc7lhfzh4i6o7ious3wcia-nodejs.brick'

    'rubble-generated/multi-molgcai/store/j6/az/brk-j6azokdcg4c72ggjyopfahoks5fxc5duku2fwhqxerrggqa4w4wq-rustc-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-molgcai/store/j7/nd/brk-j7ndjrq7aixii7bqtdkm7kw7j6bkvkbekmoqefp3zaanznjiuitq-rust-std-1.99.1-wasm32-unknown-unknown.tar.xz.brick'

    'rubble-generated/multi-molgcai/store/ja/26/brk-ja26s6rmlm22mwviv4hkae3mfkzkcq4tumc55qstm3p444zqmfzq-binaryen-117.brick'

    'rubble-generated/multi-molgcai/store/ja/2g/brk-ja2gawpefozngsdbmzs5n2a66ujesjats2qcq7homnixclj6iqrq-grep-3.11-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/jd/tc/brk-jdtcafj4hys4txg5vxmtvui2dl5sovyb5lontwbsxlieat3mlila-libexpat-2.10.0-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/ji/32/brk-ji32k7fdy4ks3cd5zalo2g7yiwt54oyfgom2ppe64xljlvrbotdq-bootstrap-env.brick'

    'rubble-generated/multi-molgcai/store/jo/mf/brk-jomf52m6ijsokfau3fyyvgd7elhgiiavaic5tzdw6lhugeziyhna-wasm-pack-0.15.0.brick'

    'rubble-generated/multi-molgcai/store/jw/hf/brk-jwhfx26nkv24vmnfckbvccnpwdkzwfvxcjty7dhntghaemjlpfxq-mpfr4-4.2.1-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/k2/sq/brk-k2sq3ksyc4xg4n3byfvtc2xp2by5lw3uus2pjw4ro7y4ad54uo4q-coreutils-fmt-9.5-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/kc/xm/brk-kcxminepu2ywfwal6sveazxuz3b5emokjvaje5k6edxumr4ncr7q-c-ares-1.34.9-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/ki/gw/brk-kigw4qx6x2y3usuis4atqauzx6klrptelpocmibhl3zsp3zr6qqa-rustc-1.99.1.brick'

    'rubble-generated/multi-molgcai/store/kp/e7/brk-kpe7kma33nmt3mijbihbuzazuupuiq4ffqabvfgogzgs2rdp2rfa-libzstd1_1.5.7_dfsg-1_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/kq/oa/brk-kqoaqdowlcmrluolokiygo33evr47gordg5y3gqjf4etscxnee2a-libbz2-1.0.8-r6.apk.brick'

    'rubble-generated/multi-molgcai/store/kr/tc/brk-krtc32gkhzcn3spc36a3ksbyjoykekcsx7bvmzj2mrxcmaxral2q-write-exec-wrappers.brick'

    'rubble-generated/multi-molgcai/store/ks/6e/brk-ks6e3u26mzxm5dwrtt4v2y5z6hltzyyoqnn5v36ctpuvq3z5ebga-libgomp1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/kt/bd/brk-ktbdwi3xid4ywlz6il2qlgx67aclu2t5gljy527g7vdnv6h7gaha-jansson-2.14-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/lb/7v/brk-lb7vuv6w3fr43o73swpjgwfuwdhyi7l2xskuuisw3eaekunxv3ia-libc6-dev_2.41-12_deb13u3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/li/qe/brk-liqeef25kxd6agiohfvzkme75fbbkq5cs5m7ojfifiv5y3jlosua-gpatch.brick'

    'rubble-generated/multi-molgcai/store/lm/bb/brk-lmbb6iujrwrlaoq65oxsi2yjh6qqs4focnkmlymfeshkdlzfosrq-unzip.brick'

    'rubble-generated/multi-molgcai/store/m5/ln/brk-m5lnpllbzm555r5zuagxbaoqomumjvcwyoq7xdkffysmdvteelwa-findutils-4.10.0-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/ma/ce/brk-macey2arela2oh55r33f2l5eana2whlqb3bzvi5vlkzpmqumk5ea-rust-std-1.99.1-wasm32-unknown-unknown.brick'

    'rubble-generated/multi-molgcai/store/mf/6o/brk-mf6ojsery4icegsr6oyx2h6sfvywokrcudxxmbod4evgnnwqiufa-rubble.brick'

    'rubble-generated/multi-molgcai/store/mf/wk/brk-mfwkvtv3n6hvvrci2nxbilte5df2wpayqreolg3t5xnlwedydz2q-libmpfr6_4.2.2-1_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/mg/vp/brk-mgvpjsbz7sujl5qdndfmqhtclpxfhlytkeyidejyjfez5jloit7a-g__-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/mh/ux/brk-mhuxl3qogm466jjjfbxne7e5iun5rusy6qpp26aekt65vpamhjqa-gnu-make.brick'

    'rubble-generated/multi-molgcai/store/mr/v3/brk-mrv3skvefohwhqxqk3loonbdoqonymgrvgcggyajysjlj44rvo6q-coreutils.brick'

    'rubble-generated/multi-molgcai/store/n6/vt/brk-n6vtqu3bxkksa6hlrwirri6entermnuofp2sdqcfcrzxarqrr3hq-isl26-0.26-r1.apk.brick'

    'rubble-generated/multi-molgcai/store/n7/qb/brk-n7qbevbly56oq5vdzjm2bzhl77wjewdp4k5gmoimlbiv62nbv7pa-bash.brick'

    'rubble-generated/multi-molgcai/store/na/a2/brk-naa2ad3mxbwsl6syyyeikeu6srwar3mxn4lv6faf72kx6hjpq72q-libgomp-14.2.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/nc/3b/brk-nc3b5fnwrjhizdtqakhrmgkntigd7tkzddqwknxrlyxe6oalqhpa-m4.brick'

    'rubble-generated/multi-molgcai/store/ng/2y/brk-ng2yhab3txqyfgtnrgwttzyliczkrx52jeu7skkoaxeu5d752ynq-libncursesw-6.5_p20241006-r3.apk.brick'

    'rubble-generated/multi-molgcai/store/no/p3/brk-nop3l5s2u3rvgjlnmttxmes6s7vuobxonog437kopvwrgje534ga-bun-1.4.3.brick'

    'rubble-generated/multi-molgcai/store/nq/ez/brk-nqezvr7gvu4qzj2ite3o6mk64b5foml47t6vrs2j37pggzdvnvgq-gnu-sed.brick'

    'rubble-generated/multi-molgcai/store/nu/72/brk-nu72a7zrxgfiwzjx6xkvc7d3eorpvhltbyv6a3vxbwwuwkkhnguq-musl-1.2.5-r12.apk.brick'

    'rubble-generated/multi-molgcai/store/nw/jn/brk-nwjntcya5bc7tfxrl5i22jo3v2rnlixwjc6ri3r4kwupxtwlaqsa-cpp-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/o3/fr/brk-o3fr3g3ieq5rz4buroyiwmyb545zbiw22hunovruvykeihtb2mta-rubble-elf-runtime.brick'

    'rubble-generated/multi-molgcai/store/oc/a4/brk-oca4i4igup25hy7wsfzuzkug2rvvfu2h4d237d6syf33h4co2soq-write-native-toolchain-env.brick'

    'rubble-generated/multi-molgcai/store/oc/wt/brk-ocwtgbworvapy5sxnfnyytj73ua3hlruyaply427t5wh2h5grcqq-bootstrap-env.brick'

    'rubble-generated/multi-molgcai/store/od/lz/brk-odlzblejigvixnek4zw3qpf6kdmpduizlfdol6phkrwrrltm3kdq-libc6_2.41-12_deb13u3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/od/qb/brk-odqbahexzejvph4rmduwzcwwacchcx6bzzqpejkb5lhhde5bkkua-rubble-canonical-script.brick'

    'rubble-generated/multi-molgcai/store/oe/dx/brk-oedx42pgtkscsyrm2vn6hyrci7hw74ladlpu6f6bwgt5yguhmyqq-m4-1.4.19-r3.apk.brick'

    'rubble-generated/multi-molgcai/store/og/3u/brk-og3uxejhmzd6gzyfx5ggid4dzkwzet7lsi5k7rhpxf5svupsrpva-diffutils.brick'

    'rubble-generated/multi-molgcai/store/oh/zg/brk-ohzg3khe3y5zbg6it742hi63cwoz7k3vbr5jufkccupj4kcrkpwq-curl-linux-aarch64-musl-8.18.0.tar.xz.brick'

    'rubble-generated/multi-molgcai/store/ov/g7/brk-ovg7cu6kkazcpj32mrk53yc3kb2z2mrl4yd5yzrj3uytgwcanawa-curl.brick'

    'rubble-generated/multi-molgcai/store/ow/oy/brk-owoyhne4rlabd6ti2usbbxf5qm6px4edpaa2ixltmg55lde2ckuq-sqlite-libs-3.48.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/oy/e2/brk-oye2ypgxbkwk5tvdjf7e2cmrsr7ituchdudsw2znzjzrokjzx5fq-cargo-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-molgcai/store/p4/37/brk-p437dghiaad2yb57qr2yhpsmwaw3z3jwfkdlsqaf6pgahrueysja-zstd-1.5.6-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/p5/eb/brk-p5ebnikkn7phl3xojq52xmdrfb2de5dldc3qfbkr3euo6kxr3ala-ca-certificates-bundle-20261020-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/p5/rx/brk-p5rxp6x26yjm6b5t2lf3kco5u2w2zko2k3ma5odcrnnmsixwhj6a-libcurl-8.14.1-r3.apk.brick'

    'rubble-generated/multi-molgcai/store/p6/eq/brk-p6eqluqrei7jxrpnr2nogcmndvhzkr37f2j47nrfkscrbtnpy64q-libssl3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/pj/6o/brk-pj6ok275ispcmivb4gpez2bzug46p2ge6a7pd3dncpfzelwebihq-liblsan0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/pt/g4/brk-ptg4o4phfr2eutq2xrcoqi6zx2d2rk4nqoxdm73hvskgosibuh4a-tar-1.35-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/pv/vz/brk-pvvzoxgx7z6mmjnme5ravamtm5ce2mbexhvimkyopjclasv4dhpq-ca-certificates.pem.brick'

    'rubble-generated/multi-molgcai/store/q6/6x/brk-q66xooc3uyetlxp6565oyihya5babf4sn3opal27qo6em5wjkuca-gcc-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/qb/rl/brk-qbrlu376mq3m5jhng65mdeobdbrpjzv3thrthfrpvoam77zovt3q-patchelf-0.18.0-aarch64.tar.gz.brick'

    'rubble-generated/multi-molgcai/store/qg/3g/brk-qg3g2dinqfibxj3dkbjqgp6q4vhezm2w5ayy7ibamcbqov7sunuq-git-2.47.3-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/qm/dv/brk-qmdv4se7cy5zxuxhuq6la3h562eim3kyrj3eud44s2njzmqn3mlq-libpanelw-6.5_p20241006-r3.apk.brick'

    'rubble-generated/multi-molgcai/store/qn/3l/brk-qn3lywhoc2dno3mvjvoq3mihzjcc6yz76oy3bvxnhgrsw5ewd7xq-libtsan2_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/qs/or/brk-qsorrmuoq5ncj2yuseriaitxwpswca2an4ott5gxlritcgujxudq-perl.brick'

    'rubble-generated/multi-molgcai/store/qv/xc/brk-qvxcj4lj5jj5mbgvpcfw5svnfaljwbkil7ghzzofovoqehagqava-diffutils-3.10-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/qw/d3/brk-qwd3quqioqiv5a7rm7s73nowdeq6xvvhyrzquhncrfn35xsh5msq-musl-dev-1.2.5-r12.apk.brick'

    'rubble-generated/multi-molgcai/store/qw/fw/brk-qwfwhqp2o5ysc6wj72oc5qmextbjnqdockbzflpzm2nprxwvrm3a-zstd.brick'

    'rubble-generated/multi-molgcai/store/qx/xt/brk-qxxt6f726go3553r3bhxadzrgj637yghleeivlrsywklrpcr3pnq-libitm1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/rg/ds/brk-rgdskue4seruek4fxopdeftkm4uf7jxa7nxjyqkhkj5yak2ebc4a-gcc-14-base_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/rm/4z/brk-rm4zxsn5qycajrfwexlu4perkspongbyp6ae77564am5knq453wa-libgcc-14-dev_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/s3/pv/brk-s3pvvtqxrdzleije623ea64covxuywd4s6akx2d5lpxokyytr4ea-libidn2-2.3.7-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/sa/xd/brk-saxdsta5ltm7iomdgyx3f23uma6qmu7hz674djpkjgbgi76tsisa-gcc-14.2.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/sf/xf/brk-sfxfw5yxrv3hd72ixioxy6fzrfuc7kq2tg35pj2j7mi5vlrporta-rust-std-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-molgcai/store/sg/dy/brk-sgdyuezwsbzpgusurjxb7bvquikinj455qz7q5c2emyrynor4f3q-binutils-2.43.1-r3.apk.brick'

    'rubble-generated/multi-molgcai/store/sj/34/brk-sj34zwxqnwbisud3uwj6ue6oyyofj74i7triozoch2q5kfhjkqpa-python3.brick'

    'rubble-generated/multi-molgcai/store/sl/7z/brk-sl7zsbzcfjdoz6ohe72ecirudxewciohnjumdqn7bkuunn2hp5lq-libstdc__-14-dev_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/sr/cz/brk-srcz7na45y5mw4nstnijhjfjxbygirgzrt45wa2zienq6uxmxafq-RubbleR.git.partial.brick'

    'rubble-generated/multi-molgcai/store/sr/kq/brk-srkqvjpnfpsurs3ab2qhnh2kwh7aufvqv2r4tvfkmdc3aj34arda-rustc-1.99.1.brick'

    'rubble-generated/multi-molgcai/store/sz/tg/brk-sztgsa3wvvpgrkldc5f43d43c4mrcpyrilum3h4je46dls33cjja-rubble-web-node-modules.brick'

    'rubble-generated/multi-molgcai/store/ta/cn/brk-tacnuufbmsgvjjdv35jnlei72ofv46gglzsjzt76wnp6nf7qphdq-binaryen-117.brick'

    'rubble-generated/multi-molgcai/store/tb/fs/brk-tbfsz6yscqgyjhqi2s6uzd2vam65e2d2gcrfe6lnzyevowdrb5ja-grep.brick'

    'rubble-generated/multi-molgcai/store/tf/we/brk-tfwerhssr57zeijsd7u7riwnmsgd4rjhakkjphg3o4p3vt2mxjga-cargo-1.99.1.brick'

    'rubble-generated/multi-molgcai/store/tj/io/brk-tjio2v733kwkxtlnn5o543tyu6apvpthovtlcbhdi3dzfkycs64a-git.brick'

    'rubble-generated/multi-molgcai/store/tl/62/brk-tl62xl2nvhg5gvv673ub5jufiio7lgbu6zpmldsomyusnox2htta-rubble-src-checkout.brick'

    'rubble-generated/multi-molgcai/store/tq/su/brk-tqsuozbttwsomh5wvv7b6dpdyncjonki3oundni2xhfwz2uxrj7q-llvm-tools-1.99.1.brick'

    'rubble-generated/multi-molgcai/store/tt/xo/brk-ttxoxb3lfk7t3rzpgq4m42lsl7lmgzt2e5w5pdt6rxna3q6pulra-skalibs-libs-2.14.3.0-r0.apk.brick'

    'rubble-generated/multi-molgcai/store/ty/qo/brk-tyqosp4fpdd7pjacveojot6m2g5ls3hqljfqp4qerplz2kuwcvua-musl-install-tools.brick'

    'rubble-generated/multi-molgcai/store/ud/dv/brk-uddv6krsdvnxc7tfxwgucpbilghbnae23heo74anfah5rxvhhvxa-glibc-runtime-support.brick'

    'rubble-generated/multi-molgcai/store/um/qu/brk-umqurwdghxika7vrorfax65c26gkoxeq7xpmy7hyao7c4vwe2pgq-RubbleR.git.brick'

    'rubble-generated/multi-molgcai/store/uo/qc/brk-uoqcoqwc3pd3qhp55ta6hijrrojvlcogx2y4uznmwauqfahkwtaa-bison.brick'

    'rubble-generated/multi-molgcai/store/vq/3s/brk-vq3sirpitu5prsi2ig3ld3d7am7x6cxjxscc4qchsiecywgz3bfa-libatomic-14.2.0-r4.apk.brick'

    'rubble-generated/multi-molgcai/store/vs/wq/brk-vswqqehwz73whpxezmbr7nf4anbs7slwoknh6pi76q7askntz5iq-libctf-nobfd0_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/w6/64/brk-w664xv3i7l4c2vahfdto6wouwerljg7pgln6evk6d4icuwvi4xoa-rust-std-1.99.1.brick'

    'rubble-generated/multi-molgcai/store/wk/mp/brk-wkmpl2hwgob7qvcfpgzvx56hogur3qhmor7od77tv6hr4gd7eurq-ld-musl.so.brick'

    'rubble-generated/multi-molgcai/store/wq/h5/brk-wqh5ufbakrh57mxqdeoonkvgqptjv5ofcz2al642pbl32cwhwcmq-rust-web-wasm-toolchain.brick'

    'rubble-generated/multi-molgcai/store/ws/jd/brk-wsjd6bhyeay7o42k276g7ep5plfqmlqubqztlvbu5aw7rjjeuq2a-gzip-1.13-r1.apk.brick'

    'rubble-generated/multi-molgcai/store/wx/52/brk-wx522xces6aeljkz5y55o6kdkgi6zgyvebi63xgqxclodxabs56q-libatomic1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/x6/m3/brk-x6m3rqymxcy5i664gnpmwk7ucihlqh6ycfty4kbsjtg7mmfvb6eq-ld-musl.so.brick'

    'rubble-generated/multi-molgcai/store/x7/pw/brk-x7pwlzkrrh3cqzsqlvdtwpqpny7mthxe75cr26axhvbzmfui6tra-pcre2-10.43-r1.apk.brick'

    'rubble-generated/multi-molgcai/store/xa/vn/brk-xavn33v6xwtxgf7j7snhvwd5urqxswa4c2d2hxtjxjza37nizg4a-libctf0_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/xd/67/brk-xd6754nmp4gkhqzd34hnjcg4bsyq676y6w4gnk7yjtl6du3bosga-rubble-deps-cache.brick'

    'rubble-generated/multi-molgcai/store/xe/gj/brk-xegj6c4wj7xvxgjn3aqb7sadamfng5tai2kuicxrguaji2wgpfta-nodejs-runtime.brick'

    'rubble-generated/multi-molgcai/store/xk/pw/brk-xkpwht5j77al73t57tas35u6xacltjd3sdjh6edfidlq5jbuz4ga-wasm-bindgen-cli-0.2.130.brick'

    'rubble-generated/multi-molgcai/store/xq/si/brk-xqsi7id5qiefha72ytziphoznjlv4hodlahf6snm4ukkjdnhtp3q-rust-web-wasm-toolchain.brick'

    'rubble-generated/multi-molgcai/store/xr/ab/brk-xrabzjajmehgka3yl2q5bx4rm524tarj7rngb7myx5cl4wzjtama-gpatch.brick'

    'rubble-generated/multi-molgcai/store/y3/6j/brk-y36jc6fqzle2ogxmk3yhwtqjohkbox44f7aavi5vxtvuxmstqh6a-bison.brick'

    'rubble-generated/multi-molgcai/store/yb/6t/brk-yb6tefhslyriibghffdurwb2wvapj6x3xizoboao2doaj7v7xgda-libcc1-0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/yq/cl/brk-yqclwkhxs54k6dzwj7w7pq7rq2hcyrdlueoo7ttgp5tttbczuo2q-RubbleR.git.brick'

    'rubble-generated/multi-molgcai/store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

    'rubble-generated/multi-molgcai/store/yt/5n/brk-yt5noi5764mqbnvv6n6ce2dcsh7smajtviko4wfl4bjbw7x25bia-xz.brick'

    'rubble-generated/multi-molgcai/store/yv/ay/brk-yvayrwqg5legw6u4uqvntspm3qgizvmdz7gen65dlwmy4mjfqk2q-diffutils.brick'

    'rubble-generated/multi-molgcai/store/yy/rj/brk-yyrjximmxz5nsy5s2674rewp6hhbuhasydtpqkwdi43ymhl26tbq-grep.brick'

    'rubble-generated/multi-molgcai/store/z3/zu/brk-z3zu7eym3hbr2r5k2thkthyci3xqsfz6hlzevuf2dhvj5w7sxfrq-bzip2.brick'

    'rubble-generated/multi-molgcai/store/za/b7/brk-zab7x4pj4e4cmrnw753rp5hyl7jadtxtfddargzdbkkqoq2k7uwq-libubsan1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-molgcai/store/zc/bn/brk-zcbnhzsvsrb2ugrvykackedb4zet6pjg7txbszo4tgwdkjokandq-gnu-sed.brick'

    'rubble-generated/multi-molgcai/store/zf/da/brk-zfdanpwpbs2u3ar5qijrkn7nnv3aijzahufatoxxurr4e4rru7xa-nodejs-build-tools.brick'

    'rubble-generated/multi-molgcai/store/zg/ja/brk-zgjazgvdcdjsqdl27mjgs5c3yhorkmd7rfofd6qtsp4ugwn2y3qa-cargo-1.99.1.brick'

    'rubble-generated/multi-molgcai/store/zq/h6/brk-zqh6lunhozithbpfnbwqg5j54lg5ze77yzuwedmjltfo45ghffuq-binaryen-version_117-aarch64-linux.tar.gz.brick'

    'rubble-generated/multi-molgcai/store/zq/oa/brk-zqoabx4ecncoo27qvfn46vipjiccvfwzj6opcvbskar5wazv7voa-RubbleR.git.partial.brick'

    'rubble-generated/multi-molgcai/store/zw/da/brk-zwdawolcw4fqjnlmmwfrxjwrxcplq7t3jb73x5seskofbtj353na-libattr-2.5.2-r2.apk.brick'

    'rubble-generated/multi-molgcai/store/zy/dn/brk-zydn5atoc2sxh2z3uf2jqbdtwctsseprwey2r7kmfze45av5arna-gnu-tar.brick'

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