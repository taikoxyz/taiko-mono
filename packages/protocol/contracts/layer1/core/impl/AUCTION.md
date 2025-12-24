# ProverAuction Contract Design Document

## Overview

The Taiko based rollup protocol (Inbox.sol) has two core L1 actions: (1) **propose** and (2) **prove**. Proposing is permissionless — anyone can submit proposals. However, each proposal requires a **designated prover** who must prove it within a time window or face bond slashing.

The `ProverAuction` contract determines who the designated prover is and at what fee. When `Inbox.propose()` is called, it queries `ProverAuction.getCurrentProver()` to get the current prover and their fee.

## Auction Model

**Continuous Reverse Auction** — provers compete by offering the lowest proving fee per proposal.

### Key Rules

1. **Winning**: The prover offering the lowest fee wins immediately (no delay)
2. **Staying**: Winner remains prover indefinitely until outbid, exited, or forced out
3. **Outbidding**: Must offer at least 5% lower fee than current prover
4. **Self-Bidding**: Current prover can call `bid()` to lower their own fee (no 5% requirement)
5. **Exiting**: Prover can exit anytime; bond withdrawable after delay
6. **Forced Exit**: If bond falls below threshold, prover is automatically removed

### Vacancy Handling

When no active prover exists (after exit or force-out), new bids use a **time-based fee cap**:

```
Fee Cap
   │
256x│                                            ┌───── (capped)
    │                                      ┌─────┘
 64x│                                ┌─────┘
    │                          ┌─────┘
 16x│                    ┌─────┘
    │              ┌─────┘
  4x│        ┌─────┘
    │  ┌─────┘
  1x│──┘
    │  │     │     │     │     │     │     │     │
    └──┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴───► Time
     +15   +30   +45   +60   +75   +90  +105  +120 min
```

- **Base fee**: Previous prover's fee (or `initialMaxFee` if never had a prover)
- **Doubling**: Max fee doubles every 15 minutes
- **Cap**: 256x base fee maximum (after ~2 hours)

This encourages quick takeover at reasonable rates while allowing market correction over time.

---

## Contract Parameters

### Immutables (Set at Deployment)

| Parameter             | Type    | Description                                        |
| --------------------- | ------- | -------------------------------------------------- |
| `inbox`               | address | Inbox contract (only caller for `slashBond`)       |
| `bondToken`           | address | TAIKO token for bonds                              |
| `livenessBond`        | uint96  | Bond amount slashed per failed proof               |
| `maxPendingProposals` | uint16  | Max unproven proposals at any time                 |
| `minFeeReductionBps`  | uint16  | Min fee reduction to outbid (e.g., 500 = 5%)       |
| `bondWithdrawalDelay` | uint48  | Time after exit before withdrawal (e.g., 48 hours) |
| `feeDoublingPeriod`   | uint48  | Time period for fee doubling (e.g., 15 minutes)    |
| `maxFeeDoublings`     | uint8   | Max doublings allowed (e.g., 8 = 256x cap)         |
| `initialMaxFee`       | uint48  | Initial max fee for first-ever bid (in Gwei)       |

### Derived Values

| Value                | Formula                                  | Purpose                           |
| -------------------- | ---------------------------------------- | --------------------------------- |
| Required Bond        | `livenessBond * maxPendingProposals * 2` | Minimum bond to become prover     |
| Force-Exit Threshold | `livenessBond * maxPendingProposals / 2` | Bond level triggering forced exit |

---

## Data Structures

### Prover (1 Storage Slot)

```solidity
/// @dev Packed into 32 bytes for single SLOAD in getCurrentProver()
struct Prover {
    address addr;         // 20 bytes - prover address
    uint48 feeInGwei;     // 6 bytes - fee per proposal
    uint48 exitTimestamp; // 6 bytes - when exited (0 = active)
}
```

### BondInfo (Per Address)

```solidity
struct BondInfo {
    uint128 balance;       // Bond token balance
    uint48 withdrawableAt; // When withdrawal allowed (0 = immediately if not current prover)
}
```

### Storage Layout

```solidity
Prover internal _prover;                          // Current prover (1 slot)
mapping(address => BondInfo) internal _bonds;     // Bond balances
uint48 internal _movingAverageFee;                // EMA of winning fees
uint128 internal _totalSlashDiff;                 // Accumulated (slashed - rewarded), locked forever
uint48 internal _contractCreationTime;            // For initial fee timing
```

---

## Interface

