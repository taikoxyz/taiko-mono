---
title: TaikoEvents
---

## TaikoEvents

This abstract contract provides event declarations for the Taiko
protocol, which are emitted during block proposal, proof, verification, and
Ethereum deposit processes.

_The events defined here must match the definitions in the corresponding
L1 libraries._

### BlockProposed

```solidity
event BlockProposed(uint256 blockId, address prover, uint256 reward, struct TaikoData.BlockMetadata meta)
```

_Emitted when a block is proposed._

#### Parameters

| Name    | Type                           | Description                                                         |
| ------- | ------------------------------ | ------------------------------------------------------------------- |
| blockId | uint256                        | The ID of the proposed block.                                       |
| prover  | address                        | The address of the assigned prover for the block.                   |
| reward  | uint256                        | The proposer's block reward in Taiko token.                         |
| meta    | struct TaikoData.BlockMetadata | The block metadata containing information about the proposed block. |

### BlockProven

```solidity
event BlockProven(uint256 blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
```

_Emitted when a block is proven._

#### Parameters

| Name       | Type    | Description                                        |
| ---------- | ------- | -------------------------------------------------- |
| blockId    | uint256 | The ID of the proven block.                        |
| parentHash | bytes32 | The hash of the parent block.                      |
| blockHash  | bytes32 | The hash of the proven block.                      |
| signalRoot | bytes32 | The signal root of the proven block.               |
| prover     | address | The address of the prover who submitted the proof. |

### BlockVerified

```solidity
event BlockVerified(uint256 blockId, address prover, bytes32 blockHash)
```

_Emitted when a block is verified._

#### Parameters

| Name      | Type    | Description                                                        |
| --------- | ------- | ------------------------------------------------------------------ |
| blockId   | uint256 | The ID of the verified block.                                      |
| prover    | address | The address of the prover that proved the block which is verified. |
| blockHash | bytes32 | The hash of the verified block.                                    |

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```

_Emitted when an Ethereum deposit is made._

#### Parameters

| Name    | Type                        | Description                                                           |
| ------- | --------------------------- | --------------------------------------------------------------------- |
| deposit | struct TaikoData.EthDeposit | The Ethereum deposit information including recipient, amount, and ID. |

### BondReceived

```solidity
event BondReceived(address from, uint64 blockId, uint256 bond)
```

_The following events are emitted when bonds are received, returned,
or rewarded. Note that no event is emitted when a bond is kept/burnt as
for a single block, multiple bonds may get burned or retained by the
protocol, emitting events will consume more gas._

### BondReturned

```solidity
event BondReturned(address to, uint64 blockId, uint256 bond)
```

### BondRewarded

```solidity
event BondRewarded(address to, uint64 blockId, uint256 bond)
```
