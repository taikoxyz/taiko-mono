# Multi-Prover Auction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a multi-prover auction implementation that allows multiple current provers at the same fee, while keeping `getProver()` O(1) and preserving the existing single-prover `ProverAuction` behavior.

**Architecture:** Introduce a new `MultiProverAuctionBase` contract with pool management and O(1) prover selection via precomputed slot tables, plus derived contracts for each option (bond premium, fee tax, weighted selection). Keep `IProverAuction` minimal and add an internal Inbox-only interface for `slashProver` and any option-2 fee-tax helpers.

**Tech Stack:** Solidity 0.8.26, Foundry tests, Taiko protocol contracts.

## Decisions (locked)

1) Max pool size cap: 16.  
2) Slot table size for O(1) weighted selection: 256.  
3) Option 2 tax recipient: not applicable (Option 2 not implemented).  
4) Weight curve for Option 3: linear decay by join order.  

## Options Comparison (summary)

- **Option 1: Bond premium (+5% per join order)**
  - Pros: Simple, no fee-path changes, deters late joiners, naturally caps pool size.
  - Cons: Higher capital barrier for late provers.
- **Option 2: Fee tax (1% per join order)**
  - Pros: Ongoing disincentive, no extra bond.
  - Cons: Requires fee-path changes in `Inbox`, more complexity and extra gas.
- **Option 3: Weighted selection (late provers selected less)**
  - Pros: Preserves fee path, keeps capital flat, strong incentive alignment.
  - Cons: Requires slot-table rebuilds on pool changes.

**Recommended best achievable:** Option 1 + Option 3 combined in a dedicated contract (no flags).

---

### Task 0: Confirm parameters (non-code)

**Files:**
- Modify: `docs/plans/2026-01-01-multi-prover-auction.md`

**Step 1:** Record the chosen max pool size, slot table size, tax recipient, and weight curve in this plan.

---

### Task 1: Trim interface and add Inbox-only interface

**Files:**
- Modify: `packages/protocol/contracts/layer1/core/iface/IProverAuction.sol`
- Create: `packages/protocol/contracts/layer1/core/impl/IProverAuctionInbox.sol`
- Modify: `packages/protocol/contracts/layer1/core/impl/Inbox.sol`

**Step 1: Write failing test (rename + interface compile break)**

Update one test that calls `getCurrentProver()` to use `getProver()` so compilation fails until code is updated.

```solidity
// packages/protocol/test/layer1/core/ProverAuction.t.sol
(address prover, uint32 fee) = auction.getProver();
```

**Step 2: Run test to verify it fails**

Run:

```bash
cd packages/protocol
forge test --match-path test/layer1/core/ProverAuction.t.sol -vvv
```

Expected: compile error (function `getProver` not found).

**Step 3: Update `IProverAuction.sol` to the minimal surface**

```solidity
// packages/protocol/contracts/layer1/core/iface/IProverAuction.sol
interface IProverAuction {
    event ProverSlashed(
        address indexed prover,
        uint128 slashed,
        address indexed recipient,
        uint128 rewarded
    );
    event ProverEjected(address indexed prover);

    function bid(uint32 _feeInGwei) external;
    function requestExit() external;
    function getProver() external view returns (address prover_, uint32 feeInGwei_);
    function checkBondDeferWithdrawal(address _prover) external returns (bool success_);
    function getRequiredBond() external view returns (uint128 requiredBond_);
    function getLivenessBond() external view returns (uint96 livenessBond_);
    function getEjectionThreshold() external view returns (uint128 threshold_);
    function getTotalSlashedAmount() external view returns (uint128 totalSlashedAmount_);
}
```

**Step 4: Add Inbox-only interface for slashing**

```solidity
// packages/protocol/contracts/layer1/core/impl/IProverAuctionInbox.sol
pragma solidity ^0.8.26;

import { IProverAuction } from "../iface/IProverAuction.sol";

interface IProverAuctionInbox is IProverAuction {
    function slashProver(address _prover, address _recipient) external;
}
```

