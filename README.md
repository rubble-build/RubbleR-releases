# RubbleR Releases

Release artifacts and generated GitHub Actions validation payloads for RubbleR.

The Stage-1 bootstrap workflow is manual-only. Its verified public bootstrap
inputs are:

- `https://store.rubble.build/n4w263q-rubble-inventory-bundle-import`
- `https://store.rubble.build/f6glb7k-rubble.tar`

The Rubble bundle contains
`f6glb7kwomsuin53gprzt6f35czrrbnpmwvbpfznoipkb6dkkecq-rubble` and has
SHA-256 `1719c2ae1ab0178ae8a3a42f029eff95c42d7a1bf19d83299017a86e29f2a999`.
This is the current required bootstrap identity for this validation repository's
cache-miss contract: a completely absent remote archive must let
`pull --depth 1 --unpack` continue to build. Bootstrap inputs are managed
separately and are not included in normal generated root releases.

The manual Stage-1 bootstrap workflow still uses the repository's dedicated
R2 secrets. Generated builder workflows do not use or field-merge those
secrets. The validation repository exercises both explicit authentication
sources: complete files preconfigured as `RUBBLE_SERVER_CONFIG` and
`RUBBLE_SERVER_CREDENTIALS`, and complete local files encrypted into a one-use
payload whose key exists only in that pipeline's unique GitHub Environment.

This validation repository currently uses the trusted-contributor convenience
level. Only ciphertext enters Git in `local-files` mode, runner plaintext is
temporary, and the local publisher deletes the Environment after the observed
run. All repository writers and workflow declarations are trusted.

`.github/workflows/rubble-cleanup.yml` is an optional best-effort second
cleanup path. `RUBBLE_ENVIRONMENT_ADMIN_TOKEN` is a repository secret and can
be explicitly requested by another same-repository workflow; it is not a
tenant-isolation boundary. The current private-repository plan also does not
enforce the protected-default-branch assumption. Operators must verify the
`workflow_run` name binding and actual cleanup runs before relying on it.
Abrupt local-publisher loss, an unregistered run, or a persistent deletion
failure may leave an Environment until manual cleanup. Stronger protected or
separate control planes are future optional security levels, not requirements
for this validation repository's trusted main flow.

`fixtures/github-actions-dag.yaml` is a non-Rubble fan-out/fan-in validation
graph. From the RubbleR checkout, generate, publish, and wait for its one-use
workflow branch with:

```sh
/workspace/src/RubbleR/target/release/rubble \
  --config /workspace/src/RubbleR-releases/.rubble/github-actions-config.yaml \
  --credentials /home/chaifeng/.config/rubble/credentials.yaml \
  build --builder github-actions \
  /workspace/src/RubbleR-releases/fixtures/github-actions-dag.yaml
```
