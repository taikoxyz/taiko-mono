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

## Architecture

`Inbox` depends on `IProverMarket`, not `IProverWhitelist`.

If `proverMarket == address(0)`, proving is fully permissionless and remains a first-prove-first-win
path. When `proverMarket` is set, `Inbox` delegates proving authorization and fee accounting to it.

```text
Inbox.propose()
  -> emit Proposed(...)
  -> ProverMarket.onProposalAccepted(...)

Inbox.prove()
  -> ProverMarket.beforeProofSubmission(...)
  -> Inbox verifies proof and updates state
  -> ProverMarket.onProofAccepted(...)
```

Note: `_emitProposedEvent` is called before `onProposalAccepted` (checks-effects-interactions).

The proving market is responsible for:

- deciding whether a proof submission is allowed
- tracking which epoch owns which proposal interval
- reserving or accruing prover fees
- tracking liability for slashing and exit

`Inbox` remains responsible for:

- proposal sequencing
- proof verification
- finalization state
- liveness bond handling for permissionless proving paths (when `proverMarket == address(0)`)

## Core Model: Epoch-Based Reverse Auction

The market is modeled around **epochs** instead of a single mutable "winner".

### Data Structures

```solidity
struct Epoch {
    address operator;              // prover who won this epoch
    address feeRecipient;          // receives proving fees
    uint64  feeInGwei;             // fee quote per proposal
    uint64  bondedAmount;          // locked bond (in gwei)
    uint48  activatedAt;           // timestamp when epoch became active
    uint48  firstProposalId;       // first proposal assigned to this epoch
    uint48  lastAssignedProposalId; // last proposal assigned to this epoch
}

struct MarketState {
    uint48 activeEpochId;          // current active epoch
    uint48 pendingEpochId;         // next epoch selected by bidding
    uint48 lastFinalizedProposalId;// last finalized proposal (for bond release)
    uint48 nextEpochId;            // monotonic counter for epoch creation
    bool   permissionlessMode;     // emergency override
    bool   activeEpochExiting;     // true if active operator called exit()
    bool   degradedMode;           // true when churn pressure disables exclusivity for new proposals
}
```

### Storage

```solidity
// Immutables (constructor)
IInbox  internal immutable _inbox;
IERC20  internal immutable _bondToken;
uint64  internal immutable _minBond;                    // gwei
uint48  internal immutable _permissionlessProvingDelay; // seconds

// State
MarketState public marketState;
mapping(uint48 epochId => Epoch)    public epochs;
mapping(address => uint64)          public bondBalances;       // gwei
mapping(address => uint256)         public feeCreditBalances;  // wei
mapping(uint48 proposalId => uint48 epochId) public proposalEpochs;

// Displaced epoch tracking for bond release (bounded queue, one slot reserved for graceful degrade)
uint48[8] internal _displacedEpochIds;
uint8     internal _numDisplacedEpochs;
```

### Epoch Lifecycle

1. **Bid**: A prover calls `bid(feeRecipient, feeInGwei)`. This creates a **pending epoch**.
   - Must have `bondBalances[msg.sender] >= _minBond`.
   - If an active epoch exists, the bid fee must be **strictly less** than the active fee (reverse
     auction: lower fee wins).
   - If another operator already holds the pending slot, the new bid must also undercut their fee.
     The displaced pending operator's bond is refunded.
   - Bond (`_minBond`) is locked from `bondBalances` into the epoch's `bondedAmount`.

2. **Activation**: The pending epoch activates on the **next `onProposalAccepted` call** — either
   because no active epoch exists, or the active epoch is exiting, or a pending epoch outbid the
   active one.
   - `activatedAt` and `firstProposalId` are set.
   - The old active epoch is moved to the displaced list for bond release tracking.

3. **Assignment**: Each proposal accepted by `Inbox` is assigned to the active epoch.
   - `epochs[activeId].lastAssignedProposalId = proposalId`
   - `proposalEpochs[proposalId] = activeId`

4. **Exit**: An operator calls `exit()`.
   - If pending: epoch is cleared, bond refunded immediately.
   - If active: epoch is marked `activeEpochExiting = true`. The operator stays liable for
     already-assigned proposals.
   - If a pending replacement exists, the next proposal activates it.
   - If no replacement exists, new proposals become immediately permissionless instead of being
     assigned to the exiting epoch.

5. **Bond Release**: When `onProofAccepted` is called, displaced epochs whose
   `lastAssignedProposalId <= lastFinalizedProposalId` get their bond released back to the
   operator's `bondBalances`.

