---
title: IProver
---

## IProver

Defines the function that handle prover assignment.

### onBlockAssigned

```solidity
function onBlockAssigned(uint64 blockId, struct TaikoData.BlockMetadataInput input, struct TaikoData.ProverAssignment assignment) external payable
```

Assigns a prover to a specific block or reverts if this prover
is not available.

#### Parameters

| Name       | Type                                | Description                                                                                                                                                   |
| ---------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| blockId    | uint64                              | The ID of the proposed block. Note that the ID is only known when the block is proposed, therefore, it should not be used for verifying prover authorization. |
| input      | struct TaikoData.BlockMetadataInput | The block's BlockMetadataInput data.                                                                                                                          |
| assignment | struct TaikoData.ProverAssignment   | The assignment to evaluate                                                                                                                                    |
