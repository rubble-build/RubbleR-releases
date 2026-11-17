#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

auth_dir="${1:?authentication directory is required}"
rm -f -- "${auth_dir}/config.yaml" "${auth_dir}/credentials.yaml"
if rmdir -- "${auth_dir}" 2>/dev/null; then
  printf '[builder-auth] removed temporary authentication files\n' >&2
fi
