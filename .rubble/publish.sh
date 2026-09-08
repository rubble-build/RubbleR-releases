#!/usr/bin/env bash
# User-owned entry. Empty this file to disable publication; delete it to restore the default.
set -euo pipefail
exec "${rubble:?}" -q script --inherit-env --language bash "${RUBBLE_PUBLISH_SCRIPT:?}" default-publish
