#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

export rubble="${RUBBLE_EXECUTABLE:?RUBBLE_EXECUTABLE is required}"
tool_information="$("${rubble}" -q info --format bash --tools)"
eval "${tool_information}"
unset tool_information
script_dir="$(builtin cd -- "$(rubble-exec dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
lifecycle_relative='lifecycle.sh'
source "${script_dir}/${lifecycle_relative}"
managed_publish_script="${script_dir}/$(rubble-exec basename -- "${BASH_SOURCE[0]}")"
target_root_relative='../..'
payload_root_relative='.'
root_brick_relative='store/d3/6z/brk-d36zxhgikhmojnqedc6wmfyfu4xc3zvcnexsyo2onyixqsebt7tq-rubble.brick'
target_root="$(builtin cd "${script_dir}/${target_root_relative}" && builtin pwd)"
payload_dir="$(builtin cd "${script_dir}/${payload_root_relative}" && builtin pwd)"
root_brick="${script_dir}/${root_brick_relative}"
user_publish_relative='../../.rubble/publish.sh'
user_publish_script="${script_dir}/${user_publish_relative}"
root_id='d36zxhgikhmojnqedc6wmfyfu4xc3zvcnexsyo2onyixqsebt7tq-rubble'
root_name='rubble'
pipeline_id='f6c5fc48-a964-4201-b6d3-7d6c956beba7'
pipeline_branch="runs/${pipeline_id}"

pipeline_environment='rubble-pipeline-f6c5fc48-a964-4201-b6d3-7d6c956beba7'
environment_created=0
cleanup_repository=''

workflow_path='.github/workflows/rubble.yml'
generated_root='rubble-generated/d36zxhg-rubble'
managed_output_paths=(

  '.github/workflows/rubble.yml'

  '.rubble/hooks/github-actions'

  '.rubble/hooks/github-actions/post-job.sh'

  '.rubble/hooks/github-actions/post-publish.sh'

  '.rubble/hooks/github-actions/post-release.sh'

  '.rubble/hooks/github-actions/pre-job.sh'

  '.rubble/hooks/github-actions/pre-publish.sh'

  '.rubble/hooks/github-actions/prepare-release.sh'

  '.rubble/publish.sh'

  'rubble-generated'

  'rubble-generated/d36zxhg-rubble/build-brick.sh'

  'rubble-generated/d36zxhg-rubble/cleanup-auth.sh'

  'rubble-generated/d36zxhg-rubble/github-actions-publish.sh'

  'rubble-generated/d36zxhg-rubble/lifecycle.sh'

  'rubble-generated/d36zxhg-rubble/open-pipeline-auth.mjs'

  'rubble-generated/d36zxhg-rubble/pipeline-auth.enc'

  'rubble-generated/d36zxhg-rubble/publish-release.mjs'

  'rubble-generated/d36zxhg-rubble/release-inventory.txt'

  'rubble-generated/d36zxhg-rubble/release-root.sh'

  'rubble-generated/d36zxhg-rubble/store/2b/fw/brk-2bfwkovamqlgqawc2obxigc4yho4jgx6rrkc6tyhubog5tm2vhxa-nghttp2-libs-1.69.0-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/3b/lb/brk-3blbc3vt3hw6l2yenxtxlwpfnv7432fvq4xhhkr7lbtpk7msi3pq-readline-8.2.13-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/3e/xo/brk-3exo4yvcmu45p6oevi6u6v7fkppbt2fohg5gpkfvwhjykut7m3wa-linux-headers-6.6-r1.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/3i/sl/brk-3isljfsdiufidx6nanfu323k7zozw2mkua3ht56d2dlnq6eideca-libisl23_0.27-1_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/3n/3b/brk-3n3bc5ncagillpn2mz3jicaeyjvq6myp5b2prh2kn6tllwded3qa-libgcc-s1_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/3o/ot/brk-3oothg4a44icdojzlibmxrxhn2xs6hase67u2pgy4z77l7gj6kgq-libjansson4_2.14-2_b3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/3p/wy/brk-3pwyzin2s6znyulfwpta6mbiky3ksdwnmvi4k4oblrddcyccpbkq-libbinutils_2.44-3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/4f/s5/brk-4fs5rx3x7gzapbcpl3d5oin6v4arzvcmthyhvu6vt3eamlsnngga-rubble-elf-runtime.brick'

  'rubble-generated/d36zxhg-rubble/store/4g/be/brk-4gbejr52ozzofmznelc52fgic4nsoasxjr6i4phtf6utztaoz6la-binutils-common_2.44-3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/4r/av/brk-4ravoggd7ip3ozxtjw2pppx3c2btu4xx7jhfrevaupwjdbyyrqmq-RubbleR.git.partial.brick'

  'rubble-generated/d36zxhg-rubble/store/4u/ec/brk-4uecjax2lpo5idputrmq6yayy6admss7pdzmgzf6pwomzimzj3qa-unzip-6.0-r15.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/5f/6h/brk-5f6h42fvytrovpiqc6uef6hb35eujabalgjpgxeksmjvoxwthtca-wasm-pack-v0.15.0-aarch64-unknown-linux-musl.tar.gz.brick'

  'rubble-generated/d36zxhg-rubble/store/5h/6c/brk-5h6cchin5lidxx4alu3objrowtlsbqblhb27i6svhihosmwda3ja-gzip.brick'

  'rubble-generated/d36zxhg-rubble/store/5h/u5/brk-5hu5obb4yrhcphlmjq4eze7rbdrnkszt7o2obqnpvtuehzgqdqoa-libexpat-2.8.4-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/5t/d6/brk-5td6qvq3hkwnfc5vqh6lcuv5xlk5yh26d2esafb7byxkpwl6klua-gawk-5.3.1-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/5u/xz/brk-5uxzpu3vurxnu4v22sz2bo74ffqh3phfbwz66xnxcbxfg2rvdoxq-nodejs.brick'

  'rubble-generated/d36zxhg-rubble/store/5v/ex/brk-5vexncx3cian4rymupdaft3bwnvswvrzp6pcxohuilbll3lii53a-zstd-libs-1.5.6-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/5w/sm/brk-5wsmysbedc7wbcb22csq254i5hrsdbwpdwuzyi5seacce7a4iaoa-coreutils-sha512sum-9.5-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/5z/qz/brk-5zqzbtecxd2bwjpypfrcgfmzvuqihlmabhg5jtqztyhjc656maja-perl-5.40.4-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/65/xn/brk-65xn763kfhf7ye2ax5rr3hjotrij3qjagkddvfhqarwrt2a7mnha-ld-musl.so.brick'

  'rubble-generated/d36zxhg-rubble/store/6l/p4/brk-6lp456cvhb7ckx65h7yhuzgup3uli5rrlhgesi7cgtyuqcgbwp3q-zstd.brick'

  'rubble-generated/d36zxhg-rubble/store/76/oq/brk-76oqeriyjzj3hwadz7k3q2brpihh2w3wg7pd7x7yoygfbdiso2aq-rubble-web-node-modules.brick'

  'rubble-generated/d36zxhg-rubble/store/77/pa/brk-77pafwgzhgk3kbtyd3i5bnikedwfoif6mfaibfesmfc655t35naq-libpsl-0.21.5-r3.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/7f/cr/brk-7fcrm7iiq4agepnnbu46kixt3exop6fqy2ylv34zgifmrjjckczq-bzip2.brick'

  'rubble-generated/d36zxhg-rubble/store/7g/wd/brk-7gwdsqgvkrl5q7ztjhu2z65wbjt2eywqrtwg7xc7jewdoolhnmea-acl-libs-2.3.2-r1.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/7h/vr/brk-7hvrra6ygcaaeexgncdv3uasq6xy65zzagujucn6atyplqhhviua-wasm-pack-0.15.0.brick'

  'rubble-generated/d36zxhg-rubble/store/7u/ow/brk-7uow7tpjx4wohzjkr7lsr7q2hryfyqrgpznjpjiw6u76y5uxs66q-wasm-bindgen-cli-0.2.115.brick'

  'rubble-generated/d36zxhg-rubble/store/a7/ud/brk-a7ud4y2emz4jysev4e5p275gywgintjlenar2fsfrjokko6cdclq-bootstrap-env.brick'

  'rubble-generated/d36zxhg-rubble/store/aa/bk/brk-aabkmflstkagk4gv7pzdgfmzkzirwp5zxrcvnqcuhdy2dg2zigwq-rust-std-1.94.0.brick'

  'rubble-generated/d36zxhg-rubble/store/ad/yk/brk-adykhpm55qerngmtx6ke7csou4r73gh5lnubblp7jj6ro4oeyxna-patch-2.7.6-r10.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/ar/ds/brk-ardstcgczrhdaibp6jmdzypxykeymbity6aut4wr3ijnqozjrcxq-git.brick'

  'rubble-generated/d36zxhg-rubble/store/ay/6k/brk-ay6kezqef2anhdm53akx7elc7ge7cmrhesutg3b6lzj2jolgnv2a-rust-std-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'rubble-generated/d36zxhg-rubble/store/ay/vl/brk-ayvlr7htt6lml5iosty2yuiuogndl4xwu27xkbizrjbocyts5nrq-zlib-1.3.2-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/b7/hd/brk-b7hdib2p2djrz7gu5mylkac6ijbvjwskm3shr5semy4ekaanow6q-c-ares-1.34.8-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/bg/yp/brk-bgypnnermvrmj657kbamz6dhvtc7ic743c3tlooizg54udk3ocka-curl.brick'

  'rubble-generated/d36zxhg-rubble/store/bs/cz/brk-bsczck3itaibqqkhhwkkzdh3fv5i477527aika7gfcttdyn6chhq-libgcc-14.2.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/c5/wb/brk-c5wbg5jn3pylcmup7sbxmniucuw6dzpkte46m6h7buk2xbxyxtsq-python3.brick'

  'rubble-generated/d36zxhg-rubble/store/cn/de/brk-cndex52rgwiybhxcbkpry2isc55dz3hrc5lblmzr3xyeilghixda-patchelf.brick'

  'rubble-generated/d36zxhg-rubble/store/cn/su/brk-cnsuk57bulhj544m3skp3wwq4lsh5qegyneycg7bgfo2zzu5z7ua-coreutils-env-9.5-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/d3/6z/brk-d36zxhgikhmojnqedc6wmfyfu4xc3zvcnexsyo2onyixqsebt7tq-rubble.brick'

  'rubble-generated/d36zxhg-rubble/store/dj/wp/brk-djwpbnhqo3ymgm2tvei36nze3s4s6daodvkmqlklfufz7vddonoq-cargo-1.94.0.brick'

  'rubble-generated/d36zxhg-rubble/store/dk/ct/brk-dkctajvl2il4pypc32olxna3wh7rq2dnch3in6y6qkziz74prrka-zlib1g_1.3.dfsg_really1.3.1-1_b1_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/du/so/brk-dusoct55bmpgvm2ldpmeths6hggdhr33vyflycel7kjgjw3ts6ha-ca-certificates.pem.brick'

  'rubble-generated/d36zxhg-rubble/store/dx/bm/brk-dxbm5xbf7vkb35noka43so2duja6uw3kitmmhxbybcer6op5bcla-utmps-libs-0.1.2.3-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/e5/bi/brk-e5bidgxbvr5crgxvo3tckxld466txu5dxi674pplgncc4fifmkva-gdbm-1.24-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/e7/aw/brk-e7aw53vitgjqbosohujzxudnmbfqylyi27ehtmvbucoevvgocfoq-libsframe1_2.44-3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/e7/dd/brk-e7ddcesxg2zmvb5wamzn6k6wq77wdqf5jxs3cow4m64xubmstluq-gnu-make.brick'

  'rubble-generated/d36zxhg-rubble/store/ea/y2/brk-eay2yd76jtq2n72kafauwkofupanezwq2muobm7bjlf6mfojk4ma-linux-libc-dev_6.12.86-1_all.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/ec/xk/brk-ecxkum7thkjwggmltz3jlz67amewczlvf6ybucueqawsamou6t4a-binutils-aarch64-linux-gnu_2.44-3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/em/on/brk-emonumondcre3b5pnxo4hp5dzwkoobjp7fi6ofxmqudceo4dxjnq-node-v22.22.3-linux-arm64.tar.xz.brick'

  'rubble-generated/d36zxhg-rubble/store/em/um/brk-emumr4qhmj3md4udqk36vvpcou3bcq2q6x47b2utro76mglanp6q-libffi-3.4.7-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/es/h7/brk-esh7pawc46nsh5b2uuykm4qsjsoowbes5uu4nt2kcg6hocags6vq-coreutils-9.5-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/es/iy/brk-esiyaxnxz3qbqhmjp3kjdfummyfpbmzr6eoub362jjpavkrlzyiq-pcre2-10.43-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/eu/kf/brk-eukfornac6zeehc5o4izhyj6vslke65etzbod6j3x2u3w2igbi6q-bzip2-1.0.8-r6.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/ex/wh/brk-exwhj5vebfaduvvhd7f6xtppocqwgqam7csyi3u5434k3ypqofpq-libmpc3_1.3.1-1_b3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/f4/2p/brk-f42ppjfbnfjsed7bwyertmyxb2rwak677b54f7masrcakdbb725q-llvm-tools-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'rubble-generated/d36zxhg-rubble/store/fa/qk/brk-faqk22fjqryqxjx6pkufmb2mttau3gwuv2qu6roi3d4melszcu7q-libunistring-1.2-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/fb/xg/brk-fbxgu4t24gr47iq2yhyaygays2hvcmyidx4tkwjmlx52pttyr6yq-libasan8_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/fd/vb/brk-fdvblu7ednc2u5nevmdvxyvycn4fejjclnyaqzg6itd54yacupcq-xz.brick'

  'rubble-generated/d36zxhg-rubble/store/fg/32/brk-fg32tsmkrioagedunckpr37qz35rn4b7obxt3wsbxx56ajpxviza-mpc1-1.3.1-r1.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/fu/4g/brk-fu4gjf2vujnnxzbws5i2w57yneqm7tmgiqzxodte6s6rf74vchrq-g__-14.2.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/fz/so/brk-fzsocvqoawb6atzh5tfjxgahm2yualfjxwxicd55hjyf4gfjo5da-libstdc__-dev-14.2.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/g3/fx/brk-g3fxen4ug3f3g34imdsefwplwd3ulzn75tn5uxd5jqe7t23bzyna-bash-linux-aarch64.brick'

  'rubble-generated/d36zxhg-rubble/store/gb/4d/brk-gb4dlxkuu36d4olrckbxrdwlkvocpv2amucqerzpih2nv5w3uxuq-libstdc__6_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/gb/6k/brk-gb6koiwm57ptlyzvdywugocbx67enpv3tog76ksqiccrr3pxaota-python3-3.12.14-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/gg/bv/brk-ggbvlarbi7gglrpbr4rkqgybe4mndc4eaxbgv4nsixqmis74zkda-gcc-glibc.brick'

  'rubble-generated/d36zxhg-rubble/store/gk/zo/brk-gkzo3hlntyvplswvkk6opvczvh5xzc2kicpff2y7dsljkyhfw7oq-rust-toolchain.brick'

  'rubble-generated/d36zxhg-rubble/store/hd/hi/brk-hdhimhaqn7bul5k67m2gmw4ea6xibuprz2mgla5obsjibs7tfnoa-make-4.4.1-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/ho/55/brk-ho552ymbr5wqlkbb7xckcvqfjs5fd4ytbrf5rjp3vaqnwocxhx5q-gmp-6.3.0-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/hr/3g/brk-hr3gsmedt3iyx26xhety6rvbs2nzhv6o4oyscyt7qvuuixa7fbfa-libhwasan0_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/hw/ud/brk-hwudtbqp6mtqd433zl777ixamegzf5s6pqjc3vbkw4yy7ca6rpzq-libstdc__-14.2.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/i3/vz/brk-i3vzwzq5ceekylzear5wrwz4teano37g32htjtcd4rma3zvjzz3a-libgmp10_6.3.0_dfsg-3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/i6/rp/brk-i6rpnovdyaumnm4dbmqheqhnimae5nyro5b25ewahcsz4tksxefq-mpdecimal-4.0.0-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/is/xo/brk-isxo3o4skm7vtiqyhakx4x4uxrw7hnycm3ldwp43grskdhxl3qxq-sed-4.9-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/iu/rp/brk-iurpgonnj2ueak3ta44zihvtdksmjx5j62dy7n2ebbd7pdb3lfja-bison.brick'

  'rubble-generated/d36zxhg-rubble/store/iw/xf/brk-iwxfog3m6w6osk73jf7h77lycjwgis2khdcwgi5vp2bngilpq5qa-gnu-sed.brick'

  'rubble-generated/d36zxhg-rubble/store/ja/2g/brk-ja2gawpefozngsdbmzs5n2a66ujesjats2qcq7homnixclj6iqrq-grep-3.11-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/je/z2/brk-jez2sbbjieywlgekhwhs23jazl2lzvqfjtog5rlsrp2hpzeq5exq-RubbleR.git.brick'

  'rubble-generated/d36zxhg-rubble/store/jw/hf/brk-jwhfx26nkv24vmnfckbvccnpwdkzwfvxcjty7dhntghaemjlpfxq-mpfr4-4.2.1-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/jz/ib/brk-jzib76o6jwvszofr4g7p5ceo7li2szw2zm25pt6bwpu4plo7wdwq-rubble-src-checkout.brick'

  'rubble-generated/d36zxhg-rubble/store/jz/sb/brk-jzsbx4e7xjrjybgzigm2xnhrpc6rldvgwpqlhvca7vjzks7fzunq-gcc.brick'

  'rubble-generated/d36zxhg-rubble/store/k2/sq/brk-k2sq3ksyc4xg4n3byfvtc2xp2by5lw3uus2pjw4ro7y4ad54uo4q-coreutils-fmt-9.5-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/k5/fr/brk-k5frhmbdkv7cwqivkkbpn54wsufwddmytey446lzvulwfj7ggc4q-gpatch.brick'

  'rubble-generated/d36zxhg-rubble/store/kf/5c/brk-kf5czgbhfrjlfvr54qqevkuwi43wqxq6nf25ih2xadevek5i2cpa-rustc-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'rubble-generated/d36zxhg-rubble/store/km/24/brk-km24gkz4zqqu7uqftehftqfd26smur3oitfkvhpv35pqsc5llvca-cargo-1.94.0-aarch64-unknown-linux-gnu.tar.xz.brick'

  'rubble-generated/d36zxhg-rubble/store/ko/ve/brk-kovec6hpuborsbsvc7t6mvkfvwylfdlf4evnpad24hnwoyiflz5q-musl-dev-1.2.5-r11.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/kp/e7/brk-kpe7kma33nmt3mijbihbuzazuupuiq4ffqabvfgogzgs2rdp2rfa-libzstd1_1.5.7_dfsg-1_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/kq/oa/brk-kqoaqdowlcmrluolokiygo33evr47gordg5y3gqjf4etscxnee2a-libbz2-1.0.8-r6.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/ks/6e/brk-ks6e3u26mzxm5dwrtt4v2y5z6hltzyyoqnn5v36ctpuvq3z5ebga-libgomp1_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/kt/bd/brk-ktbdwi3xid4ywlz6il2qlgx67aclu2t5gljy527g7vdnv6h7gaha-jansson-2.14-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/lb/7v/brk-lb7vuv6w3fr43o73swpjgwfuwdhyi7l2xskuuisw3eaekunxv3ia-libc6-dev_2.41-12_deb13u3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/lh/k2/brk-lhk2czt5ht6it4mtrkafkipvagjn2fbpwbrunt2txlirsokfeeva-bun-1.4.2.brick'

  'rubble-generated/d36zxhg-rubble/store/m5/ln/brk-m5lnpllbzm555r5zuagxbaoqomumjvcwyoq7xdkffysmdvteelwa-findutils-4.10.0-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/mf/2z/brk-mf2zom7awa7olgagfl3ruhqhflotm3vdkxcrpruwdsofqnugvraa-ca-certificates-bundle-20260413-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/mf/wk/brk-mfwkvtv3n6hvvrci2nxbilte5df2wpayqreolg3t5xnlwedydz2q-libmpfr6_4.2.2-1_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/mg/vp/brk-mgvpjsbz7sujl5qdndfmqhtclpxfhlytkeyidejyjfez5jloit7a-g__-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/n6/vt/brk-n6vtqu3bxkksa6hlrwirri6entermnuofp2sdqcfcrzxarqrr3hq-isl26-0.26-r1.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/na/a2/brk-naa2ad3mxbwsl6syyyeikeu6srwar3mxn4lv6faf72kx6hjpq72q-libgomp-14.2.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/ng/2y/brk-ng2yhab3txqyfgtnrgwttzyliczkrx52jeu7skkoaxeu5d752ynq-libncursesw-6.5_p20241006-r3.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/nh/57/brk-nh577btyfes2xq2gotqnt6ur4vqq6qojz4kmf7xbewchtdzrmyzq-gnu-tar.brick'

  'rubble-generated/d36zxhg-rubble/store/nw/ad/brk-nwadxrnuk7cydd6sigwmkqkyyxpkgj3b7bfoyhol66daeqo4rfka-rust-std-1.94.0-wasm32-unknown-unknown.tar.xz.brick'

  'rubble-generated/d36zxhg-rubble/store/nw/jn/brk-nwjntcya5bc7tfxrl5i22jo3v2rnlixwjc6ri3r4kwupxtwlaqsa-cpp-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/od/lz/brk-odlzblejigvixnek4zw3qpf6kdmpduizlfdol6phkrwrrltm3kdq-libc6_2.41-12_deb13u3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/oe/dx/brk-oedx42pgtkscsyrm2vn6hyrci7hw74ladlpu6f6bwgt5yguhmyqq-m4-1.4.19-r3.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/oh/zg/brk-ohzg3khe3y5zbg6it742hi63cwoz7k3vbr5jufkccupj4kcrkpwq-curl-linux-aarch64-musl-8.18.0.tar.xz.brick'

  'rubble-generated/d36zxhg-rubble/store/on/cm/brk-oncm47zwljpb5u4lekuyhgdpx5rv4mn6vxvbkmuxps6izjagxiva-xz-5.8.3-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/or/yv/brk-oryvpwa2ctnjptul44ck6l3nzemkchspnw5qr45tjuz3w44z5cqa-RubbleR.git.partial.brick'

  'rubble-generated/d36zxhg-rubble/store/ow/oy/brk-owoyhne4rlabd6ti2usbbxf5qm6px4edpaa2ixltmg55lde2ckuq-sqlite-libs-3.48.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/p2/y6/brk-p2y62ixbitokcpknxcdicbt27xe6kt2sgl4cwhrou24siujik46q-rubble-deps-cache.brick'

  'rubble-generated/d36zxhg-rubble/store/p4/37/brk-p437dghiaad2yb57qr2yhpsmwaw3z3jwfkdlsqaf6pgahrueysja-zstd-1.5.6-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/pc/6e/brk-pc6egjgq2ba3z3wnas2zd4lygye7s6qa34rdem6tqt2oxizk3kfa-gawk.brick'

  'rubble-generated/d36zxhg-rubble/store/pj/6o/brk-pj6ok275ispcmivb4gpez2bzug46p2ge6a7pd3dncpfzelwebihq-liblsan0_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/pm/cz/brk-pmcz3tfl7nkzrimbo5dmhkhbjumdijspqs7s26of7sw44lf4yq2a-linux-native-toolchain.brick'

  'rubble-generated/d36zxhg-rubble/store/pt/g4/brk-ptg4o4phfr2eutq2xrcoqi6zx2d2rk4nqoxdm73hvskgosibuh4a-tar-1.35-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/px/kz/brk-pxkzws6fwby35jvgf5tcak6wdo5gj66sjdmzwpjjxdbfknufrvwq-rustc-1.94.0.brick'

  'rubble-generated/d36zxhg-rubble/store/q2/5i/brk-q25i4gbxfmjfwwxzolshgu7hsx5zgkuiz6blowocu6rx6wlmd7wa-llvm-tools-1.94.0.brick'

  'rubble-generated/d36zxhg-rubble/store/q6/6x/brk-q66xooc3uyetlxp6565oyihya5babf4sn3opal27qo6em5wjkuca-gcc-14-aarch64-linux-gnu_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/q7/b3/brk-q7b3knedxjnnqxxaghcvu2a7mrk5dw5ueoyvqlsu2spmjhil2zkq-glibc-runtime-support.brick'

  'rubble-generated/d36zxhg-rubble/store/qb/rl/brk-qbrlu376mq3m5jhng65mdeobdbrpjzv3thrthfrpvoam77zovt3q-patchelf-0.18.0-aarch64.tar.gz.brick'

  'rubble-generated/d36zxhg-rubble/store/qg/3g/brk-qg3g2dinqfibxj3dkbjqgp6q4vhezm2w5ayy7ibamcbqov7sunuq-git-2.47.3-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/qj/7s/brk-qj7s4kfeu7lleafbwujkfsjkts575oc7v5agukewx2ic3y6b6mdq-coreutils.brick'

  'rubble-generated/d36zxhg-rubble/store/qm/dv/brk-qmdv4se7cy5zxuxhuq6la3h562eim3kyrj3eud44s2njzmqn3mlq-libpanelw-6.5_p20241006-r3.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/qn/3l/brk-qn3lywhoc2dno3mvjvoq3mihzjcc6yz76oy3bvxnhgrsw5ewd7xq-libtsan2_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/qs/3n/brk-qs3nb5qcclaodccu6unqj42b76lly2d4htpputfm77xzao6fzema-musl-1.2.5-r11.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/qv/xc/brk-qvxcj4lj5jj5mbgvpcfw5svnfaljwbkil7ghzzofovoqehagqava-diffutils-3.10-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/qx/xt/brk-qxxt6f726go3553r3bhxadzrgj637yghleeivlrsywklrpcr3pnq-libitm1_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/rg/ds/brk-rgdskue4seruek4fxopdeftkm4uf7jxa7nxjyqkhkj5yak2ebc4a-gcc-14-base_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/rl/qg/brk-rlqgbuxu4kleo257tmrhzkllhb6thfjrmbcsr6hkxf2cduly7vta-xz-libs-5.8.3-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/rm/4z/brk-rm4zxsn5qycajrfwexlu4perkspongbyp6ae77564am5knq453wa-libgcc-14-dev_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/ry/gp/brk-rygpip6ibvqdklrmfwyhoin4d2a6ee7yzsubvi7s7aqkyqp7ervq-rust-std-1.94.0-wasm32-unknown-unknown.brick'

  'rubble-generated/d36zxhg-rubble/store/s2/cs/brk-s2csfg2tc2jzs43r6ne53ha5qvt2jtczod6tfqfztgplw7z5oe7a-nodejs-runtime.brick'

  'rubble-generated/d36zxhg-rubble/store/s3/pv/brk-s3pvvtqxrdzleije623ea64covxuywd4s6akx2d5lpxokyytr4ea-libidn2-2.3.7-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/s4/36/brk-s436fi4eiqcbgfl3sxxy6qiehrwo3ytnrcmp3s4u5meq6dlhmola-m4.brick'

  'rubble-generated/d36zxhg-rubble/store/sa/xd/brk-saxdsta5ltm7iomdgyx3f23uma6qmu7hz674djpkjgbgi76tsisa-gcc-14.2.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/sb/d6/brk-sbd67om27qkuxxrdw3tvbfvzq7w6wrvgygynmeee5t3jdicydboq-bun-linux-aarch64.zip.brick'

  'rubble-generated/d36zxhg-rubble/store/sg/dy/brk-sgdyuezwsbzpgusurjxb7bvquikinj455qz7q5c2emyrynor4f3q-binutils-2.43.1-r3.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/si/63/brk-si63kbjoeh5l76hedrmuxjzzuolovggsbkabc2fqnwt7ujic7ajq-binaryen-117.brick'

  'rubble-generated/d36zxhg-rubble/store/sl/7z/brk-sl7zsbzcfjdoz6ohe72ecirudxewciohnjumdqn7bkuunn2hp5lq-libstdc__-14-dev_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/t5/am/brk-t5amqprssgcztj7qgv4d7bqmtbtagdixvn4hvjtycdm44t4gtrda-diffutils.brick'

  'rubble-generated/d36zxhg-rubble/store/te/dz/brk-tedz642cat5wbxa5xk2cl6gbj4rmqaj6r64ivlzc6wu4bg4iolla-grep.brick'

  'rubble-generated/d36zxhg-rubble/store/tp/ql/brk-tpqlnp3dvgnq36l5ubgs4c2ficukfs4d4v3nllkbxjvgoluw4eta-libcurl-8.14.1-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/tt/xo/brk-ttxoxb3lfk7t3rzpgq4m42lsl7lmgzt2e5w5pdt6rxna3q6pulra-skalibs-libs-2.14.3.0-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/vq/3s/brk-vq3sirpitu5prsi2ig3ld3d7am7x6cxjxscc4qchsiecywgz3bfa-libatomic-14.2.0-r4.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/vs/wq/brk-vswqqehwz73whpxezmbr7nf4anbs7slwoknh6pi76q7askntz5iq-libctf-nobfd0_2.44-3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/vx/wg/brk-vxwgaxdchz7bshf2frb2nciw5fvmchcygr76c7nstnwaithr3t2q-unzip.brick'

  'rubble-generated/d36zxhg-rubble/store/w4/54/brk-w454nqkzwaes5sipplnsifvijlalui7oas47jt43b27szts3pz4a-RubbleR.git.partial.brick'

  'rubble-generated/d36zxhg-rubble/store/wn/76/brk-wn765puibuqspttk5t23jagim6c3i7xrestty5wp5ihfcx5k5bxa-rubble-web-assets.brick'

  'rubble-generated/d36zxhg-rubble/store/ws/jd/brk-wsjd6bhyeay7o42k276g7ep5plfqmlqubqztlvbu5aw7rjjeuq2a-gzip-1.13-r1.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/wx/52/brk-wx522xces6aeljkz5y55o6kdkgi6zgyvebi63xgqxclodxabs56q-libatomic1_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/xa/vn/brk-xavn33v6xwtxgf7j7snhvwd5urqxswa4c2d2hxtjxjza37nizg4a-libctf0_2.44-3_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/xd/cj/brk-xdcjb5anir2fm7jr5abmf2vtwqiltfj6pr3sufepj6l72bh2azfa-libssl3-3.3.7-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/xp/4n/brk-xp4ng2csk5hs2jlwyfptf7imm4gd3jifcoxvhghuz7b7qf5nidla-findutils.brick'

  'rubble-generated/d36zxhg-rubble/store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'rubble-generated/d36zxhg-rubble/store/yb/6t/brk-yb6tefhslyriibghffdurwb2wvapj6x3xizoboao2doaj7v7xgda-libcc1-0_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/ye/cb/brk-yecbppbe2hram3gythftkgn6mwelxq6l42vejdrjy3czbotcwmoq-bash.brick'

  'rubble-generated/d36zxhg-rubble/store/ys/rv/brk-ysrvjznwd73kp7ikl6ymcdrfrcuxlklubsx6wlnxzuqa7gwuxdxq-bison-3.8.2-r1.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/za/b7/brk-zab7x4pj4e4cmrnw753rp5hyl7jadtxtfddargzdbkkqoq2k7uwq-libubsan1_14.2.0-19_arm64.deb.brick'

  'rubble-generated/d36zxhg-rubble/store/zk/j7/brk-zkj7262l7rctago4tw4edylztcehl6bcvsxrow4o4lpqurjcftdq-libcrypto3-3.3.7-r0.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/zl/qk/brk-zlqkh4hv6jitrpj2uumu62lrfbvr6hozsu4j6wjoo75glrnl4f6a-RubbleR.git.partial.brick'

  'rubble-generated/d36zxhg-rubble/store/zm/2b/brk-zm2bpcu5lxnkvg3jntp5l3mmr5l7cvaqc27gswsvtwvjusugmqta-wasm-bindgen-0.2.115-aarch64-unknown-linux-gnu.tar.gz.brick'

  'rubble-generated/d36zxhg-rubble/store/zn/wh/brk-znwhzlmuwlllrzalgrnpvastzcrjizp6j6uko2ijyvss5ycuwr6q-perl.brick'

  'rubble-generated/d36zxhg-rubble/store/zq/h6/brk-zqh6lunhozithbpfnbwqg5j54lg5ze77yzuwedmjltfo45ghffuq-binaryen-version_117-aarch64-linux.tar.gz.brick'

  'rubble-generated/d36zxhg-rubble/store/zr/7s/brk-zr7ser4omrmjwzjfkik44mdmgvtrjakkpkcqq4llvhfrke2n6sma-brotli-libs-1.1.0-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/zt/bw/brk-ztbwuqmg77pfi6tzkoy4asfmpiy22x6lugzprlhhhvjldam36n4q-rubble-script-shebang.brick'

  'rubble-generated/d36zxhg-rubble/store/zw/da/brk-zwdawolcw4fqjnlmmwfrxjwrxcplq7t3jb73x5seskofbtj353na-libattr-2.5.2-r2.apk.brick'

  'rubble-generated/d36zxhg-rubble/store/zx/uk/brk-zxuk5z6fzmgkuov5rw3gdh5bqqj4lrd65zo4xli4umiqjmemdqra-rust-web-wasm-toolchain.brick'

)

log() {
  printf '[github-actions-publish] %s\n' "$1" >&2
}

fail() {
  log "ERROR: $1"
  exit 1
}

shell_quote() {
  local value="$1"
  printf "'"
  printf '%s' "${value}" | rubble-exec sed "s/'/'\\\\''/g"
  printf "'"
}

print_assignment() {
  printf '%s=%s\n' "$1" "$(shell_quote "$2")"
}

local_plan() {
  print_assignment RUBBLE_PUBLISH_SUGGESTED_BRANCH "${pipeline_branch}"
  print_assignment RUBBLE_PUBLISH_PIPELINE_ID "${pipeline_id}"

  print_assignment RUBBLE_PUBLISH_ENVIRONMENT "${pipeline_environment}"

  print_assignment RUBBLE_PUBLISH_GENERATED_ROOT "${generated_root}"
  print_assignment RUBBLE_PUBLISH_WORKFLOW_PATH "${workflow_path}"
  print_assignment RUBBLE_PUBLISH_OUTPUT_COUNT "${#managed_output_paths[@]}"
  local index
  for index in "${!managed_output_paths[@]}"; do
    print_assignment "RUBBLE_PUBLISH_OUTPUT_${index}" "${managed_output_paths[$index]}"
  done
}

publish_git() (
  local repo_root target_prefix base_branch unrelated branch index_directory tree commit
  repo_root="$(rubble-exec git -C "${target_root}" rev-parse --show-toplevel)"
  target_prefix="$(rubble-exec git -C "${target_root}" rev-parse --show-prefix)"
  base_branch="$(rubble-exec git -C "${repo_root}" branch --show-current)"
  [[ -n "${base_branch}" ]] || fail "publishing requires a named base branch"
  local -a paths=() status_pathspecs=(.) pathspecs=()
  local path tracked
  for path in "${managed_output_paths[@]}"; do
    paths+=("${target_prefix}${path}")
    status_pathspecs+=(":(exclude,literal)${target_prefix}${path}")
  done
  unrelated="$(rubble-exec git --no-optional-locks -C "${repo_root}" status --porcelain --untracked-files=all -- "${status_pathspecs[@]}")"
  [[ -z "${unrelated}" ]] || fail "repository has unrelated changes; commit or remove them before publishing"
  branch="${pipeline_branch}"
  if rubble-exec git -C "${repo_root}" show-ref --verify --quiet "refs/heads/${branch}" || \
     rubble-exec git -C "${repo_root}" ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; then
    fail "one-use pipeline branch already exists: ${branch}"
  fi

  # Build the run commit without consuming local hook edits or changing the caller's index/branch.
  index_directory="$(rubble-exec mktemp -d "$(rubble-exec git -C "${repo_root}" rev-parse --path-format=absolute --git-common-dir)/rubble-publish.XXXXXXXX")"
  trap 'rubble-exec rm -rf -- "${index_directory}"' EXIT
  export GIT_INDEX_FILE="${index_directory}/index"
  rubble-exec git -C "${repo_root}" read-tree HEAD
  for path in "${paths[@]}"; do
    # Missing optional hooks are valid. Keep tracked deletions, using the run index rather than the caller's.
    if [[ ! -e "${repo_root}/${path}" && ! -L "${repo_root}/${path}" ]]; then
      tracked="$(rubble-exec git -C "${repo_root}" ls-files -- ":(literal)${path}")"
      [[ -n "${tracked}" ]] || continue
    fi
    pathspecs+=(":(literal)${path}")
  done
  rubble-exec git -C "${repo_root}" add -A -- "${pathspecs[@]}"
  tree="$(rubble-exec git -C "${repo_root}" write-tree)"
  commit="$(rubble-exec git -C "${repo_root}" commit-tree "${tree}" -p HEAD -m "Run Rubble workflow for ${root_id}")"
  rubble-exec git -C "${repo_root}" update-ref "refs/heads/${branch}" "${commit}" ''
  rubble-exec git -C "${repo_root}" push origin "refs/heads/${branch}:refs/heads/${branch}"
  wait_run --repo "$(resolve_repository)" --branch "${branch}" --commit "${commit}"
)

resolve_repository() {
  local origin_url
  origin_url="$(rubble-exec git -C "${target_root}" remote get-url origin)"
  if [[ -n "${RUBBLE_PUBLISH_GITHUB_REPOSITORY:-}" ]]; then
    printf '%s\n' "${RUBBLE_PUBLISH_GITHUB_REPOSITORY}"
  else
    gh repo view "${origin_url}" --json nameWithOwner --jq .nameWithOwner
  fi
}


delete_environment() {
  local repository="$1"
  local response=""
  if response="$(gh api --method DELETE "repos/${repository}/environments/${pipeline_environment}" 2>&1)"; then
    log "deleted one-use Environment ${pipeline_environment}"
    return 0
  fi
  if [[ "${response}" == *"HTTP 404"* ]]; then
    log "one-use Environment ${pipeline_environment} is already absent"
    return 0
  fi
  log "ERROR: failed to delete one-use Environment ${pipeline_environment}"
  return 1
}

create_environment() {
  local repository="$1"
  local key="${RUBBLE_PIPELINE_AUTH_KEY:-}"
  [[ -n "${key}" ]] || fail "RUBBLE_PIPELINE_AUTH_KEY is required"
  log "creating one-use Environment ${pipeline_environment}"
  gh api --method PUT "repos/${repository}/environments/${pipeline_environment}" \
    -F 'deployment_branch_policy[protected_branches]=false' \
    -F 'deployment_branch_policy[custom_branch_policies]=true' >/dev/null
  environment_created=1
  gh api --method POST \
    "repos/${repository}/environments/${pipeline_environment}/deployment-branch-policies" \
    -f name="${pipeline_branch}" \
    -f type=branch >/dev/null
  printf '%s' "${key}" | \
    gh secret set RUBBLE_PIPELINE_AUTH_KEY --repo "${repository}" --env "${pipeline_environment}"
  unset key RUBBLE_PIPELINE_AUTH_KEY
  log "bound one-use Environment to ${pipeline_branch}"
}


consume_pipeline_identity() {
  local state_file
  state_file="$(pipeline_state_file used)"
  if ! (set -o noclobber; printf '%s\n' "${pipeline_id}" >"${state_file}") 2>/dev/null; then
    fail "pipeline identity has already been consumed; run Rubble again to create a new pipeline"
  fi
  rubble-exec chmod 600 "${state_file}"
  log "consumed one-use pipeline identity ${pipeline_id}"
}

pipeline_state_file() {
  local suffix="$1"
  local git_common_dir
  local state_dir
  git_common_dir="$(rubble-exec git -C "${target_root}" rev-parse --path-format=absolute --git-common-dir)"
  state_dir="${git_common_dir}/rubble-pipelines"
  rubble-exec mkdir -p "${state_dir}" || return 1
  rubble-exec chmod 700 "${state_dir}" || return 1
  printf '%s/%s.%s\n' "${state_dir}" "${pipeline_id}" "${suffix}"
}


cleanup_environment_on_exit() {
  local publisher_status=$?
  local cleanup_status=0
  trap - EXIT
  set +e
  if ((environment_created == 1)); then
    delete_environment "${cleanup_repository}"
    cleanup_status=$?
  fi
  set -e
  if ((publisher_status != 0)); then
    exit "${publisher_status}"
  fi
  exit "${cleanup_status}"
}


json_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "${value}"
}

