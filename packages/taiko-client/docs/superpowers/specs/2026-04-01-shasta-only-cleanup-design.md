# Shasta-Only Cleanup Design

## Summary

`packages/taiko-client` still carries a mixed Pacaya/Shasta model across runtime config, RPC client setup, proposer/driver/prover flows, metadata abstractions, tests, and local documentation. Now that all chains have moved to Shasta, this package should stop treating Pacaya as a supported fork.

This design removes Pacaya compatibility entirely from `taiko-client` and makes Shasta the only supported protocol path inside this package. The change is intentionally breaking within the package boundary: Pacaya-named CLI flags, config fields, env vars, helper types, and test inputs will be deleted rather than preserved as aliases.

## Goals

- Remove Pacaya-specific runtime behavior from `packages/taiko-client`.
- Remove Pacaya-named public surface from this package's CLI and config types.
- Simplify internal abstractions so Shasta is the only supported protocol path.
- Update package-local tests, integration scripts, and docs to match the Shasta-only model.
- Remove the `PACAYA_FORK_TAIKO_MONO` integration-test dependency and load protocol deployments from `../protocol` directly.

## Non-Goals

- No changes outside `packages/taiko-client`.
- No attempt to preserve Pacaya compatibility aliases.
- No unrelated refactors outside code that must change to support the cleanup.
- No changes to the sibling `packages/protocol` repository layout or deployment outputs.

## Recommended Approach

Use a hard cutover inside `taiko-client`.

This package is already in an awkward transitional state where Shasta was added on top of Pacaya-era abstractions. Keeping Pacaya aliases or staging the removal in multiple passes would preserve misleading names, extend test burden, and create unnecessary churn. A single package-local cutover is simpler to reason about and easier to verify because there is only one valid protocol path after the change.

## Scope

The cleanup applies only to files under `packages/taiko-client`, including:

- runtime flags and config parsing
- `pkg/rpc` protocol client setup
- proposer, driver, and prover execution paths
- metadata abstractions and protocol helper types
- package-local unit and integration tests
- package-local docs and guidance files

The cleanup may read deployment data from the sibling `../protocol` directory during integration tests, but it will not modify files outside `packages/taiko-client`.

## Design

### 1. Public Surface Cleanup

Remove Pacaya-named public inputs from the package.

Examples of removal targets:

- CLI flags and env vars such as `pacayaInbox`, `PACAYA_INBOX`, `raiko.host.pacaya`, and `RAIKO_HOST_PACAYA`
- config fields such as `PacayaInboxAddress`, `RaikoHostEndpointPacaya`, and `RaikoZKVMHostEndpointPacaya`
- helper methods and interfaces such as `IsPacaya`, `Pacaya()`, and `ForkHeightsPacaya`

Replacement rules:

- If the concept is now uniquely Shasta, use a Shasta name such as `ShastaInboxAddress`.
- If the concept is fork-agnostic after the cleanup, use a neutral name such as `InboxAddress` or `ProtocolConfigs`.

No compatibility aliases will be kept.

### 2. RPC Client Simplification

`pkg/rpc` will stop constructing and exposing Pacaya clients.

Expected changes:

- remove `PacayaClients` as an active protocol client container
- stop initializing Pacaya bindings during `rpc.NewClient`
- stop reading Pacaya config or fork-height state from Pacaya inbox contracts
- keep only the Shasta contract clients needed by current proposer, driver, prover, and preconfirmation flows

Where existing structs or field names are protocol-specific only because Pacaya used to exist, rename them to Shasta-specific or neutral names in the same pass.

### 3. Runtime Flow Cleanup

`driver`, `proposer`, and `prover` will stop selecting between Pacaya and Shasta behavior at runtime.

Expected changes:

- remove Pacaya subscriptions, handlers, and transaction-building branches
- delete Pacaya-only helper files whose sole purpose is maintaining the old fork path
- reduce mixed files to Shasta-only logic where they currently branch on Pacaya vs Shasta
- replace fork-switch checks that distinguish Ontake, Pacaya, and Shasta when Pacaya is only an obsolete transition step

