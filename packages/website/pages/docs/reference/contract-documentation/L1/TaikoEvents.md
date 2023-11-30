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
event BlockProposed(uint256 blockId, address assignedProver, uint96 livenessBond, struct TaikoData.BlockMetadata meta, struct TaikoData.EthDeposit[] depositsProcessed)
```

_Emitted when a block is proposed._

#### Parameters

| Name              | Type                           | Description                                                         |
| ----------------- | ------------------------------ | ------------------------------------------------------------------- |
| blockId           | uint256                        | The ID of the proposed block.                                       |
| assignedProver    | address                        | The block's assigned prover.                                        |
| livenessBond      | uint96                         | The bond in Taiko token from the assigned prover.                   |
| meta              | struct TaikoData.BlockMetadata | The block metadata containing information about the proposed block. |
| depositsProcessed | struct TaikoData.EthDeposit[]  | Ether deposits processed.                                           |

### BlockVerified

```solidity
event BlockVerified(uint256 blockId, address assignedProver, address prover, bytes32 blockHash, bytes32 signalRoot, uint16 tier, uint8 contestations)
```

_Emitted when a block is verified._

#### Parameters

| Name           | Type    | Description                                                 |
| -------------- | ------- | ----------------------------------------------------------- |
| blockId        | uint256 | The ID of the verified block.                               |
| assignedProver | address | The block's assigned prover.                                |
| prover         | address | The prover whose transition is used for verifing the block. |
| blockHash      | bytes32 | The hash of the verified block.                             |
| signalRoot     | bytes32 | The latest value of the signal service storage.             |
| tier           | uint16  | The tier ID of the proof.                                   |
| contestations  | uint8   | Number of total contestations.                              |

### TransitionProved

```solidity
event TransitionProved(uint256 blockId, struct TaikoData.Transition tran, address prover, uint96 validityBond, uint16 tier)
```

_Emitted when a block transition is proved or re-proved._

### TransitionContested

```solidity
event TransitionContested(uint256 blockId, struct TaikoData.Transition tran, address contester, uint96 contestBond, uint16 tier)
```

_Emitted when a block transition is contested._

### BlobCached

```solidity
event BlobCached(bytes32 blobHash)
```

_Emitted when a blob is cached for reuse._

### ProvingPaused

```solidity
event ProvingPaused(bool paused)
```

_Emitted when proving has been paused_

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```

_Emitted when an Ethereum deposit is made._

#### Parameters

| Name    | Type                        | Description                                                           |
| ------- | --------------------------- | --------------------------------------------------------------------- |
| deposit | struct TaikoData.EthDeposit | The Ethereum deposit information including recipient, amount, and ID. |

### TokenDeposited

```solidity
event TokenDeposited(uint256 amount)
```

_Emitted when a user deposited Taiko token into this contract._

### TokenWithdrawn

```solidity
event TokenWithdrawn(uint256 amount)
```

_Emitted when a user withdrawed Taiko token from this contract._

### TokenCredited

```solidity
event TokenCredited(address to, uint256 amount)
```

_Emitted when Taiko token are credited to the user's in-protocol
balance._

### TokenDebited

```solidity
event TokenDebited(address from, uint256 amount)
```

_Emitted when Taiko token are debited from the user's in-protocol
balance._
