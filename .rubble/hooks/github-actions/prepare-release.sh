#!/usr/bin/env bash
# Supply release data here. Optional metadata files: title, tag, notes.md.
set -xeuo pipefail
source "${RUBBLE_GITHUB_ACTIONS_RUNTIME:?}"
rubble-exec mkdir -p -- "${RUBBLE_RELEASE_DIR:?}/assets"
source <($RUBBLE_EXECUTABLE -q list --depth 1 --format bash "${RUBBLE_ROOT_BRICK}")

if [[ "${brick_inventory[::root]}" = *-rubble-inventory-bundle-import ]]; then
  cp -v "${brick_inventory[${brick_inventory[::root]}:out]}" "${RUBBLE_RELEASE_DIR}/assets/${brick_inventory[::root]}.sh"
else
  "${rubble}" -q script --inherit-env rubble-inventory-bundle export \
    --output "${RUBBLE_RELEASE_DIR}/assets/${RUBBLE_ROOT_ID:0:7}-${RUBBLE_ROOT_NAME}.tar" \
    --depth 1 "${RUBBLE_ROOT_BRICK}"
fi

cd "${RUBBLE_RELEASE_DIR}/assets"
for file in *; do
  [[ "$file" = *.SHA256 ]] && continue
  [[ -f "${file}.SHA256" ]] && continue
  rubble-exec sha256sum "$file" > "${file}.SHA256"
done