```solidity
interface IProverAuction {
    // ═══════════════════════════════════════════════════════════════════
    //                              EVENTS
    // ═══════════════════════════════════════════════════════════════════

    event Deposited(address indexed account, uint128 amount);
    event Withdrawn(address indexed account, uint128 amount);
    event BidPlaced(address indexed newProver, uint48 feeInGwei, address indexed oldProver);
    event ExitRequested(address indexed prover, uint48 withdrawableAt);
    event BondSlashed(
        address indexed prover,
        uint128 slashed,
        address indexed recipient,
        uint128 rewarded
    );
    event ProverForcedOut(address indexed prover);

    // ═══════════════════════════════════════════════════════════════════
    //                         BOND MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Deposit bond tokens to caller's balance
    function deposit(uint128 _amount) external;

    /// @notice Withdraw bond tokens (must not be current prover, must pass delay)
    function withdraw(uint128 _amount) external;

    // ═══════════════════════════════════════════════════════════════════
    //                         AUCTION FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Get current active prover and fee
    /// @dev Optimized for 1 SLOAD - called on every proposal
    function getCurrentProver() external view returns (address prover_, uint48 feeInGwei_);

    /// @notice Get maximum allowed bid fee at current time
    /// @dev Considers active prover (5% reduction) or vacancy (time-based cap)
    function getMaxBidFee() external view returns (uint48);

    /// @notice Submit bid to become prover, or lower fee if already current prover
    /// @param _feeInGwei Fee per proposal in Gwei
    /// @dev If caller is current prover: fee must be lower than current (no 5% requirement)
    /// @dev If caller is not current prover: fee must be at least 5% lower than current
    /// @dev If slot is vacant: fee must be within time-based cap
    function bid(uint48 _feeInGwei) external;

    /// @notice Request to exit as current prover
    function requestExit() external;

    // ═══════════════════════════════════════════════════════════════════
    //                         SLASHING (INBOX ONLY)
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Slash prover's bond
    /// @param _prover Address to slash
    /// @param _slashAmount Amount to slash from bond
    /// @param _recipient Address to receive reward (actual prover who proved)
    /// @param _rewardAmount Amount to reward recipient
    function slashBond(
        address _prover,
        uint128 _slashAmount,
        address _recipient,
        uint128 _rewardAmount
    ) external;

    // ═══════════════════════════════════════════════════════════════════
    //                         VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    function getBondInfo(address _account) external view returns (BondInfo memory);
    function getRequiredBond() external view returns (uint128);
    function getForceExitThreshold() external view returns (uint128);
    function getMovingAverageFee() external view returns (uint48);
    function getTotalSlashDiff() external view returns (uint128);
}
```

---

## Core Logic

### getCurrentProver() — 1 SLOAD

```solidity
function getCurrentProver() external view returns (address prover_, uint48 feeInGwei_) {
    Prover memory p = _prover;

    if (p.addr == address(0) || p.exitTimestamp > 0) {
        return (address(0), 0);
    }

    return (p.addr, p.feeInGwei);
}
```

### getMaxBidFee() — Time-Based Cap

```solidity
function getMaxBidFee() public view returns (uint48) {
    Prover memory current = _prover;

    // Active prover: must undercut by minFeeReductionBps
    if (current.addr != address(0) && current.exitTimestamp == 0) {
        return uint48(uint256(current.feeInGwei) * (10000 - minFeeReductionBps) / 10000);
    }

    // Vacant: time-based doubling
    uint48 baseFee;
    uint48 startTime;

    if (current.addr == address(0)) {
        // Never had a prover
        baseFee = initialMaxFee;
        startTime = _contractCreationTime;
    } else {
        // Previous prover exited
        baseFee = current.feeInGwei;
        startTime = current.exitTimestamp;
    }

    uint256 elapsed = block.timestamp - startTime;
    uint256 periods = elapsed / feeDoublingPeriod;

    if (periods > maxFeeDoublings) {
        periods = maxFeeDoublings;
    }

    uint256 maxFee = uint256(baseFee) << periods; // baseFee * 2^periods

    if (maxFee > type(uint48).max) {
        return type(uint48).max;
    }

    return uint48(maxFee);
}
```

### bid() — Unified for New Bidders and Current Prover

```solidity
function bid(uint48 _feeInGwei) external {
    BondInfo storage bidderBond = _bonds[msg.sender];

    // 1. Validate bond
    require(bidderBond.balance >= getRequiredBond(), "Insufficient bond");

    // 2. Load current prover
    Prover memory current = _prover;

    // 3. Validate fee based on caller
    bool isVacant = current.addr == address(0) || current.exitTimestamp > 0;
    bool isSelfBid = current.addr == msg.sender && !isVacant;

    if (isSelfBid) {
        // Current prover lowering their own fee - just needs to be lower
        require(_feeInGwei < current.feeInGwei, "Fee must be lower");
    } else if (isVacant) {
        // Vacant slot: time-based cap
        require(_feeInGwei <= getMaxBidFee(), "Fee too high");
    } else {
        // Outbidding another prover: 5% reduction required
        uint48 maxAllowedFee = uint48(uint256(current.feeInGwei) * (10000 - minFeeReductionBps) / 10000);
        require(_feeInGwei <= maxAllowedFee, "Fee reduction too small");
    }

    // 4. Clear bidder's exit status if re-entering
    bidderBond.withdrawableAt = 0;

    // 5. Handle outbid prover (only if different address)
    if (current.addr != address(0) && current.addr != msg.sender) {
        _bonds[current.addr].withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
    }

    // 6. Set new prover
    _prover = Prover({
        addr: msg.sender,
        feeInGwei: _feeInGwei,
        exitTimestamp: 0
    });

    // 7. Update moving average
    _updateMovingAverage(_feeInGwei);

    emit BidPlaced(msg.sender, _feeInGwei, current.addr);
}
```

