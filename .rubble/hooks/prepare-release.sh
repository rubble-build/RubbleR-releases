#!/usr/bin/env bash
# Supply release data here. Optional metadata files: title, tag, notes.md.
set -euo pipefail
source "${RUBBLE_CI_RUNTIME:?}"
rubble-exec mkdir -p -- "${RUBBLE_RELEASE_DIR:?}/assets"
for root_id in "${rubble_roots[@]}"; do
  "${rubble}" script --inherit-env rubble-inventory-bundle export \
    --output "${RUBBLE_RELEASE_DIR}/assets/${rubble_root_short_ids[$root_id]}.tar" \
    --depth 1 "${rubble_root_bricks[$root_id]}"
done
