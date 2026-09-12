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

  'store/hs/eq/brk-hseqkp4htbof2oy5ft32zmuk6nrjwse7qhf2e7nlyfrrphs3sc5a-wasm-pack-0.15.0.brick'

  'store/eo/ps/brk-eopsbz4ia2xmktldjshfv6bferpwxnexagroon63m4ryp3nu6lgq-wasm-bindgen-cli-0.2.115.brick'

  'store/jz/ib/brk-jzib76o6jwvszofr4g7p5ceo7li2szw2zm25pt6bwpu4plo7wdwq-rubble-src-checkout.brick'

  'store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'store/te/ie/brk-teieaxxyjdoyw4gqby5r4ywgrstjp3t6ui4dxasa6j7ba34arziq-patchelf.brick'

  'store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

  'store/3y/ms/brk-3ymsqx4irog2cwz3opdekqpw4otufpn5qdjdmbgzswfjrt23imbq-zstd.brick'

  'store/wl/uw/brk-wluwjucbrlkece4f3oq2qk6uxprq3t7h2ogids4ymiz4nsvjqmwa-xz.brick'

  'store/vj/kf/brk-vjkfcfgkm77x6m2ulurl7euwz2rnspl5pijijlqq5wmu4fcyn6la-unzip.brick'

  'store/cc/a6/brk-cca6hpdxtvtjn3hkbljrizdlu2cpldgeodds67hxlcf2nhclfc5a-m4.brick'

  'store/b6/du/brk-b6du7m4wvh6hhvuzjxtbgjxv3kmgap4w2jh2mjw7ztfs2mbseida-gzip.brick'

  'store/xp/q3/brk-xpq3y53udiwojwu3cmwsgbqn7pkk6y74expqaf4ss6goibdgypuq-grep.brick'

  'store/to/yy/brk-toyyhmevribb7khuvecg75ctwezy43ob5us3fe232gwncayr5hkq-gpatch.brick'

  'store/6i/tb/brk-6itbkpqgk46i34vxf2bxe2jjugitys6463c73qfk5fhiipwku4ha-gnu-sed.brick'

  'store/cd/gy/brk-cdgy6susoq245z4mch7qbgfzwfyqzywqchtfoveem66yiwhb4qba-gnu-make.brick'

  'store/pw/37/brk-pw37lfr3ixpwcll66ytcwfkezsbh2smxf77zdjlx6ox6vwlifwxa-gawk.brick'

  'store/26/tn/brk-26tn2yq4ryvlust5j46r2gfdg7ew7zg7gpth4bowtw5vxvj5xeiq-findutils.brick'

  'store/vv/yh/brk-vvyhmuysr2vjsftzfyed3zekunsonl6t34mrh55zkb3mmepagjsa-diffutils.brick'

  'store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'store/it/xg/brk-itxgxgppoxlnoqfhav4tgvdmsqhkb6xraelfh5my4ex6t6asd6jq-bzip2.brick'

  'store/yz/2g/brk-yz2gkzppzklqwxcexejnusirhckaj5q3znbfvnvabxdkbrjrduaq-binaryen-117.brick'

  'store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'store/x6/3s/brk-x63s7v4qom7r4x7j6vg6y7p2sofdrxxj3dgw7fqdqftwwhjpixaq-perl.brick'

  'store/zy/6b/brk-zy6bvkew2exlrwyg3zjlgc47llzncsko4l6kssqxbtdjpcoe4wbq-git.brick'

  'store/xt/64/brk-xt64bpkydygjzezkokdv36klu36dn4cnhm762iasa23j2g4qwyoq-gcc.brick'

  'store/bt/u4/brk-btu4wdeflhf6iv4rk4awpoj4h3ke6bdsgsdmdj6icerqhprab2zq-bison.brick'

  'store/6f/yi/brk-6fyi5giuhq2rktxlfg2epgwit5rqik345vr2o25yognyocmskspq-gnu-tar.brick'

  'store/pp/dg/brk-ppdghkityovkxogtghygvs2mls7qza646xifdh4qt3pdr7enpi2a-coreutils.brick'

  'store/gh/ch/brk-ghchiozjtl2ibn4fj6cqsjqwccmgb4bjneutfqoawhgozjexoboq-python3.brick'

  'store/46/lf/brk-46lfnhiwl7xwedh2m5nqmsiz53zc3vcpqiox4v4mctm56nzwlz6a-bootstrap-env.brick'

  'store/vz/2d/brk-vz2dx3arjctaftbe7d5vpdjuirb3kaazss2o7od6nzfodmnft7vq-glibc-runtime-support.brick'

  'store/sr/52/brk-sr52rwj7bmy3tlzfdlapjgmliny67qg7cvtynhazlbrwk4koywaq-gcc-glibc.brick'

  'store/bh/uw/brk-bhuwjt6muvbas3234rg6hiztqaxaxka7qmz4cklimmqsp42wezsa-rustc-1.94.0.brick'

  'store/b6/2v/brk-b62vfhtmwhetnclf3wzpqnizw4tyl6l6g6rtlplpqw5v7t5o2wga-rubble-elf-runtime.brick'

  'store/vr/6l/brk-vr6lejgazglhajucqrmb5zeqaes6a2rjwrol7pi6dtquye232inq-nodejs-runtime.brick'

  'store/kk/fq/brk-kkfq6qjkqef75l7pbyx2qmcbufsgc2izdob6qeb6iwxpwhys4p2a-nodejs.brick'

  'store/k5/no/brk-k5nod6g7ihdibb47wucouwkdvrw4oiehldah22hbmnxa3dk3g62a-llvm-tools-1.94.0.brick'

  'store/dj/tb/brk-djtbbkcmd3fks7bmhvltqdf2elnjpkxxmnomacolyktv7gv62osa-linux-native-toolchain.brick'

  'store/yw/bz/brk-ywbzguary6l35nkpuelpn6w5b5slltd7hfhfv67tojuig22767pq-cargo-1.94.0.brick'

  'store/3v/ek/brk-3vekdx6h4osrh5zrjkdsnfwemyy2cloecivkejkytz4xykoej5ka-rust-web-wasm-toolchain.brick'

  'store/yy/34/brk-yy34lfziw4urddnizor3up3ueebiexzcakzkmbutp7n6bmpwxibq-rust-toolchain.brick'

  'store/27/ly/brk-27lywesxsihp4b32em6bcd3isu64iv4jm7jc7gzvzrscaarg2t3q-bun-1.4.2.brick'

  'store/5f/gq/brk-5fgq6nxtxfoshjibiitri45orpjtzk7tfv2fihqmzbsaekdbvpbq-RubbleR.git.partial.brick'

  'store/tn/iv/brk-tnivbsqih6yi5vmz44754aghhpyjnqkam6pdcnfqfys2y45rxpla-rubble-web-node-modules.brick'

  'store/5o/fu/brk-5ofu7tlhimzuzbbscur7f3njcbfptaj24ypginkeoltpk3khv6fa-rubble-deps-cache.brick'

  'store/iz/7x/brk-iz7xzqarhalz5y32vms2f2s33mfpyubkvvdxqehw5hk7kwohcgla-rubble-web-assets.brick'

  'store/fk/rg/brk-fkrgemdnawnj4wbejzyy65tq4azyvxxgwlwtjmh7rpkrjp6eme4a-RubbleR.git.brick'

  'store/gg/em/brk-ggem3s3ueu6ucbqpc5vd2en4qrxvtvm6xb473xozlwo2actjojxq-rubble.brick'

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