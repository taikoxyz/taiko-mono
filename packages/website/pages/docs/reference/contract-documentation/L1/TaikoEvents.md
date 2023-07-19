---
title: TaikoEvents
---

## TaikoEvents

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct TaikoData.BlockMetadata meta, uint64 blockFee)
```

_Emitted when a block is proposed_

#### Parameters

| Name     | Type                           | Description                                |
| -------- | ------------------------------ | ------------------------------------------ |
| id       | uint256                        | The ID of the proposed block               |
| meta     | struct TaikoData.BlockMetadata | The metadata of the proposed block         |
| blockFee | uint64                         | The fee associated with the proposed block |

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover, uint32 parentGasUsed)
```

_Emitted when a block is proven_

#### Parameters

| Name          | Type    | Description                         |
| ------------- | ------- | ----------------------------------- |
| id            | uint256 | The ID of the proven block          |
| parentHash    | bytes32 | The hash of the parent block        |
| blockHash     | bytes32 | The hash of the proven block        |
| signalRoot    | bytes32 | The signal root of the proven block |
| prover        | address | The address of the prover           |
| parentGasUsed | uint32  | The gas used by the parent block    |

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash, uint64 reward)
```

_Emitted when a block is verified_

#### Parameters

| Name      | Type    | Description                                      |
| --------- | ------- | ------------------------------------------------ |
| id        | uint256 | The ID of the verified block                     |
| blockHash | bytes32 | The hash of the verified block                   |
| reward    | uint64  | The amount of token rewarded to the verification |

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```

_Emitted when an Ethereum deposit is made_

#### Parameters

| Name    | Type                        | Description                               |
| ------- | --------------------------- | ----------------------------------------- |
| deposit | struct TaikoData.EthDeposit | The information of the deposited Ethereum |

### ProofParamsChanged

```solidity
event ProofParamsChanged(uint64 proofTimeTarget, uint64 proofTimeIssued, uint64 blockFee, uint16 adjustmentQuotient)
```

_Emitted when the proof parameters are changed_

#### Parameters

| Name               | Type   | Description                                                                     |
| ------------------ | ------ | ------------------------------------------------------------------------------- |
| proofTimeTarget    | uint64 | The target time of proof generation                                             |
| proofTimeIssued    | uint64 | The actual time of proof generation                                             |
| blockFee           | uint64 | The fee associated with the proposed block                                      |
| adjustmentQuotient | uint16 | The quotient used for adjusting future proof generation time to the target time |
