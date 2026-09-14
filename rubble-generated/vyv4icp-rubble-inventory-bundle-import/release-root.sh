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

  'store/ry/jw/brk-ryjwb6a3ynqdajbncvpdzwephlmhpxe56zvtgfs4cv4x5lvdguca-rubble-src-checkout.brick'

  'store/xp/su/brk-xpsu7cfnztrrwbvvhovnnlzvjzp3f6qf6funj7ehcobaqgpnx6ha-rubble-canonical-script.brick'

  'store/zk/if/brk-zkiff2cic77r6rxw3quhxg6gu4rznq4omwpz5tui7zwbvlqj6mbq-ld-musl.so.brick'

  'store/3y/ms/brk-3ymsqx4irog2cwz3opdekqpw4otufpn5qdjdmbgzswfjrt23imbq-zstd.brick'

  'store/bx/ch/brk-bxchorbehgapcopsqwo7w5zwjgenujywlkkytlnad3dvy5hpqc5q-bash.brick'

  'store/6f/yi/brk-6fyi5giuhq2rktxlfg2epgwit5rqik345vr2o25yognyocmskspq-gnu-tar.brick'

  'store/pp/dg/brk-ppdghkityovkxogtghygvs2mls7qza646xifdh4qt3pdr7enpi2a-coreutils.brick'

  'store/aa/tx/brk-aatxzhh6ddldsiuelw3vq4psl7mvoxxxqjdeclexroawf34pjnkq-RubbleR.git.partial.brick'

  'store/vy/v4/brk-vyv4icpqbdbpz3rraxm4xn46qrrvpdin7a3d6i4buksmyvxhvb6a-rubble-inventory-bundle-import.brick'

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