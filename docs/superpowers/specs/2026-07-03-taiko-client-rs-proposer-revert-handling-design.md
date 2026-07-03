# Taiko Client Rust Proposer Revert Handling Design

## Context

The Rust proposer in `packages/taiko-client-rs/crates/proposer` submits Shasta proposal
transactions through `base-tx-manager`. The proposer main loop is intended to survive
operational proposal failures and continue on the next epoch.

The current loop already handles some operational failures, including transport errors,
send timeouts, and mempool deadline expiry. A propose transaction revert can still terminate
the process because `TxManagerError::ExecutionReverted` is not considered an operational
loop error.

Upstream `base-tx-manager` also documents that confirmed receipts are returned without
inspecting EVM execution status. That means a mined reverted transaction can be returned as
`Ok(receipt)` with `receipt.status() == false`.

## Goal

If an L1 propose transaction reverts, the proposer process must not crash or exit. It should
record the failed proposal attempt, log the failure, and continue to the next proposal epoch.

## Non-Goals

- Do not change `base-tx-manager` behavior.
- Do not add new retry knobs or CLI flags.
- Do not alter proposal construction, gas policy, forced-inclusion behavior, or whitelist
  precheck semantics.
- Do not suppress startup, configuration, signing, unsupported-feature, or deterministic
  local errors that still require operator intervention.

## Selected Approach

Make the proposer classify proposal reverts as epoch-local failures:

1. Add a proposer error variant for a reverted proposal receipt, carrying the transaction hash.
2. After `tx_manager.send(...)` returns a receipt, record existing metrics and logs. If
   `receipt.status()` is false, return the new proposer error instead of returning `Ok(receipt)`.
3. Include `TxManagerError::ExecutionReverted` in `is_operational_loop_error(...)`, so
   tx-manager-surfaced reverts are handled by the existing loop continuation path.
4. Keep the existing fatal classification for nonce, fee-limit, signing, invalid config, and
   unsupported-feature errors.

This keeps revert handling local to the proposer process while preserving tx-manager's generic
contract for other callers.

## Alternatives Considered

### Only classify `ExecutionReverted` as operational

This fixes the crash when tx-manager returns an error, but it leaves mined reverted receipts
reported through the success-shaped `Ok(receipt)` path. The loop would continue, but logs would
say the attempt completed even though the contract execution failed.

### Change `base-tx-manager`

Changing tx-manager to reject reverted receipts would affect all downstream callers and would
conflict with its documented behavior. The proposer can enforce its own contract without
expanding the blast radius.

## Error Handling

`start()` keeps its current structure:

- retryable precheck or proposal failures increment failed proposal metrics and continue;
- non-operational errors still return and stop the process;
- successful proposal receipts increment success metrics and observe gas usage.

The new reverted-receipt error is operational only in the proposer loop. Direct callers of
`fetch_and_propose()` receive an error when the transaction was mined but reverted, which is
more accurate than returning `Ok(receipt)`.

## Testing

Add focused tests in `crates/proposer/src/proposer.rs`:

- `TxManagerError::ExecutionReverted` is classified as an operational loop error.
- Fatal tx-manager errors remain fatal.
- A failed receipt is recorded as a failed submission and converted into a proposer error.

If test helpers make receipt construction awkward, use the existing Alloy receipt type directly
inside unit tests rather than adding broader integration fixtures.

## Verification

Run targeted verification first:

```bash
cargo test -p proposer operational
cargo test -p proposer reverted
```

Before declaring completion, run the package-required sequence from
`packages/taiko-client-rs/AGENTS.md`. If the environment prevents the full
sequence from completing, report the blocker and the targeted checks that did run:

```bash
cd packages/taiko-client-rs
just fmt && just clippy-fix && just test
```