6. **Degraded Mode**: The market reserves one displaced-epoch slot for safe retirement of the
   current active epoch.
   - When churn pressure reaches a high watermark, the market stops granting exclusivity for new
     proposals and enters `degradedMode`.
   - The current active epoch is retired into the reserved displaced slot so its already-assigned
     proposals remain slashable and releasable.
   - While degraded, newly accepted proposals are immediately permissionless and are not assigned
     to any epoch.
   - The latest best bid may remain parked as `pendingEpochId`, but it does not activate until the
     displaced backlog drains below a recovery watermark.

### Proving Authorization

`beforeProofSubmission(caller, firstNewProposalId, proposalTimestamp, proposalAge)`:

1. If `permissionlessMode` or `degradedMode` is true: anyone can prove (return immediately).
2. If `proposalAge >= _permissionlessProvingDelay`: anyone can prove.
3. Look up `proposalEpochs[firstNewProposalId]`:
   - If `epochId == 0`: no epoch assigned (permissionless proposal), anyone can prove.
   - Otherwise: require `caller == epochs[epochId].operator` (exclusive proving window).

### Fee Model

Fees may still be reserved **per-proposal at proposal acceptance time**, not at proof time.

In `onProposalAccepted`:
- Fee = `epochs[activeId].feeInGwei * 1 gwei` (in wei).
- If `feeCreditBalances[proposer] >= fee`: deduct from proposer and accrue it to the epoch's fee
  recipient balance immediately.
- If proposer has insufficient credit: **skip fee** (preserves liveness — the chain doesn't halt
  because a proposer forgot to top up). The prover is still obligated to prove (bond at stake).

Proposers deposit fee credits via `depositFeeCredit()` (payable) and withdraw via
`withdrawFeeCredit(amount)`.

Important constraint: up-front fee reservation is only acceptable if the missed-proof slash is
materially larger than the fee itself. Otherwise the prover can still treat the fee as a cheap free
option on delaying finalization.

### Bond Management

- `depositBond(amount)`: transfers `amount * 1 gwei` of `_bondToken` from sender, credits
  `bondBalances[sender]`.
- `withdrawBond(amount)`: requires `bondBalances[sender] >= amount`, transfers out. Bond locked in
  active/pending epochs is tracked separately in `epoch.bondedAmount` (already deducted from
  `bondBalances` at bid time), so `withdrawBond` only sees the free balance.
- `missed-proof slash`: if the assigned prover fails to prove before the SLA expires, the market
  slashes an amount that is intentionally much larger than the reserved prover fee for the affected
  proposal interval.
- The slash is not burned. Part is paid immediately to the rescue prover, and the remainder stays in
  the prover market as an additional reward pool for the rescue prover that eventually finalizes the
  fallback proof.

### Churn Safety

The market must never revert proposal acceptance because prover churn outran proof finalization.

Recommended constants:
- `MAX_DISPLACED_EPOCHS = 8`
- `ENTER_DEGRADED_AT = 7` so one slot is always reserved to retire the current active epoch safely
- `EXIT_DEGRADED_AT = 0` or another low watermark to avoid rapid flapping

Operational rule:
- In normal mode, active epochs can be displaced by better bids.
- Once the displaced backlog reaches the high watermark, the market enters `degradedMode` instead
  of taking one more displacement and risking proposal-path revert.
- While degraded, new proposals are permissionless; old epoch liabilities still settle normally as
  proofs arrive.
- Once enough displaced epochs clear, the market exits degraded mode and the next proposal may
  activate the best pending bid.

## Emergency Behavior

The market must not reintroduce a hidden whitelist through governance.

Allowed emergency actions:

- `forcePermissionlessMode(true)` — owner can force permissionless proving (anyone can prove)
- `forcePermissionlessMode(false)` — restore market enforcement
- Pausing new bids via `whenNotPaused` on `bid()` (inherited from `EssentialContract`)

Disallowed emergency action:

- Assign proving exclusivity to an arbitrary operator

## Inbox Integration Points

### In `Inbox.propose()` (after `_emitProposedEvent`):

```solidity
if (address(_proverMarket) != address(0)) {
    _proverMarket.onProposalAccepted(proposal.id, proposal.proposer, proposal.timestamp);
}
```

### In `Inbox.prove()` (before proof verification):

```solidity
_checkProverMarket(msg.sender, firstNewProposalId, firstNewProposalTimestamp, proposalAge);
```