wait_run() {
  local repository=""
  local branch=""
  local commit=""
  local response=""
  local run_id=""
  local status=""
  local conclusion=""
  local html_url=""
  local registration_attempt=1
  local registration_max_attempts=60

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --repo)
        [[ "$#" -ge 2 ]] || fail "--repo requires a value"
        repository="$2"
        shift 2
        ;;
      --branch)
        [[ "$#" -ge 2 ]] || fail "--branch requires a value"
        branch="$2"
        shift 2
        ;;
      --commit)
        [[ "$#" -ge 2 ]] || fail "--commit requires a value"
        commit="$2"
        shift 2
        ;;
      *)
        fail "unknown wait-run argument: $1"
        ;;
    esac
  done
  [[ -n "${repository}" ]] || fail "wait-run requires --repo"
  [[ -n "${branch}" ]] || fail "wait-run requires --branch"
  [[ -n "${commit}" ]] || fail "wait-run requires --commit"

  log "waiting for workflow registration at commit ${commit}"
  while [[ -z "${run_id}" ]]; do
    if run_id="$(gh api --method GET "repos/${repository}/actions/runs" \
      -f head_sha="${commit}" -f event=push -f per_page=100 \
      --jq ".workflow_runs | map(select(.head_branch == $(json_quote "${branch}") and .head_sha == $(json_quote "${commit}") and .path == $(json_quote "${workflow_path}"))) | sort_by(.run_number, .run_attempt) | last | .id // empty")"; then
      if [[ -z "${run_id}" ]]; then
        log "workflow run is not registered yet; retrying"
      else
        log "found workflow run ${run_id}"
      fi
    else
      log "Actions run lookup failed; retrying"
    fi
    if [[ -z "${run_id}" ]]; then
      if ((registration_attempt >= registration_max_attempts)); then
        fail "workflow run was not registered after ${registration_max_attempts} attempts"
      fi
      registration_attempt=$((registration_attempt + 1))
      rubble-exec sleep 5
    fi
  done

  while true; do
    if ! response="$(gh api "repos/${repository}/actions/runs/${run_id}" --jq '[.status // "", .conclusion // "", .html_url // ""] | .[]')"; then
      log "Actions run status lookup failed; retrying"
      rubble-exec sleep 10
      continue
    fi
    local -a fields=()
    mapfile -t fields <<<"${response}"
    status="${fields[0]:-}"
    conclusion="${fields[1]:-}"
    html_url="${fields[2]:-}"
    case "${status}" in
      completed)
        if [[ "${conclusion}" == success ]]; then
          log "workflow run ${run_id} succeeded: ${html_url}"
          return 0
        fi
        log "workflow run ${run_id} completed with conclusion '${conclusion}': ${html_url}"
        gh run view "${run_id}" --repo "${repository}" --log-failed || true
        return 1
        ;;
      queued|in_progress|requested|waiting|pending)
        log "workflow run ${run_id} status=${status}; waiting"
        ;;
      *)
        log "workflow run ${run_id} returned status='${status}'; waiting"
        ;;
    esac
    rubble-exec sleep 10
  done
}

