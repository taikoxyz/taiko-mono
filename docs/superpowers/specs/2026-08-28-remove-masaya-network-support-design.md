# Remove Masaya Network Support

## Summary

Remove active support for the Masaya network (chain ID `167011`) from every package in this monorepo. After this change, the Go and Rust Taiko clients treat the chain as unsupported through their existing generic behavior.

Historical release notes remain unchanged. Pinned upstream Taiko Geth and Alethia Reth dependencies may continue to define Masaya constants internally, but no package in this repository will import or use those constants for active support.

## Current State

Active Masaya handling exists in two packages:

- `packages/taiko-client` registers a display name and fork schedule for Masaya and returns its Shasta activation time from the manifest helper.
- `packages/taiko-client-rs` re-exports Masaya's chain ID, imports its hardfork schedule, and accepts it in fork-condition lookups.

The Rust client changelog also records when Masaya support was added. That historical entry is not active configuration and will be preserved.

## Runtime Design

### Go client

Remove Masaya from the `NetworkNames` registry and from `ChainConfig.forkInfo`. Chain ID `167011` will therefore receive the same unknown-network description and missing fork schedule as any other unregistered chain.

Remove the Masaya case from `ShastaForkTimeByChainID` and update its documentation. The helper will use its existing unknown-chain fallback for `167011`; no new compatibility shim or error type will be introduced.

### Rust client

Remove the Masaya hardfork schedule and chain ID imports/re-exports from the Shasta protocol constants module. Remove the Masaya arm from `fork_condition_for_chain`.

Shasta and Unzen fork-condition lookups for chain ID `167011` will then return the existing `ForkConfigError::UnsupportedChainId(167011)` error. Downstream timestamp and activation helpers will inherit that behavior without interface changes.

## Files

Expected production and test changes are limited to:

- `packages/taiko-client/pkg/config/chain_config.go`
- `packages/taiko-client/pkg/config/chain_config_test.go` (new regression coverage)
- `packages/taiko-client/bindings/manifest/manifest.go`
- `packages/taiko-client/bindings/manifest/manifest_test.go`
- `packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs`

No dependency manifests, lockfiles, or changelogs will change.

## Testing

Implementation will begin with negative regression tests:

- Go tests will assert that chain ID `167011` has neither a registered network name nor fork information.
- Rust tests will assert that Shasta and Unzen fork-condition lookups for `167011` return `UnsupportedChainId`.
- Existing positive Masaya assertions in the Go manifest tests will be removed because Masaya is no longer a supported chain.

Verification will include:

1. Targeted Go tests for `pkg/config` and `bindings/manifest`.
2. Rust protocol tests, including the no-default-features variant when practical.
3. Go and Rust formatting checks for all changed files.
4. A repository search confirming that the Masaya name remains only in the preserved changelog and that chain ID `167011` appears in active code only as negative regression coverage.
5. A final diff and working-tree review before committing.

## Pull Request

Work will be committed on `codex/remove-masaya-network-support` and pushed to the configured origin. The draft pull request will use the title `chore(taiko-client,taiko-client-rs): remove Masaya network support` and will document the runtime behavior change and exact verification results.

## Non-Goals

- Removing or rewriting historical changelog entries.
- Updating Taiko Geth, Alethia Reth, or other upstream dependencies solely to delete their Masaya constants.
- Refactoring supported-network configuration into a shared registry.
- Changing generic unknown-chain behavior or public APIs.
