#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

fail() {
  printf '[rubble-publish] ERROR: %s\n' "$1" >&2
  exit 1
}

source <("${RUBBLE_PUBLISH_SCRIPT}" local-plan)
repo_root="$(git -C "${RUBBLE_PUBLISH_TARGET_ROOT}" rev-parse --show-toplevel)"
target_prefix="$(git -C "${RUBBLE_PUBLISH_TARGET_ROOT}" rev-parse --show-prefix)"
base_branch="$(git -C "${repo_root}" branch --show-current)"
[[ -n "${base_branch}" ]] || fail "publishing requires a named base branch"
repo_workflow_path="${target_prefix}${RUBBLE_PUBLISH_WORKFLOW_PATH}"
repo_generated_root="${target_prefix}${RUBBLE_PUBLISH_GENERATED_ROOT}"

unrelated="$(git -C "${repo_root}" status --porcelain --untracked-files=all -- . \
  ":(exclude)${repo_workflow_path}" \
  ":(exclude)${repo_generated_root}" \
  ":(exclude)${repo_generated_root}/**")"
[[ -z "${unrelated}" ]] || fail "repository has unrelated changes; commit or remove them before publishing"

branch="${RUBBLE_PUBLISH_SUGGESTED_BRANCH}"
suffix=1
while git -C "${repo_root}" show-ref --verify --quiet "refs/heads/${branch}" || \
      git -C "${repo_root}" ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; do
  branch="${RUBBLE_PUBLISH_SUGGESTED_BRANCH}-${suffix}"
  suffix=$((suffix + 1))
done

git -C "${repo_root}" switch -c "${branch}" "${base_branch}"
restore_base() {
  git -C "${repo_root}" switch "${base_branch}" >/dev/null 2>&1 || true
}
trap restore_base EXIT
git -C "${repo_root}" add -- "${repo_workflow_path}" "${repo_generated_root}"
git -C "${repo_root}" commit -m "Run Rubble workflow for ${RUBBLE_PUBLISH_ROOT_ID}"
git -C "${repo_root}" push origin "HEAD:refs/heads/${branch}"
commit="$(git -C "${repo_root}" rev-parse HEAD)"
repository="${RUBBLE_PUBLISH_GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

set +e
"${RUBBLE_PUBLISH_SCRIPT}" wait-run \
  --repo "${repository}" \
  --branch "${branch}" \
  --commit "${commit}"
status=$?
set -e
restore_base
trap - EXIT
exit "${status}"