Where `_checkProverMarket` calls `_proverMarket.beforeProofSubmission(...)` if market is non-zero.

### In `Inbox.prove()` (after proof verification):

```solidity
if (address(_proverMarket) != address(0)) {
    _proverMarket.onProofAccepted(
        msg.sender, commitment.actualProver,
        firstNewProposalId, uint48(lastProposalId),
        state.lastFinalizedTimestamp
    );
}
```

### Bond path divergence:

When `_proverMarket != address(0)`, `Inbox` skips `_processLivenessBond` — the market owns bond
accounting. When `_proverMarket == address(0)`, `Inbox` handles liveness bonds itself.

## Constructor Parameters

```solidity
constructor(
    address _inboxAddr,              // Inbox proxy address
    address _bondTokenAddr,          // ERC20 bond token
    uint64  _minBondGwei,            // minimum bond to bid (in gwei)
    uint48  _permissionlessProvingDelaySeconds  // seconds until proving opens
)
```

The contract is UUPS-upgradeable. `init(address _owner)` sets the owner.

## Access Control

- `onProposalAccepted`, `beforeProofSubmission`, `onProofAccepted`: `onlyFrom(address(_inbox))`
- `forcePermissionlessMode`: `onlyOwner`
- `bid`: `whenNotPaused` (can be paused by owner)
- `depositBond`, `withdrawBond`, `withdrawFeeCredit`: `nonReentrant`
- automatic `degradedMode`: protocol-triggered safety mode, not a governance-assigned prover role

## Files

### Core Files

- `contracts/layer1/core/iface/IProverMarket.sol` — interface
- `contracts/layer1/core/impl/ProverMarket.sol` — implementation

### Inbox Integration

- `contracts/layer1/core/iface/IInbox.sol` — `Config.proverMarket` field
- `contracts/layer1/core/impl/Inbox.sol` — hooks inlined in `propose()` and `prove()`

### Tests

- `test/layer1/core/inbox/ProverMarket.t.sol` — 36 tests across 9 contracts
- `test/layer1/core/inbox/InboxTestBase.sol` — `_readProposedEvent` made virtual for override

### Build/Layout

- `script/gen-layouts.sh` — ProverMarket added to layer1 contract list

## Testing Notes

### Test Setup

Tests extend `InboxTestBase` with a `ProverMarketTestBase` that:

1. Deploys Inbox with `proverMarket: address(0)` initially.
2. Deploys ProverMarket pointing to the Inbox proxy.
3. Upgrades Inbox implementation to one with `proverMarket` set to the market address.

This two-phase deploy is necessary because Inbox and ProverMarket reference each other (both are
immutables set in constructors).

### Log Reading Override

When ProverMarket is active, `onProposalAccepted` emits events (e.g., `EpochActivated`) after the
`Proposed` event. The base `_readProposedEvent` assumes the last log is `Proposed`, so the test
base overrides it to search by event topic hash:

```
bytes32 proposedTopic = 0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213;
```

### Proving Tests

When using `_buildBatchInput(n)`, do NOT call `_proposeOne()` or `_setupActiveBid()` beforehand if
you intend to prove those proposals, because `_buildBatchInput` proposes internally and builds
commitments starting from `lastFinalizedProposalId + 1`. Pre-proposing creates proposals that the
batch commitment won't cover, causing `FirstProposalIdTooLarge` errors.

Pattern for proof tests:
```solidity
// Set up bid (don't propose yet)
_depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
vm.prank(prover);
market.bid(prover, 100);

// _buildBatchInput proposes AND activates the epoch
_advanceBlock();
IInbox.ProveInput memory input = _buildBatchInput(1);
_prove(input);
```

### vm.expectRevert with _prove

The `_prove` helper calls `codec.encodeProveInput()` (a staticcall) before `inbox.prove()`.
`vm.expectRevert()` is consumed by the first external call, so for revert tests, encode manually
first:

```solidity
bytes memory encodedInput = codec.encodeProveInput(input);
vm.prank(prover);
vm.expectRevert();
inbox.prove(encodedInput, bytes("proof"));
```

## Future Work

- Exact slash formula and reward split for rescue provers
- Recovery thresholds and hysteresis tuning for `degradedMode`
- Configurable minimum bond (currently immutable)
- Fee model refinement (pay-on-reserve vs pay-on-proof vs hybrid)
- Gas optimization of `onProposalAccepted` and degraded-mode transitions
