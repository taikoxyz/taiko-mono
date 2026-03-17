# ProverMarket Design: Permissionless Proving via Perpetual Reverse Auction

## Context

The current prover whitelist (`ProverWhitelist.sol`) is controlled by a multisig, creating a centralization vector. This design replaces it with a permissionless prover market using a perpetual reverse auction. The goal: any prover can compete for the right to prove, with economic guarantees that the chain cannot be halted by malicious provers.

## Architecture

**Drop-in replacement.** `ProverMarket` implements `IProverWhitelist` and replaces `ProverWhitelist` as the Inbox's `_proverWhitelist` immutable dependency. **Zero changes to Inbox.sol.**

```
Inbox.prove()
  → _checkProver(msg.sender, proposalAge)
    → _proverWhitelist.isProverWhitelisted(msg.sender)
      → ProverMarket returns (isWinner, proverCount)
```

When `proverCount = 1`: only the winner can prove (or wait 5 days for permissionless).
When `proverCount = 0`: anyone can prove immediately (permissionless fallback).

## Core Mechanism

### State (2 storage slots on hot path)

```solidity
// Slot 1 (34 bytes, packed)
struct Winner {
    address addr;          // 20 bytes
    uint64  feeInGwei;     // 8 bytes (max ~18.4 ETH)
    uint48  activeAt;      // 6 bytes (when whitelist enforcement begins)
}

// Slot 2 (13 bytes, packed)
struct MarketState {
    uint48 lastEjectionTimestamp;  // 6 bytes
    uint48 cooldownUntil;          // 6 bytes
    uint8  consecutiveEjections;   // 1 byte (max 255)
}
```

Additional state:

- `mapping(address => uint64) bonds` — prover bond balances (gwei)
- `mapping(address => uint256) feeBalances` — claimable ETH for provers
- `uint48 lastClaimedProposalId` — fee settlement cursor

### IProverWhitelist Implementation

```solidity
function isProverWhitelisted(address _prover) external view returns (bool, uint256) {
    Winner memory w = winner;
    if (w.addr == address(0)) return (false, 0);            // vacant
    if (block.timestamp < w.activeAt) return (false, 0);     // grace period
    return (_prover == w.addr, 1);                           // active
}
```

**2 SLOADs** on the hot path (winner + marketState not needed here). Called every `prove()`.

### Bidding

```solidity
function bid(uint64 _feeInGwei) external;
```

- Fee must be >0
- Must have `bonds[msg.sender] >= getRequiredBond()` (escalates after ejections)
- Must undercut current winner by at least **5%** (`minFeeReductionBps = 500`)
- Cannot bid during `cooldownUntil` (global cooldown after ejection)
- Cannot bid if already the winner
- If vacant: any fee accepted (no minimum reduction)
- Winner displaced immediately; old winner can withdraw bond
- New winner's `activeAt = block.timestamp + ACTIVATION_DELAY`

**Activation delay (4 hours):** When a new winner takes over after a vacant period, `proverCount` stays 0 for 4 hours. This lets any proposals from the permissionless gap be proven by anyone before the new winner's exclusivity kicks in. Matches `provingWindow`.

### Ejection (Slashing for Missed Proofs)

```solidity
function slashAndEject() external;
```

Permissionless — anyone can call. Reads Inbox public state to verify delinquency:

```
IInbox.CoreState memory state = inbox.getCoreState();
// Must have unproven proposals
require(state.lastFinalizedProposalId + 1 < state.nextProposalId);
// Must have exceeded proving window since last finalization (or winner start)
uint48 ref = state.lastFinalizedTimestamp > 0
    ? state.lastFinalizedTimestamp : winner.activeAt;
require(block.timestamp > ref + inbox.getConfig().provingWindow);
```

On ejection:

1. **100% bond slash.** 50% to `msg.sender` (bounty), 50% burned to `address(0xdead)`
2. Winner cleared → `proverCount = 0` → permissionless proving activates
3. `consecutiveEjections++` (global counter)
4. `cooldownUntil = block.timestamp + GLOBAL_COOLDOWN` (1 hour)

### Voluntary Exit

```solidity
function exit() external;
```

Only callable by current winner. Clears winner, market goes vacant. No slashing. Winner should ensure pending proposals are proven first (their bond remains locked until withdrawn separately).

### Bond Management

```solidity
function depositBond(uint64 _amount) external;   // TAIKO token, gwei units
function withdrawBond(uint64 _amount) external;   // reverts if sender is current winner
```

**Required bond** escalates after ejections:

```
requiredBond = BASE_BOND * 2^min(consecutiveEjections, MAX_ESCALATION)
```

`consecutiveEjections` decays by 1 per 24 hours without ejection (checked at bid time). Resets to 0 after the winner successfully proves (detected via `lastFinalizedProposalId` advancing during their tenure).

