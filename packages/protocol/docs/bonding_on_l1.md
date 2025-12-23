# L1 Bonding (Shasta)

## Summary

Move bond accounting and liveness slashing back to L1. The Inbox enforces a proposer bond check before accepting proposals and performs liveness slashing directly on L1 for late proofs. This removes L2 bond signals, low-bond proposal handling, and prover delegation/auth for now while keeping propose/prove efficient.

## Goals

- Enforce proposer bond sufficiency on L1 before accepting proposals.
- Apply liveness slashing and rewards on L1 without L1->L2 bond signals.
- Remove low-bond proposal logic and prover delegation/auth for simplicity.
- Keep propose/prove fast and minimize additional calls.

## Non-goals

- Backward compatibility with the existing L2 bond flow.
- Prover delegation or ProverAuth support.
- Driver/off-chain integration updates.

## Current Design (Summary)

- Bonds live on L2 in `layer2/core/BondManager`.
- L2 `Anchor` validates prover auth, handles proving fee transfers, and marks `isLowBondProposal`.
- L1 `Inbox.prove` emits `BondInstructionCreated` for late proofs and sends signals to L2.
- L2 `BondManager.processBondInstruction` consumes those signals and applies best-effort debits/credits.

This creates low-bond proposal handling, signal proofs, and extra complexity around L1/L2 coordination.

## Proposed Design

### L1 Bond Manager

Add `layer1/core/impl/BondManager` to hold ERC20 bonds on L1:

- Tracks per-account balances.
- Enforces a `minBond` (withdrawals are immediate, no delay or request flow).
- Holds the `livenessBond` amount used for late-proof slashing.
- Only the L1 Inbox (bond operator) can apply liveness slashing.

### Inbox Changes

- **Propose**: check `bondManager.hasSufficientBond(msg.sender, 0)` and revert if insufficient. The
  required proposer bond is configured via `minBond` in the L1 BondManager.
- **Prove**: for late proofs (same timing rules as today), call `bondManager.processLivenessBond`.
  The liveness bond keeps the existing split rules (50% total slash, with a 40% payee + 10% caller
  split when payer == payee).
- Remove bond signal emission and `BondInstructionCreated` from the Inbox.

### L2 Anchor Changes

- Remove prover delegation/auth.
- Set `designatedProver = proposer` for each proposal.
- Keep `isLowBondProposal` in state/event but always set to `false` (can be removed later).

### Derivation Changes

- Remove `proverAuthBytes` usage from proposal manifests.
- `designatedProver` is always `proposer`.
- `isLowBondProposal` is no longer used to replace proposer sources.
- Liveness slashing is on L1; no bond signals or L2 bond processing.

## Contract/API Changes

- `IInbox.Config` gains `bondManager` address.
- New `layer1/core/iface/IBondManager` and `layer1/core/impl/BondManager`.
- `ICodec.hashBondInstruction` and `IInbox.BondInstructionCreated` removed.
- L2 `Anchor` removes `ProverAuth` and proving-fee transfer logic.

## Gas/Performance Impact

- **Propose**: adds one external view call to check bond.
- **Prove**: adds one external call on late proofs only; unchanged for on-time proofs.
- Removes signal proof costs and L2 bond processing overhead.

## Notes

- `minBond` should be configured to cover the intended proposer requirement (e.g., set equal to
  `livenessBond` if full liveness slashing is desired on every late proof).
