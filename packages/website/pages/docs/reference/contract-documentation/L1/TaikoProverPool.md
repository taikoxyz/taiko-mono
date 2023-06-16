---
title: TaikoProverPool
---

## TaikoProverPool

### Prover

```solidity
struct Prover {
  address proverAddress;
  uint256 stakedTokens;
  uint256 rewards;
  uint256 healthScore;
  uint256 lastBlockTsToBeProven;
  uint32 capacity;
  uint32 numAssignedBlocks;
  uint8 feeMultiplier;
}
```

### provers

```solidity
mapping(address => struct TaikoProverPool.Prover) provers
```

### topProvers

```solidity
address[32] topProvers
```

### blockIdToProver

```solidity
mapping(uint256 => address) blockIdToProver
```

### MIN_TKO_AMOUNT

```solidity
uint256 MIN_TKO_AMOUNT
```

### proversInPool

```solidity
uint16 proversInPool
```

### maxPoolSize

```solidity
uint16 maxPoolSize
```

### MIN_MULTIPLIER

```solidity
uint8 MIN_MULTIPLIER
```

### MAX_MULTIPLIER

```solidity
uint8 MAX_MULTIPLIER
```

### ProverEntered

```solidity
event ProverEntered(address prover, uint256 amount, uint256 feeMultiplier, uint64 capacity)
```

### ProverExited

```solidity
event ProverExited(address prover)
```

### onlyProver

```solidity
modifier onlyProver()
```

### onlyProtocol

```solidity
modifier onlyProtocol()
```

### init

```solidity
function init(address _addressManager, uint16 _maxPoolSize) external
```

Initialize the rollup.

#### Parameters

| Name             | Type    | Description                 |
| ---------------- | ------- | --------------------------- |
| \_addressManager | address | The AddressManager address. |
| \_maxPoolSize    | uint16  |                             |

### enterProverPool

```solidity
function enterProverPool(uint256 amount, uint256 feeMultiplier, uint32 capacity) external
```

### stakeMoreTokens

```solidity
function stakeMoreTokens(uint256 amount) external
```

### adjustFeeMultiplier

```solidity
function adjustFeeMultiplier(uint8 newFeeMultiplier) external
```

### adjustCapacity

```solidity
function adjustCapacity(uint32 newCapacity) external
```

### withdrawRewards

```solidity
function withdrawRewards(uint64 amount) external
```

### exit

```solidity
function exit() external
```

### pickRandomProver

```solidity
function pickRandomProver(uint256 randomNumber, uint256 blockId) external returns (address)
```

### getProver

```solidity
function getProver(uint256 blockId) external view returns (address)
```

### slash

```solidity
function slash(address prover) external
```

### rearrangeTop32

```solidity
function rearrangeTop32() internal
```

### getTopProverArrayId

```solidity
function getTopProverArrayId(address prover) internal view returns (uint256)
```

---

## title: ProxiedTaikoProverPool

## ProxiedTaikoProverPool
