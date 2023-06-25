---
title: IProverPool
---

## IProverPool

### assignProver

```solidity
function assignProver(uint64 blockId, uint32 feePerGas) external returns (address prover, uint32 rewardPerGas)
```

### releaseProver

```solidity
function releaseProver(address prover) external
```

### slashProver

```solidity
function slashProver(address prover) external
```

### getAvailableCapacity

```solidity
function getAvailableCapacity() external view returns (uint256)
```

---

## title: ProverPool

## ProverPool

### TopProver

```solidity
struct TopProver {
  uint32 amount;
  uint16 rewardPerGas;
  uint16 currentCapacity;
}
```

### ExitingProver

```solidity
struct ExitingProver {
  uint64 requestedAt;
  uint32 amount;
}
```

### topProvers

```solidity
struct ProverPool.TopProver[32] topProvers
```

### exitingProvers

```solidity
mapping(address => struct ProverPool.ExitingProver) exitingProvers
```

### idToProver

```solidity
mapping(uint8 => address) idToProver
```

### proverToId

```solidity
mapping(address => uint8) proverToId
```

### EXIT_PERIOD

```solidity
uint256 EXIT_PERIOD
```

### SLASH_AMOUNT_IN_BP

```solidity
uint256 SLASH_AMOUNT_IN_BP
```

### ONE_TKO

```solidity
uint256 ONE_TKO
```

### Entered

```solidity
event Entered(address prover, uint32 amount, uint16 rewardPerGas, uint16 capacity)
```

### ChangedParameters

```solidity
event ChangedParameters(address prover, uint32 newBalance, uint16 newReward, uint16 newCapacity)
```

### KickeOutByWithAmount

```solidity
event KickeOutByWithAmount(address kickedOut, address newProver, uint32 totalAmount)
```

### ExitRequested

```solidity
event ExitRequested(address prover, uint64 timestamp, bool fullExit)
```

### Exited

```solidity
event Exited(address prover, uint64 timestamp)
```

### Slashed

```solidity
event Slashed(address prover, uint32 newBalance)
```

### onlyFromProtocol

```solidity
modifier onlyFromProtocol()
```

### init

```solidity
function init(address _addressManager) external
```

Initialize the rollup.

#### Parameters

| Name             | Type    | Description                 |
| ---------------- | ------- | --------------------------- |
| \_addressManager | address | The AddressManager address. |

### assignProver

```solidity
function assignProver(uint64 blockId, uint32 feePerGas) external returns (address prover, uint32 rewardPerGas)
```

### releaseProver

```solidity
function releaseProver(address prover) external
```

### slashProver

```solidity
function slashProver(address prover) external
```

### stake

```solidity
function stake(uint32 totalAmount, uint16 rewardPerGas, uint16 capacity) external
```

### getAvailableCapacity

```solidity
function getAvailableCapacity() external view returns (uint256 totalCapacity)
```

### exit

```solidity
function exit() external
```

### lowestStakedAmountToEnter

```solidity
function lowestStakedAmountToEnter() external view returns (uint32 minStakeRequired)
```

---

## title: ProxiedProverPool

## ProxiedProverPool