**Step 5: Update `Inbox.sol` imports and call site**

```solidity
// packages/protocol/contracts/layer1/core/impl/Inbox.sol
import { IProverAuctionInbox } from "./IProverAuctionInbox.sol";

IProverAuctionInbox internal immutable _proverAuction;

// rename call
(address currentProver, uint32 feeInGwei) = _proverAuction.getProver();
```

**Step 6: Run tests again**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/ProverAuction.t.sol -vvv
```

Expected: new compile errors in `ProverAuction.sol` and other tests (to fix next tasks).

**Step 7: Commit**

```bash
git add packages/protocol/contracts/layer1/core/iface/IProverAuction.sol \
        packages/protocol/contracts/layer1/core/impl/IProverAuctionInbox.sol \
        packages/protocol/contracts/layer1/core/impl/Inbox.sol \
        packages/protocol/test/layer1/core/ProverAuction.t.sol
git commit -m "refactor: slim IProverAuction and rename getProver"
```

---

### Task 2: Keep single-prover behavior, add `getProver` wrapper

**Files:**
- Modify: `packages/protocol/contracts/layer1/core/impl/ProverAuction.sol`

**Step 1: Write failing test (single-prover path still works via getProver)**

```solidity
// packages/protocol/test/layer1/core/ProverAuction.t.sol
function test_getProver_returnsActiveProver() public {
    (address prover, uint32 fee) = auction.getProver();
    assertEq(prover, address(0));
    assertEq(fee, 0);
}
```

**Step 2: Run test to verify it fails**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/ProverAuction.t.sol::ProverAuctionTest::test_getProver_returnsActiveProver -vvv
```

Expected: compile error (function `getProver` missing on ProverAuction).

**Step 3: Add wrapper in `ProverAuction.sol` without behavior change**

```solidity
/// @inheritdoc IProverAuction
function getProver() external view returns (address prover_, uint32 feeInGwei_) {
    return this.getCurrentProver();
}
```

**Step 4: Update NatSpec for functions no longer in interface**

Replace `@inheritdoc IProverAuction` on functions removed from the interface
with plain NatSpec (or `@dev`) so compilation is clean.

**Step 5: Run tests**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/ProverAuction.t.sol -vvv
```

Expected: compile passes, tests may still fail until new multi-prover tests are added.

**Step 6: Commit**

```bash
git add packages/protocol/contracts/layer1/core/impl/ProverAuction.sol \
        packages/protocol/test/layer1/core/ProverAuction.t.sol
git commit -m "feat: add getProver wrapper to ProverAuction"
```

---

### Task 3: Introduce shared types (move BondInfo out of interface)

**Files:**
- Create: `packages/protocol/contracts/layer1/core/impl/ProverAuctionTypes.sol`
- Modify: `packages/protocol/contracts/layer1/core/impl/ProverAuction.sol`
- Modify: `packages/protocol/contracts/layer1/core/impl/MultiProverAuctionBase.sol` (next task)

**Step 1: Add shared types**

```solidity
// packages/protocol/contracts/layer1/core/impl/ProverAuctionTypes.sol
pragma solidity ^0.8.26;

library ProverAuctionTypes {
    struct BondInfo {
        uint128 balance;
        uint48 withdrawableAt;
    }
}
```

**Step 2: Update ProverAuction to use shared type**

```solidity
import { ProverAuctionTypes } from "./ProverAuctionTypes.sol";

mapping(address account => ProverAuctionTypes.BondInfo info) internal _bonds;
```

**Step 3: Run tests**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/ProverAuction.t.sol -vvv
```

**Step 4: Commit**

```bash
git add packages/protocol/contracts/layer1/core/impl/ProverAuctionTypes.sol \
        packages/protocol/contracts/layer1/core/impl/ProverAuction.sol
git commit -m "refactor: move BondInfo to shared types"
```

---

### Task 4: Build `MultiProverAuctionBase` (pool + O(1) selection)

