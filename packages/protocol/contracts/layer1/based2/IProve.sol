// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProve
/// @notice Interface for proving batches in the Taiko protocol.
/// @dev This interface defines the prove4 function for batch proofs.
/// @custom:security-contact security@taiko.xyz
interface IProve {
    /// @notice Proves batches with cryptographic proof
    /// @param _packedSummary The current summary packed as bytes
    /// @param _packedBatchProveInputs The batch prove inputs
    /// @param _proof The cryptographic proof
    function prove4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatchProveInputs,
        bytes calldata _proof
    )
        external;
}
