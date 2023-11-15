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
event BlockProposed(uint256 blockId, address assignedProver, uint96 livenessBond, uint256 proverFee, uint256 reward, struct TaikoData.BlockMetadata meta)
```

_Emitted when a block is proposed._

#### Parameters

| Name           | Type                           | Description                                                         |
| -------------- | ------------------------------ | ------------------------------------------------------------------- |
| blockId        | uint256                        | The ID of the proposed block.                                       |
| assignedProver | address                        | The address of the assigned prover for the block.                   |
| livenessBond   | uint96                         | The bond which needs to be paid by the assigned prover.             |
| proverFee      | uint256                        | The amount paid to the prover.                                      |
| reward         | uint256                        | The proposer's block reward in Taiko token.                         |
| meta           | struct TaikoData.BlockMetadata | The block metadata containing information about the proposed block. |

### TransitionProved

```solidity
event TransitionProved(uint256 blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover, uint96 validityBond, uint16 tier)
```

_Emitted when a block transition is proven or re-proven._

#### Parameters

| Name         | Type    | Description                                                               |
| ------------ | ------- | ------------------------------------------------------------------------- |
| blockId      | uint256 | The ID of the proven block.                                               |
| parentHash   | bytes32 | The hash of the parent block.                                             |
| blockHash    | bytes32 | The hash of the proven block.                                             |
| signalRoot   | bytes32 | The signal root of the proven block.                                      |
| prover       | address | The address of the prover who submitted the proof.                        |
| validityBond | uint96  | The amount prover pays to have finanical incentive to submit legit proof. |
| tier         | uint16  | The tier per given transition.                                            |

### TransitionContested

```solidity
event TransitionContested(uint256 blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address contester, uint96 contestBond, uint16 tier)
```

_Emitted when a block transition is contested._

#### Parameters

| Name        | Type    | Description                                                |
| ----------- | ------- | ---------------------------------------------------------- |
| blockId     | uint256 | The ID of the proven block.                                |
| parentHash  | bytes32 | The hash of the parent block.                              |
| blockHash   | bytes32 | The hash of the proven block.                              |
| signalRoot  | bytes32 | The signal root of the proven block.                       |
| contester   | address | The address of the contester.                              |
| contestBond | uint96  | The amount contester pays to signal it's legit intentions. |
| tier        | uint16  | The tier per given transition.                             |

### BlockVerified

```solidity
event BlockVerified(uint256 blockId, address assignedProver, address prover, bytes32 blockHash, bytes32 signalRoot)
```

_Emitted when a block is verified._

#### Parameters

| Name           | Type    | Description                                                        |
| -------------- | ------- | ------------------------------------------------------------------ |
| blockId        | uint256 | The ID of the verified block.                                      |
| assignedProver | address | The address of the originally assigned prover.                     |
| prover         | address | The address of the prover that proved the block which is verified. |
| blockHash      | bytes32 | The hash of the verified block.                                    |
| signalRoot     | bytes32 | The latest value of the signal service storage.                    |

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

#### Parameters

| Name   | Type    | Description         |
| ------ | ------- | ------------------- |
| amount | uint256 | The deposit amount. |

### TokenWithdrawn

```solidity
event TokenWithdrawn(uint256 amount)
```

_Emitted when a user withdrawed Taiko token from this contract._

#### Parameters

| Name   | Type    | Description           |
| ------ | ------- | --------------------- |
| amount | uint256 | The withdrawn amount. |

### TokenCredited

```solidity
event TokenCredited(uint256 amount, bool minted)
```

_Emitted when Taiko token are credited to the user's in-protocol balance._

#### Parameters

| Name   | Type    | Description                         |
| ------ | ------- | ----------------------------------- |
| amount | uint256 | The withdrawn amount.               |
| minted | bool    | Indicating if minting is necessary. |

### TokenDebited

```solidity
event TokenDebited(uint256 amount, bool fromLocalBalance)
```

_Emitted when Taiko token are debited from the user's in-protocol balance._

#### Parameters

| Name             | Type    | Description                                     |
| ---------------- | ------- | ----------------------------------------------- |
| amount           | uint256 | The debit amount.                               |
| fromLocalBalance | bool    | Indicating if debit from local balance or burn. |

### TokenWithdrawnByOwner

```solidity
event TokenWithdrawnByOwner(address to, uint256 amount)
```

_Emitted when the owner withdrawn Taiko token from this contract._

#### Parameters

| Name   | Type    | Description              |
| ------ | ------- | ------------------------ |
| to     | address | The beneficiary address. |
| amount | uint256 | The amount.              |
