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
  rubble_publish_config[plan_id]='multi-yzz7aoe6gnhzg5zqm6zpot73ifstczcp2yalh6q2hx34cy774riq'
  rubble_publish_config[pipeline_id]='5e833104-8bfb-4a0c-966c-a9e50341e7ab'
  rubble_publish_config[suggested_branch]="runs/${rubble_publish_config[pipeline_id]}"
  rubble_publish_config[commit_message]="Run Rubble workflow for ${rubble_publish_config[plan_id]}"
  rubble_publish_config[remote_store]='default'
  rubble_publish_config[plan_title]='2 bricks: x86_64-linux-g3c45cc-rubble, aarch64-linux-j5gf2l6-rubble'
  rubble_publish_config[generated_root]='rubble-generated/multi-yzz7aoe'
  __rp_relative='remote-auth.mjs'
  rubble_publish_config[remote_auth]="$__rp_directory/$__rp_relative"
  __rp_relative='../../.rubble/publish.sh'
  rubble_publish_config[user_script]="$__rp_directory/$__rp_relative"
  __rp_relative='.'
  rubble_publish_config[payload]="$(builtin cd -- "$__rp_directory/$__rp_relative" && builtin pwd)" || return $?
  declare -ga rubble_roots=(

    'g3c45ccdy6wpqvwoae6yeg5jp3makon7j3ziepadfbxgshp46zya-rubble'

    'j5gf2l63ovgx3lcwpqktvuftaley3gra2iqdbo2mrscdu5mmmpnq-rubble'

  )
  declare -gA rubble_root_short_ids=() rubble_root_names=() rubble_root_platforms=() rubble_root_bricks=()

  rubble_root_short_ids['g3c45ccdy6wpqvwoae6yeg5jp3makon7j3ziepadfbxgshp46zya-rubble']='g3c45cc-rubble'
  rubble_root_names['g3c45ccdy6wpqvwoae6yeg5jp3makon7j3ziepadfbxgshp46zya-rubble']='rubble'

  rubble_root_platforms['g3c45ccdy6wpqvwoae6yeg5jp3makon7j3ziepadfbxgshp46zya-rubble']='x86_64-linux'

  __rp_relative='store/g3/c4/brk-g3c45ccdy6wpqvwoae6yeg5jp3makon7j3ziepadfbxgshp46zya-rubble.brick'
  rubble_root_bricks['g3c45ccdy6wpqvwoae6yeg5jp3makon7j3ziepadfbxgshp46zya-rubble']="$__rp_directory/$__rp_relative"

  rubble_root_short_ids['j5gf2l63ovgx3lcwpqktvuftaley3gra2iqdbo2mrscdu5mmmpnq-rubble']='j5gf2l6-rubble'
  rubble_root_names['j5gf2l63ovgx3lcwpqktvuftaley3gra2iqdbo2mrscdu5mmmpnq-rubble']='rubble'

  rubble_root_platforms['j5gf2l63ovgx3lcwpqktvuftaley3gra2iqdbo2mrscdu5mmmpnq-rubble']='aarch64-linux'

  __rp_relative='store/j5/gf/brk-j5gf2l63ovgx3lcwpqktvuftaley3gra2iqdbo2mrscdu5mmmpnq-rubble.brick'
  rubble_root_bricks['j5gf2l63ovgx3lcwpqktvuftaley3gra2iqdbo2mrscdu5mmmpnq-rubble']="$__rp_directory/$__rp_relative"

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

    'rubble-generated/multi-yzz7aoe/Dockerfile'

    'rubble-generated/multi-yzz7aoe/authentication.sh'

    'rubble-generated/multi-yzz7aoe/build-brick.sh'

    'rubble-generated/multi-yzz7aoe/cleanup-auth.sh'

    'rubble-generated/multi-yzz7aoe/github-actions-publish.sh'

    'rubble-generated/multi-yzz7aoe/install-image.sh'

    'rubble-generated/multi-yzz7aoe/lifecycle.sh'

    'rubble-generated/multi-yzz7aoe/open-pipeline-auth.mjs'

    'rubble-generated/multi-yzz7aoe/pipeline-auth.enc'

    'rubble-generated/multi-yzz7aoe/prepare-image.sh'

    'rubble-generated/multi-yzz7aoe/publish-library.sh'

    'rubble-generated/multi-yzz7aoe/publish-release.mjs'

    'rubble-generated/multi-yzz7aoe/publish-runtime.sh'

    'rubble-generated/multi-yzz7aoe/release-inventory.txt'

    'rubble-generated/multi-yzz7aoe/release-plan.sh'

    'rubble-generated/multi-yzz7aoe/remote-auth.mjs'

    'rubble-generated/multi-yzz7aoe/store/26/us/brk-26usdrtsxslcuk33dt6uqeasrdrbu32fnsrtmbpilsslh5da6jgq-xz-libs-5.8.4-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/2b/fw/brk-2bfwkovamqlgqawc2obxigc4yho4jgx6rrkc6tyhubog5tm2vhxa-nghttp2-libs-1.69.0-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/2b/to/brk-2btooo6cnofph3xjrdgy2dezt4y4xl47ygmhqslj24ropfoiscdq-bun-linux-aarch64.zip.brick'

    'rubble-generated/multi-yzz7aoe/store/2l/xm/brk-2lxm3w3feqbdizjgvhexrourb5tjrb2nnihramkt7c376smkns3a-coreutils.brick'

    'rubble-generated/multi-yzz7aoe/store/2o/jy/brk-2ojyutmjxv246pbfhn5s7qiphqvt2cilve6s6rapoz66bf2lyn3q-bison.brick'

    'rubble-generated/multi-yzz7aoe/store/3b/lb/brk-3blbc3vt3hw6l2yenxtxlwpfnv7432fvq4xhhkr7lbtpk7msi3pq-readline-8.2.13-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/3e/xo/brk-3exo4yvcmu45p6oevi6u6v7fkppbt2fohg5gpkfvwhjykut7m3wa-linux-headers-6.6-r1.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/3i/sl/brk-3isljfsdiufidx6nanfu323k7zozw2mkua3ht56d2dlnq6eideca-libisl23_0.27-1_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/3n/3b/brk-3n3bc5ncagillpn2mz3jicaeyjvq6myp5b2prh2kn6tllwded3qa-libgcc-s1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/3o/ot/brk-3oothg4a44icdojzlibmxrxhn2xs6hase67u2pgy4z77l7gj6kgq-libjansson4_2.14-2_b3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/3p/wy/brk-3pwyzin2s6znyulfwpta6mbiky3ksdwnmvi4k4oblrddcyccpbkq-libbinutils_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/3s/do/brk-3sdosodx5te3olee4p5m2sx5thr2lm52mtzjlu4yrn24w6lmz4ra-gnu-make.brick'

    'rubble-generated/multi-yzz7aoe/store/42/wo/brk-42wokepkyzohd2e3y74stijm3ukr4ukvcyhfm2ncmooiruh6p4da-python3.brick'

    'rubble-generated/multi-yzz7aoe/store/4g/be/brk-4gbejr52ozzofmznelc52fgic4nsoasxjr6i4phtf6utztaoz6la-binutils-common_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/4u/ec/brk-4uecjax2lpo5idputrmq6yayy6admss7pdzmgzf6pwomzimzj3qa-unzip-6.0-r15.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/4x/2u/brk-4x2uexqjoqs5unyb4fxpdus3ctebmhvqnuruhalsl5rdwt3k6naa-rubble-canonical-script.brick'

    'rubble-generated/multi-yzz7aoe/store/52/u6/brk-52u6qpvkip6lxfj53jg23cpijgjjn7zmmr2z46wd4ucxxzng7l4q-git.brick'

    'rubble-generated/multi-yzz7aoe/store/5f/6h/brk-5f6h42fvytrovpiqc6uef6hb35eujabalgjpgxeksmjvoxwthtca-wasm-pack-v0.15.0-aarch64-unknown-linux-musl.tar.gz.brick'

    'rubble-generated/multi-yzz7aoe/store/5h/u5/brk-5hu5obb4yrhcphlmjq4eze7rbdrnkszt7o2obqnpvtuehzgqdqoa-libexpat-2.8.4-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/5p/s3/brk-5ps3po7wlt3gqh7pzkfwzfh6hodqo6wf5sqxyvg6h4opgo2f2xxa-m4.brick'

    'rubble-generated/multi-yzz7aoe/store/5t/d6/brk-5td6qvq3hkwnfc5vqh6lcuv5xlk5yh26d2esafb7byxkpwl6klua-gawk-5.3.1-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/5v/ex/brk-5vexncx3cian4rymupdaft3bwnvswvrzp6pcxohuilbll3lii53a-zstd-libs-1.5.6-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/5w/sm/brk-5wsmysbedc7wbcb22csq254i5hrsdbwpdwuzyi5seacce7a4iaoa-coreutils-sha512sum-9.5-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/5z/qz/brk-5zqzbtecxd2bwjpypfrcgfmzvuqihlmabhg5jtqztyhjc656maja-perl-5.40.4-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/72/75/brk-7275gbi26p7nwzbzemzdy6p5g2bg34i7k4itgjgkpamfuygljyta-patchelf.brick'

    'rubble-generated/multi-yzz7aoe/store/76/la/brk-76lao3bnpein6f4ggp4dwci7cdyywjnb5i7by4forhkbzf6lju6a-wasm-pack-0.15.0.brick'

    'rubble-generated/multi-yzz7aoe/store/77/pa/brk-77pafwgzhgk3kbtyd3i5bnikedwfoif6mfaibfesmfc655t35naq-libpsl-0.21.5-r3.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/7e/f7/brk-7ef7xmxyhyofo2jq4qz52u73byxo4p6jjnr2mtuy7d2hjidvrifq-rust-web-wasm-toolchain.brick'

    'rubble-generated/multi-yzz7aoe/store/7g/ai/brk-7gaiswvomctprmbv5i6dhxav3urpsmceezmwy52qv42yok44lygq-bash.brick'

    'rubble-generated/multi-yzz7aoe/store/7g/wd/brk-7gwdsqgvkrl5q7ztjhu2z65wbjt2eywqrtwg7xc7jewdoolhnmea-acl-libs-2.3.2-r1.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/7u/5d/brk-7u5doswc6jpjyxiiu2m7wgdgzzr76bhwplzdwyiio3de2qxgsj7q-linux-native-toolchain.brick'

    'rubble-generated/multi-yzz7aoe/store/ad/yk/brk-adykhpm55qerngmtx6ke7csou4r73gh5lnubblp7jj6ro4oeyxna-patch-2.7.6-r10.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/aq/c3/brk-aqc3c2ahmtsuu36l7kwk4q27mc7dnxuylxzqusvu3fp7rcurg5kq-rust-std-1.94.0.brick'

    'rubble-generated/multi-yzz7aoe/store/au/cx/brk-aucxmpgr2avv66dqgdnnrsotvckppunlmaswmfnflcktt4i5aaca-perl.brick'

    'rubble-generated/multi-yzz7aoe/store/ay/6k/brk-ay6kezqef2anhdm53akx7elc7ge7cmrhesutg3b6lzj2jolgnv2a-rust-std-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-yzz7aoe/store/b7/hd/brk-b7hdib2p2djrz7gu5mylkac6ijbvjwskm3shr5semy4ekaanow6q-c-ares-1.34.8-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/ba/io/brk-baio3rfxre2dwd25yxvlddjkceuobqewvbpv2viorb4hyksk5gzq-bun-1.4.3.brick'

    'rubble-generated/multi-yzz7aoe/store/bk/ru/brk-bkrucibifpoujfnutdgkpob2kchzsx7r4ni3mejwcvp2zyurwiha-gnu-tar.brick'

    'rubble-generated/multi-yzz7aoe/store/bs/cz/brk-bsczck3itaibqqkhhwkkzdh3fv5i477527aika7gfcttdyn6chhq-libgcc-14.2.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/by/lu/brk-bylu3g6upxzxamnew7hetpin3g47bzrxbhej2ejmeoeh57kg3jia-rubble-src-checkout.brick'

    'rubble-generated/multi-yzz7aoe/store/c3/xq/brk-c3xqnrandkmibb3fmyqvmmmdu6rs6474gsucktlplld3rafroq5q-gpatch.brick'

    'rubble-generated/multi-yzz7aoe/store/cm/da/brk-cmdaozrcvaymmdfw3jodg7rrc4qwmaqyx6q3jj6u6nsie32hvdxq-publish-output-directory.brick'

    'rubble-generated/multi-yzz7aoe/store/cn/su/brk-cnsuk57bulhj544m3skp3wwq4lsh5qegyneycg7bgfo2zzu5z7ua-coreutils-env-9.5-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/dc/7q/brk-dc7qtj7jms727isftojj6scxy5dtvk6sxndds5wdblbfjmti4diq-ca-certificates-bundle-20260909-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/de/fm/brk-defmfedonkfkblaqtfzjs7kvoq2u5k53xo3zzl43it7q634ax7ja-collect-shared-libraries.brick'

    'rubble-generated/multi-yzz7aoe/store/dk/ct/brk-dkctajvl2il4pypc32olxna3wh7rq2dnch3in6y6qkziz74prrka-zlib1g_1.3.dfsg_really1.3.1-1_b1_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/du/ql/brk-duqlm2zztlwilriz4qal3gvohwwknw5aua6kocf2xvqfrkvuunkq-gawk.brick'

    'rubble-generated/multi-yzz7aoe/store/dv/rl/brk-dvrllqig4vloxhgyjrmpzimbvdcatflu5xsgnfnhez77trxhzbaa-libcrypto3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/dx/bm/brk-dxbm5xbf7vkb35noka43so2duja6uw3kitmmhxbybcer6op5bcla-utmps-libs-0.1.2.3-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/e5/bi/brk-e5bidgxbvr5crgxvo3tckxld466txu5dxi674pplgncc4fifmkva-gdbm-1.24-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/e7/aw/brk-e7aw53vitgjqbosohujzxudnmbfqylyi27ehtmvbucoevvgocfoq-libsframe1_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/ea/y2/brk-eay2yd76jtq2n72kafauwkofupanezwq2muobm7bjlf6mfojk4ma-linux-libc-dev_6.12.86-1_all.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/ec/xk/brk-ecxkum7thkjwggmltz3jlz67amewczlvf6ybucueqawsamou6t4a-binutils-aarch64-linux-gnu_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/em/7m/brk-em7mxxxvm3fi5ntxzzlsqiwx6ckrpsjtig7bc4cnljdv3mgn3osq-nodejs-build-tools.brick'

    'rubble-generated/multi-yzz7aoe/store/em/on/brk-emonumondcre3b5pnxo4hp5dzwkoobjp7fi6ofxmqudceo4dxjnq-node-v22.22.3-linux-arm64.tar.xz.brick'

    'rubble-generated/multi-yzz7aoe/store/em/um/brk-emumr4qhmj3md4udqk36vvpcou3bcq2q6x47b2utro76mglanp6q-libffi-3.4.7-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/es/h7/brk-esh7pawc46nsh5b2uuykm4qsjsoowbes5uu4nt2kcg6hocags6vq-coreutils-9.5-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/es/iy/brk-esiyaxnxz3qbqhmjp3kjdfummyfpbmzr6eoub362jjpavkrlzyiq-pcre2-10.43-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/eu/id/brk-euidpfutoz56a7j3xxfr4jgcvmfj3hybkeku3a2k6fk3ktjr6j2a-gnu-sed.brick'

    'rubble-generated/multi-yzz7aoe/store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/ex/wh/brk-exwhj5vebfaduvvhd7f6xtppocqwgqam7csyi3u5434k3ypqofpq-libmpc3_1.3.1-1_b3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/f4/2p/brk-f42ppjfbnfjsed7bwyertmyxb2rwak677b54f7masrcakdbb725q-llvm-tools-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-yzz7aoe/store/fa/qk/brk-faqk22fjqryqxjx6pkufmb2mttau3gwuv2qu6roi3d4melszcu7q-libunistring-1.2-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/fb/xg/brk-fbxgu4t24gr47iq2yhyaygays2hvcmyidx4tkwjmlx52pttyr6yq-libasan8_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/fc/jh/brk-fcjhtbtyxa5qk3xy5jhazosrdwgn6npaqbjmm7dmyoi756zrunca-normalize-python-runtime.brick'

    'rubble-generated/multi-yzz7aoe/store/fd/jo/brk-fdjot6csltdy7pfpendap6yybjo5niybzp6knbofokgq7mxbz6kq-curl.brick'

    'rubble-generated/multi-yzz7aoe/store/fg/32/brk-fg32tsmkrioagedunckpr37qz35rn4b7obxt3wsbxx56ajpxviza-mpc1-1.3.1-r1.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/fg/l6/brk-fgl67yxmafgagbwsealbiks4426c2g2ecg227zr3infwmj7w632q-gzip.brick'

    'rubble-generated/multi-yzz7aoe/store/fu/4g/brk-fu4gjf2vujnnxzbws5i2w57yneqm7tmgiqzxodte6s6rf74vchrq-g__-14.2.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/fz/so/brk-fzsocvqoawb6atzh5tfjxgahm2yualfjxwxicd55hjyf4gfjo5da-libstdc__-dev-14.2.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/g3/c4/brk-g3c45ccdy6wpqvwoae6yeg5jp3makon7j3ziepadfbxgshp46zya-rubble.brick'

    'rubble-generated/multi-yzz7aoe/store/g3/fx/brk-g3fxen4ug3f3g34imdsefwplwd3ulzn75tn5uxd5jqe7t23bzyna-bash-linux-aarch64.brick'

    'rubble-generated/multi-yzz7aoe/store/g5/r5/brk-g5r5a7z3ismvnzq5uwsre6sfoiprc6smte4xd4jcchttjjvqidtq-xz-5.8.4-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/g7/dv/brk-g7dv6ga4ffezwkuapyxkkf6ffe7qb5m3ktlskq3tzjhcatiknfxa-python3-3.12.15-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/gb/4d/brk-gb4dlxkuu36d4olrckbxrdwlkvocpv2amucqerzpih2nv5w3uxuq-libstdc__6_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/gh/5l/brk-gh5luiujjjwwjlphcy6ab5aix5fxgjv7cuc4fbionmb25kjmw3sq-gawk.brick'

    'rubble-generated/multi-yzz7aoe/store/gp/d7/brk-gpd75vrjncv57fv3fzdfuoagqwgyqjwuizvdth2pdg7hv2q4lv5a-rubble-script-shebang.brick'

    'rubble-generated/multi-yzz7aoe/store/gr/yl/brk-gryl2ia5mgcretthghca7pk4azom5tikyd5smgjcdhayogowfnoq-RubbleR.git.partial.brick'

    'rubble-generated/multi-yzz7aoe/store/gs/he/brk-gshefcluy6kkjh2fphz6a4ef2opbn4ggm4tp6t5becfcg4tx5kxq-coreutils.brick'

    'rubble-generated/multi-yzz7aoe/store/gy/wk/brk-gywku76pr5etlbomvjxghttw6f6iygv424hoxpcb2v6c7ikp3vka-glibc-runtime-support.brick'

    'rubble-generated/multi-yzz7aoe/store/hd/hi/brk-hdhimhaqn7bul5k67m2gmw4ea6xibuprz2mgla5obsjibs7tfnoa-make-4.4.1-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/ho/55/brk-ho552ymbr5wqlkbb7xckcvqfjs5fd4ytbrf5rjp3vaqnwocxhx5q-gmp-6.3.0-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/hr/3g/brk-hr3gsmedt3iyx26xhety6rvbs2nzhv6o4oyscyt7qvuuixa7fbfa-libhwasan0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/hs/df/brk-hsdfhn2s3nbslevufmmcn6kbnfj6mhfk7j3pfo6arxghhl7lzkva-gzip.brick'

    'rubble-generated/multi-yzz7aoe/store/hw/ud/brk-hwudtbqp6mtqd433zl777ixamegzf5s6pqjc3vbkw4yy7ca6rpzq-libstdc__-14.2.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/i3/vz/brk-i3vzwzq5ceekylzear5wrwz4teano37g32htjtcd4rma3zvjzz3a-libgmp10_6.3.0_dfsg-3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/i6/rp/brk-i6rpnovdyaumnm4dbmqheqhnimae5nyro5b25ewahcsz4tksxefq-mpdecimal-4.0.0-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/ia/ii/brk-iaiiy6yxl2oc4o2ptmxc2yne2xfkig6dohqlc2vzwccr7vbuuv3a-llvm-tools-1.94.0.brick'

    'rubble-generated/multi-yzz7aoe/store/ik/gu/brk-ikguu3ujzdjtvrfcos6dnvmthv3wv266til6s4fxgi72c3ukzniq-gpatch.brick'

    'rubble-generated/multi-yzz7aoe/store/in/vn/brk-invn6jkeaqldpcy2drks3numpfd2akhcn3hj7w7mjzjfffsq6nca-rust-toolchain.brick'

    'rubble-generated/multi-yzz7aoe/store/is/xo/brk-isxo3o4skm7vtiqyhakx4x4uxrw7hnycm3ldwp43grskdhxl3qxq-sed-4.9-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/j5/gf/brk-j5gf2l63ovgx3lcwpqktvuftaley3gra2iqdbo2mrscdu5mmmpnq-rubble.brick'

    'rubble-generated/multi-yzz7aoe/store/ja/2g/brk-ja2gawpefozngsdbmzs5n2a66ujesjats2qcq7homnixclj6iqrq-grep-3.11-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/jb/55/brk-jb55xnscsoitwtv2ofozxwt7rgkazudm4j4bdys4wqnol6mgwz6a-rubble-elf-runtime.brick'

    'rubble-generated/multi-yzz7aoe/store/jg/4x/brk-jg4xyjlng4u4wq5madqqhtpqs5ftgbyd6i5sf35v7e5zxe5zqdga-perl.brick'

    'rubble-generated/multi-yzz7aoe/store/jn/3s/brk-jn3sp24cjtzterr3nitj2ca3kvd25oykmjbmxvtwqy5ydk57buqq-rubble-web-assets.brick'

    'rubble-generated/multi-yzz7aoe/store/jw/hf/brk-jwhfx26nkv24vmnfckbvccnpwdkzwfvxcjty7dhntghaemjlpfxq-mpfr4-4.2.1-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/jx/sl/brk-jxsldyydfcv7s5rykiti3q46xxqwonaiffipsyybjb7qlidaqs7q-zstd.brick'

    'rubble-generated/multi-yzz7aoe/store/k2/sq/brk-k2sq3ksyc4xg4n3byfvtc2xp2by5lw3uus2pjw4ro7y4ad54uo4q-coreutils-fmt-9.5-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/kf/5c/brk-kf5czgbhfrjlfvr54qqevkuwi43wqxq6nf25ih2xadevek5i2cpa-rustc-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-yzz7aoe/store/kk/zq/brk-kkzqrnwlzaepzs5ksyqjzc33rwhdpxtnpuzneqec35kqfzu53e5q-nodejs-runtime.brick'

    'rubble-generated/multi-yzz7aoe/store/km/24/brk-km24gkz4zqqu7uqftehftqfd26smur3oitfkvhpv35pqsc5llvca-cargo-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

    'rubble-generated/multi-yzz7aoe/store/ko/ve/brk-kovec6hpuborsbsvc7t6mvkfvwylfdlf4evnpad24hnwoyiflz5q-musl-dev-1.2.5-r11.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/kp/e7/brk-kpe7kma33nmt3mijbihbuzazuupuiq4ffqabvfgogzgs2rdp2rfa-libzstd1_1.5.7_dfsg-1_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/kq/oa/brk-kqoaqdowlcmrluolokiygo33evr47gordg5y3gqjf4etscxnee2a-libbz2-1.0.8-r6.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/kr/tc/brk-krtc32gkhzcn3spc36a3ksbyjoykekcsx7bvmzj2mrxcmaxral2q-write-exec-wrappers.brick'

    'rubble-generated/multi-yzz7aoe/store/ks/6e/brk-ks6e3u26mzxm5dwrtt4v2y5z6hltzyyoqnn5v36ctpuvq3z5ebga-libgomp1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/kt/bd/brk-ktbdwi3xid4ywlz6il2qlgx67aclu2t5gljy527g7vdnv6h7gaha-jansson-2.14-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/lb/7v/brk-lb7vuv6w3fr43o73swpjgwfuwdhyi7l2xskuuisw3eaekunxv3ia-libc6-dev_2.41-12_deb13u3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/le/tq/brk-letq76lhfq5ndp6nbitxx5a27jnpa7phrtjfrkoukt4zxbvok25a-gnu-make.brick'

    'rubble-generated/multi-yzz7aoe/store/lx/fb/brk-lxfbn4ov2wwftycfh6ez24nierxyz26wwgpjgg4jvt5joc3tpssq-bison.brick'

    'rubble-generated/multi-yzz7aoe/store/m5/ln/brk-m5lnpllbzm555r5zuagxbaoqomumjvcwyoq7xdkffysmdvteelwa-findutils-4.10.0-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/mf/wk/brk-mfwkvtv3n6hvvrci2nxbilte5df2wpayqreolg3t5xnlwedydz2q-libmpfr6_4.2.2-1_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/mg/vp/brk-mgvpjsbz7sujl5qdndfmqhtclpxfhlytkeyidejyjfez5jloit7a-g__-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/mk/i3/brk-mki3d43v2mfozu5xz3vodavqdr6muboif46l2vdzynk6z5spejwa-bzip2.brick'

    'rubble-generated/multi-yzz7aoe/store/ml/x5/brk-mlx562fytg425dlvai5udxsucvfyhb7564wogvqth6dqvocdsjfa-bzip2.brick'

    'rubble-generated/multi-yzz7aoe/store/mv/w4/brk-mvw4balnruevggsruaxcd7m3dye6dlbrsjshobcplnic3svvd4rq-ld-musl.so.brick'

    'rubble-generated/multi-yzz7aoe/store/n6/vt/brk-n6vtqu3bxkksa6hlrwirri6entermnuofp2sdqcfcrzxarqrr3hq-isl26-0.26-r1.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/n7/qb/brk-n7qbevbly56oq5vdzjm2bzhl77wjewdp4k5gmoimlbiv62nbv7pa-bash.brick'

    'rubble-generated/multi-yzz7aoe/store/na/a2/brk-naa2ad3mxbwsl6syyyeikeu6srwar3mxn4lv6faf72kx6hjpq72q-libgomp-14.2.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/ng/2y/brk-ng2yhab3txqyfgtnrgwttzyliczkrx52jeu7skkoaxeu5d752ynq-libncursesw-6.5_p20241006-r3.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/nt/63/brk-nt63tolwoibaqamxksxcd3tkkc4agjzei5z33bc5x6aehfnbcm3a-gcc.brick'

    'rubble-generated/multi-yzz7aoe/store/nw/ad/brk-nwadxrnuk7cydd6sigwmkqkyyxpkgj3b7bfoyhol66daeqo4rfka-rust-std-1.94.0-wasm32-unknown-unknown.tar.xz.brick'

    'rubble-generated/multi-yzz7aoe/store/nw/jn/brk-nwjntcya5bc7tfxrl5i22jo3v2rnlixwjc6ri3r4kwupxtwlaqsa-cpp-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/ny/xv/brk-nyxvd2fuotdmxjktenzudif5x5zq2d5ohtbciy4t5ztyf7b7x2fq-ca-certificates.pem.brick'

    'rubble-generated/multi-yzz7aoe/store/nz/e6/brk-nze6quyczuuey2d75ly265bhtvdmbxfh2czn6qu2zvnvswvkpr6q-nodejs.brick'

    'rubble-generated/multi-yzz7aoe/store/o4/ts/brk-o4tslxh2uwmqgfv6heppd5d4xitkk6jpu773b5ok4dojf4pfzlia-write-native-toolchain-env.brick'

    'rubble-generated/multi-yzz7aoe/store/o6/7s/brk-o67s3e3gl3idnjvkjvaxeg4g2bzcssmh6p2amlecfltkaeo65bla-bun-1.4.3.brick'

    'rubble-generated/multi-yzz7aoe/store/od/lz/brk-odlzblejigvixnek4zw3qpf6kdmpduizlfdol6phkrwrrltm3kdq-libc6_2.41-12_deb13u3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/oe/dx/brk-oedx42pgtkscsyrm2vn6hyrci7hw74ladlpu6f6bwgt5yguhmyqq-m4-1.4.19-r3.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/oh/zg/brk-ohzg3khe3y5zbg6it742hi63cwoz7k3vbr5jufkccupj4kcrkpwq-curl-linux-aarch64-musl-8.18.0.tar.xz.brick'

    'rubble-generated/multi-yzz7aoe/store/ov/g7/brk-ovg7cu6kkazcpj32mrk53yc3kb2z2mrl4yd5yzrj3uytgwcanawa-curl.brick'

    'rubble-generated/multi-yzz7aoe/store/ow/oy/brk-owoyhne4rlabd6ti2usbbxf5qm6px4edpaa2ixltmg55lde2ckuq-sqlite-libs-3.48.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/p4/37/brk-p437dghiaad2yb57qr2yhpsmwaw3z3jwfkdlsqaf6pgahrueysja-zstd-1.5.6-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/p6/eq/brk-p6eqluqrei7jxrpnr2nogcmndvhzkr37f2j47nrfkscrbtnpy64q-libssl3-3.3.7-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/pf/23/brk-pf23vjdt5khb6uuwsl6krlhhop4j5q4ijtiuqejx6cerrhs4xe3a-unzip.brick'

    'rubble-generated/multi-yzz7aoe/store/pj/6o/brk-pj6ok275ispcmivb4gpez2bzug46p2ge6a7pd3dncpfzelwebihq-liblsan0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/pj/yp/brk-pjypf4uv57deopm7hfvvsqswkawdtufwo6agetigpgbq7hhsorxq-findutils.brick'

    'rubble-generated/multi-yzz7aoe/store/pt/g4/brk-ptg4o4phfr2eutq2xrcoqi6zx2d2rk4nqoxdm73hvskgosibuh4a-tar-1.35-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/q4/he/brk-q4herzcgnjixdz2whd2wgrihqnubtbsoo3sroce3nyiqb3vqtrua-RubbleR.git.partial.brick'

    'rubble-generated/multi-yzz7aoe/store/q6/6x/brk-q66xooc3uyetlxp6565oyihya5babf4sn3opal27qo6em5wjkuca-gcc-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/qb/rl/brk-qbrlu376mq3m5jhng65mdeobdbrpjzv3thrthfrpvoam77zovt3q-patchelf-0.18.0-aarch64.tar.gz.brick'

    'rubble-generated/multi-yzz7aoe/store/qg/3g/brk-qg3g2dinqfibxj3dkbjqgp6q4vhezm2w5ayy7ibamcbqov7sunuq-git-2.47.3-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/qm/dv/brk-qmdv4se7cy5zxuxhuq6la3h562eim3kyrj3eud44s2njzmqn3mlq-libpanelw-6.5_p20241006-r3.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/qn/3l/brk-qn3lywhoc2dno3mvjvoq3mihzjcc6yz76oy3bvxnhgrsw5ewd7xq-libtsan2_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/qs/3n/brk-qs3nb5qcclaodccu6unqj42b76lly2d4htpputfm77xzao6fzema-musl-1.2.5-r11.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/qv/xc/brk-qvxcj4lj5jj5mbgvpcfw5svnfaljwbkil7ghzzofovoqehagqava-diffutils-3.10-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/qx/xt/brk-qxxt6f726go3553r3bhxadzrgj637yghleeivlrsywklrpcr3pnq-libitm1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/r3/ds/brk-r3dsohwjen4ivihkyzp2cakaukqzwyexk4wfjwqrqn2q5v57x4sq-grep.brick'

    'rubble-generated/multi-yzz7aoe/store/ra/hs/brk-rahsd4zwjfabkusmfq57a4dscw4kbk5gxngesfsmxcxxmsfyp35q-bootstrap-env.brick'

    'rubble-generated/multi-yzz7aoe/store/rf/6q/brk-rf6qd62cvory4e6kjkwmrjxyilqzwizbir4a5wl7co226g7fdmtq-xz.brick'

    'rubble-generated/multi-yzz7aoe/store/rg/ds/brk-rgdskue4seruek4fxopdeftkm4uf7jxa7nxjyqkhkj5yak2ebc4a-gcc-14-base_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/rm/4z/brk-rm4zxsn5qycajrfwexlu4perkspongbyp6ae77564am5knq453wa-libgcc-14-dev_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/s3/pv/brk-s3pvvtqxrdzleije623ea64covxuywd4s6akx2d5lpxokyytr4ea-libidn2-2.3.7-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/sa/xd/brk-saxdsta5ltm7iomdgyx3f23uma6qmu7hz674djpkjgbgi76tsisa-gcc-14.2.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/sb/64/brk-sb64ioyugaehkllixkmpaka2hdzbubj3yiepjnya65eyzamkmpda-gcc-glibc.brick'

    'rubble-generated/multi-yzz7aoe/store/sb/p2/brk-sbp2cshyiejko2u3bh7yyrbnmudme6jmrk3ai2577nndvbmj5qvq-bootstrap-env.brick'

    'rubble-generated/multi-yzz7aoe/store/sg/22/brk-sg22i4opdq454yvxpsldgfkwjuypnst27lluytpeon55arrj7k2q-zstd.brick'

    'rubble-generated/multi-yzz7aoe/store/sg/dy/brk-sgdyuezwsbzpgusurjxb7bvquikinj455qz7q5c2emyrynor4f3q-binutils-2.43.1-r3.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/si/6n/brk-si6nyn5fdb3ti7j4mrkcpn3ilq2irsteztsfw2kfd24nd7qmrx4a-findutils.brick'

    'rubble-generated/multi-yzz7aoe/store/sl/7z/brk-sl7zsbzcfjdoz6ohe72ecirudxewciohnjumdqn7bkuunn2hp5lq-libstdc__-14-dev_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/sm/ef/brk-smefglijvfslmn2xkdzvh5wgvyw2re7ltujawll63ioiowgaathq-gnu-sed.brick'

    'rubble-generated/multi-yzz7aoe/store/so/zc/brk-sozcnlol642zf43ubwvnmsk2w4xpynrnebhiy2xefdy4kuy5jajq-wasm-bindgen-cli-0.2.115.brick'

    'rubble-generated/multi-yzz7aoe/store/sw/pr/brk-swpr75bcyzcrbxyesubbc2rbt2m5qbeeuxkb654s6br5k4jylfaa-xz.brick'

    'rubble-generated/multi-yzz7aoe/store/ta/cn/brk-tacnuufbmsgvjjdv35jnlei72ofv46gglzsjzt76wnp6nf7qphdq-binaryen-117.brick'

    'rubble-generated/multi-yzz7aoe/store/tp/ql/brk-tpqlnp3dvgnq36l5ubgs4c2ficukfs4d4v3nllkbxjvgoluw4eta-libcurl-8.14.1-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/tt/xo/brk-ttxoxb3lfk7t3rzpgq4m42lsl7lmgzt2e5w5pdt6rxna3q6pulra-skalibs-libs-2.14.3.0-r0.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/tu/ym/brk-tuymn44julj3gy4btic7qvuk55uy2wcw5papd4bqlmikb46qnmmq-git.brick'

    'rubble-generated/multi-yzz7aoe/store/tx/mz/brk-txmznhwijz6pz7m652w5pqqlymsnvboo2rsvqqwp7jprcfm6cw4a-zlib-1.3.2-r1.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/tx/xx/brk-txxxkk3synyqsaxa2kpishc2fltzecdbydtpqxxhupczprrfjuha-rubble-deps-cache.brick'

    'rubble-generated/multi-yzz7aoe/store/ty/qo/brk-tyqosp4fpdd7pjacveojot6m2g5ls3hqljfqp4qerplz2kuwcvua-musl-install-tools.brick'

    'rubble-generated/multi-yzz7aoe/store/uv/sb/brk-uvsbyovw5cc5kbfvzvvs54et2nt26vvmy3bwb6yhvrvlfblqpmkq-rubble-web-node-modules.brick'

    'rubble-generated/multi-yzz7aoe/store/uy/js/brk-uyjsp4ouuc5rwiwdnqimjbiittyoyvx5vzdamkdqenaf4fazaj4q-cargo-1.94.0.brick'

    'rubble-generated/multi-yzz7aoe/store/vb/te/brk-vbtevx2mawx5viwt7bvre4owl56p5ocnksz6mdpdxibb3eefzzzq-RubbleR.git.partial.brick'

    'rubble-generated/multi-yzz7aoe/store/vq/3s/brk-vq3sirpitu5prsi2ig3ld3d7am7x6cxjxscc4qchsiecywgz3bfa-libatomic-14.2.0-r4.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/vs/wq/brk-vswqqehwz73whpxezmbr7nf4anbs7slwoknh6pi76q7askntz5iq-libctf-nobfd0_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/vv/vd/brk-vvvdnsecu6lpcglwdf3caq5z2e7kht7mznem2pe2cmicv6r47eca-m4.brick'

    'rubble-generated/multi-yzz7aoe/store/wd/yz/brk-wdyz3is2b6mebmuvspxovh65zqtb7etghgqare6skzmkwr3uzewa-rustc-1.94.0.brick'

    'rubble-generated/multi-yzz7aoe/store/wj/ui/brk-wjui6krvqdbuwumfp2qweb7n2uolcwz2ajuyvkq3ld4dyp6lcz7q-grep.brick'

    'rubble-generated/multi-yzz7aoe/store/ws/jd/brk-wsjd6bhyeay7o42k276g7ep5plfqmlqubqztlvbu5aw7rjjeuq2a-gzip-1.13-r1.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/wx/52/brk-wx522xces6aeljkz5y55o6kdkgi6zgyvebi63xgqxclodxabs56q-libatomic1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/x7/qx/brk-x7qxtfi2npyewp64xdyhckglv5hrtv2qiahanhiw5vjsyqh7hxlq-RubbleR.git.partial.brick'

    'rubble-generated/multi-yzz7aoe/store/xa/vn/brk-xavn33v6xwtxgf7j7snhvwd5urqxswa4c2d2hxtjxjza37nizg4a-libctf0_2.44-3_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/yb/6t/brk-yb6tefhslyriibghffdurwb2wvapj6x3xizoboao2doaj7v7xgda-libcc1-0_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/yg/oa/brk-ygoaz524fbxylyorentj3kdcspsb7r5g4qau6goj5gbboocuupsq-glibc-runtime-support.brick'

    'rubble-generated/multi-yzz7aoe/store/yh/uw/brk-yhuwpmx2juvfpkppkzsxtwbmldgxa7jg2xvaete5siwflujtfkyq-gcc.brick'

    'rubble-generated/multi-yzz7aoe/store/yh/wd/brk-yhwdxhsr3hp4yp25qou4lxwmobx7wgru5jg6gr7f2yh6zwblmdjq-diffutils.brick'

    'rubble-generated/multi-yzz7aoe/store/yi/gm/brk-yigmijc5ij3rpsaberwyafdvndneutsn76xdruhwjcug2zlebmqq-rust-std-1.94.0-wasm32-unknown-unknown.brick'

    'rubble-generated/multi-yzz7aoe/store/yj/t3/brk-yjt3yx4qjiz5tmd2ffbhlr7bzhzfsqrwwjogtydtjn5spt4wxzda-unzip.brick'

    'rubble-generated/multi-yzz7aoe/store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/yw/ic/brk-ywic3uxzmw46mvwd7ot7xsqot6z2vazpoiil7cevxamibahulkxq-RubbleR.git.brick'

    'rubble-generated/multi-yzz7aoe/store/yw/tw/brk-ywtwqdahjrlxhzaik2lp5pbtsh5orqweuqdwhjjutxgbd7kz2apq-rubble-elf-runtime.brick'

    'rubble-generated/multi-yzz7aoe/store/z3/xh/brk-z3xhjdr5it75lq5iwals4toaklhutksbdphbucgwhtgqhxz32k6q-ld-musl.so.brick'

    'rubble-generated/multi-yzz7aoe/store/za/b7/brk-zab7x4pj4e4cmrnw753rp5hyl7jadtxtfddargzdbkkqoq2k7uwq-libubsan1_14.2.0-19_arm64.deb.brick'

    'rubble-generated/multi-yzz7aoe/store/zg/pt/brk-zgptfa36kfu3onwxjxeqkaekqliwbsazdezeyj6kzyebldtz4oca-diffutils.brick'

    'rubble-generated/multi-yzz7aoe/store/zj/i5/brk-zji5om2su2ddkysxsg3xzzbvx7uvgespdsko7wze2bovygtgnuzq-ca-certificates.pem.brick'

    'rubble-generated/multi-yzz7aoe/store/zl/43/brk-zl432u5pf5qal6yaxxq73s5wxeul7qmewu6y7qcydvb2rrkr77pq-gnu-tar.brick'

    'rubble-generated/multi-yzz7aoe/store/zm/2b/brk-zm2bpcu5lxnkvg3jntp5l3mmr5l7cvaqc27gswsvtwvjusugmqta-wasm-bindgen-0.2.115-aarch64-unknown-linux-gnu.tar.gz.brick'

    'rubble-generated/multi-yzz7aoe/store/zq/h6/brk-zqh6lunhozithbpfnbwqg5j54lg5ze77yzuwedmjltfo45ghffuq-binaryen-version_117-aarch64-linux.tar.gz.brick'

    'rubble-generated/multi-yzz7aoe/store/zr/7s/brk-zr7ser4omrmjwzjfkik44mdmgvtrjakkpkcqq4llvhfrke2n6sma-brotli-libs-1.1.0-r2.apk.brick'

    'rubble-generated/multi-yzz7aoe/store/zw/da/brk-zwdawolcw4fqjnlmmwfrxjwrxcplq7t3jb73x5seskofbtj353na-libattr-2.5.2-r2.apk.brick'

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