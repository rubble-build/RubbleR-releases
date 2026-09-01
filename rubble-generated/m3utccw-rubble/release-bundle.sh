#!/usr/bin/env bash
RUBBLE_PUBLISHED_SCRIPT=0 # RUBBLE_PUBLISHED_SCRIPT_PLACEHOLDER
RUBBLE_PUBLISHED_EXECUTABLE='' # RUBBLE_PUBLISHED_EXECUTABLE_PLACEHOLDER

if [[ "$-" == *x* ]]; then
  # Preserve caller stderr for xtrace before private diagnostic redirects.
  exec 8>&2
  BASH_XTRACEFD=8
fi

set -euo pipefail
IFS=$'\n\t'

readonly BUNDLE_VERSION=1
readonly BUNDLE_MANIFEST='manifest.rbm'
readonly BUNDLE_MAX_USTAR_MEMBER_SIZE=8589934591
readonly BUNDLE_IMPORT_ONLY=0
declare -ag BUNDLE_CLEANUP_DIRS=()
declare -ag BUNDLE_BRICK_SHORT_IDS=()
declare -ag BUNDLE_BRICK_FULL_IDS=()
declare -ag BUNDLE_BRICK_HOME_MODES=()
declare -ag BUNDLE_BRICK_HOMES=()
declare -ag BUNDLE_BRICK_OPAQUE=()
declare -ag BUNDLE_BRICK_PATHS=()
declare -ag BUNDLE_OUTPUT_BRICK_ORDINALS=()
declare -ag BUNDLE_OUTPUT_ORDINALS=()
declare -ag BUNDLE_OUTPUT_NAMES=()
declare -ag BUNDLE_OUTPUT_PATHS=()
declare -ag BUNDLE_ARTIFACT_KINDS=()
declare -ag BUNDLE_ARTIFACT_BRICK_ORDINALS=()
declare -ag BUNDLE_ARTIFACT_OUTPUT_ORDINALS=()
declare -ag BUNDLE_ARTIFACT_MEMBERS=()
declare -ag BUNDLE_ARTIFACT_SIZES=()
declare -ag BUNDLE_ARTIFACT_DIGESTS=()
declare -ag BUNDLE_ARTIFACT_PATHS=()
declare -ag BUNDLE_BRICK_TARGET_PATHS=()
declare -ag BUNDLE_BRICK_INSTALL=()
declare -ag BUNDLE_OUTPUT_TARGET_PATHS=()
declare -ag BUNDLE_OUTPUT_SKIP=()
declare -ag BUNDLE_OUTPUT_RBL_INSTALL=()
declare -ag BUNDLE_TAR_MEMBERS=()
declare -ag BUNDLE_ROLLBACK_FILES=()
declare -ag BUNDLE_ROLLBACK_OUTPUTS=()
declare -ag BUNDLE_EXPORT_INVENTORY_IDS=()
declare -Ag BUNDLE_EXPORT_INVENTORY_SET=()
BUNDLE_CHECKSUM_RECORD_PATH=''
BUNDLE_IMPORT_ACTIVE=0
BUNDLE_IMPORT_COMMITTED=0
BUNDLE_EXPORT_INVENTORY_FILE=''
BUNDLE_EXPORT_INVENTORY_ACTIVE=0

if [[ ! -v RUBBLE_EXECUTABLE && -n $RUBBLE_PUBLISHED_EXECUTABLE ]]; then
  RUBBLE_EXECUTABLE=$RUBBLE_PUBLISHED_EXECUTABLE
  export RUBBLE_EXECUTABLE
fi

bundle_usage() {
  local invocation
  local managed_help=false
  if [[ ${RUBBLE_SCRIPT_MANAGED:-0} == 1 || $RUBBLE_PUBLISHED_SCRIPT == 1 ]]; then
    invocation='rubble script rubble-inventory-bundle'
    managed_help=true
  else
    invocation='RUBBLE_EXECUTABLE=/absolute/path/to/rubble scripts/rubble-inventory-bundle.sh'
  fi
  builtin printf '%s\n' \
    'Usage:' \
    "  $invocation export --output FILE [--depth N] [--inventory-file FILE] [BRICK]" \
    "  $invocation import FILE" \
    '' \
    'Exports or imports one uncompressed, versioned inventory bundle.' \
    'BRICK defaults to ./ and N defaults to 1; depth 0 means unlimited.' \
    'An inventory file narrows that traversal to the listed full Brick IDs.' \
    '' \
    'Environment:'
  if [[ $managed_help == false ]]; then
    builtin printf '%s\n' \
      '  RUBBLE_EXECUTABLE' \
      '    Absolute Rubble executable used for inventory and managed tools.' \
      '    Published copies default to the Rubble that built them; an explicit' \
      '    value overrides that default. Repository execution requires a value.'
  fi
  builtin printf '%s\n' \
    '  RUBBLE_INVENTORY_BUNDLE_USE_ORIGINAL' \
    '    Set to 1 to skip the private import snapshot. Default: 0.' \
    '  TMPDIR' \
    '    Parent for private staging directories. Default: /tmp.'
}

bundle_log() {
  local level="$1"
  shift
  builtin printf '[%s] [inventory_bundle] %s\n' "$level" "$*" >&2
}

bundle_fail() {
  bundle_log ERROR "$*"
  exit 1
}

bundle_require_bash() {
  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
    return 0
  fi
  bundle_fail "Bash 4.4 or newer is required"
}