publish_context() {
  export RUBBLE_PUBLISH_TARGET_ROOT="${target_root}"
  export RUBBLE_PUBLISH_PAYLOAD_DIR="${payload_dir}"
  export RUBBLE_PUBLISH_ROOT_ID="${root_id}"
  export RUBBLE_PUBLISH_ROOT_NAME="${root_name}"
  export RUBBLE_PUBLISH_PIPELINE_ID="${pipeline_id}"

  export RUBBLE_PUBLISH_ENVIRONMENT="${pipeline_environment}"

}

publish() {
  if [[ ! -f "${user_publish_script}" || ! -s "${user_publish_script}" ]]; then
    log "user publisher is absent or empty; skipping publication"
    return 0
  fi
  publish_context
  (builtin cd -- "${target_root}" && "${rubble}" -q script --inherit-env "${user_publish_script}")
}

default_publish() {
  publish_context

  local repository
  repository="$(resolve_repository)" || fail "could not resolve target GitHub repository"
  cleanup_repository="${repository}"
  trap cleanup_environment_on_exit EXIT

  rubble_run_hook pre-publish
  consume_pipeline_identity

  create_environment "${repository}"

  publish_git
  rubble_run_hook post-publish
}

command_name="${1:-publish}"
case "${command_name}" in
  publish)
    [[ "$#" -le 1 ]] || fail "publish does not accept arguments"
    publish
    ;;
  default-publish)
    [[ "$#" -eq 1 ]] || fail "default-publish does not accept arguments"
    default_publish
    ;;
  local-plan)
    [[ "$#" -eq 1 ]] || fail "local-plan does not accept arguments"
    local_plan
    ;;
  wait-run)
    shift
    wait_run "$@"
    ;;
  *)
    fail "unknown command '${command_name}'; expected publish, default-publish, local-plan, or wait-run"
    ;;
esac