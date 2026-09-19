#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[github-actions-image] ERROR: %s\n' "$1" >&2
  exit 1
}

bundle=/rubble-bootstrap/rubble.tar
manifest="$(tar -xOf "${bundle}" manifest.rbm)"
root_short="$(awk -F '\t' '$1 == "root" { print $2; exit }' <<<"${manifest}")"
root_full="$(awk -F '\t' -v root="${root_short}" '$1 == "brick" && $3 == root { print $4; exit }' <<<"${manifest}")"
[[ -n "${root_short}" && -n "${root_full}" ]] || fail "Rubble bundle manifest has no resolvable root"
root_hash="${root_full%%-*}"
[[ "${#root_hash}" -eq 52 ]] || fail "Rubble bundle root has an invalid hash: ${root_full}"
rubble="/var/lib/rubble/store/${root_hash:0:2}/${root_hash:2:2}/out-${root_full}"
RUBBLE_HOME=/var/lib/rubble \
RUBBLE_RUNTIME_HOME=/var/lib/rubble \
RUBBLE_INVENTORY_BUNDLE_USE_ORIGINAL=1 \
  /bin/sh /rubble-bootstrap/importer import "${bundle}"
web="/var/lib/rubble/store/${root_hash:0:2}/${root_hash:2:2}/web-${root_full}"
[[ -x "${rubble}" && -x "${web}" ]] || fail "Rubble bundle must provide executable out and web outputs"
ln -sf -- "${rubble}" /usr/bin/rubble
ln -sf -- "${web}" /usr/bin/rubble-web