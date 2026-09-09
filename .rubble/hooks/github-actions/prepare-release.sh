#!/usr/bin/env bash
# Supply release data here. Optional metadata files: title, tag, notes.md.
set -euo pipefail
source "${RUBBLE_GITHUB_ACTIONS_RUNTIME:?}"
rubble-exec mkdir -p -- "${RUBBLE_RELEASE_DIR:?}/assets"

root_brick_out="$("$rubble" -q shell -- -eu -c 'source <($RUBBLE_EXECUTABLE -q list --depth 1 --format bash "${1:?root brick}"); echo "${brick_inventory[${brick_inventory[::root]}:out]}"' -s "${RUBBLE_ROOT_BRICK}")" || true
if [ "$root_brick_out" = */out-*-rubble-inventory-bundle-import ] && [ -f "$root_brick_out" ]; then
  rubble_inventory_bundle_import_full_id="${root_brick_out#*/out-}"
  cp -v "$root_brick_out" "${RUBBLE_RELEASE_DIR}/assets/${rubble_inventory_bundle_import_full_id:0:7}-rubble-inventory-bundle-import.sh"
else
  "${rubble}" -q script --inherit-env rubble-inventory-bundle export \
    --output "${RUBBLE_RELEASE_DIR}/assets/${RUBBLE_ROOT_ID:0:7}-${RUBBLE_ROOT_NAME}.tar" \
    --depth 1 "${RUBBLE_ROOT_BRICK}"
fi