**Files:**
- Create: `packages/protocol/contracts/layer1/core/impl/MultiProverAuctionBase.sol`
- Create: `packages/protocol/contracts/layer1/core/impl/MultiProverAuction_Layout.sol`
- Modify: `packages/protocol/contracts/layer1/core/impl/ProverAuctionTypes.sol`

**Step 1: Write failing tests for multi-prover pool**

Create a new test file and add a minimal failing test:

```solidity
// packages/protocol/test/layer1/core/MultiProverAuction.t.sol
function test_getProver_returnsZeroWhenNoPool() public view {
    (address prover, uint32 fee) = multi.getProver();
    assertEq(prover, address(0));
    assertEq(fee, 0);
}
```

**Step 2: Run test to verify it fails**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/MultiProverAuction.t.sol -vvv
```

Expected: compile error (contract not found).

**Step 3: Add base storage and pool structures**

```solidity
// MultiProverAuctionBase.sol (core storage)
struct PoolState {
    uint32 feeInGwei;
    uint8 poolSize;
    uint48 vacantSince;
}

struct PoolMember {
    uint8 index;
    uint8 joinOrder;
    uint16 weightBps;
    bool active;
}

uint8 public constant MAX_POOL_SIZE = 16;
uint16 public constant SLOT_TABLE_SIZE = 256; // confirm in Task 0

PoolState internal _pool;
address[MAX_POOL_SIZE] internal _activeProvers;
uint8[SLOT_TABLE_SIZE] internal _slotTable;
mapping(address => PoolMember) internal _members;
mapping(address => ProverAuctionTypes.BondInfo) internal _bonds;
```

**Step 4: Implement O(1) `getProver()` (no loops)**

```solidity
function getProver() external view returns (address prover_, uint32 feeInGwei_) {
    PoolState memory p = _pool;
    if (p.poolSize == 0 || p.vacantSince > 0) return (address(0), 0);
    uint8 slot = uint8(uint256(block.number) % SLOT_TABLE_SIZE);
    uint8 idx = _slotTable[slot];
    return (_activeProvers[idx], p.feeInGwei);
}
```

**Step 5: Implement pool mutation helpers (O(n), bounded by cap)**

```solidity
function _resetPool(address leader, uint32 fee) internal {
    _pool.feeInGwei = fee;
    _pool.poolSize = 1;
    _pool.vacantSince = 0;
    _activeProvers[0] = leader;
    _members[leader] = PoolMember({ index: 0, joinOrder: 1, weightBps: _weightForJoin(1), active: true });
    _rebuildSlotTable();
}

function _addToPool(address prover) internal {
    uint8 size = _pool.poolSize;
    require(size < MAX_POOL_SIZE, PoolFull());
    _activeProvers[size] = prover;
    _members[prover] = PoolMember({ index: size, joinOrder: uint8(size + 1), weightBps: _weightForJoin(uint8(size + 1)), active: true });
    _pool.poolSize = size + 1;
    _rebuildSlotTable();
}