The target runtime model is explicit Shasta-only operation rather than fork autodetection.

### 4. Metadata And Type Cleanup

Metadata abstractions currently preserve both Pacaya and Shasta representations. After the cleanup, only the Shasta path should remain.

Expected changes:

- remove Pacaya metadata structs and Pacaya-only interfaces
- stop exposing `Pacaya()` and `IsPacaya()` on proposal metadata
- update downstream code to consume only the surviving Shasta metadata representation

The resulting interfaces should describe current protocol behavior directly instead of encoding legacy fork branching.

### 5. Integration-Test Cleanup

Integration tests will stop depending on `PACAYA_FORK_TAIKO_MONO`.

Expected changes:

- remove `PACAYA_FORK_TAIKO_MONO` from package-local scripts and documentation
- stop maintaining separate Pacaya and Shasta protocol roots in integration scripts
- resolve the protocol deployment from the sibling `../protocol` directory directly, following the same basic pattern already used by `packages/taiko-client-rs`
- read `../protocol/deployments/deploy_l1.json` once and export the Shasta addresses required by `taiko-client`

This keeps the integration-test contract simple: `taiko-client` depends on the default local protocol checkout rather than on Pacaya-specific path indirection.

### 6. Documentation Cleanup

Update package-local docs and operator guidance to match the new model.

Files expected to change include:

- `README.md`
- `AGENTS.md`
- any package-local test or setup scripts that mention Pacaya-specific flags, env vars, or fork-path requirements

The docs should describe Shasta-only setup and remove instructions that require `PACAYA_FORK_TAIKO_MONO`.

## Error Handling And Compatibility Stance

- Old Pacaya flags and env vars are removed rather than silently remapped.
- Missing required Shasta config should fail fast during config parsing or RPC client initialization.
- Runtime code should prefer explicit Shasta assumptions over hidden fallback logic.

This is a deliberate cleanup, not a compatibility migration layer.

## Testing Strategy

Verification should be sequenced so the rename/removal work stays controlled.

Recommended checkpoints:

1. Build-focused pass to surface all broken references after the public-surface rename.
2. Targeted test pass for `pkg/rpc`, metadata, `driver`, `proposer`, and `prover`.
3. Integration-script verification for the Shasta-only local deployment flow.
4. Package-local linting and any relevant higher-level tests that still apply after the deletion pass.

Tests that only preserve Pacaya compatibility should be deleted. Mixed-mode tests should be rewritten to assert Shasta-only behavior.

## Risks

- The biggest risk is mechanical rename fallout across tests and helper packages.
- Some files embed Pacaya semantics more deeply than their names suggest, especially around metadata, proof submission, and event handling.
- Integration scripts may rely on Pacaya-era assumptions in subtle ways even after obvious env vars are removed.

These risks are acceptable because the cleanup is limited to one package and the target architecture is simpler than the current mixed state.

## Implementation Outline

1. Remove Pacaya-named flags, config fields, and env vars from package-local public surface.
2. Simplify `pkg/rpc` to construct only the protocol clients needed for Shasta.
3. Remove Pacaya branches and helpers from proposer, driver, and prover flows.
4. Replace mixed metadata abstractions with a Shasta-only representation.
5. Update tests to remove Pacaya compatibility coverage and validate the Shasta-only behavior.
6. Update integration scripts and package-local docs to use `../protocol` directly and eliminate `PACAYA_FORK_TAIKO_MONO`.

## Success Criteria

- `packages/taiko-client` no longer contains Pacaya-specific runtime/config compatibility paths.
- Pacaya-named CLI/config/env surface is removed from this package.
- Package-local tests and integration scripts run against the default sibling `../protocol` deployment path without `PACAYA_FORK_TAIKO_MONO`.
- Package-local docs describe only the Shasta-based workflow.
