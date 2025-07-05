// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox2.sol";

/// @title IProposeBatch2
/// @notice Interface for proposing batches in the Taiko protocol.
/// @dev This interface defines the propose4 function for batch proposals.
/// @custom:security-contact security@taiko.xyz
interface IProposeBatch2 {
    /// @notice Proposes multiple batches to be proven and verified.
    /// @dev This function allows proposers to submit batches of blocks for processing.
    /// @param _summary The current state summary of the protocol.
    /// @param _batch Array of batches to be proposed.
    /// @param _evidence Evidence proving the validity of the batch metadata.
    function propose4(
        ITaikoInbox2.Summary memory _summary,
        ITaikoInbox2.Batch[] memory _batch,
        ITaikoInbox2.BatchProposeMetadataEvidence memory _evidence
    )
        external;
}
