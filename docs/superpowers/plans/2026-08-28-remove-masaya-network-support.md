# Remove Masaya Network Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove active Masaya network support from the Go and Rust Taiko clients and open a verified draft pull request.

**Architecture:** Delete Masaya-specific registry and fork-schedule branches while preserving each client's existing generic unsupported-chain behavior. Add negative tests for chain ID `167011`, keep historical release notes and upstream dependency pins unchanged, and verify both packages independently before opening the draft PR.

**Tech Stack:** Go 1.26, Testify, Rust 1.95, Cargo, Alethia Reth chain specifications, Git, GitHub CLI

**Spec:** `docs/superpowers/specs/2026-08-28-remove-masaya-network-support-design.md`

## Global Constraints

- Historical release notes remain unchanged.
- Pinned upstream Taiko Geth and Alethia Reth dependencies may continue to define Masaya constants internally.
- No dependency manifests, lockfiles, or changelogs will change.
- Do not add a compatibility shim, new error type, shared network registry, or public API change.
- Go must use the existing unknown-network behavior for chain ID `167011`.
- Rust must return `ForkConfigError::UnsupportedChainId(167011)` for Shasta and Unzen lookups.
- Work on branch `codex/remove-masaya-network-support`.
- Use draft PR title `chore(taiko-client,taiko-client-rs): remove Masaya network support`.

---

### Task 1: Remove Go client support

**Files:**

- Create: `packages/taiko-client/pkg/config/chain_config_test.go`
- Modify: `packages/taiko-client/pkg/config/chain_config.go:45-51,96-113`
- Modify: `packages/taiko-client/bindings/manifest/manifest.go:80-103`
- Modify: `packages/taiko-client/bindings/manifest/manifest_test.go:26-42`

**Interfaces:**

- Consumes: `NetworkNames map[uint64]string`, `(*ChainConfig).forkInfo() (forkInfo, bool)`, and `ShastaForkTimeByChainID(*big.Int) uint64`.
- Produces: Go runtime configuration with no special handling for chain ID `167011`; no public signature changes.

- [ ] **Step 1: Add a failing negative regression test**

Create `packages/taiko-client/pkg/config/chain_config_test.go` with this content:

```go
package config

import (
	"math/big"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestRemovedChainIsUnsupported(t *testing.T) {
	const removedChainID = uint64(167_011)

	_, ok := NetworkNames[removedChainID]
	require.False(t, ok)

	_, ok = (&ChainConfig{ChainID: new(big.Int).SetUint64(removedChainID)}).forkInfo()
	require.False(t, ok)
}
```

- [ ] **Step 2: Run the new test and confirm the red state**

Run:

```bash
go test ./packages/taiko-client/pkg/config -run '^TestRemovedChainIsUnsupported$' -count=1
```

Expected: FAIL on the first `require.False` because chain ID `167011` is still present in `NetworkNames`.

- [ ] **Step 3: Remove Masaya from the Go chain registry and fork schedule**

In `chain_config.go`, make the supported network map contain only these entries:

```go
var NetworkNames = map[uint64]string{
	params.TaikoInternalNetworkID.Uint64(): "Taiko Internal Devnet",
	params.TaikoHoodiNetworkID.Uint64():    "Taiko Hoodi Testnet",
	params.TaikoMainnetNetworkID.Uint64():  "Taiko Mainnet",
}
```

Delete the complete `case params.MasayaDevnetNetworkID.Uint64()` branch from `(*ChainConfig).forkInfo()`, leaving the internal, Hoodi, mainnet, and default branches unchanged.

- [ ] **Step 4: Remove Masaya from the Go manifest helper and tests**

Update the `ShastaForkTimeByChainID` documentation and switch to this form:

```go
// ShastaForkTimeByChainID returns the Shasta fork activation timestamp based on chainID.
//
// The values are sourced from the taiko-geth fork schedule (the same source consumed by
// pkg/config.ChainConfig), so the driver stays in lockstep with the execution client. A return
// value of 0 means Shasta is active from genesis for the internal devnet, which imposes no
// additional lower-bound constraint on derived block timestamps. Unknown or nil chain IDs are
// treated as genesis-activated (0).
func ShastaForkTimeByChainID(chainID *big.Int) uint64 {
	if chainID == nil {
		return 0
	}

	switch chainID.Uint64() {
	case params.TaikoMainnetNetworkID.Uint64():
		return gethcore.MainnetShastaTime
	case params.TaikoHoodiNetworkID.Uint64():
		return gethcore.HoodiShastaTime
	case params.TaikoInternalNetworkID.Uint64():
		return gethcore.InternalShastaTime
	default:
		return 0
	}
}
```

