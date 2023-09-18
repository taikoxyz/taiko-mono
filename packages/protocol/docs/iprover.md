# Implementing ERC-20 Token Payments in ProverPool

In this guide, we will outline the steps to implement a solution that enables prover pools to accept arbitrary ERC-20 tokens as payments for providing with proofs. This solution allows proposers to interact with pools (implementing `IProver`), agree on a price for proving a block, and make payments using ERC-20 tokens.

NOTE: This works also with NFTs (ERC-721/ERC-1155) as well (applying the proper `approval`/`approvalForAll`), just because it might be less likely those will be used as payment methods, we highlighted the ERC-20. 

## Prerequisites

Before implementing this solution, make sure you have an existing ERC-20 token contract that you want to accept as payment in your ProverPool.

## Implementation Steps

### Step 1: An example ProverPool Contract

Start by creating a ProverPool contract that implements the `IProver` interface. This interface should include the `onBlockAssigned` function, which will be called during `proposeBlock()`.
A boilerplate (non-comprehensive) example:

```solidity
// Import necessary libraries and interfaces
import "./IProver.sol";

// Define the ProverPool contract
contract ProverPool is IProver {

    // ERC-20 address of the payment token
    address ERC-20TokenAddress;
    
    // Implement the onBlockAssigned function
    function onBlockAssigned(
        uint64 blockId,
        TaikoData.BlockMetadataInput calldata input,
        TaikoData.ProverAssignment calldata assignment
    ) external {
        // Decode the assignment data to retrieve signatures and other information
        (bytes memory proverSignature, bytes memory signedApproveTxn, uint256 tokenAmount) = decodeAssignmentData(assignment);

        // 1. Verify the prover signature is valid (off-chain verification)
        require(isValidSignature(proverSignature, input), "Invalid prover signature");

        // 2. Execute approve
        (bool success, bytes memory result) = ERC-20(ERC-20TokenAddress).call(signedApproveTxn);

        // 3. Execute the transaction transfer tokens
        ERC-20(ERC-20TokenAddress).transferFrom(input.proposer, address(this), tokenAmount);

        // Additional logic for block proving goes here
    }

    // Implement functions to decode assignment data, verify signatures, and execute token transfer
}
```

### Step 2: Off-Chain Interaction

The proposer and prover interact off-chain to agree on the price and perform the ERC-20 token approval. Here's an example of how this interaction might work:

1. Proposer asks the ProverPool for the cost of proving a block and receives a price (e.g., `10 DAI` tokens). If price is acceptable, prover provides proposer with a valid ECDSA signature which signs the commitment (e.g.: transaction list hash), expiration and price.

2. Proposer signs the following transaction off-chain: `ERC-20(DAI_ADDRESS).approve(proverPool, 10)`.

3. Proposer encodes these signatures into the `assignment.data` and calls the `proposeBlock()`.

During `proposeBlock()` transaction, the `onBlockAssigned()` hook which will evaluate the validity of the prover signature, and if that one is correct then executes 2 transactions:
1. The approval `ERC-20(DAI_ADDRESS).approve(proverPool, 10)` which is signed by the proposer.
2. The transfer of that `10 DAI`.