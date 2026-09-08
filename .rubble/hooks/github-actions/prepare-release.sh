#!/usr/bin/env bash
# Supply release data here. Optional metadata files: title, tag, notes.md.
set -euo pipefail
source "${RUBBLE_GITHUB_ACTIONS_RUNTIME:?}"
rubble-exec mkdir -p -- "${RUBBLE_RELEASE_DIR:?}/assets"
"${rubble}" -q script --inherit-env rubble-inventory-bundle export \
  --output "${RUBBLE_RELEASE_DIR}/assets/${RUBBLE_ROOT_ID:0:7}-${RUBBLE_ROOT_NAME}.tar" \
  --depth 1 --inventory-file "${RUBBLE_RELEASE_INVENTORY}" "${RUBBLE_ROOT_BRICK}"
