# Shared builder authentication runtime. Source this file before activation.

rubble_auth_library_dir="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd)"
rubble_auth_owned_dir=''
rubble_auth_executable=''

rubble_auth_cleanup() {
  if [[ -n "${rubble_auth_owned_dir}" ]]; then
    local cleanup_relative='cleanup-auth.sh'
    # Cleanup must still run when the distributed config cannot be loaded.
    (unset RUBBLE_CONFIG RUBBLE_CREDENTIALS
     "${rubble_auth_executable}" script --inherit-env --language bash "${rubble_auth_library_dir}/${cleanup_relative}" "${rubble_auth_owned_dir}")
    rubble_auth_owned_dir=''
    rubble_auth_executable=''
  fi
}

rubble_auth_activate() {
  local executable="$1" directory="$2"
  rubble_auth_executable="${executable}"
  local action_relative='open-pipeline-auth.mjs'
  mkdir -m 700 -- "${directory}" || return
  rubble_auth_owned_dir="${directory}"
  local config_file="${directory}/config.yaml"
  local credentials_file="${directory}/credentials.yaml"
  local arguments=()

  local ciphertext_relative='pipeline-auth.enc'
  arguments=(local-files '17824ec6-e51d-42a6-866a-8104fb593cd8' "${rubble_auth_library_dir}/${ciphertext_relative}")

  if ! "${executable}" script --inherit-env "${rubble_auth_library_dir}/${action_relative}" \
      "${arguments[@]}" "${config_file}" "${credentials_file}"; then
    rubble_auth_cleanup
    return 1
  fi
  unset RUBBLE_PIPELINE_AUTH_KEY RUBBLE_SERVER_CONFIG RUBBLE_SERVER_CREDENTIALS
  unset RUBBLE_SERVER_CONFIG_FILE RUBBLE_SERVER_CREDENTIALS_FILE
  export RUBBLE_CONFIG="${config_file}" RUBBLE_CREDENTIALS="${credentials_file}"
}
