# ProverMarket Design: First-Class Proving Rights Controller

## Context

The current prover whitelist is a privileged allowlist managed outside the market itself. The
prover market should replace that model entirely, not sit behind the whitelist interface.

This design therefore removes the whitelist abstraction from the proving path and makes
`ProverMarket` a first-class dependency of `Inbox`.

## Goals

- Remove the manual prover whitelist entirely
- Make proving authorization explicit in `Inbox`
- Let the market own prover selection, fee accounting, and slashing state
- Keep `Inbox` as the source of truth for proposal acceptance and proof finalization
- Stage the implementation so `Inbox` integration can be reviewed before the market economics are
  finalized

## Non-Goals For This First Pass

- Finalize the full auction and slashing logic
- Ship production fee accounting
- Preserve the old `IProverWhitelist` integration shape

The first implementation pass in this branch is intentionally a skeleton: interfaces, wiring, and
contract surfaces only.

## Architecture

`Inbox` should depend on `IProverMarket`, not `IProverWhitelist`.

If `proverMarket == address(0)`, proving is fully permissionless and remains a first-prove-first-win
path.

```text
Inbox.propose()
  -> ProverMarket.onProposalAccepted(...)

Inbox.prove()
  -> ProverMarket.beforeProofSubmission(...)
  -> Inbox verifies proof and updates state
  -> ProverMarket.onProofAccepted(...)
```

This makes the proving market responsible for:

- deciding whether a proof submission is allowed
- tracking which epoch owns which proposal interval
- reserving or accruing prover fees
- tracking liability for slashing and exit

`Inbox` remains responsible for:

- proposal sequencing
- proof verification
- finalization state
- liveness bond handling for permissionless proving paths

## Core Model

The market should be modeled around epochs instead of a single mutable "winner".

Each epoch owns:

- a prover operator
- a fee recipient
- a fee quote
- a locked bond
- an activation timestamp
- a proposal interval or equivalent liability cursor

Important consequences:

- New proposals are assigned to the active epoch when they are accepted by `Inbox`
- An outbid creates a pending next epoch for future proposals
- A displaced prover stays liable for the proposals assigned during its epoch until those proposals
  are proven or the epoch is slashed
- Emergency logic may remove exclusivity, but may not assign exclusivity to a named prover

## Required Inbox Changes

The prover market cannot be implemented cleanly through a boolean whitelist check. `Inbox` must be
updated directly.

### Config and Immutable Wiring

- Replace `Config.proverWhitelist` with `Config.proverMarket`
- Replace `_proverWhitelist` with `_proverMarket`
- Update `getConfig()` to return the market address
- Update mainnet and devnet inbox constructors to take a prover market address

### Proposal Path

After a proposal is accepted and before the `Proposed` event is emitted, `Inbox` should notify the
market that a new proposal has entered the proving queue.

The hook should carry enough information for future fee reservation and epoch assignment:

- proposal id
- proposer
- proposal timestamp

### Proof Path

Before a proof is accepted, `Inbox` should ask the market whether the caller may submit the proof
for the first newly finalized proposal in the batch.

The authorization hook should carry enough information to support future policy:

- caller
- first new proposal id
- first new proposal timestamp
- proposal age

After a proof is accepted and finalization state is updated, `Inbox` should notify the market of
the newly finalized interval.

The completion hook should carry:

- caller
- actual prover
- first new proposal id
- last proposal id
- finalized timestamp

## Proposed `IProverMarket` Surface

The first pass should add the interface and wire `Inbox` to it. Function bodies in
`ProverMarket.sol` can remain skeletal until the surface is reviewed.

Expected responsibilities:

- `beforeProofSubmission(...)`
- `onProposalAccepted(...)`
- `onProofAccepted(...)`
- bid lifecycle functions
- bond management functions
- fee balance management functions
- emergency mode functions that only reduce privilege

## Fee Model Direction

The previous shared global ETH pool design is intentionally dropped.

The next version should instead reserve prover fees against proposer-funded balances when
proposals are accepted. That accounting requires explicit `Inbox` hooks, which is another reason
the whitelist-shaped integration is insufficient.

If this remains too large for the first production version, the fee accounting should be staged
separately rather than hidden behind a misleading "shared pool" placeholder.

## Emergency Behavior

The market must not reintroduce a hidden whitelist through governance.

Allowed emergency actions:

- force permissionless proving
- clear the active market epoch
- pause new bids

Disallowed emergency action:

- assign proving exclusivity to an arbitrary operator

## Files

### New Files

- `contracts/layer1/core/iface/IProverMarket.sol`

### Modified Files

- `contracts/layer1/core/iface/IInbox.sol`
- `contracts/layer1/core/impl/Inbox.sol`
- `contracts/layer1/core/impl/ProverMarket.sol`
- `contracts/layer1/mainnet/MainnetInbox.sol`
- `contracts/layer1/devnet/DevnetInbox.sol`

### Removed Or Reworked

- `contracts/layer1/core/iface/IProverWhitelist.sol`
- `test/layer1/core/ProverMarket.t.sol`

## Verification

This first pass is for interface and wiring review, not production-complete market behavior.

Review focus:

1. Does `Inbox` expose the right market hooks?
2. Does `IProverMarket` contain the right responsibilities?
3. Does the `ProverMarket` skeleton reflect the intended boundary between `Inbox` and market
   logic?
4. Have all whitelist-specific assumptions been removed from the proving path?
