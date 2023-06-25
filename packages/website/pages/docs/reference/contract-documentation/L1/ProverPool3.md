---
title: ProverPool3
---

## ProverPool3

### NUM_SLOTS

```solidity
uint256 NUM_SLOTS
```

### EXIT_PERIOD

```solidity
uint256 EXIT_PERIOD
```

### totalStaked

```solidity
uint256 totalStaked
```

### Staker

```solidity
struct Staker {
  uint256 amount;
  uint256 numSlots;
  uint256 unstakedAt;
}
```

### slots

```solidity
mapping(uint256 => address) slots
```

### stakers

```solidity
mapping(address => struct ProverPool3.Staker) stakers
```

### assignProver

```solidity
function assignProver(uint64 blockId, uint32 feePerGas) external view returns (address prover, uint32 rewardPerGas)
```

### stake

```solidity
function stake(address staker, uint256 amount) external
```

### unstake

```solidity
function unstake(address staker) external
```

### claimSlot

```solidity
function claimSlot(address staker, uint256 slotIdx) external
```

### slashProver

```solidity
function slashProver(address staker) external
```

### withdraw

```solidity
function withdraw(address staker) public
```

### getNumClaimableSlots

```solidity
function getNumClaimableSlots(address staker) public view returns (uint256)
```

### isSlotClaimable

```solidity
function isSlotClaimable(uint256 slotIdx) public view returns (bool)
```

### getClaimableSlots

```solidity
function getClaimableSlots() public view returns (uint256[])
```