function _removeFromPool(address prover) internal {
    PoolMember memory m = _members[prover];
    if (!m.active) return;
    uint8 last = _pool.poolSize - 1;
    if (m.index != last) {
        address swapped = _activeProvers[last];
        _activeProvers[m.index] = swapped;
        _members[swapped].index = m.index;
    }
    _activeProvers[last] = address(0);
    _members[prover].active = false;
    _pool.poolSize = last;
    if (_pool.poolSize == 0) _pool.vacantSince = uint48(block.timestamp);
    _rebuildSlotTable();
}
```

**Step 6: Implement slot-table rebuild (bounded by SLOT_TABLE_SIZE)**

```solidity
function _rebuildSlotTable() internal {
    uint8 size = _pool.poolSize;
    if (size == 0) return;
    uint256 totalWeight = 0;
    for (uint8 i = 0; i < size; i++) {
        totalWeight += _members[_activeProvers[i]].weightBps;
    }
    uint16 cursor = 0;
    for (uint8 i = 0; i < size; i++) {
        uint256 slots = SLOT_TABLE_SIZE * _members[_activeProvers[i]].weightBps / totalWeight;
        for (uint256 j = 0; j < slots && cursor < SLOT_TABLE_SIZE; j++) {
            _slotTable[cursor++] = i;
        }
    }
    while (cursor < SLOT_TABLE_SIZE) {
        _slotTable[cursor++] = uint8(size - 1);
    }
}
```

**Step 7: Implement bid / join / outbid logic**

- If pool is vacant: accept bid under max fee, reset pool to bidder.
- If fee equals current fee: treat as join (requires extra bond for option 1).
- If fee is lower: outbid (reset pool and set previous members withdrawable).

Use `ProverAuction` logic for moving average and max fee (copy into base).

**Step 8: Implement slashing/ejection and withdrawal deferral**

- `slashProver` (Inbox-only): slash bond; if below threshold, remove from pool and set withdrawableAt.
- `checkBondDeferWithdrawal`: return false if below threshold; set withdrawableAt on prover.

**Step 9: Run tests**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/MultiProverAuction.t.sol -vvv
```

Expected: tests fail until option-specific behavior is added.

**Step 10: Commit**

```bash
git add packages/protocol/contracts/layer1/core/impl/MultiProverAuctionBase.sol \
        packages/protocol/contracts/layer1/core/impl/MultiProverAuction_Layout.sol \
        packages/protocol/test/layer1/core/MultiProverAuction.t.sol
git commit -m "feat: add multi-prover auction base"
```

---

### Task 5: Implement the three option contracts (no flags)

**Files:**
- Create: `packages/protocol/contracts/layer1/core/impl/MultiProverAuctionPremium.sol`
- Create: `packages/protocol/contracts/layer1/core/impl/MultiProverAuctionWeighted.sol`
- Create: `packages/protocol/contracts/layer1/core/impl/MultiProverAuctionFeeTax.sol`
- Create: `packages/protocol/contracts/layer1/core/impl/MultiProverAuctionPremiumWeighted.sol` (recommended)

**Step 1: Option 1 (bond premium)**

```solidity
// MultiProverAuctionPremium.sol
function _requiredBondForJoin(uint8 joinOrder) internal view override returns (uint128) {
    // joinOrder 1 => 100%, 2 => 105%, 3 => 110%
    uint256 bps = 10_000 + uint256(joinOrder - 1) * 500;
    return uint128(uint256(getRequiredBond()) * bps / 10_000);
}
```

**Step 2: Option 3 (weighted selection)**

```solidity
// MultiProverAuctionWeighted.sol
function _weightForJoin(uint8 joinOrder) internal pure override returns (uint16) {
    // Example: linear decay 10000, 9000, 8000 ... (confirm in Task 0)
    uint256 weight = 10_000 - uint256(joinOrder - 1) * 1_000;
    if (weight < 1) weight = 1;
    return uint16(weight);
}
```

**Step 3: Option 2 (fee tax)**

Add a small fee-tax interface and update `Inbox` fee collection in Task 6.

```solidity
// MultiProverAuctionFeeTax.sol
function feeTaxBps(address prover) external view returns (uint16) {
    uint8 joinOrder = _members[prover].joinOrder;
    if (joinOrder <= 1) return 0;
    return uint16((joinOrder - 1) * 100); // 1% per join order
}

function feeTaxRecipient() external view returns (address) {
    return _taxRecipient;
}
```

**Step 4: Combine Option 1 + 3 (recommended)**

Create `MultiProverAuctionPremiumWeighted.sol` that overrides both hooks.

**Step 5: Run tests**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/MultiProverAuction.t.sol -vvv
```

**Step 6: Commit**

```bash
git add packages/protocol/contracts/layer1/core/impl/MultiProverAuction*.sol
git commit -m "feat: add option-specific multi-prover auction variants"
```

---

### Task 6: Update Inbox for Option 2 fee tax

**Files:**
- Create: `packages/protocol/contracts/layer1/core/impl/IProverAuctionFeeTax.sol`
- Modify: `packages/protocol/contracts/layer1/core/impl/Inbox.sol`

**Step 1: Add fee-tax interface**

```solidity
// IProverAuctionFeeTax.sol
pragma solidity ^0.8.26;

