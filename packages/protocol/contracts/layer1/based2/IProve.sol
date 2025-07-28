// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProve
/// @notice Interface for proving batches in the Taiko protocol.
/// @dev This interface defines the prove4 function for batch proofs.
/// @custom:security-contact security@taiko.xyz
interface IProve {
    /// @notice Proves batch transitions using cryptographic proofs
    /// @dev Validates and processes cryptographic proofs for batch state transitions
    /// @param _inputs encoded IInbox.ProveBatchInput[]
    /// @param _proof The cryptographic proof data for validation
    function prove4(bytes calldata _inputs, bytes calldata _proof) external;
}
