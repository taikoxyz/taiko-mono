# Inbox and LibBonds Design Notes

## Scope

Recommendations for the TODOs in Inbox and LibBonds, with focus on architecture clarity
and gas efficiency. Also addresses whether LibBonds should be merged into Inbox.

## Goals and First Principles

- Preserve the invariant: the reserved bond amount must be exactly what is refunded/slashed.
- Avoid per-proposal storage or per-proposal events on hot paths like `prove`.
- Keep off-chain observability with minimal, intention-revealing events.
- Keep code paths simple and auditable; avoid precision logic unless it changes incentives.

## Recommendations

### Inbox: bond amount mutability (TODO at `_settleProposalBonds`)

Best architecture is to keep `livenessBond` effectively immutable for the contract lifetime,
or only allow changes when there are no outstanding proposals
(`nextProposalId == lastFinalizedProposalId + 1`).

Why: if `livenessBond` can change mid-flight, you need per-proposal storage (or an epoch
schedule keyed by proposal id) to know what to refund/slash. That adds storage writes
and complexity. A "no outstanding proposals" guard preserves correctness without
extra per-proposal data and keeps gas minimal.

If changes must be allowed while proposals exist, prefer an epoch schedule:

- store `(startProposalId, bondAmount)` records
- resolve the bond for a proposal by binary search or by iterating a short array
  This is still cheaper and clearer than per-proposal storage, and avoids mismatches.

### Inbox: batch refund of proposer bonds (TODO in refund loop)

Avoid calling `creditBond` for every proposal. Instead, group by proposer in the
`transitions` array and credit once per contiguous run or per unique proposer.

Implementation approach:

- iterate transitions
- accumulate amounts for the current proposer
- when proposer changes (or on end), credit once
  This reduces storage writes and event emissions while keeping behavior identical.

If you still want events, emit one per proposer batch, not per proposal.

### LibBonds: event emission

Remove `BondCredited` and `BondDebited` events from the library and emit them
from the caller only when needed. Keep `BondDeposited`, `BondWithdrawn`, and
`LivenessBondProcessed` as the main public signals.

Rationale: the library is low-level accounting; callers should control emission
and can batch. This avoids redundant logs and makes event semantics clearer.

### LibBonds: precision for liveness splits

Integer division is sufficient. The rounding error is small and does not change
incentives. If exact splits are desired, enforce configuration constraints such as
`livenessBond % 10 == 0` (and `% 2 == 0` for the 50% path).

Avoid fixed-point math for this unless it materially changes incentives; it adds
gas and complexity for marginal benefit.

## Should LibBonds be merged into Inbox?

Recommendation: keep LibBonds separate.

Reasons:

- No meaningful runtime gas benefit to merging; internal functions compile similarly.
- Keeping it separate preserves modularity and reuse potential.
- Inbox stays smaller and clearer, especially if bond logic evolves.

The best gas savings come from batching credits and minimizing events, not from
collapsing the library.