### requestExit()

```solidity
function requestExit() external {
    Prover storage p = _prover;

    require(p.addr == msg.sender, "Not current prover");
    require(p.exitTimestamp == 0, "Already exited");

    p.exitTimestamp = uint48(block.timestamp);
    _bonds[msg.sender].withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;

    emit ExitRequested(msg.sender, _bonds[msg.sender].withdrawableAt);
}
```

### deposit()

```solidity
function deposit(uint128 _amount) external {
    bondToken.safeTransferFrom(msg.sender, address(this), _amount);
    _bonds[msg.sender].balance += _amount;
    emit Deposited(msg.sender, _amount);
}
```

### withdraw()

```solidity
function withdraw(uint128 _amount) external {
    BondInfo storage info = _bonds[msg.sender];

    require(_prover.addr != msg.sender, "Current prover cannot withdraw");

    if (info.withdrawableAt > 0) {
        require(block.timestamp >= info.withdrawableAt, "Withdrawal delay not passed");
    }

    require(info.balance >= _amount, "Insufficient balance");
    info.balance -= _amount;

    bondToken.safeTransfer(msg.sender, _amount);
    emit Withdrawn(msg.sender, _amount);
}
```

### slashBond()

```solidity
function slashBond(
    address _proverAddr,
    uint128 _slashAmount,
    address _recipient,
    uint128 _rewardAmount
) external {
    require(msg.sender == inbox, "Only Inbox");

    BondInfo storage bond = _bonds[_proverAddr];

    // Best-effort slash
    uint128 actualSlash = _slashAmount > bond.balance ? bond.balance : _slashAmount;
    bond.balance -= actualSlash;

    // Reward recipient
    uint128 actualReward = _rewardAmount > actualSlash ? actualSlash : _rewardAmount;
    if (actualReward > 0 && _recipient != address(0)) {
        bondToken.safeTransfer(_recipient, actualReward);
    }

    // Track difference (locked forever in contract)
    _totalSlashDiff += actualSlash - actualReward;

    emit BondSlashed(_proverAddr, actualSlash, _recipient, actualReward);

    // Force out if below threshold
    Prover storage currentProver = _prover;
    if (_proverAddr == currentProver.addr && bond.balance < getForceExitThreshold()) {
        currentProver.exitTimestamp = uint48(block.timestamp);
        bond.withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
        emit ProverForcedOut(_proverAddr);
    }
}
```

### \_updateMovingAverage()

```solidity
/// @dev Exponential moving average - updated on every bid (including self-bids)
function _updateMovingAverage(uint48 _newFee) internal {
    uint48 currentAvg = _movingAverageFee;

    if (currentAvg == 0) {
        _movingAverageFee = _newFee;
    } else {
        // EMA with N=10: newAvg = (oldAvg * 9 + newFee) / 10
        _movingAverageFee = uint48((uint256(currentAvg) * 9 + uint256(_newFee)) / 10);
    }
}
```

---

## Fee Rules Summary

| Scenario                            | Max Fee                    |
| ----------------------------------- | -------------------------- |
| Active prover exists (other bidder) | 95% of current fee         |
| Current prover self-bidding         | Any fee lower than current |
| Vacant: 0-15 min                    | 1x base fee                |
| Vacant: 15-30 min                   | 2x base fee                |
| Vacant: 30-45 min                   | 4x base fee                |
| Vacant: 45-60 min                   | 8x base fee                |
| ...                                 | ...                        |
| Vacant: 120+ min                    | 256x base fee (capped)     |

**Base fee** = previous prover's fee, or `initialMaxFee` if no previous prover.

---

## Q&A Section (All Answered)

