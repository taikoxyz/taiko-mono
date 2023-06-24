---
title: ProverPool2
---

## ProverPool2

### Prover

```solidity
struct Prover {
  uint32 stakedAmount;
  uint16 rewardPerGas;
  uint16 currentCapacity;
}
```

### Staker

```solidity
struct Staker {
  uint64 exitRequestedAt;
  uint32 exitAmount;
  uint16 maxCapacity;
  uint8 proverId;
}
```

### EXIT_PERIOD

```solidity
uint64 EXIT_PERIOD
```

### ONE_TKO

```solidity
uint64 ONE_TKO
```

### SLASH_POINTS

```solidity
uint32 SLASH_POINTS
```

### MIN_STAKE_PER_CAPACITY

```solidity
uint32 MIN_STAKE_PER_CAPACITY
```

### MAX_CAPACITY_LOWER_BOUND

```solidity
uint32 MAX_CAPACITY_LOWER_BOUND
```

### idToProver

```solidity
mapping(uint256 => address) idToProver
```

### stakers

```solidity
mapping(address => struct ProverPool2.Staker) stakers
```

### provers

```solidity
struct ProverPool2.Prover[32] provers
```

### Withdrawn

```solidity
event Withdrawn(address addr, uint32 amount)
```

### Exited

```solidity
event Exited(address addr, uint32 amount)
```

### Staked

```solidity
event Staked(address addr, uint32 amount, uint16 rewardPerGas, uint16 currentCapacity)
```

### Slashed

```solidity
event Slashed(address addr, uint32 amount)
```

### INVALID_PARAMS

```solidity
error INVALID_PARAMS()
```

### NO_MATURE_EXIT

```solidity
error NO_MATURE_EXIT()
```

### PROVER_NOT_GOOD_ENOUGH

```solidity
error PROVER_NOT_GOOD_ENOUGH()
```

### UNAUTHORIZED

```solidity
error UNAUTHORIZED()
```

### onlyFromProtocol

```solidity
modifier onlyFromProtocol()
```

### init

```solidity
function init(address _addressManager) external
```

### assignProver

```solidity
function assignProver(uint64 blockId, uint32 feePerGas) external returns (address prover, uint32 rewardPerGas)
```

### releaseProver

```solidity
function releaseProver(address addr) external
```

### slashProver

```solidity
function slashProver(address addr) external
```

### stake

```solidity
function stake(uint32 amount, uint16 rewardPerGas, uint16 maxCapacity) external
```

### withdraw

```solidity
function withdraw() external
```

### getStaker

```solidity
function getStaker(address addr) public view returns (struct ProverPool2.Staker staker, struct ProverPool2.Prover prover)
```

### getCapacity

```solidity
function getCapacity() public view returns (uint256 capacity)
```

### getWeights

```solidity
function getWeights(uint32 feePerGas) public view returns (uint256[32] weights, uint256 totalWeight)
```

---

## title: ProxiedProverPool2

## ProxiedProverPool2
