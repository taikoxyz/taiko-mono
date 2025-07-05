// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox2.sol";

/// @title IProveBatches2
/// @notice Interface for proving batches in the Taiko protocol.
/// @dev This interface defines the prove4 function for batch proofs.
/// @custom:security-contact security@taiko.xyz
interface IProveBatches2 {
    /// @notice Proves multiple batches with their corresponding proofs.
    /// @dev This function allows provers to submit proofs for proposed batches.
    /// @param _summary The current state summary of the protocol.
    /// @param _inputs Array of batch prove inputs containing metadata and transitions.
    /// @param _proof The proof data for validating the batches.
    function prove4(
        ITaikoInbox2.Summary memory _summary,
        ITaikoInbox2.BatchProveInput[] calldata _inputs,
        bytes calldata _proof
    )
        external;
}
