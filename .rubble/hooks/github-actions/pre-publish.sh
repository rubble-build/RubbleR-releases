#!/usr/bin/env bash
# Optional local cache seed. Customize the store/authentication here when local and CI stores differ.
set -euo pipefail
if "${rubble:?}" push --depth 0 --expand-opaque -r "${RUBBLE_REMOTE_STORE:?}" "${RUBBLE_ROOT_BRICK:?}"; then
  printf '[github-actions] seeded remote store %s\n' "${RUBBLE_REMOTE_STORE}" >&2
else
  status=$?
  printf '[github-actions] WARNING: local remote-store seed failed with status %s; continuing publication\n' "${status}" >&2
fi