Delete these obsolete assertions from `TestShastaForkTimeByChainID`:

```diff
- require.Equal(t, gethcore.MasayaShastaTime, ShastaForkTimeByChainID(params.MasayaDevnetNetworkID))
- require.Zero(t, ShastaForkTimeByChainID(params.MasayaDevnetNetworkID))
```

Keep the mainnet, Hoodi, internal devnet, nil, and unknown-chain assertions unchanged.

- [ ] **Step 5: Format and run the focused Go tests**

Run:

```bash
gofmt -w packages/taiko-client/pkg/config/chain_config.go packages/taiko-client/pkg/config/chain_config_test.go packages/taiko-client/bindings/manifest/manifest.go packages/taiko-client/bindings/manifest/manifest_test.go
go test ./packages/taiko-client/pkg/config ./packages/taiko-client/bindings/manifest -count=1
```

Expected: both packages report `ok`.

- [ ] **Step 6: Confirm the Go package contains no active Masaya name**

Run:

```bash
rg -n -i 'masaya' packages/taiko-client
```

Expected: no output and exit status 1.

- [ ] **Step 7: Commit the Go removal**

```bash
git add packages/taiko-client/pkg/config/chain_config.go packages/taiko-client/pkg/config/chain_config_test.go packages/taiko-client/bindings/manifest/manifest.go packages/taiko-client/bindings/manifest/manifest_test.go
git commit -m "chore(taiko-client): remove Masaya network support"
```

### Task 2: Remove Rust client support

**Files:**

- Modify: `packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs:5-12,180-192,256-287`

**Interfaces:**

- Consumes: `shasta_fork_condition_for_chain(u64) -> ForkConfigResult<ForkCondition>` and `unzen_fork_condition_for_chain(u64) -> ForkConfigResult<ForkCondition>`.
- Produces: both functions return `Err(ForkConfigError::UnsupportedChainId(167011))` for the removed chain; no signature changes.

- [ ] **Step 1: Extend the unsupported-chain test with the removed chain ID**

Replace `unsupported_chain_ids_error_on_fork_condition_lookup` with:

```rust
#[test]
fn unsupported_chain_ids_error_on_fork_condition_lookup() {
    for chain_id in [u64::MAX, 167_011] {
        assert!(matches!(
            shasta_fork_condition_for_chain(chain_id),
            Err(ForkConfigError::UnsupportedChainId(error_chain_id))
                if error_chain_id == chain_id
        ));
        assert!(matches!(
            unzen_fork_condition_for_chain(chain_id),
            Err(ForkConfigError::UnsupportedChainId(error_chain_id))
                if error_chain_id == chain_id
        ));
    }
}
```

- [ ] **Step 2: Run the Rust test and confirm the red state**

From `packages/taiko-client-rs`, run:

```bash
cargo test --locked -p protocol --lib unsupported_chain_ids_error_on_fork_condition_lookup
```

Expected: FAIL for chain ID `167011` because the Shasta lookup still returns an `Ok` fork condition.

- [ ] **Step 3: Delete the Rust imports, re-export, and lookup arm**

Change the chain-spec imports to:

```rust
use alethia_reth_chainspec::hardfork::{
    TAIKO_DEVNET_HARDFORKS, TAIKO_HOODI_HARDFORKS, TAIKO_MAINNET_HARDFORKS, TaikoHardfork,
};
pub use alethia_reth_chainspec::{
    TAIKO_DEVNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID,
};
```

Change the lookup match to:

```rust
match chain_id {
    TAIKO_DEVNET_CHAIN_ID => Ok(TAIKO_DEVNET_HARDFORKS.fork(hardfork)),
    TAIKO_HOODI_CHAIN_ID => Ok(TAIKO_HOODI_HARDFORKS.fork(hardfork)),
    TAIKO_MAINNET_CHAIN_ID => Ok(TAIKO_MAINNET_HARDFORKS.fork(hardfork)),
    _ => Err(ForkConfigError::UnsupportedChainId(chain_id)),
}
```

