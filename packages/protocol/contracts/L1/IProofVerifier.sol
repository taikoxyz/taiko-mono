// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title IProofVerifier
/// @notice Contract that is responsible for verifying proofs.
interface IProofVerifier {
    /// @notice Verify the given proof(s) for the given blockId. This function
    /// should revert if the verification fails.
    /// @param blockId Unique identifier for the block.
    /// @param blockProofs Raw bytes representing the proof(s).
    /// @param instance Hashed evidence & config data. If set to zero, proof is
    /// assumed to be from oracle prover.
    function verifyProofs(
        uint64 blockId,
        bytes calldata blockProofs,
        bytes32 instance
    )
        external;
}
