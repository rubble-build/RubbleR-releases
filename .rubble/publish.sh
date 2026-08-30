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
repo_user_publish_script="${target_prefix}.rubble/publish.sh"
managed_output_paths=()
for ((index = 0; index < RUBBLE_PUBLISH_OUTPUT_COUNT; index++)); do
  managed_output_variable="RUBBLE_PUBLISH_OUTPUT_${index}"
  managed_output_paths+=("${target_prefix}${!managed_output_variable}")
done
[[ "${#managed_output_paths[@]}" -gt 0 ]] || fail "publisher plan contains no managed outputs"

status_pathspecs=(.)
for managed_output_path in "${managed_output_paths[@]}"; do
  status_pathspecs+=(":(exclude,literal)${managed_output_path}")
done
status_pathspecs+=(":(exclude,literal)${repo_user_publish_script}")
unrelated="$(git -C "${repo_root}" status --porcelain --untracked-files=all -- "${status_pathspecs[@]}")"
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
managed_output_pathspecs=()
for managed_output_path in "${managed_output_paths[@]}"; do
  managed_output_pathspecs+=(":(literal)${managed_output_path}")
done
git -C "${repo_root}" add -- "${managed_output_pathspecs[@]}"
git -C "${repo_root}" commit -m "Run Rubble workflow for ${RUBBLE_PUBLISH_ROOT_ID}"
git -C "${repo_root}" push origin "HEAD:refs/heads/${branch}"
commit="$(git -C "${repo_root}" rev-parse HEAD)"
origin_url="$(git -C "${repo_root}" remote get-url origin)"
repository="${RUBBLE_PUBLISH_GITHUB_REPOSITORY:-$(gh repo view "${origin_url}" --json nameWithOwner --jq .nameWithOwner)}"

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
