#!/usr/bin/env bash
# Optional local cache seed. Customize the store/authentication here when local and CI stores differ.
set -euo pipefail
source "${RUBBLE_CI_RUNTIME:?}"
for root in "${rubble_roots[@]}"; do
if "${rubble:?}" push --depth 0 --expand-opaque -r "${RUBBLE_REMOTE_STORE:?}" "${rubble_root_bricks[${root}]}"; then
  printf '[remote] seeded remote store %s\n' "${RUBBLE_REMOTE_STORE}" >&2
else
  status=$?
  # Cancellation is never a best-effort upload failure.
  [[ "${status}" -ne 130 ]] || exit "${status}"
  printf '[remote] WARNING: local remote-store seed failed with status %s; continuing publication\n' "${status}" >&2
fi
done
