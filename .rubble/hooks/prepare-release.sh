#!/usr/bin/env bash
# Supply release data here. Optional metadata files: title, tag, notes.md.
set -euo pipefail
source "${RUBBLE_CI_RUNTIME:?}"
rubble-exec mkdir -pv -- "${RUBBLE_RELEASE_DIR:?}/assets"

source <($RUBBLE_EXECUTABLE -q list --depth 1 --format bash "${rubble_root_bricks[@]}")
declare -p brick_inventory >&2

for root_id in "${rubble_roots[@]}"; do
  if [[ "${brick_inventory[${root_id}::short-id]}" = ???????-rubble-inventory-bundle-import ]]; then
    rubble-exec cp -v "${brick_inventory[${root_id}:out]}" "${RUBBLE_RELEASE_DIR}/assets/${brick_inventory[${root_id}::platform]}-${brick_inventory[${root_id}::short-id]}.sh"
    continue
  fi
  asset_name="${rubble_root_short_ids[$root_id]}.tar"
  if [[ -n "${rubble_root_platforms[$root_id]}" ]]; then
    asset_name="${rubble_root_platforms[$root_id]}-${asset_name}"
  fi
  "${rubble}" script --inherit-env rubble-inventory-bundle export \
    --output "${RUBBLE_RELEASE_DIR}/assets/${asset_name}" \
    --depth 1 "${rubble_root_bricks[$root_id]}"

  if [[ "${brick_inventory[${root_id}::short-id]}" = ???????-rubble ]]; then
    echo '#!/bin/sh'
    echo "RUBBLE_INSTALL_VERSION=${brick_inventory[${root_id}::short-id]}"
    rubble-exec sed 1d "${brick_inventory[${root_id}:scripts]}/install.sh"
  fi > "${RUBBLE_RELEASE_DIR}/assets/install-${rubble_root_short_ids[$root_id]}.sh"
done

cd "${RUBBLE_RELEASE_DIR}/assets"
for file in *; do
  [[ "$file" = *.SHA256 ]] && continue
  [[ -f "${file}.SHA256" ]] && continue
  rubble-exec sha256sum "$file" > "${file}.SHA256"
done
