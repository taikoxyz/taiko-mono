# Inbox Reactivation + Guards Design

## Goal

Enable safe Inbox reactivation semantics that invalidate prior proposal history, add defensive
invariant checks for ring-buffer capacity, and guard `minForcedInclusionCount` configuration from
becoming unfulfillable. Also remove BondManager from gen-layout scripts. Forced-inclusion queue
state is preserved across reactivation and this behavior is documented.

## Approach

Reactivation remains allowed within the activation window. When `activate()` is called after
proposals already exist, the contract resets core state and proposal hash history to a new genesis
proposal, effectively invalidating all prior proposals. The forced-inclusion queue is explicitly
left untouched to avoid discarding paid inclusion requests; this is documented in `activate()`
NatSpec. For capacity safety, `_getAvailableCapacity` will validate invariants and revert if
`nextProposalId <= lastFinalizedProposalId` or if unfinalized proposal count exceeds the ring
buffer size, preventing unchecked underflow from returning a large capacity. Configuration
validation will enforce `minForcedInclusionCount <= type(uint8).max` to align with
`ProposeInput.numForcedInclusions` bounds. Gen-layout scripts will be updated to remove
BondManager from layout generation.

## Tests

- Add a new config validation test that reverts when `minForcedInclusionCount > 255`.
- Add a new activation test asserting reactivation invalidates proposal history while leaving the
  forced-inclusion queue intact.
- Add a new invariant test asserting `_getAvailableCapacity` reverts on corrupted state.

## Notes

- No changes to calldata layouts or codec packing are planned.
- Reactivation does not clear forced-inclusion queue entries by design.
