#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source "${RUBBLE_GITHUB_ACTIONS_RUNTIME:?}"
if ! rubble_hook_present prepare-release; then
  printf '[github-actions-release] prepare-release hook is absent or empty; skipping\n' >&2
  exit 0
fi

release_dir="$(rubble-exec mktemp -d "${RUNNER_TEMP:?}/rubble-release.XXXXXXXX")"
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

  'store/4z/45/brk-4z45nx65xw3y3yxdn5rw2qf5jwclaclnqqfhofeig6xotqxb7ajq-patchelf.brick'

  'store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

  'store/wq/ck/brk-wqckb6fysqnzuzmnm3hrgnie52iiuwqibunb222ynntml7x5lxjq-zstd.brick'

  'store/bc/kp/brk-bckpkewd24sqpe6rkydj4yn3u2zzm2fpcukdzgimleqxusuefnyq-xz.brick'

  'store/bb/3w/brk-bb3woz66hfzaf7nxyfp5ihp6vxai7te2ymga2i65rr4rqmaipiyq-unzip.brick'

  'store/st/lj/brk-stljkkdnfyucz33nxoovmbhimt6ff63ihoue4xv5uddik7it2v2q-m4.brick'

  'store/po/br/brk-pobrsy2ju6afixohsh7wvks3aeccssrma4wwzy7ovmfg5qcucf7a-gzip.brick'

  'store/en/i6/brk-eni6622eybzafiaivzmic5h3itxj6zsfrz2e7ifzoe2zlab25wua-grep.brick'

  'store/rt/t7/brk-rtt7zlxbdwlqvf6xcv3ibd2j72sav5aq7a4osmz6in3hijdh67va-gpatch.brick'

  'store/gm/ie/brk-gmiepopf36g4nt4bgf2k6ydxwomd3eahnlg5kzfd7itw6you5ynq-gnu-sed.brick'

  'store/bn/h6/brk-bnh6a6xptku7pe37i7fyefxb3jn2eepsszqlp2xhok35cgvfhxuq-gnu-make.brick'

  'store/x5/qv/brk-x5qvjdfenrs6bc4xuttjluurx6ow3aj326m5ay6ni2ezq2u757va-gawk.brick'

  'store/ws/zc/brk-wszckkjwj7owe2w6seb3pficxwimbmjwkoqsa6m46ki64ujgqz2q-findutils.brick'

  'store/n2/y6/brk-n2y6cwlexb642nzfj7px6pn7pantf4zaw6mtlfscqidlarztalxq-diffutils.brick'

  'store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'store/pf/ct/brk-pfctzr6y2rty63c32st2rmmgrexbnfrdgt2iic4na3bctqmrwoea-bzip2.brick'

  'store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'store/oo/lq/brk-oolqu2vtbb4frcjavzuszx435gk62yg4qby6szr2w6rv4zzuj3zq-perl.brick'

  'store/l5/ca/brk-l5cahjri52ofysycyibbzhr65aq4t6tyjkqtpvxk3d6oxuxjm4fa-git.brick'

  'store/ic/3m/brk-ic3mcp6r2byudz4wwzrzs7ld3te3lmfdcopyerhhnjybz6b4gz5q-gcc.brick'

  'store/wk/al/brk-wkalziix43j55svwzjj2vbsjfaxxnqhhshnnfcz2v3dnih4fcqha-bison.brick'

  'store/jf/ai/brk-jfai7zz72pherkoxskwv2r6de64ms2lv7eetewbbhcemhfmvu7sq-gnu-tar.brick'

  'store/72/mk/brk-72mkfvxl5mmbm7vwb7lqf2zdm4fspzwzv2cmpnsrum2l4c77u5cq-coreutils.brick'

  'store/od/zc/brk-odzciqpr5fl5qqpdqnohs7qpqqwvahqodbydsv7er2ztrfnfhbuq-bootstrap-env.brick'

  'store/mo/dx/brk-modxqyxhoi2teskd4wu75p6pkquxmwjxnuq2zsjl3lm66o2dbhtq-rubble-elf-runtime.brick'

  'store/dm/sg/brk-dmsgfhvob3pdpiukrljf5s3ktrdwdzr3jaerijvrtfudntru2ksa-rust-toolchain.brick'

  'store/op/z3/brk-opz3r6tpol44zcnet7hgpade5bwepv4e5ahgkc2qgc3pa66ajgwq-bun-1.4.2.brick'

  'store/fm/yg/brk-fmygahk5j3smbzx2qm2ywzls5bqlfiq4cyopw4wb7biwzc2ygl2a-rubble-deps-cache.brick'

  'store/oo/l5/brk-ool5ve77mq2ekbsqilk6maad7ojuuk4qeyahm36xvhltnqcpbhgq-RubbleR.git.brick'

  'store/63/3c/brk-633ce32zh3iodyjv7gefxxwbtyafjc4g3pmbioy6h2cyjkqehiya-rubble-web-assets.brick'

  'store/ho/hr/brk-hohriqulrt66q27rx6zra3ftyp6sev6jhnmmpmyhefrss5iewv2a-rubble.brick'

)
for relative in "${release_brick_files[@]}"; do
  "${rubble}" -q pull --depth 1 --unpack -r "${RUBBLE_REMOTE_STORE}" "${script_dir}/${relative}"
done
rubble_run_hook prepare-release

shopt -s nullglob dotglob
assets=()
for asset in "${release_dir}/assets/"*; do
  [[ -f "${asset}" && ! -L "${asset}" ]] && assets+=("${asset}")
done
if ((${#assets[@]} == 0)); then
  printf '[github-actions-release] no prepared assets; skipping\n' >&2
  exit 0
fi

export RUBBLE_GITHUB_CLI="${rubble_runner_commands[gh]:?runner gh command is required}"
publish_relative='publish-release.mjs'
"${rubble}" -q script --inherit-env "${script_dir}/${publish_relative}"
rubble_run_hook post-release