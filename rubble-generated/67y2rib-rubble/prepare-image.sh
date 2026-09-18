#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log() {
  printf '[github-actions-image] %s\n' "$1" >&2
}

fail() {
  log "ERROR: $1"
  exit 1
}

download_file() {
  local description="$1"
  local source_url="$2"
  local destination="$3"
  local partial="${destination}.part"
  local attempt=1
  local max_attempts=6
  local retry_delay=1

  rm -f -- "${destination}" "${partial}"
  while ((attempt <= max_attempts)); do
    log "downloading ${description} (attempt ${attempt}/${max_attempts})"
    if curl --fail --location --output "${partial}" "${source_url}"; then
      mv -- "${partial}" "${destination}"
      log "downloaded ${description}"
      return 0
    fi

    rm -f -- "${partial}"
    if ((attempt >= max_attempts)); then
      fail "failed to download ${description} after ${max_attempts} attempts"
    fi
    log "download of ${description} failed on attempt ${attempt}; retrying in ${retry_delay}s"
    sleep "${retry_delay}"
    attempt=$((attempt + 1))
    retry_delay=$((retry_delay * 2))
  done
}

[[ "${RUNNER_OS:?}" == Linux && "${RUNNER_ARCH:?}" == "${RUBBLE_EXPECTED_RUNNER_ARCH:?}" ]] || \
  fail "runner platform does not match the configured Rubble image"
dockerfile="${1:?Dockerfile is required}"
install_script="${2:?image installation script is required}"
image_repository="${RUBBLE_IMAGE_REPOSITORY:-ghcr.io/${GITHUB_REPOSITORY:?}/rubble}"
image_repository="${image_repository,,}"
image="${image_repository}:${RUBBLE_IMAGE_TAG:?}"
image_work="$(mktemp -d "${RUNNER_TEMP:?}/rubble-image.XXXXXXXX")"
trap 'rm -rf -- "${image_work}"' EXIT
export DOCKER_CONFIG="${image_work}/docker-config"
mkdir -p "${DOCKER_CONFIG}"
printf '%s' "${GHCR_TOKEN:?}" | docker login ghcr.io --username "${GITHUB_ACTOR:?}" --password-stdin
unset GHCR_TOKEN

if docker manifest inspect "${image}" > /dev/null 2>"${image_work}/manifest.stderr"; then
  log "reusing image ${image}"
else
  manifest_error="$(cat "${image_work}/manifest.stderr")"
  case "${manifest_error,,}" in
    *"manifest unknown"*|*"no such manifest"*|*"manifest not found"*) ;;
    *) cat "${image_work}/manifest.stderr" >&2; fail "failed to query image ${image}" ;;
  esac
  log "building missing image ${image}"
  context="${image_work}/context"
  mkdir -p "${context}/bootstrap"
  cp -- "${dockerfile}" "${context}/Dockerfile"
  cp -- "${install_script}" "${context}/bootstrap/install-image.sh"
  download_file "Rubble bundle" "${RUBBLE_BUNDLE_URL:?}" "${context}/bootstrap/rubble.tar"
  download_file "Rubble importer" "${RUBBLE_IMPORTER_URL:?}" "${context}/bootstrap/importer"
  docker build --build-arg "RUBBLE_BASE_IMAGE=${RUBBLE_BASE_IMAGE:?}" \
    --label "org.opencontainers.image.source=https://github.com/${GITHUB_REPOSITORY:?}" \
    --tag "${image}" "${context}"
  docker run --rm --entrypoint /usr/bin/rubble "${image}" --version
  docker run --rm --entrypoint /usr/bin/rubble-web "${image}" --help
  docker push "${image}"
fi
printf 'image=%s\n' "${image}" >> "${GITHUB_OUTPUT:?}"