interface IProverAuctionFeeTax {
    function feeTaxBps(address prover) external view returns (uint16);
    function feeTaxRecipient() external view returns (address);
}
```

**Step 2: Update `_collectProverFee` to apply tax (only for fee-tax auction)**

```solidity
// Inbox.sol (new helper for option 2)
function _collectProverFeeWithTax(
    address designatedProver,
    uint32 feeInGwei
)
    private
    returns (uint256 refund_)
{
    refund_ = msg.value;
    if (feeInGwei == 0 || msg.sender == designatedProver) return refund_;
    uint256 feeWei = uint256(feeInGwei) * 1 gwei;
    require(msg.value >= feeWei, ProverFeeNotPaid());

    uint16 taxBps = IProverAuctionFeeTax(address(_proverAuction)).feeTaxBps(designatedProver);
    address recipient = IProverAuctionFeeTax(address(_proverAuction)).feeTaxRecipient();
    uint256 taxWei = feeWei * taxBps / 10_000;

    (bool paidProver,) = payable(designatedProver).call{ value: feeWei - taxWei }("");
    if (paidProver) {
        refund_ = msg.value - feeWei;
        if (taxWei > 0) {
            (bool paidTax,) = payable(recipient).call{ value: taxWei }("");
            if (!paidTax) refund_ += taxWei;
        }
    }
}
```

**Step 3: Add tests for fee tax**

- Ensure tax is sent to recipient.
- Ensure full refund if prover rejects payment.

**Step 4: Run targeted tests**

```bash
cd packages/protocol
forge test --match-path test/layer1/core/InboxProverAuctionTest.t.sol -vvv
```

**Step 5: Commit**

```bash
git add packages/protocol/contracts/layer1/core/impl/IProverAuctionFeeTax.sol \
        packages/protocol/contracts/layer1/core/impl/Inbox.sol
git commit -m "feat: add optional fee-tax path for option 2"
```

---

### Task 7: Comprehensive tests and gas checks

**Files:**
- Modify/Create: `packages/protocol/test/layer1/core/MultiProverAuction.t.sol`
- Modify: `packages/protocol/test/layer1/core/ProverAuction.t.sol`

**Step 1: Add tests for pool join, outbid reset, exit, and ejection**

Examples to add:

```solidity
function test_joinSameFee_addsToPool() public { /* ... */ }
function test_outbid_resetsPool() public { /* ... */ }
function test_requestExit_removesFromPool() public { /* ... */ }
function test_slash_ejectsLowBondProver() public { /* ... */ }
```

**Step 2: Add tests for option-specific behavior**

- Option 1: bond premium for join order 2 and 3.
- Option 3: weighted distribution by sampling `getProver()` across many blocks.
- Option 2: tax calculation and recipient payment.

**Step 3: Add gas tests for O(1) `getProver()`**

- Compare gas with pool size 1 vs max pool size.

**Step 4: Run full suite**

```bash
cd packages/protocol
forge test -vvv
```

**Step 5: Commit**

```bash
git add packages/protocol/test/layer1/core
git commit -m "test: add multi-prover auction coverage"
```

---

### Task 8: Documentation and migration notes

**Files:**
- Modify: `README.md` (or protocol docs)

**Step 1:** Add a short section explaining multi-prover pool behavior, options, and the recommended default.

**Step 2:** Document deployment steps (new auction address in `Inbox` config).

**Step 3:** Commit

```bash
git add README.md
git commit -m "docs: document multi-prover auction options"
```

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-01-01-multi-prover-auction.md`.

Two execution options:

1. Subagent-Driven (this session) - dispatch a fresh subagent per task, review between tasks
2. Parallel Session (separate) - open a new session and execute via `superpowers:executing-plans`
