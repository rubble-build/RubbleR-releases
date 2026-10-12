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

  'store/tx/mz/brk-txmznhwijz6pz7m652w5pqqlymsnvboo2rsvqqwp7jprcfm6cw4a-zlib-1.3.2-r1.apk.brick'

  'store/26/us/brk-26usdrtsxslcuk33dt6uqeasrdrbu32fnsrtmbpilsslh5da6jgq-xz-libs-5.8.4-r0.apk.brick'

  'store/g5/r5/brk-g5r5a7z3ismvnzq5uwsre6sfoiprc6smte4xd4jcchttjjvqidtq-xz-5.8.4-r0.apk.brick'

  'store/5f/6h/brk-5f6h42fvytrovpiqc6uef6hb35eujabalgjpgxeksmjvoxwthtca-wasm-pack-v0.15.0-aarch64-unknown-linux-musl.tar.gz.brick'

  'store/76/la/brk-76lao3bnpein6f4ggp4dwci7cdyywjnb5i7by4forhkbzf6lju6a-wasm-pack-0.15.0.brick'

  'store/zm/2b/brk-zm2bpcu5lxnkvg3jntp5l3mmr5l7cvaqc27gswsvtwvjusugmqta-wasm-bindgen-0.2.115-aarch64-unknown-linux-gnu.tar.gz.brick'

  'store/dx/bm/brk-dxbm5xbf7vkb35noka43so2duja6uw3kitmmhxbybcer6op5bcla-utmps-libs-0.1.2.3-r2.apk.brick'

  'store/4u/ec/brk-4uecjax2lpo5idputrmq6yayy6admss7pdzmgzf6pwomzimzj3qa-unzip-6.0-r15.apk.brick'

  'store/pt/g4/brk-ptg4o4phfr2eutq2xrcoqi6zx2d2rk4nqoxdm73hvskgosibuh4a-tar-1.35-r2.apk.brick'

  'store/ow/oy/brk-owoyhne4rlabd6ti2usbbxf5qm6px4edpaa2ixltmg55lde2ckuq-sqlite-libs-3.48.0-r4.apk.brick'

  'store/tt/xo/brk-ttxoxb3lfk7t3rzpgq4m42lsl7lmgzt2e5w5pdt6rxna3q6pulra-skalibs-libs-2.14.3.0-r0.apk.brick'

  'store/is/xo/brk-isxo3o4skm7vtiqyhakx4x4uxrw7hnycm3ldwp43grskdhxl3qxq-sed-4.9-r2.apk.brick'

  'store/kf/5c/brk-kf5czgbhfrjlfvr54qqevkuwi43wqxq6nf25ih2xadevek5i2cpa-rustc-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/nw/ad/brk-nwadxrnuk7cydd6sigwmkqkyyxpkgj3b7bfoyhol66daeqo4rfka-rust-std-1.94.0-wasm32-unknown-unknown.tar.xz.brick'

  'store/ay/6k/brk-ay6kezqef2anhdm53akx7elc7ge7cmrhesutg3b6lzj2jolgnv2a-rust-std-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/by/lu/brk-bylu3g6upxzxamnew7hetpin3g47bzrxbhej2ejmeoeh57kg3jia-rubble-src-checkout.brick'

  'store/gp/d7/brk-gpd75vrjncv57fv3fzdfuoagqwgyqjwuizvdth2pdg7hv2q4lv5a-rubble-script-shebang.brick'

  'store/4x/2u/brk-4x2uexqjoqs5unyb4fxpdus3ctebmhvqnuruhalsl5rdwt3k6naa-rubble-canonical-script.brick'

  'store/3b/lb/brk-3blbc3vt3hw6l2yenxtxlwpfnv7432fvq4xhhkr7lbtpk7msi3pq-readline-8.2.13-r0.apk.brick'

  'store/g7/dv/brk-g7dv6ga4ffezwkuapyxkkf6ffe7qb5m3ktlskq3tzjhcatiknfxa-python3-3.12.15-r0.apk.brick'

  'store/cm/da/brk-cmdaozrcvaymmdfw3jodg7rrc4qwmaqyx6q3jj6u6nsie32hvdxq-publish-output-directory.brick'

  'store/yi/gm/brk-yigmijc5ij3rpsaberwyafdvndneutsn76xdruhwjcug2zlebmqq-rust-std-1.94.0-wasm32-unknown-unknown.brick'

  'store/aq/c3/brk-aqc3c2ahmtsuu36l7kwk4q27mc7dnxuylxzqusvu3fp7rcurg5kq-rust-std-1.94.0.brick'

  'store/5z/qz/brk-5zqzbtecxd2bwjpypfrcgfmzvuqihlmabhg5jtqztyhjc656maja-perl-5.40.4-r0.apk.brick'

  'store/es/iy/brk-esiyaxnxz3qbqhmjp3kjdfummyfpbmzr6eoub362jjpavkrlzyiq-pcre2-10.43-r0.apk.brick'

  'store/qb/rl/brk-qbrlu376mq3m5jhng65mdeobdbrpjzv3thrthfrpvoam77zovt3q-patchelf-0.18.0-aarch64.tar.gz.brick'

  'store/dh/zo/brk-dhzowymraqoa262lv45rzgrpjrqdedusoctmkao7qctbpck3qiva-patchelf.brick'

  'store/ad/yk/brk-adykhpm55qerngmtx6ke7csou4r73gh5lnubblp7jj6ro4oeyxna-patch-2.7.6-r10.apk.brick'

  'store/em/on/brk-emonumondcre3b5pnxo4hp5dzwkoobjp7fi6ofxmqudceo4dxjnq-node-v22.22.3-linux-arm64.tar.xz.brick'

  'store/2b/fw/brk-2bfwkovamqlgqawc2obxigc4yho4jgx6rrkc6tyhubog5tm2vhxa-nghttp2-libs-1.69.0-r0.apk.brick'

  'store/ko/ve/brk-kovec6hpuborsbsvc7t6mvkfvwylfdlf4evnpad24hnwoyiflz5q-musl-dev-1.2.5-r11.apk.brick'

  'store/qs/3n/brk-qs3nb5qcclaodccu6unqj42b76lly2d4htpputfm77xzao6fzema-musl-1.2.5-r11.apk.brick'

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

  'store/p6/eq/brk-p6eqluqrei7jxrpnr2nogcmndvhzkr37f2j47nrfkscrbtnpy64q-libssl3-3.3.7-r2.apk.brick'

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

  'store/dv/rl/brk-dvrllqig4vloxhgyjrmpzimbvdcatflu5xsgnfnhez77trxhzbaa-libcrypto3-3.3.7-r2.apk.brick'

  'store/yb/6t/brk-yb6tefhslyriibghffdurwb2wvapj6x3xizoboao2doaj7v7xgda-libcc1-0_14.2.0-19_arm64.deb.brick'

  'store/od/lz/brk-odlzblejigvixnek4zw3qpf6kdmpduizlfdol6phkrwrrltm3kdq-libc6_2.41-12_deb13u3_arm64.deb.brick'

  'store/lb/7v/brk-lb7vuv6w3fr43o73swpjgwfuwdhyi7l2xskuuisw3eaekunxv3ia-libc6-dev_2.41-12_deb13u3_arm64.deb.brick'

  'store/kq/oa/brk-kqoaqdowlcmrluolokiygo33evr47gordg5y3gqjf4etscxnee2a-libbz2-1.0.8-r6.apk.brick'

  'store/3p/wy/brk-3pwyzin2s6znyulfwpta6mbiky3ksdwnmvi4k4oblrddcyccpbkq-libbinutils_2.44-3_arm64.deb.brick'

  'store/zw/da/brk-zwdawolcw4fqjnlmmwfrxjwrxcplq7t3jb73x5seskofbtj353na-libattr-2.5.2-r2.apk.brick'

  'store/wx/52/brk-wx522xces6aeljkz5y55o6kdkgi6zgyvebi63xgqxclodxabs56q-libatomic1_14.2.0-19_arm64.deb.brick'

  'store/vq/3s/brk-vq3sirpitu5prsi2ig3ld3d7am7x6cxjxscc4qchsiecywgz3bfa-libatomic-14.2.0-r4.apk.brick'

  'store/fb/xg/brk-fbxgu4t24gr47iq2yhyaygays2hvcmyidx4tkwjmlx52pttyr6yq-libasan8_14.2.0-19_arm64.deb.brick'

  'store/z3/xh/brk-z3xhjdr5it75lq5iwals4toaklhutksbdphbucgwhtgqhxz32k6q-ld-musl.so.brick'

  'store/mv/w4/brk-mvw4balnruevggsruaxcd7m3dye6dlbrsjshobcplnic3svvd4rq-ld-musl.so.brick'

  'store/kt/bd/brk-ktbdwi3xid4ywlz6il2qlgx67aclu2t5gljy527g7vdnv6h7gaha-jansson-2.14-r4.apk.brick'

  'store/n6/vt/brk-n6vtqu3bxkksa6hlrwirri6entermnuofp2sdqcfcrzxarqrr3hq-isl26-0.26-r1.apk.brick'

  'store/ws/jd/brk-wsjd6bhyeay7o42k276g7ep5plfqmlqubqztlvbu5aw7rjjeuq2a-gzip-1.13-r1.apk.brick'

  'store/ja/2g/brk-ja2gawpefozngsdbmzs5n2a66ujesjats2qcq7homnixclj6iqrq-grep-3.11-r0.apk.brick'

  'store/ho/55/brk-ho552ymbr5wqlkbb7xckcvqfjs5fd4ytbrf5rjp3vaqnwocxhx5q-gmp-6.3.0-r2.apk.brick'

  'store/qg/3g/brk-qg3g2dinqfibxj3dkbjqgp6q4vhezm2w5ayy7ibamcbqov7sunuq-git-2.47.3-r0.apk.brick'

  'store/e5/bi/brk-e5bidgxbvr5crgxvo3tckxld466txu5dxi674pplgncc4fifmkva-gdbm-1.24-r0.apk.brick'

  'store/sa/xd/brk-saxdsta5ltm7iomdgyx3f23uma6qmu7hz674djpkjgbgi76tsisa-gcc-14.2.0-r4.apk.brick'

  'store/rg/ds/brk-rgdskue4seruek4fxopdeftkm4uf7jxa7nxjyqkhkj5yak2ebc4a-gcc-14-base_14.2.0-19_arm64.deb.brick'

  'store/q6/6x/brk-q66xooc3uyetlxp6565oyihya5babf4sn3opal27qo6em5wjkuca-gcc-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/5t/d6/brk-5td6qvq3hkwnfc5vqh6lcuv5xlk5yh26d2esafb7byxkpwl6klua-gawk-5.3.1-r0.apk.brick'

  'store/fu/4g/brk-fu4gjf2vujnnxzbws5i2w57yneqm7tmgiqzxodte6s6rf74vchrq-g__-14.2.0-r4.apk.brick'

  'store/mg/vp/brk-mgvpjsbz7sujl5qdndfmqhtclpxfhlytkeyidejyjfez5jloit7a-g__-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/m5/ln/brk-m5lnpllbzm555r5zuagxbaoqomumjvcwyoq7xdkffysmdvteelwa-findutils-4.10.0-r0.apk.brick'

  'store/qv/xc/brk-qvxcj4lj5jj5mbgvpcfw5svnfaljwbkil7ghzzofovoqehagqava-diffutils-3.10-r0.apk.brick'

  'store/oh/zg/brk-ohzg3khe3y5zbg6it742hi63cwoz7k3vbr5jufkccupj4kcrkpwq-curl-linux-aarch64-musl-8.18.0.tar.xz.brick'

  'store/fd/jo/brk-fdjot6csltdy7pfpendap6yybjo5niybzp6knbofokgq7mxbz6kq-curl.brick'

  'store/ov/g7/brk-ovg7cu6kkazcpj32mrk53yc3kb2z2mrl4yd5yzrj3uytgwcanawa-curl.brick'

  'store/nw/jn/brk-nwjntcya5bc7tfxrl5i22jo3v2rnlixwjc6ri3r4kwupxtwlaqsa-cpp-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/5w/sm/brk-5wsmysbedc7wbcb22csq254i5hrsdbwpdwuzyi5seacce7a4iaoa-coreutils-sha512sum-9.5-r2.apk.brick'

  'store/k2/sq/brk-k2sq3ksyc4xg4n3byfvtc2xp2by5lw3uus2pjw4ro7y4ad54uo4q-coreutils-fmt-9.5-r2.apk.brick'

  'store/cn/su/brk-cnsuk57bulhj544m3skp3wwq4lsh5qegyneycg7bgfo2zzu5z7ua-coreutils-env-9.5-r2.apk.brick'

  'store/es/h7/brk-esh7pawc46nsh5b2uuykm4qsjsoowbes5uu4nt2kcg6hocags6vq-coreutils-9.5-r2.apk.brick'

  'store/km/24/brk-km24gkz4zqqu7uqftehftqfd26smur3oitfkvhpv35pqsc5llvca-cargo-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/dc/7q/brk-dc7qtj7jms727isftojj6scxy5dtvk6sxndds5wdblbfjmti4diq-ca-certificates-bundle-20260909-r0.apk.brick'

  'store/zj/i5/brk-zji5om2su2ddkysxsg3xzzbvx7uvgespdsko7wze2bovygtgnuzq-ca-certificates.pem.brick'

  'store/ny/xv/brk-nyxvd2fuotdmxjktenzudif5x5zq2d5ohtbciy4t5ztyf7b7x2fq-ca-certificates.pem.brick'

  'store/b7/hd/brk-b7hdib2p2djrz7gu5mylkac6ijbvjwskm3shr5semy4ekaanow6q-c-ares-1.34.8-r0.apk.brick'

  'store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

  'store/2b/to/brk-2btooo6cnofph3xjrdgy2dezt4y4xl47ygmhqslj24ropfoiscdq-bun-linux-aarch64.zip.brick'

  'store/zr/7s/brk-zr7ser4omrmjwzjfkik44mdmgvtrjakkpkcqq4llvhfrke2n6sma-brotli-libs-1.1.0-r2.apk.brick'

  'store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

  'store/4g/be/brk-4gbejr52ozzofmznelc52fgic4nsoasxjr6i4phtf6utztaoz6la-binutils-common_2.44-3_arm64.deb.brick'

  'store/ec/xk/brk-ecxkum7thkjwggmltz3jlz67amewczlvf6ybucueqawsamou6t4a-binutils-aarch64-linux-gnu_2.44-3_arm64.deb.brick'

  'store/sg/dy/brk-sgdyuezwsbzpgusurjxb7bvquikinj455qz7q5c2emyrynor4f3q-binutils-2.43.1-r3.apk.brick'

  'store/zq/h6/brk-zqh6lunhozithbpfnbwqg5j54lg5ze77yzuwedmjltfo45ghffuq-binaryen-version_117-aarch64-linux.tar.gz.brick'

  'store/ta/cn/brk-tacnuufbmsgvjjdv35jnlei72ofv46gglzsjzt76wnp6nf7qphdq-binaryen-117.brick'

  'store/g3/fx/brk-g3fxen4ug3f3g34imdsefwplwd3ulzn75tn5uxd5jqe7t23bzyna-bash-linux-aarch64.brick'

  'store/7g/ai/brk-7gaiswvomctprmbv5i6dhxav3urpsmceezmwy52qv42yok44lygq-bash.brick'

  'store/o4/ts/brk-o4tslxh2uwmqgfv6heppd5d4xitkk6jpu773b5ok4dojf4pfzlia-write-native-toolchain-env.brick'

  'store/kr/tc/brk-krtc32gkhzcn3spc36a3ksbyjoykekcsx7bvmzj2mrxcmaxral2q-write-exec-wrappers.brick'

  'store/fc/jh/brk-fcjhtbtyxa5qk3xy5jhazosrdwgn6npaqbjmm7dmyoi756zrunca-normalize-python-runtime.brick'

  'store/em/7m/brk-em7mxxxvm3fi5ntxzzlsqiwx6ckrpsjtig7bc4cnljdv3mgn3osq-nodejs-build-tools.brick'

  'store/ty/qo/brk-tyqosp4fpdd7pjacveojot6m2g5ls3hqljfqp4qerplz2kuwcvua-musl-install-tools.brick'

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

  'store/de/fm/brk-defmfedonkfkblaqtfzjs7kvoq2u5k53xo3zzl43it7q634ax7ja-collect-shared-libraries.brick'

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

  'store/vf/th/brk-vfthpdhrrixmo7ewqosxes2hbagrr4iuhtp3x5ax4vrohm65ynba-bootstrap-env.brick'

  'store/7g/wd/brk-7gwdsqgvkrl5q7ztjhu2z65wbjt2eywqrtwg7xc7jewdoolhnmea-acl-libs-2.3.2-r1.apk.brick'

  'store/u6/gp/brk-u6gpy6gfub4xlqrvjvqq4dtfafufxauxuste7lkmoc6vvpkuzp2q-gnu-tar.brick'

  'store/r2/ag/brk-r2agl7x5h3nujgwasxf2d2vcopngkncwb6ronredz5n7o6va5s3a-coreutils.brick'

  'store/tx/2i/brk-tx2iwpuhoretwx7gt3mczqcjfolradt4egn6sikj25wxrf7k4hva-python3.brick'

  'store/ps/mh/brk-psmhk3rswggelskf3qvnkd7itd3bwmik75jdyyje4nh7jdmi3j4q-bootstrap-env.brick'

  'store/dz/3h/brk-dz3hrjf4ofomjm3ndcb7tywxrsmhmdnkusrbcyycryrydqv65wta-RubbleR.git.partial.brick'

  'store/vb/te/brk-vbtevx2mawx5viwt7bvre4owl56p5ocnksz6mdpdxibb3eefzzzq-RubbleR.git.partial.brick'

  'store/x7/qx/brk-x7qxtfi2npyewp64xdyhckglv5hrtv2qiahanhiw5vjsyqh7hxlq-RubbleR.git.partial.brick'

  'store/ls/yn/brk-lsynl73e7ktcvlmld6ewr3gisv7i2iozi6sk2jfwzmwk3xry6eta-glibc-runtime-support.brick'

  'store/sx/ko/brk-sxkohobqr6a6m2ablufksvklaofvkig6srfi3g57nuxyirvaj7ha-glibc-runtime-support.brick'

  'store/66/jx/brk-66jxu53cwkwsnco6ihr46qbvbgl567ejinmkuq3xuv6jcp2djxuq-rubble-elf-runtime.brick'

  'store/26/j6/brk-26j6wzm7hs7rr2xur7thtuzaxaofdjs6oq6c5dofczgmyafu47zq-gcc-glibc.brick'

  'store/2x/tf/brk-2xtfnbzjpolxyk7qwq2io2uep27gskbunbbq5suqouzubedaobia-rustc-1.94.0.brick'

  'store/as/po/brk-aspo4zoslypuz7dvhceditqnt6aznrsi4gubxm6t3ilj2csxrgkq-rubble-elf-runtime.brick'

  'store/tl/qm/brk-tlqml4ugs7p2qpt5kjq5npbr2itwz2jzjecvjhxucc5jnfhgd6xq-wasm-bindgen-cli-0.2.115.brick'

  'store/4k/57/brk-4k57773dbutwftqwqrfuxbktvvn6iyvqby4xf75e2kh36jraf4ga-nodejs-runtime.brick'

  'store/kt/kw/brk-ktkwocefankbahreprgte4qu5xcfc4hcajy7n55owd5zernajcyq-nodejs.brick'

  'store/6s/lp/brk-6slp5n453p4epf5vkebjevpv5evupfkjqpiaiz3wejmrmrkxgkjq-rubble-web-node-modules.brick'

  'store/27/lh/brk-27lhenhqhuia2b3j4mzor5u7wuncxqctarvg2wxhcwcea4s3fybq-llvm-tools-1.94.0.brick'

  'store/ej/dq/brk-ejdqlq53ggatey4cv4tv5jfsulmfwhwpgk4vi44ynqseyfaqn3uq-linux-native-toolchain.brick'

  'store/oe/zp/brk-oezpjuskndm65dhcpdnvf7vkbm43vloc4qaktw7eax24dld5oqwq-cargo-1.94.0.brick'

  'store/ke/ff/brk-keffkplm6prpwfdkdipufb6rj4aexo7qvdeugu3ugtiih2kvwreq-rust-web-wasm-toolchain.brick'

  'store/rr/re/brk-rrrezck3b4aixgbqlcufnm627wbt76d6adguhhiltllcsfajszda-rust-toolchain.brick'

  'store/y3/wh/brk-y3whdltlpkgmz3ignngwhuhseer7giqgogsjlphaefpekie5bxqq-bun-1.4.3.brick'

  'store/tv/oj/brk-tvojkizhgwszv5smsge3oetac3eqtb2rwzj6a7mqofgwkkenpxqq-bun-1.4.3.brick'

  'store/q4/he/brk-q4herzcgnjixdz2whd2wgrihqnubtbsoo3sroce3nyiqb3vqtrua-RubbleR.git.partial.brick'

  'store/vn/lq/brk-vnlqujt46wksvznn5ggox4putejqnxoscmcxfc75kmwbbqnbszna-rubble-deps-cache.brick'

  'store/r3/3n/brk-r33nde4rjqefgds4u2ac4zjmhbj5lezpwf2bqj23224l2jd3b5rq-rubble-web-assets.brick'

  'store/tg/sa/brk-tgsan56yxa6ux2hbr6dz2rc7c556bq4dilf4ugvzjxctacv2wn2a-RubbleR.git.brick'

  'store/bt/ad/brk-btad4wvl22dc7rtwelki64xp2naqzm7zbnroq7bp62pmsz7bmbta-rubble.brick'

  'store/hm/4r/brk-hm4rqjs5na3t6nwgyfr3t6rz7ly3odfkshtmnj243lkqt6rqvjra-rubble.brick'

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