| #   | Question                             | Answer                                                                  |
| --- | ------------------------------------ | ----------------------------------------------------------------------- |
| 1   | Bond slashing mechanism              | Inbox calls `slashBond()`. Best-effort. Force out when below threshold. |
| 2   | getCurrentProver returns address(0)? | Inbox handles it. Not Auction's concern.                                |
| 3   | Fee payment flow                     | Proposer pays prover directly in ETH. Auction not involved.             |
| 4   | Bond token                           | TAIKO token.                                                            |
| 5   | Auction model                        | Continuous. Immediate effect. Time-based fee cap on vacancy.            |
| 6   | Fee denomination                     | Gwei (uint48). Max ~281K ETH.                                           |
| 7   | Gas optimization                     | 1 SLOAD for `getCurrentProver()`.                                       |
| 8   | Upgrade path                         | Upgradeable via proxy.                                                  |
| 9   | Slashed funds destination            | Kept in contract. Tracked via `_totalSlashDiff`.                        |
| 10  | Can prover update fee?               | Yes, via `bid()` — unified interface.                                   |
| 11  | Moving average init                  | First bid sets baseline.                                                |
| 12  | Reward recipient                     | Actual prover who submitted proof.                                      |
| 13  | Deposit for others?                  | No. Only own balance.                                                   |
| 14  | Vacancy fee handling                 | Time-based: 2x every 15 min, starting at previous fee.                  |
| 15  | Moving average affects vacancy cap?  | No — let market decide entirely.                                        |
| 16  | `_totalSlashDiff` funds              | Locked forever (no withdrawal mechanism).                               |
| 17  | Minimum fee                          | No minimum — if someone wants to prove for free, let them.              |
| 18  | Re-bidding by current prover         | Unified `bid()` — current prover can lower fee without 5% requirement.  |
| 19  | Bond top-up                          | Yes — `deposit()` always works. Prover can top up to avoid force-exit.  |
| 20  | Initial state                        | No prover — anyone can bid up to `initialMaxFee` (time-based).          |
| 21  | Prover can be a contract?            | Yes — any address allowed (EOA, multisig, smart contract wallet).       |
| 22  | Fee update affects moving average?   | Yes — all bids (including self-bids) update the moving average.         |

---

## Design Summary

### Key Design Decisions

1. **Unified `bid()` function** — removes separate `lowerFee()`, current prover uses same function
2. **No minimum fee** — market decides; free proving allowed
3. **Any address can be prover** — supports smart contract wallets and multisigs
4. **Slashed funds locked forever** — `_totalSlashDiff` has no withdrawal mechanism
5. **Deposit always allowed** — prover can top up bond during slashing to avoid force-exit
6. **Moving average updated on all bids** — including self-bids for fee reduction

### Storage Layout (Final)

| Variable                | Type     | Slots      | Access Pattern                  |
| ----------------------- | -------- | ---------- | ------------------------------- |
| `_prover`               | Prover   | 1          | Every `getCurrentProver()` call |
| `_bonds[addr]`          | BondInfo | 1 per addr | On deposit/withdraw/slash/bid   |
| `_movingAverageFee`     | uint48   | shared     | On bid                          |
| `_totalSlashDiff`       | uint128  | shared     | On slash                        |
| `_contractCreationTime` | uint48   | shared     | On getMaxBidFee (vacancy)       |

### Functions (Final)

| Function             | Caller             | Purpose                              |
| -------------------- | ------------------ | ------------------------------------ |
| `getCurrentProver()` | Inbox              | Get current prover and fee (1 SLOAD) |
| `getMaxBidFee()`     | Anyone             | Get max allowed bid at current time  |
| `bid(fee)`           | Anyone             | Become prover or lower own fee       |
| `requestExit()`      | Current prover     | Exit and start withdrawal timer      |
| `deposit(amount)`    | Anyone             | Add to own bond balance              |
| `withdraw(amount)`   | Non-current prover | Withdraw after delay                 |
| `slashBond(...)`     | Inbox only         | Slash prover's bond                  |

---

## Security Considerations

1. **Reentrancy**: Use `nonReentrant` on `deposit()`, `withdraw()`, `slashBond()`, `bid()`
2. **Access control**: `slashBond()` only callable by Inbox
3. **Overflow**: Solidity 0.8+ handles this
4. **Front-running**: 5% reduction requirement mitigates bid front-running
5. **Bond token trust**: Must be trusted ERC20 (TAIKO)
6. **Time manipulation**: Miners can manipulate timestamps slightly; 15-min periods are large enough to be safe
7. **Zero-fee griefing**: Allowed by design — requires full bond commitment

---

## Open Items

1. Exact immutable values to be determined:
   - `livenessBond`: TBD
   - `maxPendingProposals`: TBD
   - `bondWithdrawalDelay`: 48 hours (suggested)
   - `feeDoublingPeriod`: 15 minutes (suggested)
   - `maxFeeDoublings`: 8 (256x cap, suggested)
   - `initialMaxFee`: TBD
   - `minFeeReductionBps`: 500 (5%, suggested)
2. EMA smoothing factor (currently N=10)
3. Emergency pause functionality?
4. Integration testing with Inbox contract
