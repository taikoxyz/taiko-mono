---
title: ITaikoProverPool
---

## ITaikoProverPool

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
