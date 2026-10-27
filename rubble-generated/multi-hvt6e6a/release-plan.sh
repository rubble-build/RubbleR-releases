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
release_stage=initializing
stage_started=${SECONDS}
cleanup_release() {
  local status=$?
  trap - EXIT
  if ((status != 0)); then
    printf '[remote-release] %s failed (exit %s) after %ss\n' "${release_stage}" "${status}" "$((SECONDS - stage_started))" >&2
  fi
  if ! rubble-exec rm -rf -- "${release_dir}"; then
    ((status != 0)) || status=1
  fi
  exit "${status}"
}
trap cleanup_release EXIT
rubble-exec mkdir -p -- "${release_dir}/assets"

script_dir="$(builtin cd -- "$(rubble-exec dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
release_brick_files=(

  'store/76/la/brk-76lao3bnpein6f4ggp4dwci7cdyywjnb5i7by4forhkbzf6lju6a-wasm-pack-0.15.0.brick'

  'store/jo/mf/brk-jomf52m6ijsokfau3fyyvgd7elhgiiavaic5tzdw6lhugeziyhna-wasm-pack-0.15.0.brick'

  'store/zu/sn/brk-zusnoxxoc5tqrnn5sff6vnbybqdvnlrjzhjm6wtgcwf3ktpb4zra-wasm-bindgen-cli-0.2.115.brick'

  'store/6v/x2/brk-6vx2ce7jcj6wfra4xg2ykz6htsdkuvhh7uxbyr4gzlwvf2mlriua-rubble-src-checkout.brick'

  'store/4x/2u/brk-4x2uexqjoqs5unyb4fxpdus3ctebmhvqnuruhalsl5rdwt3k6naa-rubble-canonical-script.brick'

  'store/hd/qx/brk-hdqxqr4vfc2rgc3rj5ywrpaykxqly77eix55tldf7wd7nqimpqfa-patchelf.brick'

  'store/dh/zo/brk-dhzowymraqoa262lv45rzgrpjrqdedusoctmkao7qctbpck3qiva-patchelf.brick'

  'store/z3/xh/brk-z3xhjdr5it75lq5iwals4toaklhutksbdphbucgwhtgqhxz32k6q-ld-musl.so.brick'

  'store/mv/w4/brk-mvw4balnruevggsruaxcd7m3dye6dlbrsjshobcplnic3svvd4rq-ld-musl.so.brick'

  'store/fd/jo/brk-fdjot6csltdy7pfpendap6yybjo5niybzp6knbofokgq7mxbz6kq-curl.brick'

  'store/ov/g7/brk-ovg7cu6kkazcpj32mrk53yc3kb2z2mrl4yd5yzrj3uytgwcanawa-curl.brick'

  'store/zj/i5/brk-zji5om2su2ddkysxsg3xzzbvx7uvgespdsko7wze2bovygtgnuzq-ca-certificates.pem.brick'

  'store/ny/xv/brk-nyxvd2fuotdmxjktenzudif5x5zq2d5ohtbciy4t5ztyf7b7x2fq-ca-certificates.pem.brick'

  'store/ta/cn/brk-tacnuufbmsgvjjdv35jnlei72ofv46gglzsjzt76wnp6nf7qphdq-binaryen-117.brick'

  'store/ja/26/brk-ja26s6rmlm22mwviv4hkae3mfkzkcq4tumc55qstm3p444zqmfzq-binaryen-117.brick'

  'store/7g/ai/brk-7gaiswvomctprmbv5i6dhxav3urpsmceezmwy52qv42yok44lygq-bash.brick'

  'store/vj/xl/brk-vjxlzrn6lje7peb2wiyior57it6egawfge3hoos2ctnlggkofvra-zstd.brick'

  'store/2n/gu/brk-2nguimja3ijn67ppduw4iymx3l63awsvfm3aeolh4huxhrtlelzq-xz.brick'

  'store/47/zo/brk-47zokkngsfutphq4c75jyibgp4htgwdbxcrgh5ufuwkgilcj7gyq-unzip.brick'

  'store/62/pd/brk-62pd2iqc5djuyptrefmfnoyqs2h7sixqjxbe4j7def3if3gwm2aa-m4.brick'

  'store/6v/64/brk-6v64oxmhrixfku2kgw6taolvksk3cur6mm3anu6lhbjirbgfggxa-gzip.brick'

  'store/nf/vs/brk-nfvskclt3cgimqtrw2eazstdf454q3p2r7hoevkjczb56ozzmtpq-gpatch.brick'

  'store/mg/7b/brk-mg7bty4vjnnybn7lxd3p5q2g2hgzp6szy5r5j3r3u5n6irldveoa-gnu-sed.brick'

  'store/sz/7s/brk-sz7scme2he4n477gpccq6kdizt6dbkntlfh3ddo67dypl7ksxtda-gnu-make.brick'

  'store/d4/oa/brk-d4oam742ndjdswucg5txv67tvctcjxom6yt2e26fii37al2wmzra-gawk.brick'

  'store/xu/sx/brk-xusxkpuh7w545vzs7pihbqmmndx52nymd5tqatmphbfm3l4zkziq-findutils.brick'

  'store/eb/zn/brk-ebznmwxxmhegjnbtc25szhhelhtux4cplgjscwjux4zxx7eekxea-diffutils.brick'

  'store/35/lu/brk-35lunc52cnmxhsxgrbztpvoejb6h2oewsxbihfsqsdo2bifm7kmq-perl.brick'

  'store/l4/jt/brk-l4jt55j5qqsfscqsfwk2ckk7iyj2hrv2kjpqf66rjw3ilg2psx7q-grep.brick'

  'store/re/6w/brk-re6wlad2vnmfnf4nrcravillaiaut6pzebyaadwgkkgh5g7tuvka-git.brick'

  'store/ev/cm/brk-evcmryzqpefcunpqoyutqjscwvwtbvogsntb5n47lbpuaohw6m6q-gcc.brick'

  'store/np/t4/brk-npt4pmjgvneqxtb3xvqge7ptntgjmjfz6vkendkmbfzspxpabvia-bzip2.brick'

  'store/i7/om/brk-i7omhhjzayh7bxlnhyvcs4274b2uaunsyh76pixjh7ixvnpcrp2a-bison.brick'

  'store/n7/qb/brk-n7qbevbly56oq5vdzjm2bzhl77wjewdp4k5gmoimlbiv62nbv7pa-bash.brick'

  'store/sc/ly/brk-sclybv3wsmgo7lnvjs4ywxykwvbpkwzeezn3l3sbg4f6xpksw63a-zstd.brick'

  'store/7t/7h/brk-7t7hvndnqng7fsb5phlfjcn7fnp2t53gucm7iaoownjbavgdimha-xz.brick'

  'store/mb/g4/brk-mbg4lwvhanztnjrvjyh36j4j7ojysmtv2cjoshzw6xj5dzztiluq-unzip.brick'

  'store/6p/rv/brk-6prv4ap5h2cndbif6hlymbvxvg3p2g3qtpdl7vdmyiwyxxp65kfq-m4.brick'

  'store/jx/55/brk-jx55n3p7uiv65atde62sfdnrktfey2co5qtqasgnglrc4qytpgtq-gzip.brick'

  'store/ab/ax/brk-abax7ryl2uma2r3kh4v4srra3jnisjuuivmrvttb2cg35q7lrdgq-gpatch.brick'

  'store/ex/gd/brk-exgdn46eagyxc5npgu2ktpyluirdd44myaua6gnfodk5ei35shxq-gnu-sed.brick'

  'store/k5/za/brk-k5zazg3iqlzgpeegvrj4ovmwfucggksuxzbuhl6kyduei2qq4xuq-gnu-make.brick'

  'store/nx/7a/brk-nx7a5qmymqncddkt6verfvnhlg64g2q2iupe3xoh2pianzay2ela-gawk.brick'

  'store/ca/tp/brk-catpfdrg7xd6pcsylgw2dzmolmqrqux6crkx64inuc42ioy4szfa-findutils.brick'

  'store/kl/zk/brk-klzkfeewgdals54pcgp3sytbcfc46yua4g3vq23ijqq4cou4almq-diffutils.brick'

  'store/rw/ce/brk-rwceoiocqfcgioh4rb3u5w5k2kie6ntmoie2c3bwv6yexxrfgkxq-perl.brick'

  'store/3g/4w/brk-3g4wslkvcdeh4prfpoamkoxdrefgts365qssdt5hsdlvxrqmze7a-grep.brick'

  'store/wx/bp/brk-wxbpprly4rrpd6sqhki7cdf6pwaau5axfok4bzaehx2hpdvsudlq-git.brick'

  'store/t4/s5/brk-t4s5x7vx7ortfirmkczsv7ajjipmwf5sbggptpzkx6sude7mdweq-gcc.brick'

  'store/2r/sa/brk-2rsatquz5uzw7dilqg64g74l2vtvruaziu5jjhpcqjhmi4rw2cbq-bzip2.brick'

  'store/sr/o2/brk-sro23mxtsmdqo6q6qnqjxue3aqpsmh44eskp6ftagjfnkxrfewuq-bison.brick'

  'store/2n/wj/brk-2nwjk6y7a53lxi3iwzujxebrd3wp45eqr2sdhyc2c6xolptn3p3q-gnu-tar.brick'

  'store/4r/ml/brk-4rml266dvj3lfnykptfshuossktxpdkis26uwp2ebjffjlgcmmra-coreutils.brick'

  'store/rm/2p/brk-rm2p5eqnfc3sdxlpambep3k5j5tdustz4iwuhb2pdzy5mz5qkfqq-python3.brick'

  'store/vf/th/brk-vfthpdhrrixmo7ewqosxes2hbagrr4iuhtp3x5ax4vrohm65ynba-bootstrap-env.brick'

  'store/u6/gp/brk-u6gpy6gfub4xlqrvjvqq4dtfafufxauxuste7lkmoc6vvpkuzp2q-gnu-tar.brick'

  'store/r2/ag/brk-r2agl7x5h3nujgwasxf2d2vcopngkncwb6ronredz5n7o6va5s3a-coreutils.brick'

  'store/tx/2i/brk-tx2iwpuhoretwx7gt3mczqcjfolradt4egn6sikj25wxrf7k4hva-python3.brick'

  'store/ps/mh/brk-psmhk3rswggelskf3qvnkd7itd3bwmik75jdyyje4nh7jdmi3j4q-bootstrap-env.brick'

  'store/nk/ar/brk-nkarriv6xdztevb5tdoq3eawwe3oba47sgpobzqopu5voszsepwq-RubbleR.git.partial.brick'

  'store/in/ak/brk-inakn65bjgy574fki4lz7ar4pgwugxvdjqqnierbkk3isic5spya-RubbleR.git.partial.brick'

  'store/yu/lm/brk-yulmh64lm74agokkfevmcy7f46x7fhmvuulbielc2d7ufenz2wia-RubbleR.git.partial.brick'

  'store/zc/wd/brk-zcwdi25y3x7przyuhrgamgk3zvpum44ipsw2e4kvyyp5xkh47ifq-glibc-runtime-support.brick'

  'store/7n/gd/brk-7ngde34g6fsmdbt57au7543vtzv75pt7ff3xnmx5a6oubzevfoba-glibc-runtime-support.brick'

  'store/ti/yd/brk-tiydotxjz7qewbo5ed3zp2qubvbtinrxxikbmtjjybfk763ytxda-gcc-glibc.brick'

  'store/bk/nc/brk-bkncl44cp7kg232ksgrqecd4odxplznwl76mocihjtlnz7oty6ea-rustc-1.94.0.brick'

  'store/cw/qg/brk-cwqgfsd3etn6cjqpyys6jv6v3xtif5qovlpujqolrd6kwhnevi5a-rubble-elf-runtime.brick'

  'store/wp/kp/brk-wpkpambmtcqapunqsckghyers4sj6gyv2zi6xdgrlvxxpujstwzq-nodejs-runtime.brick'

  'store/2j/re/brk-2jrepkvmolec3cgroapk2w35wuvlt24xeksp2wrjptsvtuyffkxq-nodejs.brick'

  'store/55/xe/brk-55xetixujjheyadinutwkiasfonswpahyw32zvpumeuyldjwdf4q-rubble-web-node-modules.brick'

  'store/77/do/brk-77doo4g4yyr7cvchp4htv6yekwiinuayw5yfvhvtcwkkycsuts2q-llvm-tools-1.94.0.brick'

  'store/p2/g3/brk-p2g3pm5ajqynwanaxd6rtohwn3hmssocwnrt4zdisparxjowefbq-linux-native-toolchain.brick'

  'store/hy/en/brk-hyenllefa2rthhx7zszyw42xo4dptaawi7tneedfkvtbt2vcdn4a-gcc-glibc.brick'

  'store/pr/oj/brk-proj7g2txf4lo4jc7khsxkdt2j7uqawxqlxeiaslrduifyiteyeq-rustc-1.94.0.brick'

  'store/ks/s6/brk-kss6ejcy6cuctp6chi5snjxtw3wmrkdee4rorg3y3x227hqdxe4a-rubble-elf-runtime.brick'

  'store/7b/cu/brk-7bcuwbkhkfv5vzgcejdkefwufisdgyxfndtncvibiq2kak3wxl4q-wasm-bindgen-cli-0.2.115.brick'

  'store/uj/kw/brk-ujkwntuqezbicf7gcgf3v7iv7umsrse4xita66ilt4cg2nsslmcq-nodejs-runtime.brick'

  'store/7v/xg/brk-7vxgxtidkpefimk7iu6534rqb2n4cgxehmolt6hr5k3hxohbuz5q-nodejs.brick'

  'store/fn/fc/brk-fnfcvey3uxm5twpokjqwt2g4i75brs75g2yo2agzqd5zbhlumlxa-rubble-web-node-modules.brick'

  'store/le/kr/brk-lekrhyo2ikgefn6vclkfygp47stsmaebfk4nnaqrpfo36qgqe33a-llvm-tools-1.94.0.brick'

  'store/t6/j6/brk-t6j6unirvmr76nvqddgao3l5vfpz434cdmkjfycy7lrspy4mos4a-linux-native-toolchain.brick'

  'store/ca/yr/brk-cayrfk5zbaep3sq7ju5parduunjvi3r5puia6tuhtudozvxfujxa-cargo-1.94.0.brick'

  'store/r5/bb/brk-r5bb2uqnlx43wrsai7bl2yxsazl4p5h7kno43wltd6olk67sdvja-rust-web-wasm-toolchain.brick'

  'store/rm/hs/brk-rmhssm54s5johitiyrmu5twpwyczednnx6nbe7qszlyknatkqxsq-rust-toolchain.brick'

  'store/ih/6j/brk-ih6jmz4n5d2pfoo6au2l46775movaxefxhtgjfpbx5fjxfi2iwla-rubble-deps-cache.brick'

  'store/sl/ig/brk-sligczofhpmkax3aqxjjp6vfhrbzqtcnbuds42arahid3mluhpva-rubble-web-assets.brick'

  'store/hl/yy/brk-hlyyiiz2oa4sx7bs7su5lml5p3czch55v6i2wwhk4agbfsa353cq-cargo-1.94.0.brick'

  'store/zp/wl/brk-zpwlj325j6odlqcjyr5defhpvjqvde6hjsxul4bie3eqibw7qb4q-rust-web-wasm-toolchain.brick'

  'store/p3/we/brk-p3we3k5oap6zudcynubezkfvmzipdz77oqeu7qbjpat5v7sn2ktq-rust-toolchain.brick'

  'store/hi/7r/brk-hi7rith752ntvblqdef27zcg6uibm556anlfbom5jionjpcmob2a-rubble-deps-cache.brick'

  'store/sx/ia/brk-sxiagghqwdzy3l5rpvhpjbvlhmclyxoup6i72vin2ns5p4ffmpha-rubble-web-assets.brick'

  'store/f4/kc/brk-f4kctu2x45xjvktknpp7soicl6epvx5dy4vtdrxagpbkhp44rkaa-bun-1.4.3.brick'

  'store/vg/lf/brk-vglfgcy37uamsfveaktm245pbgrv7l4hyq2ea46ttxagtpeoucpq-bun-1.4.3.brick'

  'store/iy/j6/brk-iyj6zmx2rfit4fmdj2o3yepmsg4j7usryocefpra6e3rcc6m6bba-RubbleR.git.brick'

  'store/r4/3k/brk-r43kpl4u3pm4bnuuaizpsfrkpxmzxctvafp6csosklfw2xzzhfxa-rubble.brick'

  'store/n2/p2/brk-n2p2k6lsdi2b4xl4ahnoyjqijbvzwo5dl325ub2gc3hvmuudup3q-RubbleR.git.brick'

  'store/id/np/brk-idnpzkif47ezy2gjddq2iiicvlnogdu7cpbxzwnsxkwy2ra6ajaa-rubble.brick'

)
release_started=${SECONDS}
release_total=${#release_brick_files[@]}
release_index=0
printf '[remote-release] pulling %s inventory entries before prepare-release\n' "${release_total}" >&2
for relative in "${release_brick_files[@]}"; do
  release_index=$((release_index + 1))
  item_started=${SECONDS}
  release_stage="pull ${release_index}/${release_total}"
  stage_started=${SECONDS}
  printf '[remote-release] pull %s/%s started: %s\n' "${release_index}" "${release_total}" "${relative}" >&2
  if "${rubble}" --no-banner pull --depth 1 --unpack -r "${RUBBLE_REMOTE_STORE}" "${script_dir}/${relative}"; then
    printf '[remote-release] pull %s/%s completed in %ss: %s\n' "${release_index}" "${release_total}" "$((SECONDS - item_started))" "${relative}" >&2
  else
    status=$?
    printf '[remote-release] pull %s/%s failed (exit %s) after %ss: %s\n' "${release_index}" "${release_total}" "${status}" "$((SECONDS - item_started))" "${relative}" >&2
    exit "${status}"
  fi
done
printf '[remote-release] inventory pulls completed in %ss; prepare-release hook started\n' "$((SECONDS - release_started))" >&2
hook_started=${SECONDS}
release_stage=prepare-release
stage_started=${SECONDS}
rubble_run_hook prepare-release
printf '[remote-release] prepare-release hook completed in %ss\n' "$((SECONDS - hook_started))" >&2

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
  printf '[remote-release] publishing %s prepared assets\n' "${#assets[@]}" >&2
  publish_started=${SECONDS}
  release_stage=publish
  stage_started=${SECONDS}
  "${rubble}" script --inherit-env "${script_dir}/${user_release_relative}"
  printf '[remote-release] publish completed in %ss (total %ss)\n' "$((SECONDS - publish_started))" "$((SECONDS - release_started))" >&2
fi