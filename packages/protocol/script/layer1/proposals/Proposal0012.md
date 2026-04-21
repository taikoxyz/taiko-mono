# PROPOSAL-0012: Upgrade Shasta Inbox for Gas-Optimized Proposing

## Executive Summary

This proposal upgrades the Shasta L1 `Inbox` proxy (`0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`) to a new implementation that reduces gas costs for the hot `propose` / `prove` paths. It executes **1 L1 action** from the DAO Controller and no L2 actions. No new state is introduced and the storage layout is unchanged.

## Rationale

`propose` and `prove` run on every Shasta proposal and every proof submission, so L1 calldata and gas savings here compound directly into lower operator costs. The new implementation delivers:

1. **`proposeDefault()`** — zero-argument entry point for the most common path (1 blob at index 0, no forced inclusions, no deadline, no lookahead). Eliminates ABI encoding overhead that dominates minimum-size proposals.
2. **`proposeCompact(uint16,uint16,uint24,uint16)`** — explicit typed parameters instead of ABI-encoded `bytes`, for callers that need blob/forced-inclusion flexibility but not deadlines. Removes one layer of decoding on the hot path.
3. **Inlined `_propose` refactor** — the three propose variants now share a single private `_propose` that folds in the former `_buildProposal` helper, removing internal call overhead.
4. **Early return in `_consumeForcedInclusions`** — when the forced-inclusion queue is empty (the common case in production), the function returns immediately instead of running the min/max + loop + dequeue sequence.
5. **`nonReentrant` guard on `prove()`** — defensive hardening with negligible gas overhead.

The original `propose(bytes)` entry point is preserved, so existing integrations continue to work unchanged.

## Technical Specification

**Single L1 action** — UUPS upgrade on the Shasta inbox:

- **Target**: `L1.INBOX` (`0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`)
- **Function**: `upgradeTo(address)`
- **New implementation**: `INBOX_IMPL` in [`Proposal0012.s.sol`](./Proposal0012.s.sol) (TBD — to be set before submission, once the new implementation is deployed on Ethereum)

### Compatibility

- **Storage layout**: unchanged. Only a transient internal `ConsumptionResult` struct was removed from the implementation; no state variables are added, reordered, or repurposed.
- **External ABI**: additive. `propose(bytes)` keeps its existing selector and behavior; `proposeDefault()` and `proposeCompact(uint16,uint16,uint24,uint16)` are new.
- **Semantics**: `proposeCompact` does **not** support deadlines — callers that need deadline-based stale-transaction protection must continue using `propose(bytes)`.

## Verification


1. Generate proposal calldata:

   ```bash
   P=0012 pnpm proposal
   ```

2. Dryrun on L1:

   ```bash
   P=0012 pnpm proposal:dryrun:l1
   ```

## Security Contacts

- security@taiko.xyz
