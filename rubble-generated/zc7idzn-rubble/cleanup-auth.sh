#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log() {
  printf '[github-actions-auth-cleanup] %s\n' "$1" >&2
}

runner_temp="${RUNNER_TEMP:?RUNNER_TEMP is required}"
auth_dir="${runner_temp}/rubble-pipeline-auth"
config_file="${auth_dir}/config.yaml"
credentials_file="${auth_dir}/credentials.yaml"

rm -f -- "${config_file}" "${credentials_file}"
if rmdir -- "${auth_dir}" 2>/dev/null; then
  log "removed one-use plaintext authentication files"
else
  log "one-use plaintext authentication files are absent or their directory is not empty"
fi
