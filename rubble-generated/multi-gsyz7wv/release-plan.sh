#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source "${RUBBLE_CI_RUNTIME:?}"
if ! rubble_hook_present prepare-release; then
  printf '[remote-release] prepare-release hook is absent or empty; skipping\n' >&2
  exit 0
fi

release_dir="$(rubble-exec mktemp -d "${RUBBLE_JOB_TEMP:?}/rubble-release.XXXXXXXX")"
export RUBBLE_RELEASE_DIR="${release_dir}"
cleanup_release() {
  local status=$?
  trap - EXIT
  if ! rubble-exec rm -rf -- "${release_dir}"; then
    ((status != 0)) || status=1
  fi
  exit "${status}"
}
trap cleanup_release EXIT
rubble-exec mkdir -p -- "${release_dir}/assets"

script_dir="$(builtin cd -- "$(rubble-exec dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
release_brick_files=(

  'store/zt/bw/brk-ztbwuqmg77pfi6tzkoy4asfmpiy22x6lugzprlhhhvjldam36n4q-rubble-script-shebang.brick'

  'store/cn/de/brk-cndex52rgwiybhxcbkpry2isc55dz3hrc5lblmzr3xyeilghixda-patchelf.brick'

  'store/qs/3n/brk-qs3nb5qcclaodccu6unqj42b76lly2d4htpputfm77xzao6fzema-musl-1.2.5-r11.apk.brick'

  'store/oe/dx/brk-oedx42pgtkscsyrm2vn6hyrci7hw74ladlpu6f6bwgt5yguhmyqq-m4-1.4.19-r3.apk.brick'

  'store/65/xn/brk-65xn763kfhf7ye2ax5rr3hjotrij3qjagkddvfhqarwrt2a7mnha-ld-musl.so.brick'

  'store/s4/36/brk-s436fi4eiqcbgfl3sxxy6qiehrwo3ytnrcmp3s4u5meq6dlhmola-m4.brick'

  'store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

  'store/7f/cr/brk-7fcrm7iiq4agepnnbu46kixt3exop6fqy2ylv34zgifmrjjckczq-bzip2.brick'

  'store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

  'store/g3/fx/brk-g3fxen4ug3f3g34imdsefwplwd3ulzn75tn5uxd5jqe7t23bzyna-bash-linux-aarch64.brick'

  'store/ye/cb/brk-yecbppbe2hram3gythftkgn6mwelxq6l42vejdrjy3czbotcwmoq-bash.brick'

  'store/iu/rp/brk-iurpgonnj2ueak3ta44zihvtdksmjx5j62dy7n2ebbd7pdb3lfja-bison.brick'

)
for relative in "${release_brick_files[@]}"; do
  "${rubble}" --no-banner pull --depth 1 --unpack -r "${RUBBLE_REMOTE_STORE}" "${script_dir}/${relative}"
done
rubble_run_hook prepare-release

shopt -s nullglob dotglob
assets=()
for asset in "${release_dir}/assets/"*; do
  [[ -f "${asset}" && ! -L "${asset}" ]] && assets+=("${asset}")
done
if ((${#assets[@]} == 0)); then
  printf '[remote-release] no prepared assets; skipping\n' >&2
  exit 0
fi

user_release_relative='../../.rubble/release.sh'
if [[ -s "${script_dir}/${user_release_relative}" ]]; then
  "${rubble}" script --inherit-env "${script_dir}/${user_release_relative}"
fi