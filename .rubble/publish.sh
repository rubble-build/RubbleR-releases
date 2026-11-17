#!/usr/bin/env bash
# User-owned publication policy. Generation installs this file only when missing.
# Edit the branch, commit message, Git commands, authorization and waiting below.
set -euo pipefail
source "${RUBBLE_PUBLISH_LIBRARY:?}" \
    "${RUBBLE_EXECUTABLE:?}" "${RUBBLE_PUBLISH_TARGET_ROOT:?}" \
    "${RUBBLE_CONFIG:-}" "${RUBBLE_CREDENTIALS:-}"

# Helpers receive CONFIG first; cleanup takes STATUS, CONFIG, RESOURCES, --, COMMAND.
# CONFIG and RESOURCES are associative-array names; PATH_OUTPUT is an array name.
# check_identity CONFIG reads one-use state without reserving or consuming it.
# prepare CONFIG RESOURCES PATH_OUTPUT BRANCH MANAGED_PATHS...
# trigger CONFIG RESOURCES RUN_OUTPUT BRANCH COMMIT
# find_run CONFIG BRANCH COMMIT RUN_HINT prints a URL; wait CONFIG URL observes it.
# Source alone does not publish. local-files defaults to waiting: removing wait
# also requires arranging remote-key cleanup before changing the exit cleanup.
# Resource/path/run outputs are caller-owned variables passed by name.
# Git commands below run in config[repository], with its tools/authentication.
# find_run returns a URL; wait accepts that URL and does not use a current-run global.
# Optional native service selection is explicit at this call site.
rubble_publish_config[github_repository]="${RUBBLE_PUBLISH_GITHUB_REPOSITORY:-}"
rubble_publish_config[github_host]="${GH_HOST:-github.com}"
rubble_publish_config[gitlab_project]="${RUBBLE_PUBLISH_GITLAB_PROJECT:-}"
if [[ "${rubble_publish_config[adapter]}" == jenkins ]]; then
    rubble_publish_config[jenkins_url]="${RUBBLE_BUILD_BUILDER_JENKINS_URL:-${rubble_publish_config[jenkins_url]}}"
    rubble_publish_config[jenkins_user]="${RUBBLE_BUILD_BUILDER_JENKINS_USER:-${rubble_publish_config[jenkins_user]}}"
    rubble_publish_config[jenkins_token_file]="${RUBBLE_BUILD_BUILDER_JENKINS_TOKEN_FILE:-${rubble_publish_config[jenkins_token_file]}}"
    rubble_publish_config[wait]="${RUBBLE_BUILD_BUILDER_JENKINS_WAIT:-${rubble_publish_config[wait]}}"
    rubble_publish_config[queue_timeout]="${RUBBLE_BUILD_BUILDER_JENKINS_QUEUE_TIMEOUT_SECONDS:-${rubble_publish_config[queue_timeout]}}"
    rubble_publish_config[build_timeout]="${RUBBLE_BUILD_BUILDER_JENKINS_BUILD_TIMEOUT_SECONDS:-${rubble_publish_config[build_timeout]}}"
fi
rubble="${rubble_publish_config[rubble]}"
remote_store="${rubble_publish_config[remote_store]}"

# First, upload locally available Bricks. Ordinary failures warn and continue.
for root in "${rubble_roots[@]}"; do
    if "$rubble" push --depth 0 --expand-opaque \
        -r "$remote_store" "${rubble_root_bricks[$root]}"; then
        printf '[publish] Uploaded %s\n' "$root" >&2
    else
        status=$?
        if [[ "$status" -eq 130 ]]; then
            exit "$status"
        fi
        printf '[publish] WARNING: upload failed for %s (exit %s); continuing\n' \
            "$root" "$status" >&2
    fi
done

branch="${rubble_publish_config[suggested_branch]}"
declare -A publication_resources=()
declare -a publish_paths=()
run_hint=''

rubble_publish_check_worktree rubble_publish_config "${rubble_managed_paths[@]}"
rubble_publish_check_identity rubble_publish_config

