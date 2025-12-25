# L1 Bonding (Shasta)

## Summary

Move bond accounting and liveness slashing back to L1. The Inbox enforces a proposer bond check
before accepting proposals and performs liveness slashing directly on L1 for late proofs. This
removes L2 bond signals, low-bond proposal handling, and prover delegation/auth for now while
keeping propose/prove efficient.

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
- L2 `BondManager.processBondInstruction` consumes those signals and applies best-effort
  debits/credits.

This creates low-bond proposal handling, signal proofs, and extra complexity around L1/L2
coordination.

## Proposed Design

### L1 Bonding In Inbox

Move bond accounting into the Inbox via a small library (`LibBonds`) to keep the Inbox readable:

- Tracks per-account balances.
- Uses `livenessBond` as the per-proposal bond amount.
- Holds the `livenessBond` amount used for late-proof slashing.
- Exposes deposit/withdraw and balance queries directly on the Inbox (via `IBondManager`).

### Inbox Changes

- **Propose**: reserve the proposer bond by debiting the caller’s Inbox bond balance; revert if the
  proposer lacks `livenessBond`. This debits `livenessBond` per proposal on acceptance.
- **Prove**: for late proofs (same timing rules as today), process liveness slashing using the
  reserved bond. The liveness bond keeps the existing split rules (50% total slash, with a 40%
  payee + 10% caller split when payer == payee).
- Remove bond signal emission and `BondInstructionCreated` from the Inbox.

### L2 Anchor Changes

- Remove prover delegation/auth.
- Remove proposal-level prover/low-bond tracking from Anchor.
- Keep only proposal ID monotonicity checks and L1 checkpoint anchoring.

### Derivation Changes

- Remove `proverAuthBytes` usage from proposal manifests.
- `designatedProver` in L1 transitions is always `proposer` (no L2 Anchor tracking).
- Liveness slashing is on L1; no bond signals or L2 bond processing.

## Contract/API Changes

- `IInbox.Config` uses `bondToken` and `livenessBond`.
- `IBondManager` is implemented by the Inbox (no standalone L1 BondManager).
- `ICodec.hashBondInstruction` and `IInbox.BondInstructionCreated` removed.
- L2 `Anchor` removes `ProverAuth` and proposal-level prover tracking.

## Gas/Performance Impact

- **Propose**: no external calls; a single storage debit in the Inbox.
- **Prove**: no external calls; slashing only adjusts Inbox storage when late.
- Removes signal proof costs and L2 bond processing overhead.

## Notes

- `livenessBond` should be configured to cover the intended proposer requirement and slashing
  severity for late proofs.
