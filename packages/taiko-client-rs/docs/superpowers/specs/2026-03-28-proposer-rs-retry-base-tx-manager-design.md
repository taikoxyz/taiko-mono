# Proposer Retry Migration To `base-tx-manager`

## Summary

This design covers the feature work currently represented by the `proposer-rs-retry`
branch, but changes the implementation strategy. Instead of keeping a proposer-local
retry and fee-bump state machine, the proposer should adopt
[`base-tx-manager`](https://github.com/base/base/tree/main/crates/utilities/tx-manager)
as the transaction lifecycle manager for L1 proposal submission.

The scope includes two coordinated changes:

1. Replace proposer-local submission retry logic with `base-tx-manager`.
2. Keep the manifest gas-limit fix from `proposer-rs-retry` as a separate proposer-local
   change.

The user-approved direction is:

- Use a direct dependency on upstream `base-tx-manager`.
- Preserve parity for core operator-visible behavior, but not necessarily every config
  name or internal timing detail.
- Keep a small proposer-specific config surface and map it internally onto
  `TxManagerConfig`.

## Goals

- Remove proposer-owned retry, fee-bump, and receipt-wait state management.
- Reuse `base-tx-manager` for nonce handling, resend policy, fee bumping, and receipt
  confirmation.
- Preserve proposer-specific proposal construction, manifest generation, and Shasta
  chain behavior.
- Land the manifest gas-limit fix alongside the retry migration work.

## Non-Goals

- Expose the full `base-tx-manager` CLI/config surface through proposer flags.
- Refactor unrelated proposer, driver, or protocol code.
- Reimplement `base-tx-manager` behavior locally.

## Current State

The `proposer-rs-retry` branch modifies:

- `crates/proposer/src/proposer.rs`
  to add proposer-local fee tracking, receipt timeout handling, retry budgeting, and
  replacement fee bump logic.
- `bin/client/src/flags/proposer.rs` and `crates/proposer/src/config.rs`
  to add retry-related operator flags.
- `crates/proposer/src/transaction_builder.rs`
  to derive non-engine manifest gas limit from the latest L2 parent block instead of
  always using the fallback maximum.

Today the proposer flow is:

1. Build a Shasta proposal transaction request, including blob sidecar data.
2. Send it through the alloy wallet-enabled provider.
3. Wait for a receipt locally.

The retry branch extends step 3 with a proposer-local resend loop. That is the logic to
replace with `base-tx-manager`.

## Key Constraint

The current proposer builds blob-carrying proposal transactions with
`with_blob_sidecar(...)`. The upstream `base-tx-manager` README currently states that blob
transactions are not yet supported and are rejected.

This means direct dependency adoption is only viable if one of the following is true:

- the selected upstream revision already includes blob transaction support, or
- blob support is added upstream as part of the dependency update before proposer
  integration proceeds.

Without blob support in `base-tx-manager`, the retry migration cannot fully replace the
proposer send path.

## Recommended Approach

Use an upstream-first phased rollout.

### Phase 1: Manifest Gas-Limit Fix

Keep the `transaction_builder.rs` change from `proposer-rs-retry` as a separate local fix.
In non-engine mode, derive the manifest gas limit from the latest canonical L2 parent
block, preserving the genesis-parent exception and the anchor-gas discount rules.

This work remains proposer-owned because it is Shasta-specific and unrelated to tx
lifecycle management.

### Phase 2: `base-tx-manager` Dependency Adoption

Add a direct dependency on `base-tx-manager` and the workspace dependencies needed to
build it cleanly in this repository.

The pinned revision must support the proposer's transaction type requirements, including
blob transactions. If that support is missing upstream, the implementation plan must treat
upstream enablement as a prerequisite.

### Phase 3: Proposer Send-Path Migration

Introduce a small proposer-owned adapter that converts a constructed proposal transaction
into a `base-tx-manager` send request. Remove proposer-local retry state, fee-bump
arithmetic, resend loops, and receipt timeout loops.

## Architecture

The ownership boundary after migration should be:

- proposer owns proposal content and chain-specific transaction construction
- `base-tx-manager` owns transaction lifecycle management

### Proposer-Owned Responsibilities

- fetching txpool content or engine payload data
- building the Shasta manifest
- building calldata for `inbox.propose(...)`
- attaching blob sidecar data
- proposer loop scheduling
- proposer-specific metrics and logging
- mapping a narrow proposer config surface into tx-manager config

### `base-tx-manager` Responsibilities

- signer/wallet-driven transaction publishing
- nonce allocation and reuse across replacements
- retryable RPC error classification
- resend timing
- fee bumping and replacement thresholds
- receipt polling and confirmation waiting
- terminal send outcome reporting

## Integration Boundary

The proposer should stop passing a mostly empty `TransactionRequest` into a wallet-filled
provider send path and instead produce an explicit tx-manager input.

Conceptually, the local adapter should look like:

```rust
async fn send_proposal(&self, proposal: BuiltProposalTx) -> Result<ProposalOutcome>;
```

Where `BuiltProposalTx` is proposer-owned data containing:

- destination address
- calldata
- blob sidecar/blob payload data
- optional gas limit override
- any proposer-local metadata needed for logging or metrics

The adapter's job is to:

1. convert proposer-built transaction data into the tx-manager candidate type
2. derive `TxManagerConfig` from proposer config
3. invoke tx-manager send
4. map tx-manager results into `ProposalOutcome` and proposer errors

## Config Strategy

The proposer should keep a small operator-facing config surface rather than flattening all
`base-tx-manager` options into CLI flags.

The retained proposer-facing knobs should cover only the behavior users actually need to
control for this feature:

- bounded resend/retry timing
- bounded retry duration or resend budget behavior
- minimum fee floors for low-activity chains

The mapping should be internal and documented. The implementation plan should choose a
stable subset of proposer flags and map them onto `TxManagerConfig` fields such as:

- resubmission timeout
- confirmation timeout
- receipt query interval
- minimum tip/base fee floors
- fee-limit settings where needed

This design intentionally avoids exposing every tx-manager tuning parameter.

## Behavioral Requirements

The migration should preserve the following core behavior from the retry branch:

- the proposer retries boundedly rather than crashing on a timed-out proposal submission
- retries use fee floors suitable for low-activity chains and devnets
- retry exhaustion does not terminate the proposer loop
- non-retryable send failures still surface as proposer errors

The following may change to align with `base-tx-manager`:

- exact retry timing implementation details
- exact naming of internal config fields
- exact replacement error handling internals, as long as operator-visible behavior is
  preserved

## Data Flow

After migration, each proposer interval should work as follows:

1. fetch txpool content or engine payload data
2. build the Shasta proposal transaction inputs
3. construct proposer-owned `BuiltProposalTx`
4. pass `BuiltProposalTx` through the local adapter
5. adapter invokes `base-tx-manager`
6. tx-manager publishes, bumps fees if needed, and waits for the final outcome
7. adapter maps the outcome back to proposer metrics/logging
8. proposer continues the outer loop

## Error Handling

Error ownership should stay clean.

### Proposer-Local Errors

- txpool fetch failures
- engine API failures
- manifest construction failures
- blob encoding/build failures
- local config translation failures

### Tx-Manager-Owned Lifecycle Errors

- publish failures
- underpriced or replacement-required errors
- nonce handling during resend
- receipt polling failures
- confirmation timeout or retry exhaustion

The migration should delete proposer-local duplicates of these tx lifecycle behaviors.
Keeping both state machines would create ambiguous retry ownership and should be treated as
an implementation failure.

## Testing Strategy

Testing should be split by responsibility boundary.

### Unit Tests

- manifest gas-limit helper tests in `transaction_builder.rs`
- proposer config to `TxManagerConfig` translation tests
- proposal transaction to tx-manager candidate translation tests
- blob transaction translation tests once upstream blob support is available

### Integration Tests

- update existing proposer integration tests to assert successful proposal mining through
  the tx-manager-backed path
- add at least one test covering bounded retry exhaustion semantics if the harness can
  force delayed confirmation or repeat resend conditions

## Implementation Notes For The Follow-Up Plan

The implementation plan should explicitly include:

- verifying whether the chosen upstream `base-tx-manager` revision supports blob
  transactions
- stopping and surfacing a blocker if blob support is absent upstream, rather than
  reintroducing proposer-local retry logic as a fallback
- adding the dependency and any missing workspace crates cleanly
- introducing a small proposer adapter module rather than spreading tx-manager calls
  throughout `proposer.rs`
- deleting proposer-local retry/bump helpers instead of layering tx-manager beneath them
- preserving doc-comment coverage for all new production symbols
- validating with `just fmt`, `just clippy`, and targeted proposer tests before claiming
  completion

## Open Risks

- Upstream blob transaction support may not exist at the required revision.
- The tx-manager config surface may not map one-to-one to the retry branch flags; the
  implementation plan will need explicit default choices.
- Metrics may shift subtly when the send lifecycle moves out of proposer-owned code; the
  implementation should decide which counters remain proposer-level and which are consumed
  from tx-manager behavior.

## Recommendation

Proceed with a phased implementation plan that:

1. lands the manifest gas-limit fix locally
2. pins a `base-tx-manager` revision with blob support
3. introduces a proposer adapter around tx-manager
4. deletes the proposer-local resend state machine instead of keeping it in parallel