# Only the default policy interprets its two known return-argument forms.
# Return 0 for a matching checkout, 1 for a mismatch, or 2 if queries fail.
_rubble_publish_returned() {
    local current_branch query_status current_commit
    if current_branch="$(rubble_git rubble_publish_config symbolic-ref --quiet HEAD)"; then
        [[ "${rubble_publish_return_args[0]}" == -- ]] || return 1
        [[ "$current_branch" == "refs/heads/${rubble_publish_return_args[1]}" ]]
    else
        query_status=$?
        [[ "$query_status" -eq 1 ]] || return 2
        [[ "${rubble_publish_return_args[0]}" == --detach ]] || return 1
        current_commit="$(rubble_git rubble_publish_config rev-parse --verify HEAD)" || return 2
        [[ "$current_commit" == "${rubble_publish_return_args[2]}" ]]
    fi
}

# On exit, clean this publication's resources, then attempt to return the checkout.
# The library preserves an earlier failure and does not install its own trap.
trap '
    status=$?
    if rubble_publish_cleanup "$status" rubble_publish_config publication_resources -- \
        rubble_git rubble_publish_config switch "${rubble_publish_return_args[@]}"; then
        exit 0
    else
        status=$?
        printf "[publish] Inspect: git -C %q status\n" "${rubble_publish_config[repository]}" >&2
        printf "[publish] Inspect: git -C %q diff\n" "${rubble_publish_config[repository]}" >&2
        printf "[publish] Inspect staged changes: git -C %q diff --cached\n" "${rubble_publish_config[repository]}" >&2
        if _rubble_publish_returned; then
            :
        else
            return_state=$?
            if [[ "$return_state" -eq 1 ]]; then
                printf "[publish] Return manually: git -C %q switch" "${rubble_publish_config[repository]}" >&2
            else
                printf "[publish] If the checkout still needs to be returned: git -C %q switch" "${rubble_publish_config[repository]}" >&2
            fi
            printf " %q" "${rubble_publish_return_args[@]}" >&2
            printf "\n" >&2
        fi
        exit "$status"
    fi
' EXIT

# Prepare a branch and this publication's resources.
# Branch naming and cleanup are yours; a failed run can leave this name in use.
# Inspect branches and uncommitted changes before resolving a conflict.
# Removing a branch does not reset a consumed identity or restore a local-files key.
# If the identity is consumed or the key is lost, generate a new pipeline.
# See docs/remote-builders.md, "Branch conflicts and recovery".
rubble_git rubble_publish_config switch -c "$branch"
RUBBLE_BUILD_BUILDER_JENKINS_TOKEN="${RUBBLE_BUILD_BUILDER_JENKINS_TOKEN:-}" \
RUBBLE_PIPELINE_AUTH_KEY="${RUBBLE_PIPELINE_AUTH_KEY:-}" \
    rubble_publish_prepare rubble_publish_config publication_resources publish_paths \
    "$branch" "${rubble_managed_paths[@]}"

# Commit and push. Add any business authorization immediately before the push.
rubble_git rubble_publish_config add -A -- "${publish_paths[@]}"
rubble_git rubble_publish_config commit --allow-empty \
    -m "${rubble_publish_config[commit_message]}"
commit="$(rubble_git rubble_publish_config rev-parse HEAD)"
rubble_git rubble_publish_config push "${rubble_publish_push_options[@]}" \
    origin "HEAD:refs/heads/$branch"
RUBBLE_BUILD_BUILDER_JENKINS_TOKEN="${RUBBLE_BUILD_BUILDER_JENKINS_TOKEN:-}" \
RUBBLE_PIPELINE_AUTH_KEY="${RUBBLE_PIPELINE_AUTH_KEY:-}" \
    rubble_publish_trigger rubble_publish_config publication_resources run_hint "$branch" "$commit"
unset RUBBLE_PIPELINE_AUTH_KEY

# Waiting is this script's choice. Users may instead find/print a URL and exit.
if [[ "${rubble_publish_config[wait]}" == true ]]; then
    run_url="$(RUBBLE_BUILD_BUILDER_JENKINS_TOKEN="${RUBBLE_BUILD_BUILDER_JENKINS_TOKEN:-}" \
        rubble_publish_find_run rubble_publish_config "$branch" "$commit" "$run_hint")"
    printf '%s\n' "$run_url"
    RUBBLE_BUILD_BUILDER_JENKINS_TOKEN="${RUBBLE_BUILD_BUILDER_JENKINS_TOKEN:-}" \
        rubble_publish_wait rubble_publish_config "$run_url"
fi