bundle_parse_depth() {
  local value="$1"
  if [[ ! "$value" =~ ^(0|[1-9][0-9]*)$ ]]; then
    bundle_fail "invalid depth '$value': expected an integer from 0 through 255"
  fi
  if ((${#value} > 3)); then
    bundle_fail "invalid depth '$value': expected an integer from 0 through 255"
  fi
  if ((10#$value > 255)); then
    bundle_fail "invalid depth '$value': expected an integer from 0 through 255"
  fi
  builtin printf '%s\n' "$value"
}

bundle_parse_export_args() {
  BUNDLE_EXPORT_OUTPUT=''
  BUNDLE_EXPORT_DEPTH=1
  BUNDLE_EXPORT_BRICK='./'
  local positional_seen=0

  while (($# > 0)); do
    case "$1" in
      --output)
        (($# >= 2)) || bundle_fail "--output requires a path"
        BUNDLE_EXPORT_OUTPUT="$2"
        shift 2
        ;;
      --output=*)
        BUNDLE_EXPORT_OUTPUT="${1#--output=}"
        shift
        ;;
      --depth)
        (($# >= 2)) || bundle_fail "--depth requires a value"
        BUNDLE_EXPORT_DEPTH="$(bundle_parse_depth "$2")"
        shift 2
        ;;
      --depth=*)
        BUNDLE_EXPORT_DEPTH="$(bundle_parse_depth "${1#--depth=}")"
        shift
        ;;
      --inventory-file)
        (($# >= 2)) || bundle_fail "--inventory-file requires a path"
        BUNDLE_EXPORT_INVENTORY_FILE="$2"
        shift 2
        ;;
      --inventory-file=*)
        BUNDLE_EXPORT_INVENTORY_FILE="${1#--inventory-file=}"
        shift
        ;;
      --)
        shift
        if (($# > 1)); then
          bundle_fail "export accepts at most one BRICK argument"
        fi
        if (($# == 1)); then
          if ((positional_seen != 0)); then
            bundle_fail "export accepts at most one BRICK argument"
          fi
          BUNDLE_EXPORT_BRICK="$1"
          positional_seen=1
          shift
        fi
        ;;
      -*)
        bundle_fail "unknown export option '$1'"
        ;;
      *)
        if ((positional_seen != 0)); then
          bundle_fail "export accepts at most one BRICK argument"
        fi
        BUNDLE_EXPORT_BRICK="$1"
        positional_seen=1
        shift
        ;;
    esac
  done

  [[ -n "$BUNDLE_EXPORT_OUTPUT" ]] || bundle_fail "export requires --output FILE"
}

bundle_load_export_inventory() {
  local path="$1"
  BUNDLE_EXPORT_INVENTORY_IDS=()
  BUNDLE_EXPORT_INVENTORY_SET=()
  BUNDLE_EXPORT_INVENTORY_ACTIVE=0
  [[ -n "$path" ]] || return 0
  bundle_has_control_text "$path" &&
    bundle_fail "inventory file path contains unsupported control characters"
  [[ -f "$path" && ! -L "$path" ]] ||
    bundle_fail "inventory file is missing or not a regular file: $path"

  local fd line=''
  exec {fd}<"$path" || bundle_fail "failed to read inventory file: $path"
  while IFS= builtin read -r line <&${fd}; do
    bundle_safe_full_id "$line" ||
      bundle_fail "inventory file contains an invalid full Brick ID"
    [[ ! ${BUNDLE_EXPORT_INVENTORY_SET[$line]+present} ]] ||
      bundle_fail "inventory file contains a duplicate full Brick ID: $line"
    BUNDLE_EXPORT_INVENTORY_IDS+=("$line")
    BUNDLE_EXPORT_INVENTORY_SET["$line"]=1
  done
  [[ -z "$line" ]] || bundle_fail "inventory file is not newline-terminated: $path"
  exec {fd}<&- || bundle_fail "failed to close inventory file: $path"
  ((${#BUNDLE_EXPORT_INVENTORY_IDS[@]} > 0)) ||
    bundle_fail "inventory file is empty: $path"
  BUNDLE_EXPORT_INVENTORY_ACTIVE=1
  bundle_log DEBUG "loaded exact export inventory: path=$path bricks=${#BUNDLE_EXPORT_INVENTORY_IDS[@]}"
}

bundle_parse_import_args() {
  BUNDLE_IMPORT_INPUT=''
  local positional_seen=0

  while (($# > 0)); do
    case "$1" in
      --)
        shift
        if (($# != 1 || positional_seen != 0)); then
          bundle_fail "import requires exactly one FILE argument"
        fi
        BUNDLE_IMPORT_INPUT="$1"
        positional_seen=1
        shift
        ;;
      -*)
        bundle_fail "unknown import option '$1'"
        ;;
      *)
        if ((positional_seen != 0)); then
          bundle_fail "import requires exactly one FILE argument"
        fi
        BUNDLE_IMPORT_INPUT="$1"
        positional_seen=1
        shift
        ;;
    esac
  done

  ((positional_seen == 1)) ||
    bundle_fail "import requires exactly one FILE argument"
}

bundle_load_tools() {
  [[ -n "${RUBBLE_EXECUTABLE:-}" ]] || bundle_fail "RUBBLE_EXECUTABLE is required"
  [[ "$RUBBLE_EXECUTABLE" == /* ]] || bundle_fail "RUBBLE_EXECUTABLE must be an absolute path"
  [[ -f "$RUBBLE_EXECUTABLE" && -x "$RUBBLE_EXECUTABLE" ]] ||
    bundle_fail "RUBBLE_EXECUTABLE is not an executable regular file: $RUBBLE_EXECUTABLE"

  local payload
  if ! payload="$("$RUBBLE_EXECUTABLE" -q info --format bash --tools)"; then
    bundle_fail "failed to load configuration and tools from RUBBLE_EXECUTABLE"
  fi
  builtin eval "$payload" || bundle_fail "failed to evaluate trusted Rubble tool information"

  local declaration
  declaration="$(builtin declare -p rubble_config 2>/dev/null)" ||
    bundle_fail "active Rubble did not provide rubble_config"
  [[ "$declaration" == 'declare -A '* ]] ||
    bundle_fail "active Rubble returned an invalid rubble_config declaration"
  builtin declare -F rubble-exec >/dev/null ||
    bundle_fail "active Rubble did not provide rubble-exec"
  [[ -n "${rubble_config[rubble_store]:-}" && "${rubble_config[rubble_store]}" == /* ]] ||
    bundle_fail "active Rubble returned an invalid rubble_store"
}

bundle_require_gnu_tools() {
  local version
  version="$(rubble-exec tar --version 2>/dev/null)" ||
    bundle_fail "GNU tar is required"
  [[ "$version" == *'GNU tar'* ]] || bundle_fail "GNU tar is required"

  version="$(rubble-exec cp --version 2>/dev/null)" ||
    bundle_fail "GNU coreutils cp is required"
  [[ "$version" == *'GNU coreutils'* ]] ||
    bundle_fail "GNU coreutils cp is required"

  version="$(rubble-exec sha256sum --version 2>/dev/null)" ||
    bundle_fail "GNU coreutils sha256sum is required"
  [[ "$version" == *'GNU coreutils'* ]] ||
    bundle_fail "GNU coreutils sha256sum is required"

  version="$(rubble-exec stat --version 2>/dev/null)" ||
    bundle_fail "GNU coreutils stat is required"
  [[ "$version" == *'GNU coreutils'* ]] ||
    bundle_fail "GNU coreutils stat is required"
}

# BEGIN SHARED INVENTORY BUNDLE BODY
bundle_has_control_text() {
  [[ "$1" == *$'\t'* || "$1" == *$'\r'* || "$1" == *$'\n'* ]]
}

bundle_safe_id() {
  [[ "$1" =~ ^[a-z2-7]{7}-[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]
}

bundle_safe_full_id() {
  [[ "$1" =~ ^[a-z2-7]{52}-[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]
}

bundle_safe_output_name() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
  case "$1" in
    [Bb][Rr][Kk] | [Bb][Rr][Ii][Cc][Kk])
      return 1
      ;;
  esac
}

bundle_safe_member_name() {
  local LC_ALL=C name="$1"
  ((${#name} >= 1 && ${#name} <= 100)) &&
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

bundle_normalize_destination() {
  local requested="$1"
  local parent name
  bundle_has_control_text "$requested" &&
    bundle_fail "output path contains unsupported control characters"

  if [[ "$requested" == */* ]]; then
    parent="${requested%/*}"
    name="${requested##*/}"
    [[ -n "$parent" ]] || parent='/'
  else
    parent='.'
    name="$requested"
  fi
  [[ -n "$name" && "$name" != '.' && "$name" != '..' ]] ||
    bundle_fail "invalid output path '$requested'"

  rubble-exec mkdir -p -- "$parent" ||
    bundle_fail "failed to create output parent: $parent"
  parent="$(builtin cd -- "$parent" && builtin pwd -P)" ||
    bundle_fail "failed to resolve output parent: $parent"
  BUNDLE_DESTINATION="${parent%/}/$name"
  [[ ! -e "$BUNDLE_DESTINATION" && ! -L "$BUNDLE_DESTINATION" ]] ||
    bundle_fail "output destination already exists: $BUNDLE_DESTINATION"
}

bundle_private_dir() {
  local requested_parent="$1"
  local tag="$2"
  local parent candidate attempt
  [[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || return 2
  parent="$(builtin cd -- "$requested_parent" 2>/dev/null && builtin pwd -P)" ||
    return 1
  [[ "$parent" == /* && -d "$parent" ]] || return 1

  for ((attempt = 0; attempt < 64; attempt++)); do
    candidate="${parent%/}/.rubble-${tag}.${BASHPID}.${RANDOM}.${RANDOM}.${attempt}"
    if (umask 077; rubble-exec mkdir -m 0700 -- "$candidate") 2>/dev/null; then
      [[ -d "$candidate" && ! -L "$candidate" ]] || return 1
      builtin printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

bundle_cleanup() {
  local status=$?
  local index
  builtin trap - EXIT HUP INT TERM
  if ((BUNDLE_IMPORT_ACTIVE != 0 && BUNDLE_IMPORT_COMMITTED == 0)); then
    for ((index = ${#BUNDLE_ROLLBACK_OUTPUTS[@]} - 1; index >= 0; index--)); do
      if ! rubble-exec rm -rf -- \
        "${BUNDLE_ROLLBACK_OUTPUTS[index]}" \
        "${BUNDLE_ROLLBACK_OUTPUTS[index]}.SHA256"; then
        bundle_log WARN "failed to roll back imported output: ${BUNDLE_ROLLBACK_OUTPUTS[index]}"
      fi
    done
    for ((index = ${#BUNDLE_ROLLBACK_FILES[@]} - 1; index >= 0; index--)); do
      if ! rubble-exec rm -f -- "${BUNDLE_ROLLBACK_FILES[index]}"; then
        bundle_log WARN "failed to roll back imported artifact: ${BUNDLE_ROLLBACK_FILES[index]}"
      fi
    done
  fi
  for ((index = ${#BUNDLE_CLEANUP_DIRS[@]} - 1; index >= 0; index--)); do
    if ! rubble-exec rm -rf -- "${BUNDLE_CLEANUP_DIRS[index]}"; then
      bundle_log WARN "failed to remove private staging directory: ${BUNDLE_CLEANUP_DIRS[index]}"
    fi
  done
  exit "$status"
}

bundle_snapshot_regular() {
  local source="$1"
  local destination="$2"
  [[ -f "$source" && ! -L "$source" ]] ||
    bundle_fail "artifact is missing or not a regular file: $source"
  [[ ! -e "$destination" && ! -L "$destination" ]] ||
    bundle_fail "private artifact destination already exists: $destination"

  rubble-exec cp --no-dereference --no-target-directory -- "$source" "$destination" ||
    bundle_fail "failed to snapshot artifact: $source"
  [[ -f "$destination" && ! -L "$destination" ]] ||
    bundle_fail "artifact changed type while being copied: $source"
  rubble-exec chmod 0400 -- "$destination" ||
    bundle_fail "failed to protect staged artifact: $destination"
}

bundle_validate_original_bundle_policy() {
  case "${RUBBLE_INVENTORY_BUNDLE_USE_ORIGINAL:-0}" in
    0 | 1)
      ;;
    *)
      bundle_fail "RUBBLE_INVENTORY_BUNDLE_USE_ORIGINAL must be 0 or 1"
      ;;
  esac
}

bundle_select_import_archive() {
  local input="$1"
  local snapshot="$2"
  bundle_validate_original_bundle_policy
  if [[ "${RUBBLE_INVENTORY_BUNDLE_USE_ORIGINAL:-0}" == 1 ]]; then
    [[ -f "$input" && ! -L "$input" ]] ||
      bundle_fail "bundle input is missing or not a regular file: $input"
    BUNDLE_IMPORT_ARCHIVE="$input"
    bundle_log WARN "using original bundle without a private snapshot; caller must keep it immutable until import completes: $input"
    return 0
  fi
  bundle_snapshot_regular "$input" "$snapshot"
  BUNDLE_IMPORT_ARCHIVE="$snapshot"
}

bundle_sha256() {
  local path="$1"
  local line digest
  line="$(LC_ALL=C rubble-exec sha256sum --binary <"$path")" ||
    bundle_fail "failed to hash staged artifact: $path"
  digest="${line%% *}"
  [[ "$line" == "$digest *-" ]] ||
    bundle_fail "unexpected sha256sum output while hashing staged artifact"
  [[ ${#digest} -eq 64 && "$digest" != *[!0-9a-f]* ]] ||
    bundle_fail "invalid SHA-256 digest for staged artifact: $path"
  builtin printf '%s\n' "$digest"
}

bundle_sidecar_digest() {
  local path="$1"
  local expected_basename="$2"
  local LC_ALL=C
  local fd line extra='' digest actual_size expected_size
  [[ -n "$expected_basename" && "$expected_basename" != '.' && "$expected_basename" != '..' ]] ||
    bundle_fail "invalid canonical artifact basename: $expected_basename"
  [[ "$expected_basename" != */* ]] ||
    bundle_fail "invalid canonical artifact basename: $expected_basename"
  bundle_has_control_text "$expected_basename" &&
    bundle_fail "invalid canonical artifact basename: $expected_basename"
  [[ -f "$path" && ! -L "$path" ]] ||
    bundle_fail "checksum is missing or not a regular file: $path"
  actual_size="$(bundle_file_size "$path")"
  expected_size=$((67 + ${#expected_basename}))
  [[ "$actual_size" == "$expected_size" ]] ||
    bundle_fail "checksum must contain exactly one canonical record: $path"

  exec {fd}<"$path" || bundle_fail "failed to read checksum: $path"
  if ! IFS= builtin read -r line <&${fd}; then
    exec {fd}<&-
    bundle_fail "checksum must contain one newline-terminated record: $path"
  fi
  if IFS= builtin read -r extra <&${fd} || [[ -n "$extra" ]]; then
    exec {fd}<&-
    bundle_fail "checksum must contain exactly one record: $path"
  fi
  exec {fd}<&- || bundle_fail "failed to close checksum: $path"

  digest="${line%% *}"
  [[ "$line" == "$digest *$expected_basename" ]] ||
    bundle_fail "checksum references the wrong artifact basename: $path"
  [[ ${#digest} -eq 64 && "$digest" != *[!0-9a-f]* ]] ||
    bundle_fail "checksum contains an invalid SHA-256 digest: $path"
  builtin printf '%s\n' "$digest"
}

bundle_file_size() {
  local path="$1"
  local size
  size="$(rubble-exec stat --format=%s -- "$path")" ||
    bundle_fail "failed to inspect artifact size: $path"
  [[ "$size" =~ ^(0|[1-9][0-9]*)$ ]] ||
    bundle_fail "invalid artifact size for: $path"
  builtin printf '%s\n' "$size"
}

bundle_member_size() {
  local path="$1"
  local size
  size="$(bundle_file_size "$path")"
  if ((${#size} > ${#BUNDLE_MAX_USTAR_MEMBER_SIZE})) ||
    ((${#size} == ${#BUNDLE_MAX_USTAR_MEMBER_SIZE} &&
      10#$size > BUNDLE_MAX_USTAR_MEMBER_SIZE)); then
    bundle_fail "artifact exceeds the ustar member limit: $path"
  fi
  builtin printf '%s\n' "$size"
}

bundle_append_artifact() {
  BUNDLE_ARTIFACT_KINDS+=("$1")
  BUNDLE_ARTIFACT_BRICK_ORDINALS+=("$2")
  BUNDLE_ARTIFACT_OUTPUT_ORDINALS+=("$3")
  BUNDLE_ARTIFACT_MEMBERS+=("$4")
  BUNDLE_ARTIFACT_SIZES+=("$5")
  BUNDLE_ARTIFACT_DIGESTS+=("$6")
}

bundle_stage_pair() {
  local members_dir="$1"
  local source="$2"
  local content_kind="$3"
  local checksum_kind="$4"
  local brick_ordinal="$5"
  local output_ordinal="$6"
  local content_member="$7"
  local checksum_member="$8"
  local source_checksum="${source}.SHA256"
  local staged_content="${members_dir}/${content_member}"
  local staged_checksum="${members_dir}/${checksum_member}"
  local expected_digest actual_digest content_size checksum_digest checksum_size

  bundle_safe_member_name "$content_member" ||
    bundle_fail "invalid generated member name: $content_member"
  bundle_safe_member_name "$checksum_member" ||
    bundle_fail "invalid generated member name: $checksum_member"
  bundle_snapshot_regular "$source" "$staged_content"
  bundle_snapshot_regular "$source_checksum" "$staged_checksum"

  expected_digest="$(bundle_sidecar_digest "$staged_checksum" "${source##*/}")"
  actual_digest="$(bundle_sha256 "$staged_content")"
  [[ "$actual_digest" == "$expected_digest" ]] ||
    bundle_fail "artifact digest does not match checksum: $source"
  content_size="$(bundle_member_size "$staged_content")"
  bundle_append_artifact \
    "$content_kind" "$brick_ordinal" "$output_ordinal" \
    "$content_member" "$content_size" "$actual_digest"

  checksum_digest="$(bundle_sha256 "$staged_checksum")"
  checksum_size="$(bundle_member_size "$staged_checksum")"
  bundle_append_artifact \
    "$checksum_kind" "$brick_ordinal" "$output_ordinal" \
    "$checksum_member" "$checksum_size" "$checksum_digest"
}

bundle_collect_inventory() {
  local brick="$1"
  local depth="$2"
  local payload list_succeeded=0 declaration
  local -a list_arguments=(-q list --depth "$depth" --format bash)
  if ((BUNDLE_EXPORT_INVENTORY_ACTIVE != 0)); then
    list_arguments+=(--expand-opaque)
  fi
  if payload="$("$RUBBLE_EXECUTABLE" "${list_arguments[@]}" -- "$brick")"; then
    list_succeeded=1
  fi
  [[ -n "$payload" ]] ||
    bundle_fail "Rubble list produced no Bash inventory"
  builtin eval "$payload" ||
    bundle_fail "failed to evaluate trusted Rubble inventory"
  declaration="$(builtin declare -p brick_inventory 2>/dev/null)" ||
    bundle_fail "Rubble list did not provide brick_inventory"
  [[ "$declaration" == 'declare -A '* ]] ||
    bundle_fail "Rubble list returned an invalid brick_inventory declaration"

  local -a brick_ids=() output_names=()
  IFS=' ' builtin read -r -a brick_ids <<<"${brick_inventory[0]:-}"
  ((${#brick_ids[@]} > 0)) || bundle_fail "Rubble list returned an empty inventory"

  BUNDLE_ROOT_SHORT_ID="${brick_inventory['::root']:-}"
  bundle_safe_id "$BUNDLE_ROOT_SHORT_ID" ||
    bundle_fail "Rubble list returned an invalid root short ID"
  local root_seen=0 brick_ordinal selected_brick_ordinal short_id full_key full_id
  local -A selected_ids_seen=()
  local home_key home_mode home opaque_key opaque brk_key brk_path
  local outputs_key output_ordinal output_name path_key output_path status_key status
  for brick_ordinal in "${!brick_ids[@]}"; do
    short_id="${brick_ids[brick_ordinal]}"
    bundle_safe_id "$short_id" ||
      bundle_fail "Rubble list returned an invalid brick short ID"
    full_key="${short_id}::id"
    [[ ${brick_inventory[$full_key]+present} ]] ||
      bundle_fail "Rubble list omitted full ID for $short_id"
    full_id="${brick_inventory[$full_key]}"
    bundle_safe_full_id "$full_id" ||
      bundle_fail "Rubble list returned an invalid full ID for $short_id"
    if ((BUNDLE_EXPORT_INVENTORY_ACTIVE != 0)) &&
      [[ ! ${BUNDLE_EXPORT_INVENTORY_SET[$full_id]+present} ]]; then
      bundle_log DEBUG "$short_id: omit Brick outside exact export inventory"
      continue
    fi
    selected_ids_seen["$full_id"]=1
    [[ "$short_id" == "$BUNDLE_ROOT_SHORT_ID" ]] && root_seen=1
    selected_brick_ordinal="${#BUNDLE_BRICK_SHORT_IDS[@]}"

    home_key="${short_id}::rubble_home"
    if [[ ${brick_inventory[$home_key]+present} ]]; then
      home_mode='fixed'
      home="${brick_inventory[$home_key]}"
      [[ "$home" == /* ]] || bundle_fail "Rubble list returned a non-absolute fixed home for $short_id"
      bundle_has_control_text "$home" &&
        bundle_fail "Rubble list returned an unsafe fixed home for $short_id"
    else
      home_mode='default'
      home='-'
    fi

    opaque_key="${short_id}::opaque"
    if [[ ${brick_inventory[$opaque_key]+present} ]]; then
      [[ "${brick_inventory[$opaque_key]}" == 'true' ]] ||
        bundle_fail "Rubble list returned an invalid opaque value for $short_id"
      opaque=1
    else
      opaque=0
    fi

    brk_key="${short_id}:brk"
    [[ ${brick_inventory[$brk_key]+present} ]] ||
      bundle_fail "Rubble list omitted canonical metadata for $short_id"
    brk_path="${brick_inventory[$brk_key]}"
    [[ "$brk_path" == /* && "${brk_path##*/}" == "brk-${full_id}.brick" ]] ||
      bundle_fail "Rubble list returned a non-canonical metadata path for $short_id"
    bundle_has_control_text "$brk_path" &&
      bundle_fail "Rubble list returned an unsafe metadata path for $short_id"

    BUNDLE_BRICK_SHORT_IDS+=("$short_id")
    BUNDLE_BRICK_FULL_IDS+=("$full_id")
    BUNDLE_BRICK_HOME_MODES+=("$home_mode")
    BUNDLE_BRICK_HOMES+=("$home")
    BUNDLE_BRICK_OPAQUE+=("$opaque")
    BUNDLE_BRICK_PATHS+=("$brk_path")

    outputs_key="${short_id}::outputs"
    [[ ${brick_inventory[$outputs_key]+present} ]] ||
      bundle_fail "Rubble list omitted outputs for $short_id"
    output_names=()
    IFS=' ' builtin read -r -a output_names <<<"${brick_inventory[$outputs_key]}"
    for output_ordinal in "${!output_names[@]}"; do
      output_name="${output_names[output_ordinal]}"
      bundle_safe_output_name "$output_name" ||
        bundle_fail "Rubble list returned an invalid output name for $short_id"
      path_key="${short_id}:${output_name}"
      status_key="${short_id}:${output_name}::status"
      [[ ${brick_inventory[$path_key]+present} && ${brick_inventory[$status_key]+present} ]] ||
        bundle_fail "Rubble list omitted output data for ${short_id}:${output_name}"
      output_path="${brick_inventory[$path_key]}"
      status="${brick_inventory[$status_key]}"
      [[ "$output_path" == /* && "${output_path##*/}" == "${output_name}-${full_id}" ]] ||
        bundle_fail "Rubble list returned a non-canonical path for ${short_id}:${output_name}"
      bundle_has_control_text "$output_path" &&
        bundle_fail "Rubble list returned an unsafe path for ${short_id}:${output_name}"
      case "$status" in
        present | packed | present+packed)
          bundle_log DEBUG "${short_id}:${output_name}: export representation=$status"
          ;;
        missing)
          bundle_fail "${short_id}:${output_name}: output is missing"
          ;;
        error)
          bundle_fail "${short_id}:${output_name}: output inspection returned error"
          ;;
        *)
          bundle_fail "${short_id}:${output_name}: unknown output status '$status'"
          ;;
      esac
      BUNDLE_OUTPUT_BRICK_ORDINALS+=("$selected_brick_ordinal")
      BUNDLE_OUTPUT_ORDINALS+=("$output_ordinal")
      BUNDLE_OUTPUT_NAMES+=("$output_name")
      BUNDLE_OUTPUT_PATHS+=("$output_path")
    done
  done

  ((root_seen == 1)) ||
    bundle_fail "Rubble list root is absent from brick_inventory"
  if ((BUNDLE_EXPORT_INVENTORY_ACTIVE != 0)); then
    local selected_id
    for selected_id in "${BUNDLE_EXPORT_INVENTORY_IDS[@]}"; do
      [[ ${selected_ids_seen[$selected_id]+present} ]] ||
        bundle_fail "inventory file Brick is absent from Rubble traversal: $selected_id"
    done
  fi
  ((list_succeeded == 1)) ||
    bundle_fail "Rubble list failed while inspecting the inventory"
}

bundle_write_manifest() {
  local manifest="$1"
  local depth="$2"
  local index
  (umask 077; : >"$manifest") ||
    bundle_fail "failed to create private bundle manifest"

  {
    builtin printf 'rubble-inventory-bundle\t%s\n' "$BUNDLE_VERSION"
    builtin printf 'depth\t%s\n' "$depth"
    builtin printf 'root\t%s\n' "$BUNDLE_ROOT_SHORT_ID"
    for index in "${!BUNDLE_BRICK_SHORT_IDS[@]}"; do
      builtin printf 'brick\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$index" \
        "${BUNDLE_BRICK_SHORT_IDS[index]}" \
        "${BUNDLE_BRICK_FULL_IDS[index]}" \
        "${BUNDLE_BRICK_HOME_MODES[index]}" \
        "${BUNDLE_BRICK_HOMES[index]}" \
        "${BUNDLE_BRICK_OPAQUE[index]}"
    done
    for index in "${!BUNDLE_OUTPUT_NAMES[@]}"; do
      builtin printf 'output\t%s\t%s\t%s\n' \
        "${BUNDLE_OUTPUT_BRICK_ORDINALS[index]}" \
        "${BUNDLE_OUTPUT_ORDINALS[index]}" \
        "${BUNDLE_OUTPUT_NAMES[index]}"
    done
    for index in "${!BUNDLE_ARTIFACT_KINDS[@]}"; do
      builtin printf 'artifact\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${BUNDLE_ARTIFACT_KINDS[index]}" \
        "${BUNDLE_ARTIFACT_BRICK_ORDINALS[index]}" \
        "${BUNDLE_ARTIFACT_OUTPUT_ORDINALS[index]}" \
        "${BUNDLE_ARTIFACT_MEMBERS[index]}" \
        "${BUNDLE_ARTIFACT_SIZES[index]}" \
        "${BUNDLE_ARTIFACT_DIGESTS[index]}"
    done
    builtin printf 'end\t%s\t%s\t%s\n' \
      "${#BUNDLE_BRICK_SHORT_IDS[@]}" \
      "${#BUNDLE_OUTPUT_NAMES[@]}" \
      "${#BUNDLE_ARTIFACT_KINDS[@]}"
  } >>"$manifest"
  rubble-exec chmod 0400 -- "$manifest" ||
    bundle_fail "failed to protect private bundle manifest"
  bundle_member_size "$manifest" >/dev/null
}

bundle_tar() {
  (
    unset TAR_OPTIONS TAR_READER_OPTIONS TAR_WRITER_OPTIONS POSIXLY_CORRECT
    LC_ALL=C TZ=UTC0 rubble-exec tar "$@"
  )
}

bundle_write_tar_member_list() {
  local member_list="$1"
  local member
  (umask 077; : >"$member_list") ||
    bundle_fail "failed to create private tar member list"
  builtin printf '%s\0' "$BUNDLE_MANIFEST" >>"$member_list"
  for member in "${BUNDLE_ARTIFACT_MEMBERS[@]}"; do
    bundle_safe_member_name "$member" ||
      bundle_fail "invalid tar member name: $member"
    builtin printf '%s\0' "$member" >>"$member_list"
  done
  rubble-exec chmod 0400 -- "$member_list" ||
    bundle_fail "failed to protect private tar member list"
}

bundle_tar_create() {
  local archive="$1"
  local members_dir="$2"
  local member_list="$3"
  local error_file="$4"
  local member
  for member in "$BUNDLE_MANIFEST" "${BUNDLE_ARTIFACT_MEMBERS[@]}"; do
    bundle_safe_member_name "$member" ||
      bundle_fail "invalid tar member name: $member"
    [[ -f "$members_dir/$member" && ! -L "$members_dir/$member" ]] ||
      bundle_fail "tar member is not a regular staged file: $member"
  done

  if ! (
    set -o noclobber
    bundle_tar --create --file=- \
      --format=ustar --blocking-factor=20 \
      --numeric-owner --owner=0 --group=0 --mode=0644 --mtime=@0 \
      --no-recursion --directory="$members_dir" \
      --null --verbatim-files-from --files-from="$member_list" >"$archive"
  ) 2>"$error_file"; then
    bundle_fail "failed to create bundle tar"
  fi
  [[ ! -s "$error_file" && -f "$archive" && ! -L "$archive" ]] ||
    bundle_fail "GNU tar reported an error while creating the bundle"
}

bundle_validate_tar_members() {
  local archive="$1"
  local names_file="$2"
  local error_file="$3"
  if ! bundle_tar --list --file=- --quoting-style=escape --show-stored-names \
    <"$archive" >"$names_file" 2>"$error_file"; then
    bundle_fail "failed to validate the completed bundle tar"
  fi
  [[ ! -s "$error_file" ]] ||
    bundle_fail "GNU tar reported an error while validating the bundle"

  local -a actual_members=() expected_members=("$BUNDLE_MANIFEST")
  local index
  expected_members+=("${BUNDLE_ARTIFACT_MEMBERS[@]}")
  builtin mapfile -t actual_members <"$names_file"
  ((${#actual_members[@]} == ${#expected_members[@]})) ||
    bundle_fail "completed bundle has an unexpected member count"
  for index in "${!expected_members[@]}"; do
    [[ "${actual_members[index]}" == "${expected_members[index]}" ]] ||
      bundle_fail "completed bundle member order is not canonical"
  done
}

bundle_import_list_tar() {
  local archive="$1"
  local names_file="$2"
  local error_file="$3"
  if ! bundle_tar --list --file=- --quoting-style=escape --show-stored-names \
    <"$archive" >"$names_file" 2>"$error_file"; then
    bundle_fail "failed to read bundle tar inventory"
  fi
  [[ ! -s "$error_file" ]] ||
    bundle_fail "GNU tar reported an error while reading the bundle inventory"

  BUNDLE_TAR_MEMBERS=()
  builtin mapfile -t BUNDLE_TAR_MEMBERS <"$names_file"
  ((${#BUNDLE_TAR_MEMBERS[@]} > 0)) ||
    bundle_fail "bundle tar inventory is empty"
  [[ "${BUNDLE_TAR_MEMBERS[0]}" == "$BUNDLE_MANIFEST" ]] ||
    bundle_fail "bundle manifest must be the first tar member"

  local -A seen_members=()
  local member
  for member in "${BUNDLE_TAR_MEMBERS[@]}"; do
    bundle_safe_member_name "$member" ||
      bundle_fail "bundle contains an unsafe tar member name: $member"
    [[ ! ${seen_members[$member]+present} ]] ||
      bundle_fail "bundle contains a duplicate tar member: $member"
    seen_members["$member"]=1
  done
}

bundle_extract_tar_member() {
  local archive="$1"
  local member="$2"
  local destination="$3"
  local error_file="$4"
  bundle_safe_member_name "$member" ||
    bundle_fail "invalid requested tar member: $member"
  [[ ! -e "$destination" && ! -L "$destination" ]] ||
    bundle_fail "private extraction destination already exists: $destination"

  if ! (
    set -o noclobber
    bundle_tar --extract --to-stdout --file=- --occurrence=1 -- "$member" \
      <"$archive" >"$destination"
  ) 2>"$error_file"; then
    bundle_fail "failed to extract exact bundle member: $member"
  fi
  [[ ! -s "$error_file" && -f "$destination" && ! -L "$destination" ]] ||
    bundle_fail "GNU tar reported an error while extracting bundle member: $member"
  rubble-exec chmod 0400 -- "$destination" ||
    bundle_fail "failed to protect extracted bundle member: $member"
}

bundle_manifest_fail() {
  bundle_fail "invalid bundle manifest: $*"
}

bundle_validate_manifest_size() {
  local value="$1"
  local context="$2"
  [[ "$value" =~ ^(0|[1-9][0-9]*)$ ]] ||
    bundle_manifest_fail "$context has an invalid size"
  if ((${#value} > ${#BUNDLE_MAX_USTAR_MEMBER_SIZE})) ||
    ((${#value} == ${#BUNDLE_MAX_USTAR_MEMBER_SIZE} &&
      10#$value > BUNDLE_MAX_USTAR_MEMBER_SIZE)); then
    bundle_manifest_fail "$context exceeds the ustar member limit"
  fi
}

bundle_parse_manifest() {
  local manifest="$1"
  local LC_ALL=C
  local fd line='' record phase='brick' manifest_size
  local line_number=0 parsed_size=0 end_seen=0 brick_ordinal output_ordinal
  local last_output_brick_ordinal=-1 output_identity
  local -a fields=()
  local -A seen_short_ids=() seen_full_ids=() known_brick_ordinals=()
  local -A next_output_ordinals=() seen_outputs=()

  BUNDLE_BRICK_SHORT_IDS=()
  BUNDLE_BRICK_FULL_IDS=()
  BUNDLE_BRICK_HOME_MODES=()
  BUNDLE_BRICK_HOMES=()
  BUNDLE_BRICK_OPAQUE=()
  BUNDLE_BRICK_PATHS=()
  BUNDLE_OUTPUT_BRICK_ORDINALS=()
  BUNDLE_OUTPUT_ORDINALS=()
  BUNDLE_OUTPUT_NAMES=()
  BUNDLE_OUTPUT_PATHS=()
  BUNDLE_ARTIFACT_KINDS=()
  BUNDLE_ARTIFACT_BRICK_ORDINALS=()
  BUNDLE_ARTIFACT_OUTPUT_ORDINALS=()
  BUNDLE_ARTIFACT_MEMBERS=()
  BUNDLE_ARTIFACT_SIZES=()
  BUNDLE_ARTIFACT_DIGESTS=()

  manifest_size="$(bundle_file_size "$manifest")"
  exec {fd}<"$manifest" ||
    bundle_fail "failed to read extracted bundle manifest"
  while IFS= builtin read -r line <&${fd}; do
    ((line_number += 1))
    ((parsed_size += ${#line} + 1))
    [[ "$line" != $'\t'* && "$line" != *$'\t' && "$line" != *$'\t\t'* ]] ||
      bundle_manifest_fail "line $line_number has non-canonical field separators"
    fields=()
    IFS=$'\t' builtin read -r -a fields <<<"$line"

    if ((line_number == 1)); then
      ((${#fields[@]} == 2)) ||
        bundle_manifest_fail "line 1 has the wrong field count"
      [[ "${fields[0]}" == 'rubble-inventory-bundle' && "${fields[1]}" == "$BUNDLE_VERSION" ]] ||
        bundle_manifest_fail "unsupported header or version"
      continue
    fi
    if ((line_number == 2)); then
      ((${#fields[@]} == 2)) ||
        bundle_manifest_fail "line 2 has the wrong field count"
      [[ "${fields[0]}" == 'depth' ]] ||
        bundle_manifest_fail "line 2 must declare depth"
      BUNDLE_IMPORT_DEPTH="$(bundle_parse_depth "${fields[1]}")"
      continue
    fi
    if ((line_number == 3)); then
      ((${#fields[@]} == 2)) ||
        bundle_manifest_fail "line 3 has the wrong field count"
      [[ "${fields[0]}" == 'root' ]] ||
        bundle_manifest_fail "line 3 must declare root"
      BUNDLE_ROOT_SHORT_ID="${fields[1]}"
      bundle_safe_id "$BUNDLE_ROOT_SHORT_ID" ||
        bundle_manifest_fail "root has an invalid short ID"
      continue
    fi

    ((end_seen == 0)) ||
      bundle_manifest_fail "records appear after the end marker"
    record="${fields[0]:-}"
    case "$record" in
      brick)
        [[ "$phase" == 'brick' ]] ||
          bundle_manifest_fail "brick record appears out of order at line $line_number"
        ((${#fields[@]} == 7)) ||
          bundle_manifest_fail "brick record has the wrong field count at line $line_number"
        brick_ordinal="${#BUNDLE_BRICK_SHORT_IDS[@]}"
        [[ "${fields[1]}" == "$brick_ordinal" ]] ||
          bundle_manifest_fail "brick ordinal is not canonical at line $line_number"
        bundle_safe_id "${fields[2]}" ||
          bundle_manifest_fail "brick has an invalid short ID at line $line_number"
        bundle_safe_full_id "${fields[3]}" ||
          bundle_manifest_fail "brick has an invalid full ID at line $line_number"
        [[ "${fields[2]}" == "${fields[3]:0:7}${fields[3]:52}" ]] ||
          bundle_manifest_fail "brick short and full IDs disagree at line $line_number"
        [[ ! ${seen_short_ids[${fields[2]}]+present} ]] ||
          bundle_manifest_fail "brick short ID is duplicated at line $line_number"
        [[ ! ${seen_full_ids[${fields[3]}]+present} ]] ||
          bundle_manifest_fail "brick full ID is duplicated at line $line_number"
        seen_short_ids["${fields[2]}"]=1
        seen_full_ids["${fields[3]}"]=1
        case "${fields[4]}" in
          default)
            [[ "${fields[5]}" == '-' ]] ||
              bundle_manifest_fail "default-home brick carries a fixed path at line $line_number"
            ;;
          fixed)
            [[ "${fields[5]}" == /* ]] ||
              bundle_manifest_fail "fixed-home brick has a non-absolute path at line $line_number"
            bundle_has_control_text "${fields[5]}" &&
              bundle_manifest_fail "fixed-home brick has an unsafe path at line $line_number"
            ;;
          *)
            bundle_manifest_fail "brick has an invalid home mode at line $line_number"
            ;;
        esac
        [[ "${fields[6]}" == 0 || "${fields[6]}" == 1 ]] ||
          bundle_manifest_fail "brick has an invalid opaque value at line $line_number"
        BUNDLE_BRICK_SHORT_IDS+=("${fields[2]}")
        BUNDLE_BRICK_FULL_IDS+=("${fields[3]}")
        BUNDLE_BRICK_HOME_MODES+=("${fields[4]}")
        BUNDLE_BRICK_HOMES+=("${fields[5]}")
        BUNDLE_BRICK_OPAQUE+=("${fields[6]}")
        known_brick_ordinals["$brick_ordinal"]=1
        ;;
      output)
        [[ "$phase" == 'brick' || "$phase" == 'output' ]] ||
          bundle_manifest_fail "output record appears out of order at line $line_number"
        phase='output'
        ((${#fields[@]} == 4)) ||
          bundle_manifest_fail "output record has the wrong field count at line $line_number"
        brick_ordinal="${fields[1]}"
        [[ "$brick_ordinal" =~ ^(0|[1-9][0-9]*)$ ]] ||
          bundle_manifest_fail "output has an invalid brick ordinal at line $line_number"
        [[ ${known_brick_ordinals[$brick_ordinal]+present} ]] ||
          bundle_manifest_fail "output references an unknown brick at line $line_number"
        ((10#$brick_ordinal >= last_output_brick_ordinal)) ||
          bundle_manifest_fail "output brick order is not canonical at line $line_number"
        last_output_brick_ordinal=$((10#$brick_ordinal))
        output_ordinal="${next_output_ordinals[$brick_ordinal]:-0}"
        [[ "${fields[2]}" == "$output_ordinal" ]] ||
          bundle_manifest_fail "output ordinal is not canonical at line $line_number"
        bundle_safe_output_name "${fields[3]}" ||
          bundle_manifest_fail "output has an invalid name at line $line_number"
        output_identity="${brick_ordinal}:${fields[3]}"
        [[ ! ${seen_outputs[$output_identity]+present} ]] ||
          bundle_manifest_fail "output name is duplicated at line $line_number"
        seen_outputs["$output_identity"]=1
        next_output_ordinals["$brick_ordinal"]=$((output_ordinal + 1))
        BUNDLE_OUTPUT_BRICK_ORDINALS+=("$brick_ordinal")
        BUNDLE_OUTPUT_ORDINALS+=("$output_ordinal")
        BUNDLE_OUTPUT_NAMES+=("${fields[3]}")
        ;;
      artifact)
        [[ "$phase" == 'brick' || "$phase" == 'output' || "$phase" == 'artifact' ]] ||
          bundle_manifest_fail "artifact record appears out of order at line $line_number"
        phase='artifact'
        ((${#fields[@]} == 7)) ||
          bundle_manifest_fail "artifact record has the wrong field count at line $line_number"
        case "${fields[1]}" in
          brick | brick_checksum | rbl | rbl_checksum) ;;
          *)
            bundle_manifest_fail "artifact has an unknown kind at line $line_number"
            ;;
        esac
        bundle_safe_member_name "${fields[4]}" ||
          bundle_manifest_fail "artifact has an invalid member name at line $line_number"
        bundle_validate_manifest_size "${fields[5]}" "artifact at line $line_number"
        [[ ${#fields[6]} -eq 64 && "${fields[6]}" != *[!0-9a-f]* ]] ||
          bundle_manifest_fail "artifact has an invalid SHA-256 digest at line $line_number"
        BUNDLE_ARTIFACT_KINDS+=("${fields[1]}")
        BUNDLE_ARTIFACT_BRICK_ORDINALS+=("${fields[2]}")
        BUNDLE_ARTIFACT_OUTPUT_ORDINALS+=("${fields[3]}")
        BUNDLE_ARTIFACT_MEMBERS+=("${fields[4]}")
        BUNDLE_ARTIFACT_SIZES+=("${fields[5]}")
        BUNDLE_ARTIFACT_DIGESTS+=("${fields[6]}")
        ;;
      end)
        [[ "$phase" == 'brick' || "$phase" == 'output' || "$phase" == 'artifact' ]] ||
          bundle_manifest_fail "end record appears out of order at line $line_number"
        ((${#fields[@]} == 4)) ||
          bundle_manifest_fail "end record has the wrong field count at line $line_number"
        [[ "${fields[1]}" == "${#BUNDLE_BRICK_SHORT_IDS[@]}" &&
          "${fields[2]}" == "${#BUNDLE_OUTPUT_NAMES[@]}" &&
          "${fields[3]}" == "${#BUNDLE_ARTIFACT_KINDS[@]}" ]] ||
          bundle_manifest_fail "end record counts do not match the manifest"
        phase='end'
        end_seen=1
        ;;
      *)
        bundle_manifest_fail "unknown record at line $line_number"
        ;;
    esac
  done
  [[ -z "$line" ]] ||
    bundle_manifest_fail "manifest is not newline-terminated"
  exec {fd}<&- ||
    bundle_fail "failed to close extracted bundle manifest"
  ((parsed_size == manifest_size)) ||
    bundle_manifest_fail "manifest contains a NUL byte"

  ((line_number >= 4 && end_seen == 1)) ||
    bundle_manifest_fail "manifest is incomplete"
  ((${#BUNDLE_BRICK_SHORT_IDS[@]} > 0)) ||
    bundle_manifest_fail "manifest contains no bricks"
  BUNDLE_ROOT_BRICK_ORDINAL=''
  for brick_ordinal in "${!BUNDLE_BRICK_SHORT_IDS[@]}"; do
    if [[ "${BUNDLE_BRICK_SHORT_IDS[brick_ordinal]}" == "$BUNDLE_ROOT_SHORT_ID" ]]; then
      BUNDLE_ROOT_BRICK_ORDINAL="$brick_ordinal"
      break
    fi
  done
  [[ -n "$BUNDLE_ROOT_BRICK_ORDINAL" ]] ||
    bundle_manifest_fail "root is absent from brick records"
}

bundle_home_store_path() {
  local home="$1"
  if [[ "$home" == '/' ]]; then
    builtin printf '/store\n'
  else
    builtin printf '%s/store\n' "${home%/}"
  fi
}

bundle_build_target_paths() {
  local default_home="${rubble_config[rubble_home]:-}"
  local default_store="${rubble_config[rubble_store]:-}"
  local expected_store brick_ordinal output_index full_id store prefix
  [[ "$default_home" == /* && "$default_store" == /* ]] ||
    bundle_fail "active Rubble returned invalid default home paths"
  bundle_has_control_text "$default_home" &&
    bundle_fail "active Rubble returned an unsafe default rubble_home"
  bundle_has_control_text "$default_store" &&
    bundle_fail "active Rubble returned an unsafe default rubble_store"
  expected_store="$(bundle_home_store_path "$default_home")"
  [[ "$default_store" == "$expected_store" ]] ||
    bundle_fail "active Rubble returned inconsistent default home paths"

  BUNDLE_BRICK_TARGET_PATHS=()
  for brick_ordinal in "${!BUNDLE_BRICK_FULL_IDS[@]}"; do
    full_id="${BUNDLE_BRICK_FULL_IDS[brick_ordinal]}"
    if [[ "${BUNDLE_BRICK_HOME_MODES[brick_ordinal]}" == 'fixed' ]]; then
      store="$(bundle_home_store_path "${BUNDLE_BRICK_HOMES[brick_ordinal]}")"
    else
      store="$default_store"
    fi
    prefix="${full_id:0:2}/${full_id:2:2}"
    BUNDLE_BRICK_TARGET_PATHS+=("${store%/}/${prefix}/brk-${full_id}.brick")
  done

  BUNDLE_OUTPUT_TARGET_PATHS=()
  for output_index in "${!BUNDLE_OUTPUT_NAMES[@]}"; do
    brick_ordinal="${BUNDLE_OUTPUT_BRICK_ORDINALS[output_index]}"
    full_id="${BUNDLE_BRICK_FULL_IDS[brick_ordinal]}"
    if [[ "${BUNDLE_BRICK_HOME_MODES[brick_ordinal]}" == 'fixed' ]]; then
      store="$(bundle_home_store_path "${BUNDLE_BRICK_HOMES[brick_ordinal]}")"
    else
      store="$default_store"
    fi
    prefix="${full_id:0:2}/${full_id:2:2}"
    BUNDLE_OUTPUT_TARGET_PATHS+=(
      "${store%/}/${prefix}/${BUNDLE_OUTPUT_NAMES[output_index]}-${full_id}"
    )
  done
  BUNDLE_IMPORT_ROOT_BRK="${BUNDLE_BRICK_TARGET_PATHS[BUNDLE_ROOT_BRICK_ORDINAL]}"
}

bundle_find_system_executable() {
  local name="$1"
  local candidate
  local -a candidates=()
  case "$name" in
    sudo)
      candidates=(/usr/bin/sudo /bin/sudo)
      ;;
    doas)
      candidates=(/usr/bin/doas /bin/doas)
      ;;
    su)
      candidates=(/usr/bin/su /bin/su)
      ;;
    *)
      return 2
      ;;
  esac
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" && -x "$candidate" ]]; then
      builtin printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

bundle_run_privileged_runtime_command() {
  local helper_name="$1"
  local helper="$2"
  local runtime_home="$3"
  local interactive="$4"
  local command_text='
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
runtime_home=$1
runtime_uid=$2
runtime_gid=$3
umask 022
mkdir "$runtime_home" &&
  chown "$runtime_uid:$runtime_gid" "$runtime_home" &&
  chmod 0755 "$runtime_home"
'
  case "$helper_name" in
    sudo | doas)
      if ((interactive != 0)); then
        command -p env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
          "$helper" /bin/sh -c "$command_text" rubble-runtime-home \
            "$runtime_home" "$EUID" "${GROUPS[0]}"
      else
        command -p env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
          "$helper" -n /bin/sh -c "$command_text" rubble-runtime-home \
            "$runtime_home" "$EUID" "${GROUPS[0]}"
      fi
      ;;
    su)
      ((interactive != 0)) ||
        return 2
      command -p env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        "$helper" -s /bin/sh root -c "$command_text" rubble-runtime-home \
          "$runtime_home" "$EUID" "${GROUPS[0]}"
      ;;
    *)
      return 2
      ;;
  esac
}

bundle_verify_created_runtime_home() {
  local runtime_home="$1"
  local metadata mode owner group
  [[ -d "$runtime_home" && ! -L "$runtime_home" &&
    -w "$runtime_home" && -x "$runtime_home" ]] ||
    return 1
  metadata="$(rubble-exec stat --format=$'%a\t%u\t%g' -- "$runtime_home")" ||
    return 1
  IFS=$'\t' builtin read -r mode owner group <<<"$metadata"
  [[ "$mode" == 755 && "$owner" == "$EUID" && "$group" == "${GROUPS[0]}" ]]
}

bundle_validate_privileged_runtime_parent() {
  local runtime_home="$1"
  local parent="${runtime_home%/*}"
  local metadata mode owner
  local relative="${runtime_home#/}"
  local component
  local -a components=()
  [[ "$runtime_home" != *'//' && "$runtime_home" != */ ]] ||
    bundle_fail "runtime home contains an unsafe path component: $runtime_home"
  IFS='/' builtin read -r -a components <<<"$relative"
  for component in "${components[@]}"; do
    [[ -n "$component" && "$component" != '.' && "$component" != '..' ]] ||
      bundle_fail "runtime home contains an unsafe path component: $runtime_home"
  done
  [[ -n "$parent" ]] || parent='/'
  [[ -d "$parent" && ! -L "$parent" && -x "$parent" ]] ||
    bundle_fail "privileged runtime-home creation requires an existing safe direct parent: $parent"
  metadata="$(rubble-exec stat --format=$'%a\t%u' -- "$parent")" ||
    bundle_fail "failed to inspect runtime-home direct parent: $parent"
  IFS=$'\t' builtin read -r mode owner <<<"$metadata"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] ||
    bundle_fail "runtime-home direct parent has an invalid mode: $parent"
  [[ "$owner" == 0 ]] ||
    bundle_fail "runtime-home direct parent is not owned by root: $parent"
  (( (8#$mode & 8#022) == 0 )) ||
    bundle_fail "runtime-home direct parent is group- or world-writable: $parent"
  [[ ! -w "$parent" ]] ||
    bundle_fail "runtime-home direct parent is writable by the invoking user: $parent"
  [[ ! -e "$runtime_home" && ! -L "$runtime_home" ]] ||
    bundle_fail "runtime home appeared during privileged parent validation: $runtime_home"
  bundle_log DEBUG "validated privileged runtime-home direct parent: path=$parent"
}

bundle_prepare_runtime_home() {
  ((BUNDLE_IMPORT_ONLY != 0)) || return 0

  local runtime_home="${rubble_config[rubble_runtime_home]:-}"
  local default_home="${rubble_config[rubble_home]:-}"
  [[ "$runtime_home" == /* ]] ||
    bundle_fail "import-only configuration returned an invalid rubble_runtime_home"
  bundle_has_control_text "$runtime_home" &&
    bundle_fail "import-only configuration returned an unsafe rubble_runtime_home"

  local used=0 brick_ordinal
  for brick_ordinal in "${!BUNDLE_BRICK_HOME_MODES[@]}"; do
    if [[ "${BUNDLE_BRICK_HOME_MODES[brick_ordinal]}" == 'fixed' ]]; then
      if [[ "${BUNDLE_BRICK_HOMES[brick_ordinal]}" == "$runtime_home" ]]; then
        used=1
        break
      fi
    elif [[ "$default_home" == "$runtime_home" ]]; then
      used=1
      break
    fi
  done
  if ((used == 0)); then
    bundle_log DEBUG "runtime home is not selected by the bundle: $runtime_home"
    return 0
  fi

  if [[ -L "$runtime_home" ]]; then
    bundle_fail "runtime home is a symbolic link: $runtime_home"
  fi
  if [[ -e "$runtime_home" ]]; then
    [[ -d "$runtime_home" ]] ||
      bundle_fail "runtime home exists but is not a directory: $runtime_home"
    [[ -w "$runtime_home" && -x "$runtime_home" ]] ||
      bundle_fail "runtime home is not writable and searchable: $runtime_home"
    bundle_log INFO "using existing runtime home: $runtime_home"
    return 0
  fi

  if rubble-exec mkdir -m 0755 -- "$runtime_home" 2>/dev/null; then
    bundle_verify_created_runtime_home "$runtime_home" ||
      bundle_fail "new runtime home failed ownership, mode, or access checks: $runtime_home"
    bundle_log INFO "created runtime home without privilege: path=$runtime_home owner=$EUID:${GROUPS[0]} mode=0755"
    return 0
  fi
  [[ ! -e "$runtime_home" && ! -L "$runtime_home" ]] ||
    bundle_fail "runtime home appeared after unprivileged creation failed: $runtime_home"

  bundle_validate_privileged_runtime_parent "$runtime_home"
  [[ -f /bin/sh && -x /bin/sh ]] ||
    bundle_fail "privileged runtime-home creation requires executable /bin/sh"
  local helper_name helper interactive=0
  [[ -t 0 ]] && interactive=1
  for helper_name in sudo doas; do
    if ! helper="$(bundle_find_system_executable "$helper_name")"; then
      bundle_log DEBUG "system runtime-home privilege helper is unavailable: $helper_name"
      continue
    fi
    bundle_log INFO "creating runtime home with scoped privilege: helper=$helper_name interactive=$interactive path=$runtime_home"
    if bundle_run_privileged_runtime_command \
      "$helper_name" "$helper" "$runtime_home" "$interactive"; then
      bundle_verify_created_runtime_home "$runtime_home" ||
        bundle_fail "privileged runtime home failed ownership, mode, or access checks: $runtime_home"
      bundle_log INFO "created runtime home with scoped privilege: helper=$helper_name path=$runtime_home owner=$EUID:${GROUPS[0]} mode=0755"
      return 0
    fi
    [[ ! -e "$runtime_home" && ! -L "$runtime_home" ]] ||
      bundle_fail "runtime home appeared after $helper_name failed: $runtime_home"
    bundle_log WARN "runtime-home creation failed with helper=$helper_name path=$runtime_home"
  done

  if ((interactive == 0)); then
    bundle_log DEBUG "interactive su fallback is unavailable without a terminal"
  elif ! helper="$(bundle_find_system_executable su)"; then
    bundle_log DEBUG "system runtime-home privilege helper is unavailable: su"
  else
    bundle_log INFO "creating runtime home with scoped privilege: helper=su interactive=1 path=$runtime_home"
    if bundle_run_privileged_runtime_command su "$helper" "$runtime_home" 1; then
      bundle_verify_created_runtime_home "$runtime_home" ||
        bundle_fail "interactive runtime home failed ownership, mode, or access checks: $runtime_home"
      bundle_log INFO "created runtime home with interactive scoped privilege: helper=su path=$runtime_home owner=$EUID:${GROUPS[0]} mode=0755"
      return 0
    fi
    if [[ -e "$runtime_home" || -L "$runtime_home" ]]; then
      if bundle_verify_created_runtime_home "$runtime_home"; then
        bundle_log WARN "su reported failure after creating a verified runtime home; continuing: path=$runtime_home owner=$EUID:${GROUPS[0]} mode=0755"
        return 0
      fi
      bundle_fail "su failed and left an unverified runtime-home path that requires manual cleanup: $runtime_home"
    fi
    bundle_log WARN "runtime-home creation failed with helper=su path=$runtime_home"
  fi
  bundle_fail "missing runtime home requires scoped permission through system sudo, doas, or interactive su: $runtime_home"
}

bundle_validate_target_path_uniqueness() {
  local -a paths=()
  local -A seen_paths=()
  local target
  for target in "${BUNDLE_BRICK_TARGET_PATHS[@]}"; do
    paths+=("$target" "${target}.SHA256")
  done
  for target in "${BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
    paths+=(
      "$target"
      "${target}.SHA256"
      "${target}.rbl"
      "${target}.rbl.SHA256"
    )
  done

  for target in "${paths[@]}"; do
    [[ ! ${seen_paths[$target]+present} ]] ||
      bundle_manifest_fail "multiple artifacts map to target path: $target"
    seen_paths["$target"]=1
  done
  bundle_log DEBUG "validated ${#paths[@]} unique import target paths"
}

bundle_expect_artifact() {
  local index="$1"
  local kind="$2"
  local brick_ordinal="$3"
  local output_ordinal="$4"
  local member="$5"
  [[ "${BUNDLE_ARTIFACT_KINDS[index]:-}" == "$kind" &&
    "${BUNDLE_ARTIFACT_BRICK_ORDINALS[index]:-}" == "$brick_ordinal" &&
    "${BUNDLE_ARTIFACT_OUTPUT_ORDINALS[index]:-}" == "$output_ordinal" &&
    "${BUNDLE_ARTIFACT_MEMBERS[index]:-}" == "$member" ]] ||
    bundle_manifest_fail "artifact order or identity is not canonical at index $index"
}

bundle_validate_import_artifact_schema() {
  local cursor=0 brick_ordinal output_index output_ordinal member
  for brick_ordinal in "${!BUNDLE_BRICK_FULL_IDS[@]}"; do
    builtin printf -v member 'brick-%08d.brick' "$brick_ordinal"
    bundle_expect_artifact "$cursor" brick "$brick_ordinal" - "$member"
    ((cursor += 1))
    bundle_expect_artifact "$cursor" brick_checksum "$brick_ordinal" - "${member}.SHA256"
    ((cursor += 1))
  done
  for output_index in "${!BUNDLE_OUTPUT_NAMES[@]}"; do
    brick_ordinal="${BUNDLE_OUTPUT_BRICK_ORDINALS[output_index]}"
    output_ordinal="${BUNDLE_OUTPUT_ORDINALS[output_index]}"
    builtin printf -v member 'output-%08d-%08d.rbl' "$brick_ordinal" "$output_ordinal"
    bundle_expect_artifact "$cursor" rbl "$brick_ordinal" "$output_ordinal" "$member"
    ((cursor += 1))
    bundle_expect_artifact \
      "$cursor" rbl_checksum "$brick_ordinal" "$output_ordinal" "${member}.SHA256"
    ((cursor += 1))
  done
  ((cursor == ${#BUNDLE_ARTIFACT_KINDS[@]})) ||
    bundle_manifest_fail "manifest contains unexpected artifact records"
}

bundle_validate_import_tar_members() {
  local expected_count=$((1 + ${#BUNDLE_ARTIFACT_MEMBERS[@]}))
  local index
  ((${#BUNDLE_TAR_MEMBERS[@]} == expected_count)) ||
    bundle_fail "bundle tar member count does not match the manifest"
  [[ "${BUNDLE_TAR_MEMBERS[0]}" == "$BUNDLE_MANIFEST" ]] ||
    bundle_fail "bundle manifest is not the first tar member"
  for index in "${!BUNDLE_ARTIFACT_MEMBERS[@]}"; do
    [[ "${BUNDLE_TAR_MEMBERS[index + 1]}" == "${BUNDLE_ARTIFACT_MEMBERS[index]}" ]] ||
      bundle_fail "bundle tar member order does not match the manifest"
  done
}

bundle_write_import_artifact_list() {
  local member_list="$1"
  local member
  (umask 077; : >"$member_list") ||
    bundle_fail "failed to create private import artifact list"
  for member in "${BUNDLE_ARTIFACT_MEMBERS[@]}"; do
    bundle_safe_member_name "$member" ||
      bundle_fail "invalid requested tar member: $member"
    builtin printf '%s\0' "$member" >>"$member_list"
  done
  rubble-exec chmod 0400 -- "$member_list" ||
    bundle_fail "failed to protect private import artifact list"
  bundle_log DEBUG "prepared exact whitelist for ${#BUNDLE_ARTIFACT_MEMBERS[@]} artifacts"
}

bundle_extract_import_artifacts() {
  local archive="$1"
  local artifacts_dir="$2"
  local member_list="$3"
  local error_file="$4"
  if ! (
    umask 077
    bundle_tar --extract --file=- \
      --directory="$artifacts_dir" \
      --keep-old-files \
      --no-same-owner --no-same-permissions --numeric-owner --touch \
      --no-acls --no-xattrs --no-selinux \
      --same-order --anchored --no-recursion --no-wildcards --no-unquote \
      --null --verbatim-files-from --files-from="$member_list" \
      <"$archive"
  ) 2>"$error_file"; then
    bundle_fail "failed to extract exact bundle artifacts"
  fi
  [[ ! -s "$error_file" ]] ||
    bundle_fail "GNU tar reported an error while extracting bundle artifacts"
  bundle_log DEBUG "extracted ${#BUNDLE_ARTIFACT_MEMBERS[@]} artifacts in one tar pass"

  local index member path metadata link_count owner
  BUNDLE_ARTIFACT_PATHS=()
  for index in "${!BUNDLE_ARTIFACT_MEMBERS[@]}"; do
    member="${BUNDLE_ARTIFACT_MEMBERS[index]}"
    path="${artifacts_dir}/${member}"
    [[ -f "$path" && ! -L "$path" ]] ||
      bundle_fail "bundle artifact is not a regular file: $member"
    metadata="$(rubble-exec stat --format=$'%h\t%u' -- "$path")" ||
      bundle_fail "failed to inspect extracted bundle artifact: $member"
    IFS=$'\t' builtin read -r link_count owner <<<"$metadata"
    [[ "$link_count" == 1 ]] ||
      bundle_fail "bundle artifact has multiple hard links: $member"
    [[ "$owner" == "$EUID" ]] ||
      bundle_fail "bundle artifact has an unexpected owner: $member"
    BUNDLE_ARTIFACT_PATHS+=("$path")
    bundle_log TRACE "$member: extracted type=regular links=$link_count owner=$owner"
  done

  local mode
  for index in "${!BUNDLE_ARTIFACT_PATHS[@]}"; do
    member="${BUNDLE_ARTIFACT_MEMBERS[index]}"
    path="${BUNDLE_ARTIFACT_PATHS[index]}"
    rubble-exec chmod 0400 -- "$path" ||
      bundle_fail "failed to protect extracted bundle artifact: $member"
    mode="$(rubble-exec stat --format=%a -- "$path")" ||
      bundle_fail "failed to inspect extracted bundle artifact mode: $member"
    [[ "$mode" == 400 ]] ||
      bundle_fail "extracted bundle artifact has an unsafe mode: $member"
    bundle_log TRACE "$member: normalized staging mode=$mode"
  done

  local size digest
  for index in "${!BUNDLE_ARTIFACT_PATHS[@]}"; do
    member="${BUNDLE_ARTIFACT_MEMBERS[index]}"
    path="${BUNDLE_ARTIFACT_PATHS[index]}"
    size="$(bundle_file_size "$path")"
    [[ "$size" == "${BUNDLE_ARTIFACT_SIZES[index]}" ]] ||
      bundle_fail "bundle artifact size mismatch: $member"
    digest="$(bundle_sha256 "$path")"
    [[ "$digest" == "${BUNDLE_ARTIFACT_DIGESTS[index]}" ]] ||
      bundle_fail "bundle artifact digest mismatch: $member"
    bundle_log TRACE "$member: validated bytes=$size sha256=$digest"
  done
}

bundle_validate_staged_import_pairs() {
  local brick_ordinal output_index content_index checksum_index
  local expected_basename expected_digest
  for brick_ordinal in "${!BUNDLE_BRICK_TARGET_PATHS[@]}"; do
    content_index=$((brick_ordinal * 2))
    checksum_index=$((content_index + 1))
    expected_basename="${BUNDLE_BRICK_TARGET_PATHS[brick_ordinal]##*/}"
    expected_digest="$(
      bundle_sidecar_digest \
        "${BUNDLE_ARTIFACT_PATHS[checksum_index]}" \
        "$expected_basename"
    )"
    [[ "$expected_digest" == "${BUNDLE_ARTIFACT_DIGESTS[content_index]}" ]] ||
      bundle_fail "bundle brick pair is internally inconsistent: $expected_basename"
  done

  local output_offset=$((${#BUNDLE_BRICK_TARGET_PATHS[@]} * 2))
  for output_index in "${!BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
    content_index=$((output_offset + output_index * 2))
    checksum_index=$((content_index + 1))
    expected_basename="${BUNDLE_OUTPUT_TARGET_PATHS[output_index]##*/}.rbl"
    expected_digest="$(
      bundle_sidecar_digest \
        "${BUNDLE_ARTIFACT_PATHS[checksum_index]}" \
        "$expected_basename"
    )"
    [[ "$expected_digest" == "${BUNDLE_ARTIFACT_DIGESTS[content_index]}" ]] ||
      bundle_fail "bundle RBL pair is internally inconsistent: $expected_basename"
  done
}

bundle_publish_noreplace() {
  local staged="$1"
  local destination="$2"
  local error_file="$3"
  rubble-exec chmod 0644 -- "$staged" ||
    bundle_fail "failed to set final bundle mode"
  if ! rubble-exec cp --link --no-target-directory -- "$staged" "$destination" 2>"$error_file"; then
    if [[ -e "$destination" || -L "$destination" ]]; then
      bundle_fail "output destination already exists: $destination"
    fi
    bundle_fail "failed to publish bundle atomically: hard links are required"
  fi
  [[ -f "$destination" && ! -L "$destination" ]] ||
    bundle_fail "published bundle is not a regular file: $destination"
}

bundle_pair_state() {
  local content="$1"
  local checksum="$2"
  local content_exists=0 checksum_exists=0
  [[ -e "$content" || -L "$content" ]] && content_exists=1
  [[ -e "$checksum" || -L "$checksum" ]] && checksum_exists=1
  if ((content_exists == 0 && checksum_exists == 0)); then
    builtin printf 'absent\n'
  elif ((content_exists == 1 && checksum_exists == 1)); then
    builtin printf 'complete\n'
  else
    builtin printf 'partial\n'
  fi
}

bundle_parse_checksum_record() {
  local LC_ALL=C
  local raw="$1"
  local encoded decoded='' character escaped_character digest
  local backslash=$'\\'
  local escaped=0 escape_seen=0 index=0
  if [[ "$raw" == \\* ]]; then
    escaped=1
    raw="${raw:1}"
  fi
  ((${#raw} >= 67)) || return 1
  digest="${raw:0:64}"
  [[ "$digest" != *[!0-9a-f]* && "${raw:64:2}" == ' *' ]] ||
    return 1
  encoded="${raw:66}"
  [[ -n "$encoded" ]] || return 1

  if ((escaped == 0)); then
    [[ "$encoded" != *\\* ]] || return 1
    BUNDLE_CHECKSUM_RECORD_PATH="$encoded"
    return 0
  fi

  while ((index < ${#encoded})); do
    character="${encoded:index:1}"
    if [[ "$character" != "$backslash" ]]; then
      decoded+="$character"
      ((index += 1))
      continue
    fi
    ((index + 1 < ${#encoded})) || return 1
    escaped_character="${encoded:index + 1:1}"
    case "$escaped_character" in
      "$backslash")
        decoded+="$backslash"
        ;;
      n)
        decoded+=$'\n'
        ;;
      *)
        return 1
        ;;
    esac
    escape_seen=1
    ((index += 2))
  done
  ((escape_seen != 0)) || return 1
  BUNDLE_CHECKSUM_RECORD_PATH="$decoded"
}

bundle_validate_directory_checksum_path() {
  local parent="$1"
  local basename="$2"
  local path="$3"
  local relative component current
  [[ "$path" == "$basename/"* ]] || return 1
  relative="${path#"$basename/"}"
  [[ -n "$relative" ]] || return 1
  current="${parent%/}/$basename"

  while [[ "$relative" == */* ]]; do
    component="${relative%%/*}"
    [[ -n "$component" && "$component" != '.' && "$component" != '..' ]] ||
      return 1
    current="$current/$component"
    [[ -d "$current" && ! -L "$current" ]] || return 1
    relative="${relative#*/}"
  done
  [[ -n "$relative" && "$relative" != '.' && "$relative" != '..' ]] ||
    return 1
  [[ -f "$current/$relative" ]]
}

bundle_validate_canonical_output() {
  local LC_ALL=C
  local output="$1"
  local checksum="${output}.SHA256"
  local parent="${output%/*}"
  local checksum_basename="${checksum##*/}"
  local output_basename="${output##*/}"
  local checksum_size fd line='' record_count=0 parsed_size=0 valid=1
  local directory=0
  [[ -n "$parent" ]] || parent='/'
  [[ -e "$output" || -L "$output" ]] || return 1
  [[ -f "$checksum" && ! -L "$checksum" ]] || return 1
  if [[ -f "$output" ]]; then
    directory=0
  elif [[ -d "$output" && ! -L "$output" ]]; then
    directory=1
  else
    return 1
  fi

  checksum_size="$(bundle_file_size "$checksum")"
  exec {fd}<"$checksum" || return 1
  while IFS= builtin read -r line <&${fd}; do
    ((parsed_size += ${#line} + 1))
    if ! bundle_parse_checksum_record "$line"; then
      valid=0
      break
    fi
    ((record_count += 1))
    if ((directory == 0)); then
      if ((record_count != 1)) ||
        [[ "$BUNDLE_CHECKSUM_RECORD_PATH" != "$output_basename" ]]; then
        valid=0
        break
      fi
    elif ! bundle_validate_directory_checksum_path \
      "$parent" "$output_basename" "$BUNDLE_CHECKSUM_RECORD_PATH"; then
      valid=0
      break
    fi
  done
  if [[ -n "$line" ]] || ! exec {fd}<&-; then
    valid=0
  fi
  ((valid != 0 && record_count > 0 && parsed_size == checksum_size)) ||
    return 1
  (
    builtin cd -- "$parent"
    rubble-exec sha256sum --check --strict --quiet -- "$checksum_basename"
  ) >/dev/null 2>&1
}

bundle_preflight_import_targets() {
  local brick_ordinal output_index state target checksum
  local content_index checksum_index actual_digest expected_digest
  BUNDLE_BRICK_INSTALL=()
  for brick_ordinal in "${!BUNDLE_BRICK_TARGET_PATHS[@]}"; do
    target="${BUNDLE_BRICK_TARGET_PATHS[brick_ordinal]}"
    checksum="${target}.SHA256"
    state="$(bundle_pair_state "$target" "$checksum")"
    case "$state" in
      absent)
        BUNDLE_BRICK_INSTALL+=(1)
        bundle_log DEBUG "${BUNDLE_BRICK_SHORT_IDS[brick_ordinal]}: install missing brick pair"
        ;;
      partial)
        bundle_fail "target brick pair is partial and will not be overwritten: $target"
        ;;
      complete)
        [[ -f "$target" && ! -L "$target" && -f "$checksum" && ! -L "$checksum" ]] ||
          bundle_fail "target brick pair is not regular and will not be overwritten: $target"
        content_index=$((brick_ordinal * 2))
        checksum_index=$((content_index + 1))
        expected_digest="$(bundle_sidecar_digest "$checksum" "${target##*/}")"
        actual_digest="$(bundle_sha256 "$target")"
        [[ "$actual_digest" == "$expected_digest" ]] ||
          bundle_fail "target brick checksum is invalid: $target"
        [[ "$actual_digest" == "${BUNDLE_ARTIFACT_DIGESTS[content_index]}" ]] ||
          bundle_fail "target brick differs from the bundle and will not be overwritten: $target"
        actual_digest="$(bundle_sha256 "$checksum")"
        [[ "$actual_digest" == "${BUNDLE_ARTIFACT_DIGESTS[checksum_index]}" ]] ||
          bundle_fail "target brick checksum differs from the bundle and will not be overwritten: $target"
        BUNDLE_BRICK_INSTALL+=(0)
        bundle_log DEBUG "${BUNDLE_BRICK_SHORT_IDS[brick_ordinal]}: reuse matching brick pair"
        ;;
      *)
        bundle_fail "internal error while inspecting target brick pair: $target"
        ;;
    esac
  done

  BUNDLE_OUTPUT_SKIP=()
  BUNDLE_OUTPUT_RBL_INSTALL=()
  for output_index in "${!BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
    target="${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}"
    checksum="${target}.SHA256"
    state="$(bundle_pair_state "$target" "$checksum")"
    case "$state" in
      complete)
        bundle_validate_canonical_output "$target" ||
          bundle_fail "target canonical output checksum is invalid: $target"
        BUNDLE_OUTPUT_SKIP+=(1)
        BUNDLE_OUTPUT_RBL_INSTALL+=(0)
        bundle_log DEBUG "${target##*/}: keep valid canonical output and ignore its RBL state"
        continue
        ;;
      partial)
        bundle_fail "target canonical output pair is partial and will not be overwritten: $target"
        ;;
      absent)
        BUNDLE_OUTPUT_SKIP+=(0)
        ;;
      *)
        bundle_fail "internal error while inspecting target output pair: $target"
        ;;
    esac

    target="${target}.rbl"
    checksum="${target}.SHA256"
    state="$(bundle_pair_state "$target" "$checksum")"
    case "$state" in
      absent)
        BUNDLE_OUTPUT_RBL_INSTALL+=(1)
        bundle_log DEBUG "${target##*/}: install missing RBL pair"
        ;;
      partial)
        bundle_fail "target RBL pair is partial and will not be overwritten: $target"
        ;;
      complete)
        [[ -f "$target" && ! -L "$target" && -f "$checksum" && ! -L "$checksum" ]] ||
          bundle_fail "target RBL pair is not regular and will not be overwritten: $target"
        expected_digest="$(bundle_sidecar_digest "$checksum" "${target##*/}")"
        actual_digest="$(bundle_sha256 "$target")"
        [[ "$actual_digest" == "$expected_digest" ]] ||
          bundle_fail "target RBL checksum is invalid: $target"
        BUNDLE_OUTPUT_RBL_INSTALL+=(0)
        bundle_log DEBUG "${target##*/}: reuse locally valid RBL pair"
        ;;
      *)
        bundle_fail "internal error while inspecting target RBL pair: $target"
        ;;
    esac
  done
}

bundle_register_output_rollbacks() {
  local output_index
  for output_index in "${!BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
    if ((BUNDLE_OUTPUT_SKIP[output_index] == 0)); then
      BUNDLE_ROLLBACK_OUTPUTS+=("${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}")
    fi
  done
}

bundle_unpack_preflight_outputs() {
  local output_index target output_parent rbl
  for output_index in "${!BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
    if ((BUNDLE_OUTPUT_SKIP[output_index] != 0)); then
      continue
    fi
    target="${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}"
    rbl="${target}.rbl"
    output_parent="${target%/*}"
    [[ -n "$output_parent" ]] || output_parent='/'
    bundle_log DEBUG "$target: standalone unpack RBL"
    if ! (
      umask 000
      builtin cd -- "$output_parent"
      rubble-exec zstd --decompress --stdout -- "$rbl" |
        bundle_tar --extract --file=- --keep-old-files --no-same-owner \
          --no-same-permissions --numeric-owner --no-acls --no-xattrs --no-selinux
    ); then
      bundle_fail "standalone RBL unpack failed: $rbl"
    fi
  done

  for output_index in "${!BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
    if ((BUNDLE_OUTPUT_SKIP[output_index] == 0)); then
      bundle_validate_canonical_output "${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}" ||
        bundle_fail "standalone canonical output checksum is invalid: ${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}"
    fi
  done
}

bundle_standalone_unpack() {
  [[ "$#" -eq 6 && "$1" == '-q' && "$2" == 'unpack' && "$3" == '--depth' &&
    "$4" =~ ^(0|[1-9][0-9]*)$ && "$5" == '--' && -n "$6" ]] ||
    bundle_fail "standalone unpack received invalid arguments"
  local requested_depth="$4"
  local requested_root="$6"
  local standalone_input="${BUNDLE_STANDALONE_BUNDLE:-}"
  bundle_validate_original_bundle_policy
  [[ -n "$standalone_input" && -f "$standalone_input" && ! -L "$standalone_input" ]] ||
    bundle_fail "standalone unpack bundle is missing: $standalone_input"

  local temporary_parent="${TMPDIR:-/tmp}"
  local stage
  stage="$(bundle_private_dir "$temporary_parent" 'inventory-unpack')" ||
    bundle_fail "failed to create a private standalone unpack staging directory"
  BUNDLE_CLEANUP_DIRS+=("$stage")
  builtin trap bundle_cleanup EXIT
  builtin trap 'exit 129' HUP
  builtin trap 'exit 130' INT
  builtin trap 'exit 143' TERM
  BUNDLE_IMPORT_ACTIVE=1

  local manifest_dir="$stage/manifest"
  local archive_snapshot="$stage/bundle.tar"
  local archive
  local manifest="$manifest_dir/$BUNDLE_MANIFEST"
  local tar_error="$stage/tar.stderr"
  local tar_names="$stage/tar.names"
  local artifact_list="$stage/artifact.members"
  local artifacts_dir="$stage/artifacts"
  rubble-exec mkdir -m 0700 -- "$manifest_dir" ||
    bundle_fail "failed to create private standalone manifest staging"
  bundle_select_import_archive "$standalone_input" "$archive_snapshot"
  archive="$BUNDLE_IMPORT_ARCHIVE"
  bundle_import_list_tar "$archive" "$tar_names" "$tar_error"
  bundle_extract_tar_member "$archive" "$BUNDLE_MANIFEST" "$manifest" "$tar_error"
  bundle_parse_manifest "$manifest"
  [[ "$BUNDLE_IMPORT_DEPTH" == "$requested_depth" ]] ||
    bundle_manifest_fail "standalone unpack depth differs from manifest"
  bundle_build_target_paths
  [[ "$BUNDLE_IMPORT_ROOT_BRK" == "$requested_root" ]] ||
    bundle_manifest_fail "standalone unpack root differs from manifest"
  bundle_validate_target_path_uniqueness
  bundle_validate_import_artifact_schema
  bundle_validate_import_tar_members
  bundle_prepare_runtime_home
  bundle_write_import_artifact_list "$artifact_list"
  rubble-exec mkdir -m 0700 -- "$artifacts_dir" ||
    bundle_fail "failed to create private standalone artifact staging"
  bundle_extract_import_artifacts \
    "$archive" "$artifacts_dir" "$artifact_list" "$tar_error"
  bundle_validate_staged_import_pairs
  bundle_preflight_import_targets

  bundle_register_output_rollbacks
  bundle_log INFO "standalone unpack start: root=$BUNDLE_ROOT_SHORT_ID depth=$BUNDLE_IMPORT_DEPTH outputs=${#BUNDLE_OUTPUT_TARGET_PATHS[@]}"
  bundle_unpack_preflight_outputs
  BUNDLE_IMPORT_COMMITTED=1
  bundle_log INFO "standalone unpack complete: root=$BUNDLE_ROOT_SHORT_ID depth=$BUNDLE_IMPORT_DEPTH outputs=${#BUNDLE_OUTPUT_TARGET_PATHS[@]}"
}

bundle_link_import_artifact() {
  local staged="$1"
  local target="$2"
  local error_file="$3"
  if ! rubble-exec cp --link --no-target-directory -- "$staged" "$target" 2>"$error_file"; then
    if [[ -e "$target" || -L "$target" ]]; then
      bundle_fail "target artifact appeared during import and will not be overwritten: $target"
    fi
    bundle_fail "failed to install target artifact atomically: hard links are required for $target"
  fi
  [[ -f "$target" && ! -L "$target" ]] ||
    bundle_fail "installed target artifact is not a regular file: $target"
  BUNDLE_ROLLBACK_FILES+=("$target")
}

bundle_install_pair() {
  local source_content="$1"
  local source_checksum="$2"
  local target_content="$3"
  local target_checksum="${target_content}.SHA256"
  local target_parent="${target_content%/*}"
  local install_stage
  [[ -n "$target_parent" ]] || target_parent='/'
  rubble-exec mkdir -p -- "$target_parent" ||
    bundle_fail "failed to create target store directory: $target_parent"
  target_parent="$(builtin cd -- "$target_parent" && builtin pwd -P)" ||
    bundle_fail "failed to resolve target store directory: $target_parent"

  install_stage="$(bundle_private_dir "$target_parent" 'inventory-install')" ||
    bundle_fail "failed to create private target staging: $target_parent"
  BUNDLE_CLEANUP_DIRS+=("$install_stage")
  bundle_snapshot_regular "$source_content" "$install_stage/content"
  bundle_snapshot_regular "$source_checksum" "$install_stage/checksum"
  rubble-exec chmod 0644 -- "$install_stage/content" "$install_stage/checksum" ||
    bundle_fail "failed to set imported artifact modes for: $target_content"
  bundle_link_import_artifact \
    "$install_stage/content" "$target_content" "$install_stage/content.stderr"
  bundle_link_import_artifact \
    "$install_stage/checksum" "$target_checksum" "$install_stage/checksum.stderr"
}

bundle_install_import_artifacts() {
  local brick_ordinal output_index content_index checksum_index
  for brick_ordinal in "${!BUNDLE_BRICK_TARGET_PATHS[@]}"; do
    if ((BUNDLE_BRICK_INSTALL[brick_ordinal] == 0)); then
      continue
    fi
    content_index=$((brick_ordinal * 2))
    checksum_index=$((content_index + 1))
    bundle_install_pair \
      "${BUNDLE_ARTIFACT_PATHS[content_index]}" \
      "${BUNDLE_ARTIFACT_PATHS[checksum_index]}" \
      "${BUNDLE_BRICK_TARGET_PATHS[brick_ordinal]}"
  done

  local output_offset=$((${#BUNDLE_BRICK_TARGET_PATHS[@]} * 2))
  for output_index in "${!BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
    if ((BUNDLE_OUTPUT_SKIP[output_index] != 0 ||
      BUNDLE_OUTPUT_RBL_INSTALL[output_index] == 0)); then
      continue
    fi
    content_index=$((output_offset + output_index * 2))
    checksum_index=$((content_index + 1))
    bundle_install_pair \
      "${BUNDLE_ARTIFACT_PATHS[content_index]}" \
      "${BUNDLE_ARTIFACT_PATHS[checksum_index]}" \
      "${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}.rbl"
  done
}

bundle_import() {
  local input="$1"
  bundle_has_control_text "$input" &&
    bundle_fail "input path contains unsupported control characters"
  bundle_validate_original_bundle_policy
  bundle_log INFO "import start: input=$input"

  local temporary_parent="${TMPDIR:-/tmp}"
  local stage
  stage="$(bundle_private_dir "$temporary_parent" 'inventory-import')" ||
    bundle_fail "failed to create a private import staging directory"
  BUNDLE_CLEANUP_DIRS+=("$stage")
  builtin trap bundle_cleanup EXIT
  builtin trap 'exit 129' HUP
  builtin trap 'exit 130' INT
  builtin trap 'exit 143' TERM
  BUNDLE_IMPORT_ACTIVE=1

  local manifest_dir="$stage/manifest"
  local archive_snapshot="$stage/bundle.tar"
  local archive
  local tar_error="$stage/tar.stderr"
  local tar_names="$stage/tar.names"
  rubble-exec mkdir -m 0700 -- "$manifest_dir" ||
    bundle_fail "failed to create private import manifest staging"
  bundle_select_import_archive "$input" "$archive_snapshot"
  archive="$BUNDLE_IMPORT_ARCHIVE"
  bundle_import_list_tar "$archive" "$tar_names" "$tar_error"

  local manifest="$manifest_dir/$BUNDLE_MANIFEST"
  bundle_extract_tar_member "$archive" "$BUNDLE_MANIFEST" "$manifest" "$tar_error"
  bundle_parse_manifest "$manifest"
  bundle_build_target_paths
  bundle_validate_target_path_uniqueness
  bundle_validate_import_artifact_schema
  bundle_validate_import_tar_members
  bundle_prepare_runtime_home

  local artifact_list="$stage/artifact.members"
  local artifacts_dir="$stage/artifacts"
  bundle_write_import_artifact_list "$artifact_list"
  rubble-exec mkdir -m 0700 -- "$artifacts_dir" ||
    bundle_fail "failed to create private import artifact staging"
  bundle_extract_import_artifacts \
    "$archive" "$artifacts_dir" "$artifact_list" "$tar_error"
  bundle_validate_staged_import_pairs
  bundle_preflight_import_targets
  bundle_install_import_artifacts

  local output_index
  bundle_register_output_rollbacks
  bundle_log INFO "${BUNDLE_ROOT_SHORT_ID}: unpack root once (depth=$BUNDLE_IMPORT_DEPTH)"
  if ((BUNDLE_IMPORT_ONLY != 0)); then
    bundle_log INFO "standalone unpack start: root=$BUNDLE_ROOT_SHORT_ID depth=$BUNDLE_IMPORT_DEPTH outputs=${#BUNDLE_OUTPUT_TARGET_PATHS[@]}"
    bundle_unpack_preflight_outputs
    bundle_log INFO "standalone unpack complete: root=$BUNDLE_ROOT_SHORT_ID depth=$BUNDLE_IMPORT_DEPTH outputs=${#BUNDLE_OUTPUT_TARGET_PATHS[@]}"
  else
    BUNDLE_STANDALONE_BUNDLE="$archive" \
      "$RUBBLE_EXECUTABLE" -q unpack \
      --depth "$BUNDLE_IMPORT_DEPTH" \
      -- "$BUNDLE_IMPORT_ROOT_BRK" >&2 ||
      bundle_fail "${BUNDLE_ROOT_SHORT_ID}: root unpack failed"

    for output_index in "${!BUNDLE_OUTPUT_TARGET_PATHS[@]}"; do
      bundle_validate_canonical_output "${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}" ||
        bundle_fail "imported canonical output checksum is invalid: ${BUNDLE_OUTPUT_TARGET_PATHS[output_index]}"
    done
  fi

  BUNDLE_IMPORT_COMMITTED=1
  bundle_log INFO "import complete: root=$BUNDLE_ROOT_SHORT_ID depth=$BUNDLE_IMPORT_DEPTH bricks=${#BUNDLE_BRICK_TARGET_PATHS[@]} outputs=${#BUNDLE_OUTPUT_TARGET_PATHS[@]}"
  builtin printf '%s\n' "$BUNDLE_IMPORT_ROOT_BRK"
}

bundle_export() {
  local output="$1"
  local depth="$2"
  local brick="$3"
  bundle_normalize_destination "$output"
  bundle_load_export_inventory "$BUNDLE_EXPORT_INVENTORY_FILE"
  bundle_log INFO "export start: root=$brick depth=$depth output=$BUNDLE_DESTINATION"
  bundle_collect_inventory "$brick" "$depth"

  local root_brk=''
  local index
  for index in "${!BUNDLE_BRICK_SHORT_IDS[@]}"; do
    if [[ "${BUNDLE_BRICK_SHORT_IDS[index]}" == "$BUNDLE_ROOT_SHORT_ID" ]]; then
      root_brk="${BUNDLE_BRICK_PATHS[index]}"
      break
    fi
  done
  [[ -n "$root_brk" ]] || bundle_fail "failed to resolve canonical root metadata"

  if ((BUNDLE_EXPORT_INVENTORY_ACTIVE != 0)); then
    bundle_log INFO "${BUNDLE_ROOT_SHORT_ID}: pack exact inventory (bricks=${#BUNDLE_BRICK_PATHS[@]})"
    for index in "${!BUNDLE_BRICK_PATHS[@]}"; do
      "$RUBBLE_EXECUTABLE" -q pack --depth 1 -- "${BUNDLE_BRICK_PATHS[index]}" >&2 ||
        bundle_fail "${BUNDLE_BRICK_SHORT_IDS[index]}: exact inventory pack failed"
    done
  else
    bundle_log INFO "${BUNDLE_ROOT_SHORT_ID}: pack root once (depth=$depth)"
    "$RUBBLE_EXECUTABLE" -q pack --depth "$depth" -- "$root_brk" >&2 ||
      bundle_fail "${BUNDLE_ROOT_SHORT_ID}: root pack failed"
  fi

  local destination_parent="${BUNDLE_DESTINATION%/*}"
  [[ -n "$destination_parent" ]] || destination_parent='/'
  local stage
  stage="$(bundle_private_dir "$destination_parent" 'inventory-export')" ||
    bundle_fail "failed to create a private staging directory"
  BUNDLE_CLEANUP_DIRS+=("$stage")
  builtin trap bundle_cleanup EXIT
  builtin trap 'exit 129' HUP
  builtin trap 'exit 130' INT
  builtin trap 'exit 143' TERM

  local members_dir="$stage/members"
  rubble-exec mkdir -m 0700 -- "$members_dir" ||
    bundle_fail "failed to create private artifact staging"

  local content_member checksum_member
  for index in "${!BUNDLE_BRICK_PATHS[@]}"; do
    builtin printf -v content_member 'brick-%08d.brick' "$index"
    checksum_member="${content_member}.SHA256"
    bundle_stage_pair \
      "$members_dir" "${BUNDLE_BRICK_PATHS[index]}" \
      brick brick_checksum "$index" - "$content_member" "$checksum_member"
  done
  for index in "${!BUNDLE_OUTPUT_PATHS[@]}"; do
    builtin printf -v content_member 'output-%08d-%08d.rbl' \
      "${BUNDLE_OUTPUT_BRICK_ORDINALS[index]}" \
      "${BUNDLE_OUTPUT_ORDINALS[index]}"
    checksum_member="${content_member}.SHA256"
    bundle_stage_pair \
      "$members_dir" "${BUNDLE_OUTPUT_PATHS[index]}.rbl" \
      rbl rbl_checksum \
      "${BUNDLE_OUTPUT_BRICK_ORDINALS[index]}" \
      "${BUNDLE_OUTPUT_ORDINALS[index]}" \
      "$content_member" "$checksum_member"
  done

  local manifest="$members_dir/$BUNDLE_MANIFEST"
  local archive="$stage/bundle.tar"
  local tar_error="$stage/tar.stderr"
  local tar_names="$stage/tar.names"
  local tar_members="$stage/tar.members"
  bundle_write_manifest "$manifest" "$depth"
  bundle_write_tar_member_list "$tar_members"
  bundle_tar_create "$archive" "$members_dir" "$tar_members" "$tar_error"
  bundle_validate_tar_members "$archive" "$tar_names" "$tar_error"

  local bundle_size
  bundle_size="$(bundle_file_size "$archive")"
  bundle_publish_noreplace "$archive" "$BUNDLE_DESTINATION" "$stage/publish.stderr"
  bundle_log INFO "export complete: output=$BUNDLE_DESTINATION bytes=$bundle_size bricks=${#BUNDLE_BRICK_SHORT_IDS[@]} outputs=${#BUNDLE_OUTPUT_NAMES[@]}"
  builtin printf '%s\n' "$BUNDLE_DESTINATION"
}

bundle_main() {
  bundle_require_bash
  if [[ "${BUNDLE_STANDALONE_REQUEST:-0}" == 1 ]]; then
    bundle_load_tools
    bundle_require_gnu_tools
    bundle_standalone_unpack "$@"
    return
  fi
  if (($# == 0)); then
    bundle_usage >&2
    exit 2
  fi
  local command_name="$1"
  shift
  case "$command_name" in
    export)
      bundle_parse_export_args "$@"
      bundle_load_tools
      bundle_require_gnu_tools
      bundle_export "$BUNDLE_EXPORT_OUTPUT" "$BUNDLE_EXPORT_DEPTH" "$BUNDLE_EXPORT_BRICK"
      ;;
    --help | -h | help)
      bundle_usage
      ;;
    import)
      bundle_parse_import_args "$@"
      bundle_load_tools
      bundle_require_gnu_tools
      bundle_import "$BUNDLE_IMPORT_INPUT"
      ;;
    *)
      bundle_usage >&2
      bundle_fail "unknown command '$command_name'"
      ;;
  esac
}

bundle_main "$@"
exit $?
