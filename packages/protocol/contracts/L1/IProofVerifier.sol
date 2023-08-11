// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
 * @title IProofVerifier Interface
 * @dev Interface for the ProofVerifier contract which is responsible for
 * verifying proofs.
 */
interface IProofVerifier {
    /**
     * @notice Verify proof(s) for the given block.
     * This function should revert if the verification fails.
     *
     * @param blockId Unique identifier for the block.
     * @param blockProofs Raw bytes representing the proof(s).
     * @param instance Hash combining evidence and configuration data.
     */
    function verifyProofs(
        uint256 blockId,
        bytes calldata blockProofs,
        bytes32 instance
    )
        external;
}
