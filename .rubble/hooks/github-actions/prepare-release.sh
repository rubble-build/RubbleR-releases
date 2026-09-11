#!/usr/bin/env bash
# Supply release data here. Optional metadata files: title, tag, notes.md.
set -euo pipefail
source "${RUBBLE_GITHUB_ACTIONS_RUNTIME:?}"

rubble-exec mkdir -pv -- "${RUBBLE_RELEASE_DIR:?}/assets"
source <($RUBBLE_EXECUTABLE -q list --depth 1 --format bash "${RUBBLE_ROOT_BRICK}")

brick_name="${brick_inventory[::root]}"

echo "$(rubble-exec date '+%Y%m%d%H%M%S'): ${brick_inventory[${brick_name}::platform]:-}${brick_inventory[${brick_name}::platform]:+-}${brick_inventory[${brick_name}::short-id]}" > "${RUBBLE_RELEASE_DIR}/title"
echo "Rubble inventory bundle for ${brick_inventory[${brick_name}::platform]:-}${brick_inventory[${brick_name}::platform]:+ }${brick_name}" > "${RUBBLE_RELEASE_DIR}/notes.md"

if [[ "${brick_inventory[::root]}" = *-rubble-inventory-bundle-import ]]; then
  rubble-exec cp -v "${brick_inventory[${brick_name}:out]}" "${RUBBLE_RELEASE_DIR}/assets/${brick_inventory[${brick_name}::platform]}-${brick_inventory[${brick_name}::short-id]}.sh"
else
  "${rubble}" -q script --inherit-env rubble-inventory-bundle export \
    --output "${RUBBLE_RELEASE_DIR}/assets/${brick_inventory[${brick_name}::platform]:-}${brick_inventory[${brick_name}::platform]:+-}${brick_inventory[${brick_name}::short-id]}.tar" \
    --depth 1 "${RUBBLE_ROOT_BRICK}"
fi

cd "${RUBBLE_RELEASE_DIR}/assets"
for file in *; do
  [[ "$file" = *.SHA256 ]] && continue
  [[ -f "${file}.SHA256" ]] && continue
  rubble-exec sha256sum "$file" > "${file}.SHA256"
done
