#!/usr/bin/bash
set -euo pipefail
IFS=$'\n\t'

log() {
  printf '[github-actions-release] %s\n' "$1" >&2
}

fail() {
  log "ERROR: $1"
  exit 1
}

required_env() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "${value}" ]] || fail "${name} is required"
  printf '%s\n' "${value}"
}

required_command_file() {
  local name="$1"
  local path="$2"
  [[ -f "${path}" && -x "${path}" ]] || \
    fail "declared runner command '${name}' is unavailable or not an executable regular file: ${path}"
  log "runner command verified: ${name}=${path}"
}

runner_bash='/usr/bin/bash'
runner_date='/usr/bin/date'
runner_dirname='/usr/bin/dirname'
runner_gh='/usr/bin/gh'
runner_mkdir='/usr/bin/mkdir'
required_command_file 'bash' "${runner_bash}"
required_command_file 'date' "${runner_date}"
required_command_file 'dirname' "${runner_dirname}"
required_command_file 'gh' "${runner_gh}"
required_command_file 'mkdir' "${runner_mkdir}"

script_dir="$(builtin cd "$("${runner_dirname}" "${BASH_SOURCE[0]}")" && builtin pwd)"
root_id='rdy6ndb3g2grclnagvl6ed3oc3xncppjojeclvbl66r4pbmp44tq-rubble'
root_name='rubble'
root_brick_relative='store/rd/y6/brk-rdy6ndb3g2grclnagvl6ed3oc3xncppjojeclvbl66r4pbmp44tq-rubble.brick'
release_inventory_relative='release-inventory.txt'
release_bundle_relative='release-bundle.sh'
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

  'store/66/xj/brk-66xjeza4g7ocenr6tbx4qdpe37dfjx67jgm36ezdopq52ag3icfa-rubble-deps-cache.brick'

  'store/em/rh/brk-emrh5fmcrvfecx4igyim44zmaphxdb6wuhai4relo7i26huvmniq-RubbleR.git.brick'

  'store/uj/yv/brk-ujyvxw5cg2wow4xk5hjif7a4gzlkmnziasveecpzq4pkcuvwpofq-rubble-web-assets.brick'

  'store/rd/y6/brk-rdy6ndb3g2grclnagvl6ed3oc3xncppjojeclvbl66r4pbmp44tq-rubble.brick'

)
root_brick="${script_dir}/${root_brick_relative}"
release_inventory="${script_dir}/${release_inventory_relative}"
release_bundle="${script_dir}/${release_bundle_relative}"
root_hash="${root_id%%-*}"
rubble="$(required_env RUBBLE_EXECUTABLE)"
config_file="$(required_env RUBBLE_CONFIG)"
rubble_home="$(required_env RUBBLE_HOME)"
runner_temp="$(required_env RUNNER_TEMP)"
repository="$(required_env GITHUB_REPOSITORY)"
run_id="$(required_env GITHUB_RUN_ID)"
run_attempt="$(required_env GITHUB_RUN_ATTEMPT)"
required_env GH_TOKEN >/dev/null
[[ -f "${rubble}" && -x "${rubble}" ]] || fail "Rubble executable not found: ${rubble}"
[[ -f "${root_brick}" ]] || fail "root Brick file not found: ${root_brick}"
[[ -f "${release_inventory}" ]] || fail "release inventory not found: ${release_inventory}"
[[ -f "${release_bundle}" ]] || fail "release bundle script not found: ${release_bundle}"

for release_brick_relative in "${release_brick_files[@]}"; do
  release_brick="${script_dir}/${release_brick_relative}"
  [[ -f "${release_brick}" ]] || fail "selected release Brick file not found: ${release_brick}"
  log "pulling and unpacking selected release Brick outputs at depth 1: ${release_brick}"
  "${rubble}" -q pull \
    --rubble-home "${rubble_home}" \
    --depth 1 \
    --unpack \
    -r default \
    "${release_brick}"
done

release_dir="${runner_temp}/rubble-release"
bundle="${release_dir}/${root_hash:0:7}-${root_name}.tar"
"${runner_mkdir}" -p "${release_dir}"

log "exporting root inventory bundle ${root_id}"
RUBBLE_EXECUTABLE="${rubble}" \
RUBBLE_CONFIG="${config_file}" \
RUBBLE_HOME="${rubble_home}" \
"${runner_bash}" "${release_bundle}" export \
  --output "${bundle}" \
  --depth 0 \
  --inventory-file "${release_inventory}" \
  "${root_brick}"
[[ -s "${bundle}" ]] || fail "exported root inventory bundle is empty: ${bundle}"

release_name="$("${runner_date}" -u +'%Y%m%d%H%M%S')"
release_tag="${release_name}-${run_id}-${run_attempt}"
log "creating GitHub release ${release_name} for ${root_id}"
"${runner_gh}" release create "${release_tag}" \
  --repo "${repository}" \
  --title "${release_name}" \
  --notes "Rubble inventory bundle for ${root_id}" \
  "${bundle}"
log "GitHub release ${release_name} created with asset ${bundle##*/}"