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

  'store/5m/2r/brk-5m2rce6vcokgll34ytyyx65fp7y4za2dncwuu52ra3i3oily32pq-RubbleR.git.partial.brick'

  'store/jo/ll/brk-jollno6o4uloupgitupgjbfxgunhmm5hx3hdhvl7kbmw47dj4dpq-glibc-runtime-support.brick'

  'store/do/yh/brk-doyhpmodramzk3rtng3a7it2nzmwko6uxm67xkypeyjeph5jv3za-gcc-glibc.brick'

  'store/qa/oa/brk-qaoants4nlzfxkjtirk4cu46xcdrqruorswdaacf6znn3io6tl6q-rustc-1.94.0.brick'

  'store/st/7k/brk-st7kemdq4iesmpfx4kbo4q2b3rtuoelmqtgfzzrpzs7hukebga5q-rubble-elf-runtime.brick'

  'store/5o/iw/brk-5oiwqkogaw73q6vr6awd73gcirefkhnxligtcbjp2yxvgcao42bq-nodejs-runtime.brick'

  'store/sn/kx/brk-snkx5dkrni2ql2hkmw3e6fba2aligzxwuoqnqk7i7jpg42slabeq-nodejs.brick'

  'store/u2/wi/brk-u2wisswub2qmsj2srgnwwrxlqrnn62s6ejh4ugyltwugyg3pfawq-rubble-web-node-modules.brick'

  'store/aj/2k/brk-aj2kicz2nqpzxgetdsoi7jgqcnbnis5wnhjvbi75pojayk6ijsiq-llvm-tools-1.94.0.brick'

  'store/ai/gf/brk-aigf2aggz7iw6qwoesebbnog7ri6p7lnos2slaojyvax4gentzia-linux-native-toolchain.brick'

  'store/va/2h/brk-va2hj35yknh7msv2ucyztilm6l5ddtxbmw3itdjxycqbtf3fqota-cargo-1.94.0.brick'

  'store/dw/bk/brk-dwbkud6kriwdtuoq6uwp2ceh5ifuxaalouu2zkq25d5cpcozppma-rust-web-wasm-toolchain.brick'

  'store/5w/5f/brk-5w5ft5y3hkcueupk46bozqrdd7fwxp52ook5odjixgomzioqvuia-rust-toolchain.brick'

  'store/sh/tk/brk-shtksgz5dfwxl3a2qy5gazbufvz5d3jrp3yghyt6kfoysejsxr7q-bun-1.4.2.brick'

  'store/5n/ra/brk-5nrap7vermuhdkqtamy653bdcnwr6ehk5a6anm7j63reercotpxq-rubble-deps-cache.brick'

  'store/4z/kf/brk-4zkfocb2otwe5ljg5a7wprh3i3udwskw3fiwmysu3feqf4cuetzq-rubble-web-assets.brick'

  'store/oi/6g/brk-oi6gb5q55d5xmwiirikhouplcabgr7j2n5ao3mgfmsg5gonhzp3q-RubbleR.git.brick'

  'store/f6/d6/brk-f6d6u2ivy2z3el6zjgj55bohuw5vqsm6fdmhgk3evby2u2kdgucq-rubble.brick'

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