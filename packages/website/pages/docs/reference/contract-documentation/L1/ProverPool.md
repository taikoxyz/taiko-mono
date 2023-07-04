---
title: ProverPool
---

## ProverPool

### Prover

```solidity
struct Prover {
  uint64 stakedAmount;
  uint16 rewardPerGas;
  uint16 currentCapacity;
  uint64 weight;
}
```

### Staker

```solidity
struct Staker {
  uint64 exitRequestedAt;
  uint64 exitAmount;
  uint16 maxCapacity;
  uint8 proverId;
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

### MIN_SLASH_AMOUNT

```solidity
uint64 MIN_SLASH_AMOUNT
```

### MAX_NUM_PROVERS

```solidity
uint256 MAX_NUM_PROVERS
```

### MIN_CHANGE_DELAY

```solidity
uint256 MIN_CHANGE_DELAY
```

### provers

```solidity
struct ProverPool.Prover[1024] provers
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

### CHANGE_TOO_FREQUENT

```solidity
error CHANGE_TOO_FREQUENT()
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
function assignProver(uint64 blockId, uint32) external returns (address prover, uint32 rewardPerGas)
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
function getProvers() public view returns (struct ProverPool.Prover[] _provers, address[] _stakers)
```

---

## title: ProxiedProverPool

## ProxiedProverPool