### Fee Payment

**Shared ETH pool model** (zero Inbox changes):

```solidity
function depositFee() external payable;              // proposers deposit ETH
function withdrawFee(uint256 _amount) external;       // proposers withdraw unused
function claimFees() external;                         // winner claims for proven proposals
```

`claimFees()` flow:

1. Read `inbox.getCoreState().lastFinalizedProposalId`
2. Calculate `newProposals = lastFinalizedProposalId - lastClaimedProposalId`
3. Pay `newProposals * winner.feeInGwei * 1 gwei` from pool to winner
4. If pool insufficient, pay what's available (winner accepted this risk)

**Economic enforcement:** If proposers don't fund the pool, the winner stops proving. After `permissionlessProvingDelay` (5 days), anyone can prove. Proposers are incentivized to pay because they need timely finalization.

### Emergency Override

```solidity
function setWinnerOverride(address _newWinner, uint64 _feeInGwei) external onlyOwner;
```

DAO can intervene in emergencies (e.g., security incident). Sets or clears winner directly.

## Anti-Griefing Summary

| Attack                            | Defense                                                       | Cost to Attacker                        |
| --------------------------------- | ------------------------------------------------------------- | --------------------------------------- |
| Win & never prove                 | 100% bond slash on ejection                                   | BASE_BOND (32 ETH equiv) per attempt    |
| Repeated eject-rebid              | Global cooldown (1h) + escalating bond (2x per ejection)      | 32 + 64 + 128 + 256 ETH for 4 cycles    |
| Sybil after ejection              | Global (not per-address) escalation                           | Fresh address faces same escalated bond |
| Transition gap                    | 4h activation delay keeps proverCount=0 for backlog           | N/A                                     |
| Timing attack (prove at deadline) | Accepted — maxProofSubmissionDelay constrains sequential gaps | N/A                                     |
| Proposer-prover collusion         | Not a problem — security from proof validity + bond           | N/A                                     |

## Parameters

| Parameter                 | Value                        | Rationale                                           |
| ------------------------- | ---------------------------- | --------------------------------------------------- |
| `BASE_BOND`               | 32 ETH equiv in TAIKO (gwei) | Same order as ETH validator stake                   |
| `MIN_FEE_REDUCTION_BPS`   | 500 (5%)                     | Prevents trivial underbids                          |
| `GLOBAL_COOLDOWN`         | 3600 (1 hour)                | Breaks rebid loops                                  |
| `ACTIVATION_DELAY`        | 14400 (4 hours)              | Matches provingWindow; lets gap proposals be proven |
| `SLASH_BOUNTY_BPS`        | 5000 (50%)                   | Incentivizes fast ejection                          |
| `MAX_ESCALATION`          | 3 (cap at 8x = 256 ETH)      | Prevents bond exceeding honest prover liquidity     |
| `ESCALATION_DECAY_PERIOD` | 86400 (24 hours)             | Returns to base after healthy operation             |

## Files

### New Files

- `contracts/layer1/core/impl/ProverMarket.sol` — main contract
- `contracts/layer1/core/impl/ProverMarket_Layout.sol` — storage layout
- `test/layer1/core/ProverMarket.t.sol` — tests

### Modified Files

- `contracts/layer1/mainnet/MainnetInbox.sol` — pass ProverMarket address as `proverWhitelist` in constructor

### Reference Files (no changes)

- `contracts/layer1/core/iface/IProverWhitelist.sol` — interface to implement
- `contracts/layer1/core/impl/Inbox.sol` — `_checkProver()` (line 730), `_processLivenessBond()` (line 686)
- `contracts/layer1/core/impl/ProverWhitelist.sol` — structural template (EssentialContract inheritance, coding conventions)
- `contracts/layer1/core/libs/LibBonds.sol` — bond pattern reference

## State Transitions

```
VACANT (proverCount=0)
  │  bid() → set winner, activeAt = now + ACTIVATION_DELAY
  ▼
GRACE (proverCount=0, winner set but not yet active)
  │  block.timestamp >= activeAt
  ▼
ACTIVE (proverCount=1, winner enforced)
  │                          │
  │ slashAndEject()          │ exit()
  │ (slash bond, cooldown)   │ (no slash)
  ▼                          ▼
VACANT ◄─────────────────────┘
  (cooldown period: no bids for 1h after ejection)
```

## Verification

1. **Unit tests:** Test all state transitions (bid, outbid, eject, exit, grace period)
2. **Integration test with Inbox:** Deploy ProverMarket as `proverWhitelist`, verify `prove()` works correctly in all modes (winner active, grace period, vacant)
3. **Anti-griefing tests:** Verify escalating bond, cooldown enforcement, 100% slash
4. **Fee tests:** Deposit, claim, insufficient pool
5. **Run:** `forge test --match-path "test/layer1/core/ProverMarket*"`
