#!/usr/bin/env bash
# User-owned release publication. Data is in RUBBLE_RELEASE_DIR; keep reusable logic here.
set -euo pipefail
source "${RUBBLE_CI_RUNTIME:?}"
case "${RUBBLE_CI_BUILDER}" in
  github-actions)
    export RUBBLE_GITHUB_CLI="${rubble_runner_commands[gh]:?runner gh command is required}"
    "${rubble}" script --inherit-env "${RUBBLE_RELEASE_PUBLISHER:?}"
    rubble_run_hook post-release
    ;;
  jenkins)
    # Publish files from "$RUBBLE_RELEASE_DIR/assets" to your release service here.
    # Once publication succeeds, call: rubble_run_hook post-release
    ;;
esac
