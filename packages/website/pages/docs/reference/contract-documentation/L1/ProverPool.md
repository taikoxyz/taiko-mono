---
title: ProverPool
---

## ProverPool

### Prover

```solidity
struct Prover {
  uint32 weight;
  uint16 rewardPerGas;
  uint16 currentCapacity;
}
```

### Staker

```solidity
struct Staker {
  uint64 exitRequestedAt;
  uint64 exitAmount;
  uint64 stakedAmount;
  uint16 maxCapacity;
  uint8 proverId;
}
```

### ProverInfo

```solidity
struct ProverInfo {
  address addr;
  struct ProverPool.Prover prover;
  struct ProverPool.Staker staker;
}
```

### MAX_CAPACITY_LOWER_BOUND

```solidity
uint32 MAX_CAPACITY_LOWER_BOUND
```

### EXIT_PERIOD

```solidity
uint64 EXIT_PERIOD
```

### SLASH_POINTS

```solidity
uint32 SLASH_POINTS
```

### MIN_STAKE_PER_CAPACITY

```solidity
uint64 MIN_STAKE_PER_CAPACITY
```

### MAX_NUM_PROVERS

```solidity
uint256 MAX_NUM_PROVERS
```

### idToProver

```solidity
mapping(uint256 => address) idToProver
```

### stakers

```solidity
mapping(address => struct ProverPool.Staker) stakers
```

### Withdrawn

```solidity
event Withdrawn(address addr, uint64 amount)
```

### Exited

```solidity
event Exited(address addr, uint64 amount)
```

### Slashed

```solidity
event Slashed(address addr, uint64 amount)
```

### Staked

```solidity
event Staked(address addr, uint64 amount, uint16 rewardPerGas, uint16 currentCapacity)
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
function stake(uint64 amount, uint16 rewardPerGas, uint16 maxCapacity) external
```

### exit

```solidity
function exit() external
```

### withdraw

```solidity
function withdraw() external
```

### getStaker

```solidity
function getStaker(address addr) public view returns (struct ProverPool.Staker staker, struct ProverPool.Prover prover)
```

### getCapacity

```solidity
function getCapacity() public view returns (uint256 capacity)
```

### getProvers

```solidity
function getProvers() public view returns (struct ProverPool.ProverInfo[] _provers)
```

### getWeights

```solidity
function getWeights(uint32) public view returns (uint32[32] weights, uint256 totalWeight)
```

---

## title: ProxiedProverPool

## ProxiedProverPool
