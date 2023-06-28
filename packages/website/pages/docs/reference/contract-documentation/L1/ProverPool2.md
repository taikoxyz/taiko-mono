---
title: ProverPool2
---

## ProverPool2

### NUM_SLOTS

```solidity
uint256 NUM_SLOTS
```

### EXIT_PERIOD

```solidity
uint256 EXIT_PERIOD
```

### SLASH_POINTS

```solidity
uint32 SLASH_POINTS
```

### MAX_CAPACITY_LOWER_BOUND

```solidity
uint8 MAX_CAPACITY_LOWER_BOUND
```

### totalStaked

```solidity
uint256 totalStaked
```

### totalWeight

```solidity
uint256 totalWeight
```

### Withdrawn

```solidity
event Withdrawn(address addr, uint256 amount)
```

### Exited

```solidity
event Exited(address addr, uint256 amount)
```

### Slashed

```solidity
event Slashed(address addr, uint256 amount)
```

### Staked

```solidity
event Staked(address addr, uint256 amount, uint16 rewardPerGas, uint16 currentCapacity)
```

### PP_CAPACITY_INCORRECT

```solidity
error PP_CAPACITY_INCORRECT()
```

### PP_CANNOT_BE_PREFERRED

```solidity
error PP_CANNOT_BE_PREFERRED()
```

### PP_STAKE_AMOUNT_TOO_LOW

```solidity
error PP_STAKE_AMOUNT_TOO_LOW()
```

### Staker

```solidity
struct Staker {
  uint256 amount;
  uint256 numSlots;
  uint256 maxNumSlots;
  uint256 unstakedAt;
  uint16 rewardPerGas;
}
```

### preferredProver

```solidity
address preferredProver
```

### slots

```solidity
mapping(uint256 => address) slots
```

### stakers

```solidity
mapping(address => struct ProverPool2.Staker) stakers
```

### init

```solidity
function init(address _addressManager) external
```

### assignProver

```solidity
function assignProver(uint64 blockId, uint32 feePerGas) external view returns (address prover, uint32 rewardPerGas)
```

### stake

```solidity
function stake(uint256 amount, uint16 rewardPerGas, uint16 maxCapacity) external
```

### unstake

```solidity
function unstake() external
```

### releaseProver

```solidity
function releaseProver(address addr) external pure
```

### setMaxNumSlots

```solidity
function setMaxNumSlots(address staker, uint16 maxNumSlots) external
```

### claimSlot

```solidity
function claimSlot(address staker, uint256 slotIdx) public
```

### claimPreferredProverStatus

```solidity
function claimPreferredProverStatus(address staker) external
```

### slashProver

```solidity
function slashProver(address slashed) external
```

### withdraw

```solidity
function withdraw(address staker) public
```

### getWeight

```solidity
function getWeight(address staker) public view returns (uint256)
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

---

## title: ProxiedProverPool2

## ProxiedProverPool2
