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

  'store/hl/6d/brk-hl6djaj44qkp6rily6m7uf6lsksicuvyiukbsphwqzo7zhddpzna-zstd-libs-1.5.6-r2.apk.brick'

  'store/5v/ex/brk-5vexncx3cian4rymupdaft3bwnvswvrzp6pcxohuilbll3lii53a-zstd-libs-1.5.6-r2.apk.brick'

  'store/p4/37/brk-p437dghiaad2yb57qr2yhpsmwaw3z3jwfkdlsqaf6pgahrueysja-zstd-1.5.6-r2.apk.brick'

  'store/dk/ct/brk-dkctajvl2il4pypc32olxna3wh7rq2dnch3in6y6qkziz74prrka-zlib1g_1.3.dfsg_really1.3.1-1_b1_arm64.deb.brick'

  'store/sc/of/brk-scofokclgi3ex4hzrtnmlf6lpkcpmii52orptjcupfmikihi6kxq-zlib1g_1.3.dfsg_really1.3.1-1_b1_amd64.deb.brick'

  'store/2g/mb/brk-2gmbwm7hmynv7bo7toieqvwfon7d47sb5peqrimgmeapxwoeazla-zlib-1.4-r0.apk.brick'

  'store/2z/yl/brk-2zylpggqvy5wrqoxp22pstx4hls2mcr4otvvtmov5ghmw4hoz7za-zlib-1.3.2-r1.apk.brick'

  'store/26/us/brk-26usdrtsxslcuk33dt6uqeasrdrbu32fnsrtmbpilsslh5da6jgq-xz-libs-5.8.4-r0.apk.brick'

  'store/g5/r5/brk-g5r5a7z3ismvnzq5uwsre6sfoiprc6smte4xd4jcchttjjvqidtq-xz-5.8.4-r0.apk.brick'

  'store/5f/6h/brk-5f6h42fvytrovpiqc6uef6hb35eujabalgjpgxeksmjvoxwthtca-wasm-pack-v0.15.0-aarch64-unknown-linux-musl.tar.gz.brick'

  'store/76/la/brk-76lao3bnpein6f4ggp4dwci7cdyywjnb5i7by4forhkbzf6lju6a-wasm-pack-0.15.0.brick'

  'store/jo/mf/brk-jomf52m6ijsokfau3fyyvgd7elhgiiavaic5tzdw6lhugeziyhna-wasm-pack-0.15.0.brick'

  'store/xk/pw/brk-xkpwht5j77al73t57tas35u6xacltjd3sdjh6edfidlq5jbuz4ga-wasm-bindgen-cli-0.2.130.brick'

  'store/6o/fb/brk-6ofbtcdyl2ncnjav3ntckdmw6efl7mfixfllsf2cs7377cl3pkkq-wasm-bindgen-0.2.130-aarch64-unknown-linux-gnu.tar.gz.brick'

  'store/dx/bm/brk-dxbm5xbf7vkb35noka43so2duja6uw3kitmmhxbybcer6op5bcla-utmps-libs-0.1.2.3-r2.apk.brick'

  'store/4u/ec/brk-4uecjax2lpo5idputrmq6yayy6admss7pdzmgzf6pwomzimzj3qa-unzip-6.0-r15.apk.brick'

  'store/pt/g4/brk-ptg4o4phfr2eutq2xrcoqi6zx2d2rk4nqoxdm73hvskgosibuh4a-tar-1.35-r2.apk.brick'

  'store/ow/oy/brk-owoyhne4rlabd6ti2usbbxf5qm6px4edpaa2ixltmg55lde2ckuq-sqlite-libs-3.48.0-r4.apk.brick'

  'store/tt/xo/brk-ttxoxb3lfk7t3rzpgq4m42lsl7lmgzt2e5w5pdt6rxna3q6pulra-skalibs-libs-2.14.3.0-r0.apk.brick'

  'store/is/xo/brk-isxo3o4skm7vtiqyhakx4x4uxrw7hnycm3ldwp43grskdhxl3qxq-sed-4.9-r2.apk.brick'

  'store/s6/sl/brk-s6slrst6crbk75uftmxwwuqcx7x7m47earozfajjzsct2yvlrk2q-rustc-1.99.1-x86_64-unknown-linux-gnu.tar.xz.brick'

  'store/j6/az/brk-j6azokdcg4c72ggjyopfahoks5fxc5duku2fwhqxerrggqa4w4wq-rustc-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/j7/nd/brk-j7ndjrq7aixii7bqtdkm7kw7j6bkvkbekmoqefp3zaanznjiuitq-rust-std-1.99.1-wasm32-unknown-unknown.tar.xz.brick'

  'store/sf/xf/brk-sfxfw5yxrv3hd72ixioxy6fzrfuc7kq2tg35pj2j7mi5vlrporta-rust-std-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/6v/x2/brk-6vx2ce7jcj6wfra4xg2ykz6htsdkuvhh7uxbyr4gzlwvf2mlriua-rubble-src-checkout.brick'

  'store/gp/d7/brk-gpd75vrjncv57fv3fzdfuoagqwgyqjwuizvdth2pdg7hv2q4lv5a-rubble-script-shebang.brick'

  'store/4x/2u/brk-4x2uexqjoqs5unyb4fxpdus3ctebmhvqnuruhalsl5rdwt3k6naa-rubble-canonical-script.brick'

  'store/3b/lb/brk-3blbc3vt3hw6l2yenxtxlwpfnv7432fvq4xhhkr7lbtpk7msi3pq-readline-8.2.13-r0.apk.brick'

  'store/45/pp/brk-45ppndjvm7i5beghuemci3wjwojeswmc65z3ev4qumk53rap4l7q-python3-3.12.16-r0.apk.brick'

  'store/cm/da/brk-cmdaozrcvaymmdfw3jodg7rrc4qwmaqyx6q3jj6u6nsie32hvdxq-publish-output-directory.brick'

  'store/ez/by/brk-ezbyzyz64k4wf43cl2s55otq6rxpsgr6aopnefxba7bcqz2767ma-rust-std-1.99.1-wasm32-unknown-unknown.brick'

  'store/ma/ce/brk-macey2arela2oh55r33f2l5eana2whlqb3bzvi5vlkzpmqumk5ea-rust-std-1.99.1-wasm32-unknown-unknown.brick'

  'store/od/5x/brk-od5x4iwvfooy74347v2ihrwjcu4yxed2q26uphzbe43e54agaymq-rust-std-1.99.1.brick'

  'store/w6/64/brk-w664xv3i7l4c2vahfdto6wouwerljg7pgln6evk6d4icuwvi4xoa-rust-std-1.99.1.brick'

  'store/5z/qz/brk-5zqzbtecxd2bwjpypfrcgfmzvuqihlmabhg5jtqztyhjc656maja-perl-5.40.4-r0.apk.brick'

  'store/x7/pw/brk-x7pwlzkrrh3cqzsqlvdtwpqpny7mthxe75cr26axhvbzmfui6tra-pcre2-10.43-r1.apk.brick'

  'store/ic/c3/brk-icc3vbhzlb7dmz7zkp5cddgyeoy5jt5ykkhg6oy6nall6z2sna6a-pcre2-10.43-r1.apk.brick'

  'store/qb/rl/brk-qbrlu376mq3m5jhng65mdeobdbrpjzv3thrthfrpvoam77zovt3q-patchelf-0.18.0-aarch64.tar.gz.brick'

  'store/hd/qx/brk-hdqxqr4vfc2rgc3rj5ywrpaykxqly77eix55tldf7wd7nqimpqfa-patchelf.brick'

  'store/dh/zo/brk-dhzowymraqoa262lv45rzgrpjrqdedusoctmkao7qctbpck3qiva-patchelf.brick'

  'store/ad/yk/brk-adykhpm55qerngmtx6ke7csou4r73gh5lnubblp7jj6ro4oeyxna-patch-2.7.6-r10.apk.brick'

  'store/w7/gt/brk-w7gterx6tkmti6wv733mqag4engf5xzrpvyrazpfjb7u7cvs7hla-node-v22.22.3-linux-x64.tar.xz.brick'

  'store/em/on/brk-emonumondcre3b5pnxo4hp5dzwkoobjp7fi6ofxmqudceo4dxjnq-node-v22.22.3-linux-arm64.tar.xz.brick'

  'store/ri/ue/brk-riuewubniwiboir5fq3jjufegmdvpfusk2fp25gcllfzgwstcwfa-nghttp2-libs-1.69.0-r0.apk.brick'

  'store/2b/fw/brk-2bfwkovamqlgqawc2obxigc4yho4jgx6rrkc6tyhubog5tm2vhxa-nghttp2-libs-1.69.0-r0.apk.brick'

  'store/qw/d3/brk-qwd3quqioqiv5a7rm7s73nowdeq6xvvhyrzquhncrfn35xsh5msq-musl-dev-1.2.5-r12.apk.brick'

  'store/nu/72/brk-nu72a7zrxgfiwzjx6xkvc7d3eorpvhltbyv6a3vxbwwuwkkhnguq-musl-1.2.5-r12.apk.brick'

  'store/jw/hf/brk-jwhfx26nkv24vmnfckbvccnpwdkzwfvxcjty7dhntghaemjlpfxq-mpfr4-4.2.1-r0.apk.brick'

  'store/i6/rp/brk-i6rpnovdyaumnm4dbmqheqhnimae5nyro5b25ewahcsz4tksxefq-mpdecimal-4.0.0-r0.apk.brick'

  'store/fg/32/brk-fg32tsmkrioagedunckpr37qz35rn4b7obxt3wsbxx56ajpxviza-mpc1-1.3.1-r1.apk.brick'

  'store/hd/hi/brk-hdhimhaqn7bul5k67m2gmw4ea6xibuprz2mgla5obsjibs7tfnoa-make-4.4.1-r2.apk.brick'

  'store/oe/dx/brk-oedx42pgtkscsyrm2vn6hyrci7hw74ladlpu6f6bwgt5yguhmyqq-m4-1.4.19-r3.apk.brick'

  'store/x5/6j/brk-x56jkwrv5shx4duab3qg53qmnuvvtc5zubpotbtxsl7k2cellbdq-llvm-tools-1.99.1-x86_64-unknown-linux-gnu.tar.xz.brick'

  'store/el/li/brk-elli4da2njhcv4aap6f2a6tueyezrnrnd7hist2qro34ttjryw5a-llvm-tools-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/ea/y2/brk-eay2yd76jtq2n72kafauwkofupanezwq2muobm7bjlf6mfojk4ma-linux-libc-dev_6.12.86-1_all.deb.brick'

  'store/3e/xo/brk-3exo4yvcmu45p6oevi6u6v7fkppbt2fohg5gpkfvwhjykut7m3wa-linux-headers-6.6-r1.apk.brick'

  'store/kp/e7/brk-kpe7kma33nmt3mijbihbuzazuupuiq4ffqabvfgogzgs2rdp2rfa-libzstd1_1.5.7_dfsg-1_arm64.deb.brick'

  'store/hy/7v/brk-hy7vvf7hx76tdededuy6vbt2zjw2rzd2papv6r7qm2m52vhchfna-libzstd1_1.5.7_dfsg-1_amd64.deb.brick'

  'store/fa/qk/brk-faqk22fjqryqxjx6pkufmb2mttau3gwuv2qu6roi3d4melszcu7q-libunistring-1.2-r0.apk.brick'

  'store/mi/6o/brk-mi6ohmutnclicttozbnjjmgo5r6nutdophs5rgp6kru2gg7tqxqq-libunistring-1.2-r0.apk.brick'

  'store/za/b7/brk-zab7x4pj4e4cmrnw753rp5hyl7jadtxtfddargzdbkkqoq2k7uwq-libubsan1_14.2.0-19_arm64.deb.brick'

  'store/7b/uu/brk-7buusvdtjbv3krfq34tglkiqz2x356bf2xwow5pmosrsliurop6a-libubsan1_14.2.0-19_amd64.deb.brick'

  'store/qn/3l/brk-qn3lywhoc2dno3mvjvoq3mihzjcc6yz76oy3bvxnhgrsw5ewd7xq-libtsan2_14.2.0-19_arm64.deb.brick'

  'store/b2/i5/brk-b2i5h3ipeqiico2oxqfkrpcrqndt5dys43nm7qrq5hh3e5n4gqpq-libtsan2_14.2.0-19_amd64.deb.brick'

  'store/gb/4d/brk-gb4dlxkuu36d4olrckbxrdwlkvocpv2amucqerzpih2nv5w3uxuq-libstdc__6_14.2.0-19_arm64.deb.brick'

  'store/eo/66/brk-eo66u6nzusdktuggisxpvr7qmzxvwr4lxwlclvsre4irq6krhcoq-libstdc__6_14.2.0-19_amd64.deb.brick'

  'store/fz/so/brk-fzsocvqoawb6atzh5tfjxgahm2yualfjxwxicd55hjyf4gfjo5da-libstdc__-dev-14.2.0-r4.apk.brick'

  'store/hw/ud/brk-hwudtbqp6mtqd433zl777ixamegzf5s6pqjc3vbkw4yy7ca6rpzq-libstdc__-14.2.0-r4.apk.brick'

  'store/sl/7z/brk-sl7zsbzcfjdoz6ohe72ecirudxewciohnjumdqn7bkuunn2hp5lq-libstdc__-14-dev_14.2.0-19_arm64.deb.brick'

  'store/p5/uk/brk-p5uktxyamskabu2gk3grichqlqinop3payt7ptqw6d4srcvsaz5a-libstdc__-14-dev_14.2.0-19_amd64.deb.brick'

  'store/p6/eq/brk-p6eqluqrei7jxrpnr2nogcmndvhzkr37f2j47nrfkscrbtnpy64q-libssl3-3.3.7-r2.apk.brick'

  'store/3l/oj/brk-3lojfc4csi3u4upmameltz6l45ti2jk5uiw2rnf2ui7g7z523odq-libssl3-3.3.7-r2.apk.brick'

  'store/e7/aw/brk-e7aw53vitgjqbosohujzxudnmbfqylyi27ehtmvbucoevvgocfoq-libsframe1_2.44-3_arm64.deb.brick'

  'store/3r/g7/brk-3rg7zno4crltlhtuwp3k5izvvdj2c6smqkw74ebwsrfv2o6grtna-libsframe1_2.44-3_amd64.deb.brick'

  'store/iq/ru/brk-iqruyywvdmkzsmzzmu7rmrnp6fqgg7e2na76j3ty3skevyvcbu4q-libquadmath0_14.2.0-19_amd64.deb.brick'

  'store/77/pa/brk-77pafwgzhgk3kbtyd3i5bnikedwfoif6mfaibfesmfc655t35naq-libpsl-0.21.5-r3.apk.brick'

  'store/t6/xq/brk-t6xqfwfwlrrilozolb4u3zqjqyvl4ak7wbq5j6hxpicb3ycidfpa-libpsl-0.21.5-r3.apk.brick'

  'store/qm/dv/brk-qmdv4se7cy5zxuxhuq6la3h562eim3kyrj3eud44s2njzmqn3mlq-libpanelw-6.5_p20241006-r3.apk.brick'

  'store/ng/2y/brk-ng2yhab3txqyfgtnrgwttzyliczkrx52jeu7skkoaxeu5d752ynq-libncursesw-6.5_p20241006-r3.apk.brick'

  'store/mf/wk/brk-mfwkvtv3n6hvvrci2nxbilte5df2wpayqreolg3t5xnlwedydz2q-libmpfr6_4.2.2-1_arm64.deb.brick'

  'store/4r/gc/brk-4rgcrtd62az4jvrpnqi7mo4lmi6jkafzaizl5renuatipxrg3soa-libmpfr6_4.2.2-1_amd64.deb.brick'

  'store/ex/wh/brk-exwhj5vebfaduvvhd7f6xtppocqwgqam7csyi3u5434k3ypqofpq-libmpc3_1.3.1-1_b3_arm64.deb.brick'

  'store/wo/6v/brk-wo6vgn55jsmxeqnkavm4rcompkku3ssc2xyxdc4nrbbcx5ggc2ea-libmpc3_1.3.1-1_b3_amd64.deb.brick'

  'store/pj/6o/brk-pj6ok275ispcmivb4gpez2bzug46p2ge6a7pd3dncpfzelwebihq-liblsan0_14.2.0-19_arm64.deb.brick'

  'store/7b/5q/brk-7b5qkq7h725rlzwyjms32eiu6becwobfozmdtl3nmob3t75vmiuq-liblsan0_14.2.0-19_amd64.deb.brick'

  'store/3o/ot/brk-3oothg4a44icdojzlibmxrxhn2xs6hase67u2pgy4z77l7gj6kgq-libjansson4_2.14-2_b3_arm64.deb.brick'

  'store/ng/fm/brk-ngfmqg7sdtevod5fupkehkz7ngg7lb4zc6hfheixgvduoprmea4a-libjansson4_2.14-2_b3_amd64.deb.brick'

  'store/qx/xt/brk-qxxt6f726go3553r3bhxadzrgj637yghleeivlrsywklrpcr3pnq-libitm1_14.2.0-19_arm64.deb.brick'

  'store/2k/he/brk-2khe7fyham7ciybnkxksiegiv56edsph55lu6pvdrik6sznbr3sa-libitm1_14.2.0-19_amd64.deb.brick'

  'store/3i/sl/brk-3isljfsdiufidx6nanfu323k7zozw2mkua3ht56d2dlnq6eideca-libisl23_0.27-1_arm64.deb.brick'

  'store/sm/gl/brk-smglbxy2qltuw55ubbydcyhowlyzyzpmmwhii6rttwdgrcn6yhwa-libisl23_0.27-1_amd64.deb.brick'

  'store/qa/hc/brk-qahczze2w5oyaxj5ledbeizlod4hco54ydowp6zvk4wryzwpqu2q-libidn2-2.3.7-r0.apk.brick'

  'store/s3/pv/brk-s3pvvtqxrdzleije623ea64covxuywd4s6akx2d5lpxokyytr4ea-libidn2-2.3.7-r0.apk.brick'

  'store/hr/3g/brk-hr3gsmedt3iyx26xhety6rvbs2nzhv6o4oyscyt7qvuuixa7fbfa-libhwasan0_14.2.0-19_arm64.deb.brick'

  'store/so/yq/brk-soyqxtymcfjf74xui3ydngvt6so3orqonn4dzhh2gpwgcp2q6gna-libhwasan0_14.2.0-19_amd64.deb.brick'

  'store/ks/6e/brk-ks6e3u26mzxm5dwrtt4v2y5z6hltzyyoqnn5v36ctpuvq3z5ebga-libgomp1_14.2.0-19_arm64.deb.brick'

  'store/5c/l2/brk-5cl2d3x6sk6fpzz2vyvzamieqdptlqxbsijlye75apvhdjupzhfq-libgomp1_14.2.0-19_amd64.deb.brick'

  'store/na/a2/brk-naa2ad3mxbwsl6syyyeikeu6srwar3mxn4lv6faf72kx6hjpq72q-libgomp-14.2.0-r4.apk.brick'

  'store/i3/vz/brk-i3vzwzq5ceekylzear5wrwz4teano37g32htjtcd4rma3zvjzz3a-libgmp10_6.3.0_dfsg-3_arm64.deb.brick'

  'store/ry/7d/brk-ry7dxugonx43nz5l7zqafhnyf7g44osnmhejuhlt4x3bhh6x4lya-libgmp10_6.3.0_dfsg-3_amd64.deb.brick'

  'store/3n/3b/brk-3n3bc5ncagillpn2mz3jicaeyjvq6myp5b2prh2kn6tllwded3qa-libgcc-s1_14.2.0-19_arm64.deb.brick'

  'store/w3/4r/brk-w34r6xbrp5naxtwy4i2yjuqgwtocs272gmp3wpl6jzg7tchrtjra-libgcc-s1_14.2.0-19_amd64.deb.brick'

  'store/bs/cz/brk-bsczck3itaibqqkhhwkkzdh3fv5i477527aika7gfcttdyn6chhq-libgcc-14.2.0-r4.apk.brick'

  'store/rm/4z/brk-rm4zxsn5qycajrfwexlu4perkspongbyp6ae77564am5knq453wa-libgcc-14-dev_14.2.0-19_arm64.deb.brick'

  'store/c2/pb/brk-c2pb6bog4hbnzghhl2bdm4jrrqnq5e5oxiobkywqsl7p7igdtfva-libgcc-14-dev_14.2.0-19_amd64.deb.brick'

  'store/em/um/brk-emumr4qhmj3md4udqk36vvpcou3bcq2q6x47b2utro76mglanp6q-libffi-3.4.7-r0.apk.brick'

  'store/pj/we/brk-pjwex5lrldalvupg3n7gbeibqhqmkv2nt45iyfl64qfty7texbqa-libexpat-2.10.0-r0.apk.brick'

  'store/jd/tc/brk-jdtcafj4hys4txg5vxmtvui2dl5sovyb5lontwbsxlieat3mlila-libexpat-2.10.0-r0.apk.brick'

  'store/gw/gs/brk-gwgsfngkxcqjwumaewugzkfdt7v62iomled2lwur35muht72aeca-libcurl-8.14.1-r3.apk.brick'

  'store/p5/rx/brk-p5rxp6x26yjm6b5t2lf3kco5u2w2zko2k3ma5odcrnnmsixwhj6a-libcurl-8.14.1-r3.apk.brick'

  'store/xa/vn/brk-xavn33v6xwtxgf7j7snhvwd5urqxswa4c2d2hxtjxjza37nizg4a-libctf0_2.44-3_arm64.deb.brick'

  'store/c2/7n/brk-c27nqfizbqju23t62gn5fz5at7aiszoc2jdo7rca33boiwj4rrwq-libctf0_2.44-3_amd64.deb.brick'

  'store/vs/wq/brk-vswqqehwz73whpxezmbr7nf4anbs7slwoknh6pi76q7askntz5iq-libctf-nobfd0_2.44-3_arm64.deb.brick'

  'store/y2/gc/brk-y2gczfciw3klma4mkheml5yh6gpkn4mnakp5qr5vsjygqqy33paa-libctf-nobfd0_2.44-3_amd64.deb.brick'

  'store/dv/rl/brk-dvrllqig4vloxhgyjrmpzimbvdcatflu5xsgnfnhez77trxhzbaa-libcrypto3-3.3.7-r2.apk.brick'

  'store/bq/qu/brk-bqqueq4hb5vdjgdpm5xn2bpxiay234jhkblmh6d2yjdmd2ncxb2q-libcrypto3-3.3.7-r2.apk.brick'

  'store/yb/6t/brk-yb6tefhslyriibghffdurwb2wvapj6x3xizoboao2doaj7v7xgda-libcc1-0_14.2.0-19_arm64.deb.brick'

  'store/tx/b6/brk-txb64vqfae7aa5nhycodgois76zpayaio6xopelsmuan5mnhhzzq-libcc1-0_14.2.0-19_amd64.deb.brick'

  'store/od/lz/brk-odlzblejigvixnek4zw3qpf6kdmpduizlfdol6phkrwrrltm3kdq-libc6_2.41-12_deb13u3_arm64.deb.brick'

  'store/p6/4u/brk-p64ubkpmkkadsqqhidffg25atg2wgfinaacychgsfyt3outqqtdq-libc6_2.41-12_deb13u3_amd64.deb.brick'

  'store/lb/7v/brk-lb7vuv6w3fr43o73swpjgwfuwdhyi7l2xskuuisw3eaekunxv3ia-libc6-dev_2.41-12_deb13u3_arm64.deb.brick'

  'store/3l/wx/brk-3lwxgkj4bfhbzzcj2f4ouooyvkjr2hnt4bixwahhr3jmry6lnmwq-libc6-dev_2.41-12_deb13u3_amd64.deb.brick'

  'store/kq/oa/brk-kqoaqdowlcmrluolokiygo33evr47gordg5y3gqjf4etscxnee2a-libbz2-1.0.8-r6.apk.brick'

  'store/3p/wy/brk-3pwyzin2s6znyulfwpta6mbiky3ksdwnmvi4k4oblrddcyccpbkq-libbinutils_2.44-3_arm64.deb.brick'

  'store/r2/rl/brk-r2rl2pbw7edcma3xcpjbnfmj5xa2l5ltff3xr3tyxxpfej5udu5a-libbinutils_2.44-3_amd64.deb.brick'

  'store/zw/da/brk-zwdawolcw4fqjnlmmwfrxjwrxcplq7t3jb73x5seskofbtj353na-libattr-2.5.2-r2.apk.brick'

  'store/wx/52/brk-wx522xces6aeljkz5y55o6kdkgi6zgyvebi63xgqxclodxabs56q-libatomic1_14.2.0-19_arm64.deb.brick'

  'store/fy/jv/brk-fyjvlznpum5cwh7apldb3sv4skrbahxa5uekyqo2eqwrcm2tzuxq-libatomic1_14.2.0-19_amd64.deb.brick'

  'store/vq/3s/brk-vq3sirpitu5prsi2ig3ld3d7am7x6cxjxscc4qchsiecywgz3bfa-libatomic-14.2.0-r4.apk.brick'

  'store/fb/xg/brk-fbxgu4t24gr47iq2yhyaygays2hvcmyidx4tkwjmlx52pttyr6yq-libasan8_14.2.0-19_arm64.deb.brick'

  'store/6m/nz/brk-6mnzlup57yva4f25swep426asen4gktqclnqldiusl5pv2ejz22q-libasan8_14.2.0-19_amd64.deb.brick'

  'store/wk/mp/brk-wkmpl2hwgob7qvcfpgzvx56hogur3qhmor7od77tv6hr4gd7eurq-ld-musl.so.brick'

  'store/x6/m3/brk-x6m3rqymxcy5i664gnpmwk7ucihlqh6ycfty4kbsjtg7mmfvb6eq-ld-musl.so.brick'

  'store/kt/bd/brk-ktbdwi3xid4ywlz6il2qlgx67aclu2t5gljy527g7vdnv6h7gaha-jansson-2.14-r4.apk.brick'

  'store/n6/vt/brk-n6vtqu3bxkksa6hlrwirri6entermnuofp2sdqcfcrzxarqrr3hq-isl26-0.26-r1.apk.brick'

  'store/ws/jd/brk-wsjd6bhyeay7o42k276g7ep5plfqmlqubqztlvbu5aw7rjjeuq2a-gzip-1.13-r1.apk.brick'

  'store/ja/2g/brk-ja2gawpefozngsdbmzs5n2a66ujesjats2qcq7homnixclj6iqrq-grep-3.11-r0.apk.brick'

  'store/ho/55/brk-ho552ymbr5wqlkbb7xckcvqfjs5fd4ytbrf5rjp3vaqnwocxhx5q-gmp-6.3.0-r2.apk.brick'

  'store/qg/3g/brk-qg3g2dinqfibxj3dkbjqgp6q4vhezm2w5ayy7ibamcbqov7sunuq-git-2.47.3-r0.apk.brick'

  'store/7w/dy/brk-7wdydh7iziyaiskuhw2qb242fvaq4rin2kprwubf7fmvooc6iopa-git-2.47.3-r0.apk.brick'

  'store/e5/bi/brk-e5bidgxbvr5crgxvo3tckxld466txu5dxi674pplgncc4fifmkva-gdbm-1.24-r0.apk.brick'

  'store/sa/xd/brk-saxdsta5ltm7iomdgyx3f23uma6qmu7hz674djpkjgbgi76tsisa-gcc-14.2.0-r4.apk.brick'

  'store/ev/ty/brk-evtymdmzbmwvbqahpv3jn3fct73m5qstjmh54f2o7msjks7krita-gcc-14-x86-64-linux-gnu_14.2.0-19_amd64.deb.brick'

  'store/rg/ds/brk-rgdskue4seruek4fxopdeftkm4uf7jxa7nxjyqkhkj5yak2ebc4a-gcc-14-base_14.2.0-19_arm64.deb.brick'

  'store/un/xl/brk-unxlmwftoohd5ub6hgpvylolxd6zjczt462o5jf6zyb2nmexflpa-gcc-14-base_14.2.0-19_amd64.deb.brick'

  'store/q6/6x/brk-q66xooc3uyetlxp6565oyihya5babf4sn3opal27qo6em5wjkuca-gcc-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/5t/d6/brk-5td6qvq3hkwnfc5vqh6lcuv5xlk5yh26d2esafb7byxkpwl6klua-gawk-5.3.1-r0.apk.brick'

  'store/fu/4g/brk-fu4gjf2vujnnxzbws5i2w57yneqm7tmgiqzxodte6s6rf74vchrq-g__-14.2.0-r4.apk.brick'

  'store/ih/kb/brk-ihkb436hgrr2ikz2jd4v5enxpqhklppqp6s5usbutl4q6fqxs3ja-g__-14-x86-64-linux-gnu_14.2.0-19_amd64.deb.brick'

  'store/mg/vp/brk-mgvpjsbz7sujl5qdndfmqhtclpxfhlytkeyidejyjfez5jloit7a-g__-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/m5/ln/brk-m5lnpllbzm555r5zuagxbaoqomumjvcwyoq7xdkffysmdvteelwa-findutils-4.10.0-r0.apk.brick'

  'store/qv/xc/brk-qvxcj4lj5jj5mbgvpcfw5svnfaljwbkil7ghzzofovoqehagqava-diffutils-3.10-r0.apk.brick'

  'store/oh/zg/brk-ohzg3khe3y5zbg6it742hi63cwoz7k3vbr5jufkccupj4kcrkpwq-curl-linux-aarch64-musl-8.18.0.tar.xz.brick'

  'store/fd/jo/brk-fdjot6csltdy7pfpendap6yybjo5niybzp6knbofokgq7mxbz6kq-curl.brick'

  'store/ov/g7/brk-ovg7cu6kkazcpj32mrk53yc3kb2z2mrl4yd5yzrj3uytgwcanawa-curl.brick'

  'store/rr/24/brk-rr24d5jtgkkrifatmbdolj2lttqqu6g5h35w3qe536jpenad2e6q-cpp-14-x86-64-linux-gnu_14.2.0-19_amd64.deb.brick'

  'store/nw/jn/brk-nwjntcya5bc7tfxrl5i22jo3v2rnlixwjc6ri3r4kwupxtwlaqsa-cpp-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'store/5w/sm/brk-5wsmysbedc7wbcb22csq254i5hrsdbwpdwuzyi5seacce7a4iaoa-coreutils-sha512sum-9.5-r2.apk.brick'

  'store/k2/sq/brk-k2sq3ksyc4xg4n3byfvtc2xp2by5lw3uus2pjw4ro7y4ad54uo4q-coreutils-fmt-9.5-r2.apk.brick'

  'store/cn/su/brk-cnsuk57bulhj544m3skp3wwq4lsh5qegyneycg7bgfo2zzu5z7ua-coreutils-env-9.5-r2.apk.brick'

  'store/es/h7/brk-esh7pawc46nsh5b2uuykm4qsjsoowbes5uu4nt2kcg6hocags6vq-coreutils-9.5-r2.apk.brick'

  'store/a5/yl/brk-a5ylj46fppw54b2mlu7gsl74itcmmkg4u3wi3x7mzg2cyanyfaea-cargo-1.99.1-x86_64-unknown-linux-gnu.tar.xz.brick'

  'store/oy/e2/brk-oye2ypgxbkwk5tvdjf7e2cmrsr7ituchdudsw2znzjzrokjzx5fq-cargo-1.99.1-aarch64-unknown-linux-gnu.tar.xz.brick'

  'store/2i/fu/brk-2ifucdhxoflj6anntvfsnjg5untghnzjvplj47aodaqkqpenxzyq-ca-certificates.pem.brick'

  'store/p5/eb/brk-p5ebnikkn7phl3xojq52xmdrfb2de5dldc3qfbkr3euo6kxr3ala-ca-certificates-bundle-20261020-r0.apk.brick'

  'store/pv/vz/brk-pvvzoxgx7z6mmjnme5ravamtm5ce2mbexhvimkyopjclasv4dhpq-ca-certificates.pem.brick'

  'store/re/l7/brk-rel7wcogzgat73st77jy3cxxhyth7hjpzxl6wfey5nttckhttxrq-c-ares-1.34.9-r0.apk.brick'

  'store/kc/xm/brk-kcxminepu2ywfwal6sveazxuz3b5emokjvaje5k6edxumr4ncr7q-c-ares-1.34.9-r0.apk.brick'

  'store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

  'store/nk/bc/brk-nkbc5fhuwgawyucceat7l2bt62mdkmrygtjkwf6uoayzdrenokvq-bun-linux-x64.zip.brick'

  'store/2b/to/brk-2btooo6cnofph3xjrdgy2dezt4y4xl47ygmhqslj24ropfoiscdq-bun-linux-aarch64.zip.brick'

  'store/cc/25/brk-cc25q3jglva6ayeaiegjq7f52i5fe3w3j2navr35izea4kmwayaq-brotli-libs-1.1.1-r0.apk.brick'

  'store/bd/t2/brk-bdt22o4d5bjqwz354evlyoovndjzdmd2rh6kmrs7iqzmis3i5viq-brotli-libs-1.1.1-r0.apk.brick'

  'store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

  'store/5s/2g/brk-5s2guvzpcv5iov3rog7fjz2t5oa3idprxh4z7lst5ipo2mlpo2mq-binutils-x86-64-linux-gnu_2.44-3_amd64.deb.brick'

  'store/4g/be/brk-4gbejr52ozzofmznelc52fgic4nsoasxjr6i4phtf6utztaoz6la-binutils-common_2.44-3_arm64.deb.brick'

  'store/lu/y4/brk-luy4bjnugq4iyxf653mduencnzaptaunhu4mph7pdata3houha5q-binutils-common_2.44-3_amd64.deb.brick'

  'store/ec/xk/brk-ecxkum7thkjwggmltz3jlz67amewczlvf6ybucueqawsamou6t4a-binutils-aarch64-linux-gnu_2.44-3_arm64.deb.brick'

  'store/sg/dy/brk-sgdyuezwsbzpgusurjxb7bvquikinj455qz7q5c2emyrynor4f3q-binutils-2.43.1-r3.apk.brick'

  'store/zq/h6/brk-zqh6lunhozithbpfnbwqg5j54lg5ze77yzuwedmjltfo45ghffuq-binaryen-version_117-aarch64-linux.tar.gz.brick'

  'store/ta/cn/brk-tacnuufbmsgvjjdv35jnlei72ofv46gglzsjzt76wnp6nf7qphdq-binaryen-117.brick'

  'store/ja/26/brk-ja26s6rmlm22mwviv4hkae3mfkzkcq4tumc55qstm3p444zqmfzq-binaryen-117.brick'

  'store/g3/fx/brk-g3fxen4ug3f3g34imdsefwplwd3ulzn75tn5uxd5jqe7t23bzyna-bash-linux-aarch64.brick'

  'store/7g/ai/brk-7gaiswvomctprmbv5i6dhxav3urpsmceezmwy52qv42yok44lygq-bash.brick'

  'store/oc/a4/brk-oca4i4igup25hy7wsfzuzkug2rvvfu2h4d237d6syf33h4co2soq-write-native-toolchain-env.brick'

  'store/kr/tc/brk-krtc32gkhzcn3spc36a3ksbyjoykekcsx7bvmzj2mrxcmaxral2q-write-exec-wrappers.brick'

  'store/fc/jh/brk-fcjhtbtyxa5qk3xy5jhazosrdwgn6npaqbjmm7dmyoi756zrunca-normalize-python-runtime.brick'

  'store/zf/da/brk-zfdanpwpbs2u3ar5qijrkn7nnv3aijzahufatoxxurr4e4rru7xa-nodejs-build-tools.brick'

  'store/ty/qo/brk-tyqosp4fpdd7pjacveojot6m2g5ls3hqljfqp4qerplz2kuwcvua-musl-install-tools.brick'

  'store/ec/vm/brk-ecvmuhel6g64yeystzfd4xmmjjdqv4p3i57tedybq2ppazcnfvzq-zstd.brick'

  'store/4a/kp/brk-4akp4e4shmwjpgpj3n6qt7t5wwhltqioq5nihepguyvtwn2gumaq-xz.brick'

  'store/lm/bb/brk-lmbb6iujrwrlaoq65oxsi2yjh6qqs4focnkmlymfeshkdlzfosrq-unzip.brick'

  'store/5f/k2/brk-5fk2gsc2wvpikazwv7m2r2tymf23xnulpwld5ai2csmdkmwetqaa-m4.brick'

  'store/bp/yv/brk-bpyvwhm4bzve42im4kgvpmxekenmlobdxdyw65x5wz5yto3vpc3a-gzip.brick'

  'store/li/qe/brk-liqeef25kxd6agiohfvzkme75fbbkq5cs5m7ojfifiv5y3jlosua-gpatch.brick'

  'store/nq/ez/brk-nqezvr7gvu4qzj2ite3o6mk64b5foml47t6vrs2j37pggzdvnvgq-gnu-sed.brick'

  'store/mh/ux/brk-mhuxl3qogm466jjjfbxne7e5iun5rusy6qpp26aekt65vpamhjqa-gnu-make.brick'

  'store/dk/tq/brk-dktqjk57lvhld37htakm5472rljxvc3dte5plieqdipyxzze6plq-gawk.brick'

  'store/eg/27/brk-eg27735m75zx7aqioqpvqjluaojdeh2kmtsizlotnmpyrir4dvcq-findutils.brick'

  'store/yv/ay/brk-yvayrwqg5legw6u4uqvntspm3qgizvmdz7gen65dlwmy4mjfqk2q-diffutils.brick'

  'store/de/fm/brk-defmfedonkfkblaqtfzjs7kvoq2u5k53xo3zzl43it7q634ax7ja-collect-shared-libraries.brick'

  'store/bn/wq/brk-bnwqa6w363zd76l73ptm5u7wqthwzyxdygt5rnyztadje3hafe2a-perl.brick'

  'store/yy/rj/brk-yyrjximmxz5nsy5s2674rewp6hhbuhasydtpqkwdi43ymhl26tbq-grep.brick'

  'store/r4/7q/brk-r47q5tofldj4g4624jepcs5tjcxbgznhhxbwnzamfmankxyz4ewa-gcc.brick'

  'store/z3/zu/brk-z3zu7eym3hbr2r5k2thkthyci3xqsfz6hlzevuf2dhvj5w7sxfrq-bzip2.brick'

  'store/mq/dn/brk-mqdngybmp7yej3tpsrxr3vm4epadyjafka5ojioijg4dcfip36pa-bison.brick'

  'store/n7/qb/brk-n7qbevbly56oq5vdzjm2bzhl77wjewdp4k5gmoimlbiv62nbv7pa-bash.brick'

  'store/6s/2s/brk-6s2slkwjetnkxspnsgj7j53skeupzwiedrcrjmtzhr3ydsuucjia-write-native-toolchain-env.brick'

  'store/6x/bc/brk-6xbcw7rsrgmctcyu25rzq64e42jggkhbuymzq2k4pfnyvv7a2hdq-write-exec-wrappers.brick'

  'store/ti/4k/brk-ti4klh4xsl6vslhhl3gmasoj57eebnstumstzpwjqyej67727c7q-nodejs-build-tools.brick'

  'store/qw/fw/brk-qwfwhqp2o5ysc6wj72oc5qmextbjnqdockbzflpzm2nprxwvrm3a-zstd.brick'

  'store/yt/5n/brk-yt5noi5764mqbnvv6n6ce2dcsh7smajtviko4wfl4bjbw7x25bia-xz.brick'

  'store/gh/q4/brk-ghq46r5f4orvr6sszvuapmkyflimfvkwlb4hv3t3dsr4k4zwplta-unzip.brick'

  'store/nc/3b/brk-nc3b5fnwrjhizdtqakhrmgkntigd7tkzddqwknxrlyxe6oalqhpa-m4.brick'

  'store/ff/pp/brk-ffppl4gr2kqvvmwgncrxlllkh6z47u6wpzeiyatswpebhvwpbvua-gzip.brick'

  'store/xr/ab/brk-xrabzjajmehgka3yl2q5bx4rm524tarj7rngb7myx5cl4wzjtama-gpatch.brick'

  'store/zc/bn/brk-zcbnhzsvsrb2ugrvykackedb4zet6pjg7txbszo4tgwdkjokandq-gnu-sed.brick'

  'store/g5/zs/brk-g5zshxvbu3styhzy6s7rga2yoofniwkfdlasmxfnt4jnls3bl3oq-gnu-make.brick'

  'store/hi/gq/brk-higqpv2dmyiorfd43aypr6zeuad53wdrig2qr4q3zzgtlwhy42bq-gawk.brick'

  'store/fq/ac/brk-fqacbxvzkp7aqbu5x5ibzixghwcxbmvzfqzhvgxdnq4tm7yoiavq-findutils.brick'

  'store/og/3u/brk-og3uxejhmzd6gzyfx5ggid4dzkwzet7lsi5k7rhpxf5svupsrpva-diffutils.brick'

  'store/tf/jx/brk-tfjxrh45sf2nytjwmw6picosxhkrbtwiuke6d3wujuptb35jb55a-collect-shared-libraries.brick'

  'store/qs/or/brk-qsorrmuoq5ncj2yuseriaitxwpswca2an4ott5gxlritcgujxudq-perl.brick'

  'store/tb/fs/brk-tbfsz6yscqgyjhqi2s6uzd2vam65e2d2gcrfe6lnzyevowdrb5ja-grep.brick'

  'store/ck/ep/brk-ckepgfvfy3zxo2mil6lzboslpe36a62fvqswiyx7jruzk4evsjrq-gcc.brick'

  'store/a7/yy/brk-a7yytixghyt2s63uxdft2bot7z5bpaqvjhhyrbwk5oek3j6whd2q-bzip2.brick'

  'store/l7/ht/brk-l7htuemjgonzrbgfwss2gd4oxktlvev5gqpeflfin3sibfx6gtrq-bison.brick'

  'store/zy/dn/brk-zydn5atoc2sxh2z3uf2jqbdtwctsseprwey2r7kmfze45av5arna-gnu-tar.brick'

  'store/mr/v3/brk-mrv3skvefohwhqxqk3loonbdoqonymgrvgcggyajysjlj44rvo6q-coreutils.brick'

  'store/hf/3l/brk-hf3lv5nokb6k6syr666pgjxoa57inppgaluc36pp5xrbs3qu7yia-python3.brick'

  'store/qh/7v/brk-qh7vuwb26yoguehicnk5b2qi6cohneetobzeehlkcn4vvt6licia-git.brick'

  'store/ga/u6/brk-gau67xaz2jijhjiytsen5gewubskzpgz2u64ij32im7umuiqr6ja-bootstrap-env.brick'

  'store/7g/wd/brk-7gwdsqgvkrl5q7ztjhu2z65wbjt2eywqrtwg7xc7jewdoolhnmea-acl-libs-2.3.2-r1.apk.brick'

  'store/46/u6/brk-46u6btbnqkhim377u2w54og4tf7ipfdazvg3ezdcoxmyzbn64lca-gnu-tar.brick'

  'store/3w/m4/brk-3wm4cdhbw7rufcah5dges6g3jzapjyjpwtravjh5rclsluy3vgaq-coreutils.brick'

  'store/vd/ms/brk-vdms6yfjfyag5lkckavsys57lvbbacysv777s6ackvaavlwcky2a-python3.brick'

  'store/xi/6o/brk-xi6olwdpuv5plotddhzff6u7glowbdw2qrtzw7hjduhk7ezoxy3q-git.brick'

  'store/7c/w7/brk-7cw7yzizlmml7slq3bpvzmdl3v3m3yi6w66fyairdsgoykvrtswa-bootstrap-env.brick'

  'store/in/ak/brk-inakn65bjgy574fki4lz7ar4pgwugxvdjqqnierbkk3isic5spya-RubbleR.git.partial.brick'

  'store/g2/qq/brk-g2qqoxqlhdq4m5ptlml7rg4j2sjvm5kcal5xohzpvcxxpaxx63za-RubbleR.git.partial.brick'

  'store/ee/45/brk-ee45eyrziex6g7ajoch2fj62l3lh7kykt3ekkjf2obzr2athu3ka-glibc-runtime-support.brick'

  'store/xe/dv/brk-xedvxtllcofffyvvz234aetsvntfip744x5z35zlo2yr4yt3rhrq-glibc-runtime-support.brick'

  'store/ra/n3/brk-ran3ty2pos5t45x5cpsmbpfi7kmuh3i2jpdbj7gk5zggwea7b2vq-gcc-glibc.brick'

  'store/fx/tn/brk-fxtnbjlqswwx7zuqjwvqf4azpgegrpm3fpcale6xlumvnhwvadya-rustc-1.99.1.brick'

  'store/e2/rz/brk-e2rzsmoh2ojatrlq7slkkltnt7z2aa2h6gmbt4gxrj5llbhymb5q-rubble-elf-runtime.brick'

  'store/6z/mh/brk-6zmhcrjjulman5kyc7bpb42rsiitpcozznio6a43um52iu6yr7jq-nodejs-runtime.brick'

  'store/ch/ld/brk-chld5ubny35e2wbkytn4wmmjslik6k7l5x5lmqu4maumnlipe7fa-nodejs.brick'

  'store/lk/qd/brk-lkqdbkmu6cjb7dgotbfcy476dwa7lwntralw6tvnks4frn7y5uzq-rubble-web-node-modules.brick'

  'store/pg/qc/brk-pgqciu5bf6v5rsxw2sudi6mejm4jdbxccplkyw33ylf327exabta-llvm-tools-1.99.1.brick'

  'store/e3/4p/brk-e34p6lvibc4y5cud27vutxqaoz6f7twpq5s2xbmem2nzejdzlgaq-linux-native-toolchain.brick'

  'store/bm/iz/brk-bmizlt5xdhghh2j45eu3hqfpshvmzoxr6vwe4oiowkuh7tldxm3q-gcc-glibc.brick'

  'store/gg/we/brk-ggwemilbyiyu537xipp6admlfza4psuqbpstue2p5qx3negueica-rustc-1.99.1.brick'

  'store/6k/ut/brk-6kuteyw6z7uzh46i3kkxiy4skplazu3wicblj6iwgqoaldxr3caq-rubble-elf-runtime.brick'

  'store/ke/tp/brk-ketpg52wdmoljath4lozmcgydwwkz4554ivzrzdnfo6blbdaan6a-wasm-bindgen-cli-0.2.130.brick'

  'store/uh/hf/brk-uhhfmqomkjkge4wvugjq2qy2uyh4nleaeh43u5ihugfyrhxriyfq-nodejs-runtime.brick'

  'store/ue/bf/brk-uebfeauaf5vguxmohlpx5swr4lvxm7unyqgo2n26asm3lenncypq-nodejs.brick'

  'store/id/ub/brk-idubmhb4paho7zn732ctx2s57kvdnsus3b2cit6spi5j2ti5epza-rubble-web-node-modules.brick'

  'store/vs/ja/brk-vsjaiiipt4nnq6yybfgc74k6mex5jlpmtk4s7glcyostfsn3h2vq-llvm-tools-1.99.1.brick'

  'store/wz/ti/brk-wztibky6ancf6wplvm64kugrm37ltcirzobzg5mgf55vwnv5taca-linux-native-toolchain.brick'

  'store/7e/gy/brk-7egybthiifzaiwm62j7t2apybvwznrrwd5rsef5dsrhubj2qegfq-cargo-1.99.1.brick'

  'store/in/kv/brk-inkvazg7bbj7b4uxzpkgnxsz2qhmoqwzmd35b3u7fi446jryzzfq-rust-web-wasm-toolchain.brick'

  'store/4j/zk/brk-4jzktrzy4eoujtgyb56yl2rwaffimfwk3g46kybwq5hl4khfnwra-rust-toolchain.brick'

  'store/dd/z7/brk-ddz7gzhteocbfkby6xzsvpmk2hzgegwfi2stx2xcllrmqvobv6qq-cargo-1.99.1.brick'

  'store/ly/d6/brk-lyd6koxcevhl2kkvyrgpauaaroebob4sbweio7ucqcnk5nihqgbq-rust-web-wasm-toolchain.brick'

  'store/3b/hy/brk-3bhyjm33b3codfx4vlt4zk5ozqks4wxkaozst2xbhyy56xfrz6mq-rust-toolchain.brick'

  'store/gq/dq/brk-gqdqq5qyytt6qihsxtcwuxmg3qhdatvlrzzcciyuyu5xcrgtg6ma-bun-1.4.3.brick'

  'store/rw/zt/brk-rwztfchzewn3b52bic5jjgvg3nn3rjix4rtqh3us57diipcxxmyq-bun-1.4.3.brick'

  'store/c2/db/brk-c2dbcqqoxhpuy4t5tk4nwlt5beuiii746wh6vaaeqsld525qldla-RubbleR.git.partial.brick'

  'store/3c/ou/brk-3cou2u4ds3iqapzjdir62kttkskmxtfz2sf36c65kpi4iby3mikq-RubbleR.git.partial.brick'

  'store/tn/7i/brk-tn7i4ngybkypz244wdsulsnk23gxd3xe5eg25ozinsunvlfb6tkq-rubble-deps-cache.brick'

  'store/5r/ra/brk-5rraxdt2uqvx2std4xg5yfcftcbtxsv276bkqau34ywi26ngkn5a-rubble-deps-cache.brick'

  'store/rj/pb/brk-rjpby4njkkmva5s4irocxwr6vrgusi6cn2kzmcdbf2bdcbxztgda-rubble-web-assets.brick'

  'store/ai/yr/brk-aiyroimpnp3yughgrvphjzh2bhwozk32bpze3k3y6uaeukdqjvzq-RubbleR.git.partial.brick'

  'store/ds/zq/brk-dszqoflekkm6ufunfjigc7qbqwgl3rezsz6y5upbarrv5rixdnjq-rubble-web-assets.brick'

  'store/g4/eh/brk-g4ehuu5eohs4yqdiesnl7qhtyk5kmz2cewtuo2elevttzc3kmx7q-RubbleR.git.brick'

  'store/z6/iz/brk-z6izgfd6pumjwweunfc4h7ztcn7we3jthybx4fjyb5bk5kqxbmha-rubble.brick'

  'store/3i/tp/brk-3itpn4hq7kjvnuxsklwvxmqulmmwqbhfai2uzpt6c4mikdvwveqa-RubbleR.git.brick'

  'store/lh/mj/brk-lhmjc36bctsjhz3cdosp4zpiqjhcc7wzaq4hw6f55nbpz6rrkzta-rubble.brick'

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