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

  'store/5v/ex/brk-5vexncx3cian4rymupdaft3bwnvswvrzp6pcxohuilbll3lii53a-zstd-libs-1.5.6-r2.apk.brick'

  'store/p4/37/brk-p437dghiaad2yb57qr2yhpsmwaw3z3jwfkdlsqaf6pgahrueysja-zstd-1.5.6-r2.apk.brick'

  'store/dk/ct/brk-dkctajvl2il4pypc32olxna3wh7rq2dnch3in6y6qkziz74prrka-zlib1g_1.3.dfsg_really1.3.1-1_b1_arm64.deb.brick'

  'store/ay/vl/brk-ayvlr7htt6lml5iosty2yuiuogndl4xwu27xkbizrjbocyts5nrq-zlib-1.3.2-r0.apk.brick'

  'store/rl/qg/brk-rlqgbuxu4kleo257tmrhzkllhb6thfjrmbcsr6hkxf2cduly7vta-xz-libs-5.8.3-r0.apk.brick'

  'store/on/cm/brk-oncm47zwljpb5u4lekuyhgdpx5rv4mn6vxvbkmuxps6izjagxiva-xz-5.8.3-r0.apk.brick'

  'store/7h/vr/brk-7hvrra6ygcaaeexgncdv3uasq6xy65zzagujucn6atyplqhhviua-wasm-pack-0.15.0.brick'

  'store/zm/2b/brk-zm2bpcu5lxnkvg3jntp5l3mmr5l7cvaqc27gswsvtwvjusugmqta-wasm-bindgen-0.2.115-aarch64-unknown-linux-gnu.tar.gz.brick'

  'store/dx/bm/brk-dxbm5xbf7vkb35noka43so2duja6uw3kitmmhxbybcer6op5bcla-utmps-libs-0.1.2.3-r2.apk.brick'

  'store/4u/ec/brk-4uecjax2lpo5idputrmq6yayy6admss7pdzmgzf6pwomzimzj3qa-unzip-6.0-r15.apk.brick'

  'store/pt/g4/brk-ptg4o4phfr2eutq2xrcoqi6zx2d2rk4nqoxdm73hvskgosibuh4a-tar-1.35-r2.apk.brick'

  'store/ow/oy/brk-owoyhne4rlabd6ti2usbbxf5qm6px4edpaa2ixltmg55lde2ckuq-sqlite-libs-3.48.0-r4.apk.brick'

  'store/tt/xo/brk-ttxoxb3lfk7t3rzpgq4m42lsl7lmgzt2e5w5pdt6rxna3q6pulra-skalibs-libs-2.14.3.0-r0.apk.brick'

  'store/is/xo/brk-isxo3o4skm7vtiqyhakx4x4uxrw7hnycm3ldwp43grskdhxl3qxq-sed-4.9-r2.apk.brick'

  'store/kf/5c/brk-kf5czgbhfrjlfvr54qqevkuwi43wqxq6nf25ih2xadevek5i2cpa-rustc-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/ry/gp/brk-rygpip6ibvqdklrmfwyhoin4d2a6ee7yzsubvi7s7aqkyqp7ervq-rust-std-1.94.0-wasm32-unknown-unknown.brick'

  'store/aa/bk/brk-aabkmflstkagk4gv7pzdgfmzkzirwp5zxrcvnqcuhdy2dg2zigwq-rust-std-1.94.0.brick'

  'store/y3/gq/brk-y3gqhzlv6vmh4jetdn3mgwhesiuk4n7dameomztj7fo5fxvgp4wa-rubble-src-checkout.brick'

  'store/zt/bw/brk-ztbwuqmg77pfi6tzkoy4asfmpiy22x6lugzprlhhhvjldam36n4q-rubble-script-shebang.brick'

  'store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'store/3b/lb/brk-3blbc3vt3hw6l2yenxtxlwpfnv7432fvq4xhhkr7lbtpk7msi3pq-readline-8.2.13-r0.apk.brick'

  'store/gb/6k/brk-gb6koiwm57ptlyzvdywugocbx67enpv3tog76ksqiccrr3pxaota-python3-3.12.14-r0.apk.brick'

  'store/5z/qz/brk-5zqzbtecxd2bwjpypfrcgfmzvuqihlmabhg5jtqztyhjc656maja-perl-5.40.4-r0.apk.brick'

  'store/es/iy/brk-esiyaxnxz3qbqhmjp3kjdfummyfpbmzr6eoub362jjpavkrlzyiq-pcre2-10.43-r0.apk.brick'

  'store/te/ie/brk-teieaxxyjdoyw4gqby5r4ywgrstjp3t6ui4dxasa6j7ba34arziq-patchelf.brick'

  'store/cn/de/brk-cndex52rgwiybhxcbkpry2isc55dz3hrc5lblmzr3xyeilghixda-patchelf.brick'

  'store/ad/yk/brk-adykhpm55qerngmtx6ke7csou4r73gh5lnubblp7jj6ro4oeyxna-patch-2.7.6-r10.apk.brick'

  'store/em/on/brk-emonumondcre3b5pnxo4hp5dzwkoobjp7fi6ofxmqudceo4dxjnq-node-v22.22.3-linux-arm64.tar.xz.brick'

  'store/2b/fw/brk-2bfwkovamqlgqawc2obxigc4yho4jgx6rrkc6tyhubog5tm2vhxa-nghttp2-libs-1.69.0-r0.apk.brick'

  'store/ko/ve/brk-kovec6hpuborsbsvc7t6mvkfvwylfdlf4evnpad24hnwoyiflz5q-musl-dev-1.2.5-r11.apk.brick'

  'store/jw/hf/brk-jwhfx26nkv24vmnfckbvccnpwdkzwfvxcjty7dhntghaemjlpfxq-mpfr4-4.2.1-r0.apk.brick'

  'store/i6/rp/brk-i6rpnovdyaumnm4dbmqheqhnimae5nyro5b25ewahcsz4tksxefq-mpdecimal-4.0.0-r0.apk.brick'

  'store/fg/32/brk-fg32tsmkrioagedunckpr37qz35rn4b7obxt3wsbxx56ajpxviza-mpc1-1.3.1-r1.apk.brick'

  'store/hd/hi/brk-hdhimhaqn7bul5k67m2gmw4ea6xibuprz2mgla5obsjibs7tfnoa-make-4.4.1-r2.apk.brick'

  'store/oe/dx/brk-oedx42pgtkscsyrm2vn6hyrci7hw74ladlpu6f6bwgt5yguhmyqq-m4-1.4.19-r3.apk.brick'

  'store/f4/2p/brk-f42ppjfbnfjsed7bwyertmyxb2rwak677b54f7masrcakdbb725q-llvm-tools-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/ea/y2/brk-eay2yd76jtq2n72kafauwkofupanezwq2muobm7bjlf6mfojk4ma-linux-libc-dev_6.12.86-1_all.deb.brick'

  'store/3e/xo/brk-3exo4yvcmu45p6oevi6u6v7fkppbt2fohg5gpkfvwhjykut7m3wa-linux-headers-6.6-r1.apk.brick'

  'store/kp/e7/brk-kpe7kma33nmt3mijbihbuzazuupuiq4ffqabvfgogzgs2rdp2rfa-libzstd1_1.5.7_dfsg-1_arm64.deb.brick'

  'store/fa/qk/brk-faqk22fjqryqxjx6pkufmb2mttau3gwuv2qu6roi3d4melszcu7q-libunistring-1.2-r0.apk.brick'

  'store/za/b7/brk-zab7x4pj4e4cmrnw753rp5hyl7jadtxtfddargzdbkkqoq2k7uwq-libubsan1_14.2.0-19_arm64.deb.brick'

  'store/qn/3l/brk-qn3lywhoc2dno3mvjvoq3mihzjcc6yz76oy3bvxnhgrsw5ewd7xq-libtsan2_14.2.0-19_arm64.deb.brick'

  'store/gb/4d/brk-gb4dlxkuu36d4olrckbxrdwlkvocpv2amucqerzpih2nv5w3uxuq-libstdc__6_14.2.0-19_arm64.deb.brick'

  'store/fz/so/brk-fzsocvqoawb6atzh5tfjxgahm2yualfjxwxicd55hjyf4gfjo5da-libstdc__-dev-14.2.0-r4.apk.brick'

  'store/hw/ud/brk-hwudtbqp6mtqd433zl777ixamegzf5s6pqjc3vbkw4yy7ca6rpzq-libstdc__-14.2.0-r4.apk.brick'

  'store/sl/7z/brk-sl7zsbzcfjdoz6ohe72ecirudxewciohnjumdqn7bkuunn2hp5lq-libstdc__-14-dev_14.2.0-19_arm64.deb.brick'

  'store/xd/cj/brk-xdcjb5anir2fm7jr5abmf2vtwqiltfj6pr3sufepj6l72bh2azfa-libssl3-3.3.7-r0.apk.brick'

  'store/e7/aw/brk-e7aw53vitgjqbosohujzxudnmbfqylyi27ehtmvbucoevvgocfoq-libsframe1_2.44-3_arm64.deb.brick'

  'store/77/pa/brk-77pafwgzhgk3kbtyd3i5bnikedwfoif6mfaibfesmfc655t35naq-libpsl-0.21.5-r3.apk.brick'

  'store/qm/dv/brk-qmdv4se7cy5zxuxhuq6la3h562eim3kyrj3eud44s2njzmqn3mlq-libpanelw-6.5_p20241006-r3.apk.brick'

  'store/ng/2y/brk-ng2yhab3txqyfgtnrgwttzyliczkrx52jeu7skkoaxeu5d752ynq-libncursesw-6.5_p20241006-r3.apk.brick'

  'store/mf/wk/brk-mfwkvtv3n6hvvrci2nxbilte5df2wpayqreolg3t5xnlwedydz2q-libmpfr6_4.2.2-1_arm64.deb.brick'

  'store/ex/wh/brk-exwhj5vebfaduvvhd7f6xtppocqwgqam7csyi3u5434k3ypqofpq-libmpc3_1.3.1-1_b3_arm64.deb.brick'

  'store/pj/6o/brk-pj6ok275ispcmivb4gpez2bzug46p2ge6a7pd3dncpfzelwebihq-liblsan0_14.2.0-19_arm64.deb.brick'

  'store/3o/ot/brk-3oothg4a44icdojzlibmxrxhn2xs6hase67u2pgy4z77l7gj6kgq-libjansson4_2.14-2_b3_arm64.deb.brick'

  'store/qx/xt/brk-qxxt6f726go3553r3bhxadzrgj637yghleeivlrsywklrpcr3pnq-libitm1_14.2.0-19_arm64.deb.brick'

  'store/3i/sl/brk-3isljfsdiufidx6nanfu323k7zozw2mkua3ht56d2dlnq6eideca-libisl23_0.27-1_arm64.deb.brick'

  'store/s3/pv/brk-s3pvvtqxrdzleije623ea64covxuywd4s6akx2d5lpxokyytr4ea-libidn2-2.3.7-r0.apk.brick'

  'store/hr/3g/brk-hr3gsmedt3iyx26xhety6rvbs2nzhv6o4oyscyt7qvuuixa7fbfa-libhwasan0_14.2.0-19_arm64.deb.brick'

  'store/ks/6e/brk-ks6e3u26mzxm5dwrtt4v2y5z6hltzyyoqnn5v36ctpuvq3z5ebga-libgomp1_14.2.0-19_arm64.deb.brick'

  'store/na/a2/brk-naa2ad3mxbwsl6syyyeikeu6srwar3mxn4lv6faf72kx6hjpq72q-libgomp-14.2.0-r4.apk.brick'

  'store/i3/vz/brk-i3vzwzq5ceekylzear5wrwz4teano37g32htjtcd4rma3zvjzz3a-libgmp10_6.3.0_dfsg-3_arm64.deb.brick'

  'store/3n/3b/brk-3n3bc5ncagillpn2mz3jicaeyjvq6myp5b2prh2kn6tllwded3qa-libgcc-s1_14.2.0-19_arm64.deb.brick'

  'store/bs/cz/brk-bsczck3itaibqqkhhwkkzdh3fv5i477527aika7gfcttdyn6chhq-libgcc-14.2.0-r4.apk.brick'

  'store/rm/4z/brk-rm4zxsn5qycajrfwexlu4perkspongbyp6ae77564am5knq453wa-libgcc-14-dev_14.2.0-19_arm64.deb.brick'

  'store/em/um/brk-emumr4qhmj3md4udqk36vvpcou3bcq2q6x47b2utro76mglanp6q-libffi-3.4.7-r0.apk.brick'

  'store/5h/u5/brk-5hu5obb4yrhcphlmjq4eze7rbdrnkszt7o2obqnpvtuehzgqdqoa-libexpat-2.8.4-r0.apk.brick'

  'store/tp/ql/brk-tpqlnp3dvgnq36l5ubgs4c2ficukfs4d4v3nllkbxjvgoluw4eta-libcurl-8.14.1-r2.apk.brick'

  'store/xa/vn/brk-xavn33v6xwtxgf7j7snhvwd5urqxswa4c2d2hxtjxjza37nizg4a-libctf0_2.44-3_arm64.deb.brick'

  'store/vs/wq/brk-vswqqehwz73whpxezmbr7nf4anbs7slwoknh6pi76q7askntz5iq-libctf-nobfd0_2.44-3_arm64.deb.brick'

  'store/zk/j7/brk-zkj7262l7rctago4tw4edylztcehl6bcvsxrow4o4lpqurjcftdq-libcrypto3-3.3.7-r0.apk.brick'

  'store/yb/6t/brk-yb6tefhslyriibghffdurwb2wvapj6x3xizoboao2doaj7v7xgda-libcc1-0_14.2.0-19_arm64.deb.brick'

  'store/od/lz/brk-odlzblejigvixnek4zw3qpf6kdmpduizlfdol6phkrwrrltm3kdq-libc6_2.41-12_deb13u3_arm64.deb.brick'

  'store/lb/7v/brk-lb7vuv6w3fr43o73swpjgwfuwdhyi7l2xskuuisw3eaekunxv3ia-libc6-dev_2.41-12_deb13u3_arm64.deb.brick'

  'store/kq/oa/brk-kqoaqdowlcmrluolokiygo33evr47gordg5y3gqjf4etscxnee2a-libbz2-1.0.8-r6.apk.brick'

  'store/3p/wy/brk-3pwyzin2s6znyulfwpta6mbiky3ksdwnmvi4k4oblrddcyccpbkq-libbinutils_2.44-3_arm64.deb.brick'

  'store/zw/da/brk-zwdawolcw4fqjnlmmwfrxjwrxcplq7t3jb73x5seskofbtj353na-libattr-2.5.2-r2.apk.brick'

  'store/wx/52/brk-wx522xces6aeljkz5y55o6kdkgi6zgyvebi63xgqxclodxabs56q-libatomic1_14.2.0-19_arm64.deb.brick'

  'store/vq/3s/brk-vq3sirpitu5prsi2ig3ld3d7am7x6cxjxscc4qchsiecywgz3bfa-libatomic-14.2.0-r4.apk.brick'

  'store/fb/xg/brk-fbxgu4t24gr47iq2yhyaygays2hvcmyidx4tkwjmlx52pttyr6yq-libasan8_14.2.0-19_arm64.deb.brick'

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

  'store/kt/bd/brk-ktbdwi3xid4ywlz6il2qlgx67aclu2t5gljy527g7vdnv6h7gaha-jansson-2.14-r4.apk.brick'

  'store/n6/vt/brk-n6vtqu3bxkksa6hlrwirri6entermnuofp2sdqcfcrzxarqrr3hq-isl26-0.26-r1.apk.brick'

  'store/ws/jd/brk-wsjd6bhyeay7o42k276g7ep5plfqmlqubqztlvbu5aw7rjjeuq2a-gzip-1.13-r1.apk.brick'

  'store/mn/tw/brk-mntwl3ijgyyni3rz7tnm25uavccs64wnoqxi6tswq6v3v4enc4bq-gzip.brick'

  'store/yj/p2/brk-yjp24zdh4gi64ec4qz232quwujkbijecntx37fvj5spvlkuqvn2a-gzip.brick'

  'store/ja/2g/brk-ja2gawpefozngsdbmzs5n2a66ujesjats2qcq7homnixclj6iqrq-grep-3.11-r0.apk.brick'

  'store/ny/m5/brk-nym5rumztuo443j6jodlaz243b7rifksbzmicvlqaageqnfrppva-grep.brick'

  'store/wk/vm/brk-wkvmcan7p2iuhnys5jhmvjhwje2gexvx37ept4kun7td6dt2jp4q-grep.brick'

  'store/gm/62/brk-gm62dcc7oanvf6pvef6m5lcyzxdbp5b3qe57rb3js7sss4vukjka-gpatch.brick'

  'store/mc/eh/brk-mcehjsnd6c44hkh6aybb3fcusdfxwcu2mmzmhuyvhg6qhec5yapa-gpatch.brick'

  'store/zs/in/brk-zsinhazapn2veaih52jxuezaslxcjtrt6nafubyxjqz3joee57ca-gnu-sed.brick'

  'store/v4/3b/brk-v43bd3czplropwap7voojb6bv3uw6cx5nbhblbnpod5rkxjhuebq-gnu-sed.brick'

  'store/f6/a7/brk-f6a7sajqali7f47k3swxnxmsq3peovl5ykpvzt33zpf5t52t6g5a-gnu-make.brick'

  'store/eo/2o/brk-eo2opoxn4hmzc3qxtlydlbszxwcv7gibdkulpfmkfziybocjbeba-gnu-make.brick'

  'store/ho/55/brk-ho552ymbr5wqlkbb7xckcvqfjs5fd4ytbrf5rjp3vaqnwocxhx5q-gmp-6.3.0-r2.apk.brick'

  'store/qg/3g/brk-qg3g2dinqfibxj3dkbjqgp6q4vhezm2w5ayy7ibamcbqov7sunuq-git-2.47.3-r0.apk.brick'

  'store/e5/bi/brk-e5bidgxbvr5crgxvo3tckxld466txu5dxi674pplgncc4fifmkva-gdbm-1.24-r0.apk.brick'

  'store/sa/xd/brk-saxdsta5ltm7iomdgyx3f23uma6qmu7hz674djpkjgbgi76tsisa-gcc-14.2.0-r4.apk.brick'

  'store/rg/ds/brk-rgdskue4seruek4fxopdeftkm4uf7jxa7nxjyqkhkj5yak2ebc4a-gcc-14-base_14.2.0-19_arm64.deb.brick'

  'store/q6/6x/brk-q66xooc3uyetlxp6565oyihya5babf4sn3opal27qo6em5wjkuca-gcc-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/5t/d6/brk-5td6qvq3hkwnfc5vqh6lcuv5xlk5yh26d2esafb7byxkpwl6klua-gawk-5.3.1-r0.apk.brick'

  'store/s7/pe/brk-s7pepykzvm4rodcuz2lqdnnti25ivmyn6hvaualljcja4pmqrjkq-gawk.brick'

  'store/qs/xv/brk-qsxvdk3agpg6ikdoivzkz2bs2aqqxoyjclqwdbl7vrkse363dofq-gawk.brick'

  'store/fu/4g/brk-fu4gjf2vujnnxzbws5i2w57yneqm7tmgiqzxodte6s6rf74vchrq-g__-14.2.0-r4.apk.brick'

  'store/mg/vp/brk-mgvpjsbz7sujl5qdndfmqhtclpxfhlytkeyidejyjfez5jloit7a-g__-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/m5/ln/brk-m5lnpllbzm555r5zuagxbaoqomumjvcwyoq7xdkffysmdvteelwa-findutils-4.10.0-r0.apk.brick'

  'store/ra/4g/brk-ra4gv7ib6y4ulchvtczh5wnhli33mvem74j54eapirukl5af5twq-findutils.brick'

  'store/46/xw/brk-46xwv4ctgwq2n2jt7ex4x7bsznc55f2z7yykja7yhdzegknpnkaq-findutils.brick'

  'store/qv/xc/brk-qvxcj4lj5jj5mbgvpcfw5svnfaljwbkil7ghzzofovoqehagqava-diffutils-3.10-r0.apk.brick'

  'store/o7/cz/brk-o7czghgecqaqhg2yqjwcdbzkpzbu5rtk6sambsubjyzpedg5bskq-diffutils.brick'

  'store/cd/dm/brk-cddmxlrjnyk4c4674ocfikhwnpqfj3kab7ke3lzcwiubazae7vra-diffutils.brick'

  'store/ad/cr/brk-adcrhlud4lao22xpeqdtkmm3cbdxrk4yn7hqqh4y2wguzsupqiqq-curl.brick'

  'store/bg/yp/brk-bgypnnermvrmj657kbamz6dhvtc7ic743c3tlooizg54udk3ocka-curl.brick'

  'store/nw/jn/brk-nwjntcya5bc7tfxrl5i22jo3v2rnlixwjc6ri3r4kwupxtwlaqsa-cpp-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/5w/sm/brk-5wsmysbedc7wbcb22csq254i5hrsdbwpdwuzyi5seacce7a4iaoa-coreutils-sha512sum-9.5-r2.apk.brick'

  'store/k2/sq/brk-k2sq3ksyc4xg4n3byfvtc2xp2by5lw3uus2pjw4ro7y4ad54uo4q-coreutils-fmt-9.5-r2.apk.brick'

  'store/cn/su/brk-cnsuk57bulhj544m3skp3wwq4lsh5qegyneycg7bgfo2zzu5z7ua-coreutils-env-9.5-r2.apk.brick'

  'store/es/h7/brk-esh7pawc46nsh5b2uuykm4qsjsoowbes5uu4nt2kcg6hocags6vq-coreutils-9.5-r2.apk.brick'

  'store/km/24/brk-km24gkz4zqqu7uqftehftqfd26smur3oitfkvhpv35pqsc5llvca-cargo-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/n6/47/brk-n6475wvske6j4dxfuhhbk6gplesuoo6c3tzd2p4bk5cciypjdqna-ca-certificates.pem.brick'

  'store/du/so/brk-dusoct55bmpgvm2ldpmeths6hggdhr33vyflycel7kjgjw3ts6ha-ca-certificates.pem.brick'

  'store/b7/hd/brk-b7hdib2p2djrz7gu5mylkac6ijbvjwskm3shr5semy4ekaanow6q-c-ares-1.34.8-r0.apk.brick'

  'store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

  'store/fx/ry/brk-fxryxn436wjuxw65ie7fbuhrasf7o4qinnx6ahmezla4gx52hboq-bzip2.brick'

  'store/tv/nr/brk-tvnruh4farfdymxw4stifghd6gpm6absnwfi3ys2slpz3hj2diwq-bzip2.brick'

  'store/sb/d6/brk-sbd67om27qkuxxrdw3tvbfvzq7w6wrvgygynmeee5t3jdicydboq-bun-linux-aarch64.zip.brick'

  'store/zr/7s/brk-zr7ser4omrmjwzjfkik44mdmgvtrjakkpkcqq4llvhfrke2n6sma-brotli-libs-1.1.0-r2.apk.brick'

  'store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

  'store/4g/be/brk-4gbejr52ozzofmznelc52fgic4nsoasxjr6i4phtf6utztaoz6la-binutils-common_2.44-3_arm64.deb.brick'

  'store/ec/xk/brk-ecxkum7thkjwggmltz3jlz67amewczlvf6ybucueqawsamou6t4a-binutils-aarch64-linux-gnu_2.44-3_arm64.deb.brick'

  'store/sg/dy/brk-sgdyuezwsbzpgusurjxb7bvquikinj455qz7q5c2emyrynor4f3q-binutils-2.43.1-r3.apk.brick'

  'store/si/63/brk-si63kbjoeh5l76hedrmuxjzzuolovggsbkabc2fqnwt7ujic7ajq-binaryen-117.brick'

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

  'store/7g/wd/brk-7gwdsqgvkrl5q7ztjhu2z65wbjt2eywqrtwg7xc7jewdoolhnmea-acl-libs-2.3.2-r1.apk.brick'

  'store/dg/fg/brk-dgfg3arw3up6lbm5g4sarffhzl2gc4nlqp4inr4ry74xdwbabp7q-gnu-tar.brick'

  'store/is/qs/brk-isqs4s7jt5knyrl7rm3ynm2n7ct37bn22zwmfmz7jkw3dhdezhwa-coreutils.brick'

  'store/c6/nb/brk-c6nbydiwm6hlbbp334o3ne36hta7rvmng5n7wqc7nlv6cs7d2sua-python3.brick'

  'store/qh/rz/brk-qhrzxrzpshk7wssuicwdv5uyvtrlzx2zi373o7esjgbpedtcmtnq-bootstrap-env.brick'

  'store/ce/sb/brk-cesb3w56bomtrhmptwovhwvtc57txanwuou5rmlhbaommxggxpzq-RubbleR.git.partial.brick'

  'store/ey/hj/brk-eyhj3p4imbapumokkpl7wjkijfuhzw22wnkvzm4qnngbrqw6gzga-glibc-runtime-support.brick'

  'store/fx/wo/brk-fxwo6gh42pwxkmohkpzzx7epy4c7sqp5nb7wdjn37xjoexk72qva-glibc-runtime-support.brick'

  'store/4r/ck/brk-4rckfmhopkgpqnaaqveh3binf5hveoq4dodae6gqqwzwmiihrsqq-gcc-glibc.brick'

  'store/4s/os/brk-4sos335zpymhnscctuhbp65ol5rkl5ggtcpgnv76ghqv6mtgqdja-rustc-1.94.0.brick'

  'store/vd/fc/brk-vdfcpqjosulvutdbkkg6j2dd4y3np4gyyzgcgn76q4ereaajq4yq-rubble-elf-runtime.brick'

  'store/gc/hs/brk-gchswiypwnoteybvspodsspdoi7lpixkqd5ylhotk5eidljeearq-wasm-bindgen-cli-0.2.115.brick'

  'store/yv/34/brk-yv34zjk6wjp5xmxfbizv6wtyki26s2elan2u5zse6bncztvmooja-nodejs-runtime.brick'

  'store/bt/mx/brk-btmxp7cxjrth2bvlt3kgx3bavmmzknstq43o252qdzeip2ccld4a-nodejs.brick'

  'store/bx/on/brk-bxonzrjzfivfzz7gy5xrcdwtuaym4mkhh45ul3xhzdfgt6netfua-llvm-tools-1.94.0.brick'

  'store/hv/4a/brk-hv4aefztcbtrgq6zlytrd342qe3ipq25jdgyhh5fdtgehm6tlwwa-linux-native-toolchain.brick'

  'store/yi/j2/brk-yij2hr7uubszcoc42epccslrqxeqxqpnl6pzbgmkeu73yuzjclyq-gcc-glibc.brick'

  'store/5y/xv/brk-5yxvhgqz2qdzccxbzdlx73h2w3x4gv4lfdc6odbg7fnypnvqa4ma-rustc-1.94.0.brick'

  'store/2k/rb/brk-2krbwasdoc6c4z33nejq23ttapdik5szjed24s65ouy5mxviosdq-rubble-elf-runtime.brick'

  'store/5j/lv/brk-5jlv2hecln7xhpc6gcfn7rpt726r4fpe32obn65vnrzjmkepkd2a-llvm-tools-1.94.0.brick'

  'store/vo/sw/brk-voswu5mhjrk3x3y5qk25nyo6oaekeo4ubyf53no67hqjipxmic2a-linux-native-toolchain.brick'

  'store/sg/m5/brk-sgm54fulikr5irvv322tits3duh7hngxxgqrpiu3ga5ingge4isa-cargo-1.94.0.brick'

  'store/7d/kp/brk-7dkpc67swnfyyyivkty3bphrsj52ettgm2b57vtlsomp45s6663q-rust-toolchain.brick'

  'store/6m/tn/brk-6mtnt3fw2aa2keybnykvzsprwfcbz2qyi5b4p6q5wl2echuhwira-cargo-1.94.0.brick'

  'store/dp/63/brk-dp63dag4yzcwjd2lwbfg6dk7xpapeqg6uqxxci2nyqblg3ndjv6a-rust-web-wasm-toolchain.brick'

  'store/ns/tf/brk-nstff6uhyhjielex3j37qcb7kg2hmrahjijkltz2mga43de3dg7a-rust-toolchain.brick'

  'store/dc/fo/brk-dcfonqabj4jd3dagsbk255cb7kxxytkebvc4yq7t6ts3c2qqsoma-bun-1.4.2.brick'

  'store/fc/6s/brk-fc6scnw3v4skjlzaemleq3stlcqba3ppvs7n453zymkdiexbucwa-bun-1.4.2.brick'

  'store/e2/km/brk-e2kmlhq7vibolvwkn65esung4pirpbjnk5f6yvetvhrb2bkbtreq-RubbleR.git.partial.brick'

  'store/ii/bk/brk-iibkgmmyuuezxc755wcop3o2xylkpwukbk55j3n4ii4j27nfig7a-rubble-deps-cache.brick'

  'store/vs/x4/brk-vsx4xwcgfmpb6acdnm53wanlc7wuksgygnurnwwaex4iptsvaeza-rubble-deps-cache.brick'

  'store/k5/dd/brk-k5ddixx3ivvxlqtykdnr2ojpyecxjf7lajp4toelh5b3zpjzupla-RubbleR.git.partial.brick'

  'store/zf/p6/brk-zfp6hsclxsgu44kpcqkud2cryz4k25cw46x2mcwejzeeeozo2j2q-RubbleR.git.partial.brick'

  'store/sa/c6/brk-sac6xpspnndeeqg64jhxlgtchiydh3ffv5d3i3n6bsrpbtglxvrq-rubble-web-node-modules.brick'

  'store/ew/ul/brk-ewulq7nxn74ek4wgce4phw43pvwfu3mimopcvvy7eiipeglwrhdq-rubble-web-assets.brick'

  'store/55/fs/brk-55fseq5xadc6hyzikfxsfgtsy5xcbcmnvhoy3hozboxuhrqfyorq-rubble-web-assets.brick'

  'store/u3/uw/brk-u3uw2zr7v4r6jv5awi3dghde37verqa565yg5ny2766w26jhsagq-RubbleR.git.brick'

  'store/xd/ff/brk-xdff5n7tzbty3u4hmc7zorsoortssk4lkxqghrrjfzyglgxkrofq-rubble.brick'

  'store/ou/tz/brk-outzfuv2ojssqyll44vizqgjqy6ohrr6iztzrimqb53eqlbukpla-RubbleR.git.brick'

  'store/3e/ol/brk-3eolsvcvh4lu23wcdycqldbyvhi2qyoauwmuy3hjxmuamq3zlzqq-rubble.brick'

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