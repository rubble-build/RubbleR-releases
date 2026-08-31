# RubbleR Releases

Release artifacts and generated GitHub Actions validation payloads for RubbleR.

The Stage-1 bootstrap workflow is manual-only. Its verified public bootstrap
inputs are:

- `https://store.rubble.build/n4w263q-rubble-inventory-bundle-import`
- `https://store.rubble.build/hh4idod-rubble.tar`

The manual Stage-1 bootstrap workflow still uses the repository's dedicated
R2 secrets. Generated builder workflows do not use or field-merge those
secrets. Each generation encrypts the complete locally selected Rubble config
and credential files into a one-use payload; the runner decrypts them only
with the key stored in that pipeline's unique GitHub Environment.

The protected default branch owns `.github/workflows/rubble-cleanup.yml`.
Configure `RUBBLE_ENVIRONMENT_ADMIN_TOKEN` as a repository secret with a token
that can delete repository Environments. Generated pipeline branches cannot
read that token or modify the trusted cleanup declaration.

`fixtures/github-actions-dag.yaml` is a non-Rubble fan-out/fan-in validation
graph. From the RubbleR checkout, generate, publish, and wait for its one-use
workflow branch with:

```sh
/workspace/src/RubbleR/target/release/rubble \
  --config /home/chaifeng/.config/rubble/config.yaml \
  --credentials /home/chaifeng/.config/rubble/credentials.yaml \
  build --builder github-actions \
  /workspace/src/RubbleR-releases/fixtures/github-actions-dag.yaml
```
