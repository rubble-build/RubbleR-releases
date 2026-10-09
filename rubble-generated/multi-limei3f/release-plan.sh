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

  'store/65/xn/brk-65xn763kfhf7ye2ax5rr3hjotrij3qjagkddvfhqarwrt2a7mnha-ld-musl.so.brick'

  'store/yl/jj/brk-yljjczaoyyqoq3m3kpsb4qnstspo3tycxc2fpba2gy4nc6ce65jq-zstd.brick'

  'store/2x/aq/brk-2xaqevxoue23okhcyevnonaeyau647anq5qe4nd272iofalgp2ya-xz.brick'

  'store/zb/oo/brk-zboovzrp3boiy63gwm32ibubobt4wvehbe4rt4yqzftypyvxetla-unzip.brick'

  'store/7q/4l/brk-7q4ljuzbhcvgmwtdlgcqloabbwtmonqipwuxkpv7kej5e5bung2a-m4.brick'

  'store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

  'store/5f/ud/brk-5fudmucn3hvy3icb6e3k4a6cvdqzpewlgzjqfojsvrpkytuy5nna-zstd.brick'

  'store/cr/nw/brk-crnwqzb6rvjywhycjdmnlxwfinfzgr2nqpfu4o5xxvn7n55lmqva-xz.brick'

  'store/gh/7s/brk-gh7s5ubsyy5hq7tz2nxnqk63nkltvxmgsmqvaiz7dflj2bthgxgq-unzip.brick'

  'store/nq/to/brk-nqtotecghxwzh3rn6cj4syyu3ary6z7gvpommrcygayky7yerbiq-m4.brick'

  'store/mn/tw/brk-mntwl3ijgyyni3rz7tnm25uavccs64wnoqxi6tswq6v3v4enc4bq-gzip.brick'

  'store/yj/p2/brk-yjp24zdh4gi64ec4qz232quwujkbijecntx37fvj5spvlkuqvn2a-gzip.brick'

  'store/ny/m5/brk-nym5rumztuo443j6jodlaz243b7rifksbzmicvlqaageqnfrppva-grep.brick'

  'store/wk/vm/brk-wkvmcan7p2iuhnys5jhmvjhwje2gexvx37ept4kun7td6dt2jp4q-grep.brick'

  'store/gm/62/brk-gm62dcc7oanvf6pvef6m5lcyzxdbp5b3qe57rb3js7sss4vukjka-gpatch.brick'

  'store/mc/eh/brk-mcehjsnd6c44hkh6aybb3fcusdfxwcu2mmzmhuyvhg6qhec5yapa-gpatch.brick'

  'store/zs/in/brk-zsinhazapn2veaih52jxuezaslxcjtrt6nafubyxjqz3joee57ca-gnu-sed.brick'

  'store/v4/3b/brk-v43bd3czplropwap7voojb6bv3uw6cx5nbhblbnpod5rkxjhuebq-gnu-sed.brick'

  'store/f6/a7/brk-f6a7sajqali7f47k3swxnxmsq3peovl5ykpvzt33zpf5t52t6g5a-gnu-make.brick'

  'store/eo/2o/brk-eo2opoxn4hmzc3qxtlydlbszxwcv7gibdkulpfmkfziybocjbeba-gnu-make.brick'

  'store/s7/pe/brk-s7pepykzvm4rodcuz2lqdnnti25ivmyn6hvaualljcja4pmqrjkq-gawk.brick'

  'store/qs/xv/brk-qsxvdk3agpg6ikdoivzkz2bs2aqqxoyjclqwdbl7vrkse363dofq-gawk.brick'

  'store/ra/4g/brk-ra4gv7ib6y4ulchvtczh5wnhli33mvem74j54eapirukl5af5twq-findutils.brick'

  'store/46/xw/brk-46xwv4ctgwq2n2jt7ex4x7bsznc55f2z7yykja7yhdzegknpnkaq-findutils.brick'

  'store/o7/cz/brk-o7czghgecqaqhg2yqjwcdbzkpzbu5rtk6sambsubjyzpedg5bskq-diffutils.brick'

  'store/cd/dm/brk-cddmxlrjnyk4c4674ocfikhwnpqfj3kab7ke3lzcwiubazae7vra-diffutils.brick'

  'store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'store/bg/yp/brk-bgypnnermvrmj657kbamz6dhvtc7ic743c3tlooizg54udk3ocka-curl.brick'

  'store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'store/du/so/brk-dusoct55bmpgvm2ldpmeths6hggdhr33vyflycel7kjgjw3ts6ha-ca-certificates.pem.brick'

  'store/fx/ry/brk-fxryxn436wjuxw65ie7fbuhrasf7o4qinnx6ahmezla4gx52hboq-bzip2.brick'

  'store/tv/nr/brk-tvnruh4farfdymxw4stifghd6gpm6absnwfi3ys2slpz3hj2diwq-bzip2.brick'

  'store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'store/gn/tb/brk-gntbxyq2xxjk3o5toyw47h7binmliq5w22u4zs72wxnxcpern7la-perl.brick'

  'store/mh/sb/brk-mhsbjq6wbipec4zus2wvgplxt2yl4q25natgh2c6k625ywz6o4ta-git.brick'

  'store/t7/bv/brk-t7bvgar26dma4k36sqzty54u7xkqkr4kmrzxvtppvl74ckyuypwa-gcc.brick'

  'store/xb/bg/brk-xbbg4ulvsd2dh6qx5bzoguv2tlozc36v62to7h5grf6pfblx75ta-bison.brick'

  'store/ye/cb/brk-yecbppbe2hram3gythftkgn6mwelxq6l42vejdrjy3czbotcwmoq-bash.brick'

  'store/a6/uz/brk-a6uzfq4xc5o7bs5l4bv2dqotrldkrqvw56woauy3hxekzxzj64dq-perl.brick'

  'store/vc/z7/brk-vcz7e4ij2tgurzqbobaw2ij2k3eayjbgc6vdglinxqcdcle6urma-git.brick'

  'store/6a/re/brk-6areo7hfvce3oyvinqgwiubiidhaf3ibtu674cgk3nkt7kw2tywa-gcc.brick'

  'store/am/qc/brk-amqckkhxkcqzeshkrzwtpd5ny2nhtivvgoh33f2lpnviovscyrkq-bison.brick'

  'store/ja/nu/brk-januf7wm3extpkf3foovevbxyhxkwu2dgvlag6z2ptfeqex2nttq-gnu-tar.brick'

  'store/3h/qb/brk-3hqbd5my4lsezw5edxdjy7lnkixedhp7g2b7ximmx77pgqohveyq-coreutils.brick'

  'store/rr/hx/brk-rrhxxra6xutre4dcfvy2p6qwehi5jcv5wpzsy56cuav2r7fdov2a-bootstrap-env.brick'

  'store/dg/fg/brk-dgfg3arw3up6lbm5g4sarffhzl2gc4nlqp4inr4ry74xdwbabp7q-gnu-tar.brick'

  'store/is/qs/brk-isqs4s7jt5knyrl7rm3ynm2n7ct37bn22zwmfmz7jkw3dhdezhwa-coreutils.brick'

  'store/qh/rz/brk-qhrzxrzpshk7wssuicwdv5uyvtrlzx2zi373o7esjgbpedtcmtnq-bootstrap-env.brick'

  'store/ey/hj/brk-eyhj3p4imbapumokkpl7wjkijfuhzw22wnkvzm4qnngbrqw6gzga-glibc-runtime-support.brick'

  'store/fx/wo/brk-fxwo6gh42pwxkmohkpzzx7epy4c7sqp5nb7wdjn37xjoexk72qva-glibc-runtime-support.brick'

  'store/vd/fc/brk-vdfcpqjosulvutdbkkg6j2dd4y3np4gyyzgcgn76q4ereaajq4yq-rubble-elf-runtime.brick'

  'store/2k/rb/brk-2krbwasdoc6c4z33nejq23ttapdik5szjed24s65ouy5mxviosdq-rubble-elf-runtime.brick'

  'store/dc/fo/brk-dcfonqabj4jd3dagsbk255cb7kxxytkebvc4yq7t6ts3c2qqsoma-bun-1.4.2.brick'

  'store/fc/6s/brk-fc6scnw3v4skjlzaemleq3stlcqba3ppvs7n453zymkdiexbucwa-bun-1.4.2.brick'

  'store/sd/w7/brk-sdw7yo62shy2gklk6sdvb64wyzag2xqejj2bbxet4n6rawpgm2xa-rubble.brick'

  'store/az/zi/brk-azziirpalsf6sqklnj2nb5o5rzgccrlbcgcl3jsofte6gj7zz42a-rubble.brick'

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