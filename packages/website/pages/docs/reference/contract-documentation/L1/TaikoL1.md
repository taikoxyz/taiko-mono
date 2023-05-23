---
title: TaikoL1
---

## TaikoL1

### L1_INSUFFICIENT_TOKEN

```solidity
error L1_INSUFFICIENT_TOKEN()
```

### taikoTokenBalances

```solidity
mapping(address => uint256) taikoTokenBalances
```

### accProposedAt

```solidity
uint64 accProposedAt
```

### accBlockFees

```solidity
uint64 accBlockFees
```

### blockFee

```solidity
uint64 blockFee
```

### proofTimeIssued

```solidity
uint64 proofTimeIssued
```

### proofTimeTarget

```solidity
uint64 proofTimeTarget
```

### \_\_gap

```solidity
uint256[47] __gap
```

### init

```solidity
function init(address _addressManager, bytes32 _genesisBlockHash, uint64 _initBlockFee, uint64 _initProofTimeTarget, uint64 _initProofTimeIssued) external
```

Initialize the rollup.

#### Parameters

| Name                  | Type    | Description                                                         |
| --------------------- | ------- | ------------------------------------------------------------------- |
| \_addressManager      | address | The AddressManager address.                                         |
| \_genesisBlockHash    | bytes32 | The block hash of the genesis block.                                |
| \_initBlockFee        | uint64  | Initial (reasonable) block fee value.                               |
| \_initProofTimeTarget | uint64  | Initial (reasonable) proof submission time target.                  |
| \_initProofTimeIssued | uint64  | Initial proof time issued corresponding with the initial block fee. |

### setProofParams

```solidity
function setProofParams(uint64 newProofTimeTarget, uint64 newProofTimeIssued) external
```

Change proof parameters (time target and time issued) - to avoid complex/risky upgrades in case need to change relatively frequently.

#### Parameters

| Name               | Type   | Description                                                             |
| ------------------ | ------ | ----------------------------------------------------------------------- |
| newProofTimeTarget | uint64 | New proof time target.                                                  |
| newProofTimeIssued | uint64 | New proof time issued. If set to type(uint64).max, let it be unchanged. |

### withdrawTaikoToken

```solidity
function withdrawTaikoToken(uint256 amount) public
```

### depositTaikoToken

```solidity
function depositTaikoToken(uint256 amount) public
```

### getTaikoTokenBalance

```solidity
function getTaikoTokenBalance(address addr) public view returns (uint256)
```

### afterBlockProposed

```solidity
function afterBlockProposed(address proposer) public
```

### afterBlockVerified

```solidity
function afterBlockVerified(address prover, uint64 proposedAt, uint64 provenAt) public
```

### getProofReward

```solidity
function getProofReward(uint64 proofTime) public view returns (uint64)
```

---

## title: ProxiedTaikoL1

## ProxiedTaikoL1
