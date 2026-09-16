# syntax=docker/dockerfile:1
ARG RUBBLE_BASE_IMAGE
FROM ${RUBBLE_BASE_IMAGE}
USER root
SHELL ["/bin/sh", "-c"]
RUN --mount=type=bind,source=bootstrap,target=/rubble-bootstrap <<'INSTALL'
set -eu
prerequisites_ready=true
for tool in bash curl tar awk readlink git gh; do
    command -v "$tool" >/dev/null 2>&1 || prerequisites_ready=false
done
if [ "$prerequisites_ready" = true ]; then
    printf '[github-actions-image] using preinstalled prerequisites\n'
elif command -v apk >/dev/null 2>&1; then
    printf '[github-actions-image] installing prerequisites with apk\n'
    apk add --no-cache bash ca-certificates coreutils curl gawk git github-cli libstdc++ tar
elif command -v apt-get >/dev/null 2>&1; then
    printf '[github-actions-image] installing prerequisites with apt-get\n'
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash ca-certificates coreutils curl gawk git gh libstdc++6 tar
    rm -rf /var/lib/apt/lists/*
elif command -v dnf >/dev/null 2>&1; then
    printf '[github-actions-image] installing prerequisites with dnf\n'
    set -- bash ca-certificates gawk git gh libstdc++ tar
    # Keep working minimal variants already supplied by RPM base images.
    command -v curl >/dev/null 2>&1 || set -- "$@" curl
    command -v readlink >/dev/null 2>&1 || set -- "$@" coreutils
    dnf install -y --setopt=install_weak_deps=False "$@"
    dnf clean all
else
    printf '[github-actions-image] no supported package manager; base must supply prerequisites\n'
fi
bash /rubble-bootstrap/install-image.sh
INSTALL
ENTRYPOINT []