- [ ] **Step 4: Format and rerun the focused Rust test**

From `packages/taiko-client-rs`, run:

```bash
cargo +nightly-2025-09-27 fmt
cargo test --locked -p protocol --lib unsupported_chain_ids_error_on_fork_condition_lookup
```

Expected: the focused test passes.

- [ ] **Step 5: Run both Rust protocol test variants and formatting check**

From `packages/taiko-client-rs`, run:

```bash
cargo test --locked -p protocol
cargo test --locked -p protocol --no-default-features
just fmt-check
```

Expected: all tests and the formatting check pass.

- [ ] **Step 6: Confirm the Rust package preserves only historical Masaya text**

From the repository root, run:

```bash
rg -n -i 'masaya' packages/taiko-client-rs --glob '!CHANGELOG.md'
```

Expected: no output and exit status 1.

- [ ] **Step 7: Commit the Rust removal**

```bash
git add packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs
git commit -m "chore(taiko-client-rs): remove Masaya network support"
```

### Task 3: Verify the combined change and open the draft PR

**Files:**

- Verify: `docs/superpowers/specs/2026-08-28-remove-masaya-network-support-design.md`
- Verify: `docs/superpowers/plans/2026-08-28-remove-masaya-network-support.md`
- Verify: all files changed by Tasks 1 and 2

**Interfaces:**

- Consumes: the committed Go and Rust unsupported-chain behavior from Tasks 1 and 2.
- Produces: a pushed `codex/remove-masaya-network-support` branch and a draft GitHub pull request.

- [ ] **Step 1: Rerun the combined targeted tests**

From the repository root, run:

```bash
go test ./packages/taiko-client/pkg/config ./packages/taiko-client/bindings/manifest -count=1
```

From `packages/taiko-client-rs`, run:

```bash
cargo test --locked -p protocol
cargo test --locked -p protocol --no-default-features
```

Expected: every command passes.

- [ ] **Step 2: Audit names, chain IDs, formatting, and the final diff**

From the repository root, run:

```bash
rg -n -i 'masaya' packages --glob '!taiko-client-rs/CHANGELOG.md'
rg -n '167_?011' packages
git diff main...HEAD --check
git status --short
```

Expected:

- The Masaya-name search returns no output.
- The chain-ID search returns only the preserved changelog entry and the two negative regression tests.
- `git diff --check` returns no output.
- `git status --short` returns no output.

- [ ] **Step 3: Review the exact commits and changed files**

Run:

```bash
git log --oneline main..HEAD
git diff --stat main...HEAD
git diff main...HEAD
```

Expected: the diff contains the design, this plan, the focused Go removal, the focused Rust removal, and no dependency or changelog changes.

- [ ] **Step 4: Push the feature branch**

Run:

```bash
git push -u origin codex/remove-masaya-network-support
```

Expected: the branch is created on `origin` and configured as the local upstream.

- [ ] **Step 5: Open the draft pull request**

Run:

```bash
gh pr create --draft \
  --base main \
  --head codex/remove-masaya-network-support \
  --title "chore(taiko-client,taiko-client-rs): remove Masaya network support" \
  --body $'## Summary\n\n- remove Masaya network registration and fork scheduling from the Go client\n- make the Rust protocol reject chain ID 167011 through the existing unsupported-chain error\n- preserve historical release notes and upstream dependency pins\n\n## Testing\n\n- `go test ./packages/taiko-client/pkg/config ./packages/taiko-client/bindings/manifest -count=1`\n- `cargo test --locked -p protocol`\n- `cargo test --locked -p protocol --no-default-features`\n- `just fmt-check`'
```

Expected: GitHub returns the new pull request URL and reports it as a draft.

- [ ] **Step 6: Verify the pull request state**

Run:

```bash
gh pr view --json url,title,isDraft,headRefName,baseRefName
```

Expected: `isDraft` is `true`, the title matches the required title, `headRefName` is `codex/remove-masaya-network-support`, and `baseRefName` is `main`.
