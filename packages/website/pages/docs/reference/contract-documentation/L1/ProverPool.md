---
title: ProverPool
---

## ProverPool

This contract manages a pool of the top 32 provers. This pool is
where the protocol selects provers from to prove L1 block validity. There are
two actors:

- Provers (generating the proofs)
- Stakers (staking tokens for the provers)

### Prover

_These values are used to compute the prover's rank (along with the
protocol feePerGas)._

```solidity
struct Prover {
  uint64 stakedAmount;
  uint32 rewardPerGas;
  uint32 currentCapacity;
}
```

### Staker

_Make sure we only use one slot._

```solidity
struct Staker {
  uint64 exitRequestedAt;
  uint64 exitAmount;
  uint32 maxCapacity;
  uint32 proverId;
}
```

### MIN_CAPACITY

```solidity
uint32 MIN_CAPACITY
```

### EXIT_PERIOD

```solidity
uint64 EXIT_PERIOD
```

### SLASH_POINTS

```solidity
uint64 SLASH_POINTS
```

### SLASH_MULTIPLIER

```solidity
uint64 SLASH_MULTIPLIER
```

### MIN_STAKE_PER_CAPACITY

```solidity
uint64 MIN_STAKE_PER_CAPACITY
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

### proverIdToAddress

```solidity
mapping(uint256 => address) proverIdToAddress
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
event Slashed(uint64 blockId, address addr, uint64 amount)
```

### Staked

```solidity
event Staked(address addr, uint64 amount, uint32 rewardPerGas, uint32 currentCapacity)
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
function assignProver(uint64 blockId, uint32 feePerGas) external returns (address prover, uint32 rewardPerGas)
```

_Protocol specifies the current feePerGas and assigns a prover to a
block._

#### Parameters

| Name      | Type   | Description              |
| --------- | ------ | ------------------------ |
| blockId   | uint64 | The block id.            |
| feePerGas | uint32 | The current fee per gas. |

#### Return Values

| Name         | Type    | Description                                 |
| ------------ | ------- | ------------------------------------------- |
| prover       | address | The address of the assigned prover.         |
| rewardPerGas | uint32  | The reward per gas for the assigned prover. |

### releaseProver

```solidity
function releaseProver(address addr) external
```

_Increases the capacity of the prover by releasing a prover._

#### Parameters

| Name | Type    | Description                           |
| ---- | ------- | ------------------------------------- |
| addr | address | The address of the prover to release. |

### slashProver

```solidity
function slashProver(uint64 blockId, address addr, uint64 proofReward) external
```

_Slashes a prover._

#### Parameters

| Name        | Type    | Description                         |
| ----------- | ------- | ----------------------------------- |
| blockId     | uint64  |                                     |
| addr        | address | The address of the prover to slash. |
| proofReward | uint64  |                                     |

### stake

```solidity
function stake(uint64 amount, uint32 rewardPerGas, uint32 maxCapacity) external
```

This function is used for a staker to stake tokens for a prover.
It will also perform the logic of updating the prover's rank, possibly
moving it into the active prover pool.

#### Parameters

| Name         | Type   | Description                                                                                                                                                 |
| ------------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| amount       | uint64 | The amount of Taiko tokens to stake.                                                                                                                        |
| rewardPerGas | uint32 | The expected reward per gas for the prover. If the expected reward is higher (implying that the prover is less efficient), the prover will be ranked lower. |
| maxCapacity  | uint32 | The maximum number of blocks that a prover can handle.                                                                                                      |

### exit

```solidity
function exit() external
```

Request an exit for the staker. This will withdraw the staked
tokens and exit
prover from the pool.

### withdraw

```solidity
function withdraw() external
```

Withdraws staked tokens back from matured an exit.

### getStaker

```solidity
function getStaker(address addr) public view returns (struct ProverPool.Staker staker, struct ProverPool.Prover prover)
```

Retrieves the information of a staker and their corresponding
prover using their address.

#### Parameters

| Name | Type    | Description                |
| ---- | ------- | -------------------------- |
| addr | address | The address of the staker. |

#### Return Values

| Name   | Type                     | Description               |
| ------ | ------------------------ | ------------------------- |
| staker | struct ProverPool.Staker | The staker's information. |
| prover | struct ProverPool.Prover | The prover's information. |

### getCapacity

```solidity
function getCapacity() public view returns (uint256 capacity)
```

Calculates and returns the current total capacity of the pool.

#### Return Values

| Name     | Type    | Description                     |
| -------- | ------- | ------------------------------- |
| capacity | uint256 | The total capacity of the pool. |

### getProvers

```solidity
function getProvers() public view returns (struct ProverPool.Prover[] _provers, address[] _stakers)
```

Retreives the current active provers and their corresponding
stakers.

#### Return Values

| Name      | Type                       | Description                        |
| --------- | -------------------------- | ---------------------------------- |
| \_provers | struct ProverPool.Prover[] | The active provers.                |
| \_stakers | address[]                  | The stakers of the active provers. |

### getProverWeights

```solidity
function getProverWeights(uint32 feePerGas) public view returns (uint256[32] weights, uint32[32] erpg)
```

Returns the current active provers and their weights. The weight
is dependent on the:

1. The prover's amount staked.
2. The prover's current capacity.
3. The prover's expected reward per gas.
4. The protocol's current fee per gas.

#### Parameters

| Name      | Type   | Description                         |
| --------- | ------ | ----------------------------------- |
| feePerGas | uint32 | The protocol's current fee per gas. |

#### Return Values

| Name    | Type        | Description                                                                                                                      |
| ------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------- |
| weights | uint256[32] | The weights of the current provers in the pool.                                                                                  |
| erpg    | uint32[32]  | The effective reward per gas of the current provers in the pool. This is smoothed out to be in range of the current fee per gas. |

---

## title: ProxiedProverPool

## ProxiedProverPool
