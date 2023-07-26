---
title: LibTokenomics_A3
---

## LibTokenomics_A3

### L1_INSUFFICIENT_TOKEN

```solidity
error L1_INSUFFICIENT_TOKEN()
```

### withdrawTaikoToken

```solidity
function withdrawTaikoToken(struct TaikoData.State state, contract AddressResolver resolver, uint256 amount) internal
```

### depositTaikoToken

```solidity
function depositTaikoToken(struct TaikoData.State state, contract AddressResolver resolver, uint256 amount) internal
```

### getProofReward

```solidity
function getProofReward(struct TaikoData.State state, uint64 proofTime) internal view returns (uint64)
```

Get the block reward for a proof

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct TaikoData.State | The actual state data |
| proofTime | uint64 | The actual proof time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint64 | reward The reward given for the block proof |

### getNewBlockFeeAndProofTimeIssued

```solidity
function getNewBlockFeeAndProofTimeIssued(struct TaikoData.State state, uint64 proofTime) internal view returns (uint64 newProofTimeIssued, uint64 blockFee)
```

Calculate the newProofTimeIssued and blockFee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct TaikoData.State | The actual state data |
| proofTime | uint64 | The actual proof time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| newProofTimeIssued | uint64 | Accumulated proof time |
| blockFee | uint64 | New block fee |

