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

  'store/7h/vr/brk-7hvrra6ygcaaeexgncdv3uasq6xy65zzagujucn6atyplqhhviua-wasm-pack-0.15.0.brick'

  'store/ry/jw/brk-ryjwb6a3ynqdajbncvpdzwephlmhpxe56zvtgfs4cv4x5lvdguca-rubble-src-checkout.brick'

  'store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'store/cn/de/brk-cndex52rgwiybhxcbkpry2isc55dz3hrc5lblmzr3xyeilghixda-patchelf.brick'

  'store/65/xn/brk-65xn763kfhf7ye2ax5rr3hjotrij3qjagkddvfhqarwrt2a7mnha-ld-musl.so.brick'

  'store/6l/p4/brk-6lp456cvhb7ckx65h7yhuzgup3uli5rrlhgesi7cgtyuqcgbwp3q-zstd.brick'

  'store/fd/vb/brk-fdvblu7ednc2u5nevmdvxyvycn4fejjclnyaqzg6itd54yacupcq-xz.brick'

  'store/vx/wg/brk-vxwgaxdchz7bshf2frb2nciw5fvmchcygr76c7nstnwaithr3t2q-unzip.brick'

  'store/s4/36/brk-s436fi4eiqcbgfl3sxxy6qiehrwo3ytnrcmp3s4u5meq6dlhmola-m4.brick'

  'store/5h/6c/brk-5h6cchin5lidxx4alu3objrowtlsbqblhb27i6svhihosmwda3ja-gzip.brick'

  'store/te/dz/brk-tedz642cat5wbxa5xk2cl6gbj4rmqaj6r64ivlzc6wu4bg4iolla-grep.brick'

  'store/k5/fr/brk-k5frhmbdkv7cwqivkkbpn54wsufwddmytey446lzvulwfj7ggc4q-gpatch.brick'

  'store/iw/xf/brk-iwxfog3m6w6osk73jf7h77lycjwgis2khdcwgi5vp2bngilpq5qa-gnu-sed.brick'

  'store/e7/dd/brk-e7ddcesxg2zmvb5wamzn6k6wq77wdqf5jxs3cow4m64xubmstluq-gnu-make.brick'

  'store/pc/6e/brk-pc6egjgq2ba3z3wnas2zd4lygye7s6qa34rdem6tqt2oxizk3kfa-gawk.brick'

  'store/xp/4n/brk-xp4ng2csk5hs2jlwyfptf7imm4gd3jifcoxvhghuz7b7qf5nidla-findutils.brick'

  'store/t5/am/brk-t5amqprssgcztj7qgv4d7bqmtbtagdixvn4hvjtycdm44t4gtrda-diffutils.brick'

  'store/bg/yp/brk-bgypnnermvrmj657kbamz6dhvtc7ic743c3tlooizg54udk3ocka-curl.brick'

  'store/du/so/brk-dusoct55bmpgvm2ldpmeths6hggdhr33vyflycel7kjgjw3ts6ha-ca-certificates.pem.brick'

  'store/7f/cr/brk-7fcrm7iiq4agepnnbu46kixt3exop6fqy2ylv34zgifmrjjckczq-bzip2.brick'

  'store/si/63/brk-si63kbjoeh5l76hedrmuxjzzuolovggsbkabc2fqnwt7ujic7ajq-binaryen-117.brick'

  'store/ye/cb/brk-yecbppbe2hram3gythftkgn6mwelxq6l42vejdrjy3czbotcwmoq-bash.brick'

  'store/zn/wh/brk-znwhzlmuwlllrzalgrnpvastzcrjizp6j6uko2ijyvss5ycuwr6q-perl.brick'

  'store/ar/ds/brk-ardstcgczrhdaibp6jmdzypxykeymbity6aut4wr3ijnqozjrcxq-git.brick'

  'store/jz/sb/brk-jzsbx4e7xjrjybgzigm2xnhrpc6rldvgwpqlhvca7vjzks7fzunq-gcc.brick'

  'store/iu/rp/brk-iurpgonnj2ueak3ta44zihvtdksmjx5j62dy7n2ebbd7pdb3lfja-bison.brick'

  'store/nh/57/brk-nh577btyfes2xq2gotqnt6ur4vqq6qojz4kmf7xbewchtdzrmyzq-gnu-tar.brick'

  'store/qj/7s/brk-qj7s4kfeu7lleafbwujkfsjkts575oc7v5agukewx2ic3y6b6mdq-coreutils.brick'

  'store/c5/wb/brk-c5wbg5jn3pylcmup7sbxmniucuw6dzpkte46m6h7buk2xbxyxtsq-python3.brick'

  'store/a7/ud/brk-a7ud4y2emz4jysev4e5p275gywgintjlenar2fsfrjokko6cdclq-bootstrap-env.brick'

  'store/p2/th/brk-p2thxjrt4enoru7wjpubhfnj6xs7f2c2ig3eitngr7jdcneqsiqa-RubbleR.git.partial.brick'

  'store/vi/sd/brk-visdzgzf627yppudc7znj4basgcbxhgmqwjn2nyiugitptyaitea-glibc-runtime-support.brick'

  'store/3w/tm/brk-3wtmg3emr45kij2bqxsu26sgurjr2qhzvlbflvo2jbonsy27ky7a-gcc-glibc.brick'

  'store/pu/u3/brk-puu36hrkbbnfc3pjiyvtfpejz7bbtp4towjhci2zkc3nklh7qiaa-rustc-1.94.0.brick'

  'store/5p/zr/brk-5pzrau5ndljrzmkds5h2bs34mrf5nle5j3u4itfclyubfi4ub2ba-rubble-elf-runtime.brick'

  'store/w5/uo/brk-w5uonp27enqbgfgnn5iej5bxy46h4wsarwscbtt44xyjcvswteaq-wasm-bindgen-cli-0.2.115.brick'

  'store/q4/fu/brk-q4fupy6ofwyh2j5rnst4z47nr5lp3jsee4gdi6y4jiybfwincczq-nodejs-runtime.brick'

  'store/2h/d6/brk-2hd6u265z3wib6gwseiazg3zwct4omkjbc5ntlurpklgilzjjadq-nodejs.brick'

  'store/7s/4o/brk-7s4o767a44rz37525ykn7eadrhimstjjvdts2segihab4tqgk3yq-llvm-tools-1.94.0.brick'

  'store/tn/qp/brk-tnqpv7axhecqr2tjhs2hmryfrd44wqwv77le6kdgqihbvohqtyxa-linux-native-toolchain.brick'

  'store/ia/nt/brk-iantrfpk2ym7cs3gogddteqf55vid2cqroar3baw24nbvg7dxu3q-cargo-1.94.0.brick'

  'store/pl/ir/brk-plirr2s7hgoniokenfwlknvmhw6nz2unh5nrlaazae3sn5kwvkhq-rust-web-wasm-toolchain.brick'

  'store/ok/3n/brk-ok3nzhwwjno635puiomjcgab4zs3do2lodekydllpb3hw3h3pkqq-rust-toolchain.brick'

  'store/og/dq/brk-ogdqjl6v7umf45svfgxqm7myx3aq4lyg634c5mm6lf3r777mlkba-rubble-deps-cache.brick'

  'store/ib/kn/brk-ibknsfta5hwy3yipkynoqj6cflte22cxtj6h4qw6g2z2vwioy22a-bun-1.4.2.brick'

  'store/qv/l2/brk-qvl2rmykqyiei7tbqvllz6gdcbfmq57dgzlns3lydcsgzy4qpxia-rubble-web-node-modules.brick'

  'store/nl/af/brk-nlafddbuq7viz5x57zx4vgca2kuueiv4gr372nbwqfntb5buta2a-rubble-web-assets.brick'

  'store/ks/tm/brk-kstm375tcxoylrqngxkxmxplapgizkd4nwsmw6mv7ol26pqbdj4a-RubbleR.git.brick'

  'store/j4/l4/brk-j4l43hvomqceu6rngdrgg43uep7uauaurxl7ihnetu3jj3hlaucq-rubble.brick'

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