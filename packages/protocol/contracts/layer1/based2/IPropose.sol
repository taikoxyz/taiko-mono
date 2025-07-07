// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "./ITaikoInbox2.sol";

/// @title IPropose
/// @notice Interface for proposing batches in the Taiko protocol.
/// @dev This interface defines the propose4 function for batch proposals.
/// @custom:security-contact security@taiko.xyz
interface IPropose {
    /// @notice Proposes multiple batches to be proven and verified.
    /// @dev This function allows proposers to submit batches of blocks for processing.
    /// @param _summary The current state summary of the protocol.
    /// @param _batch Array of batches to be proposed.
    /// @param _evidence Evidence proving the validity of the batch metadata.
    function propose4(
        I.Summary memory _summary,
        I.Batch[] memory _batch,
        I.BatchProposeMetadataEvidence memory _evidence,
        I.TransitionMeta[] calldata _trans
    )
        external
        returns (I.Summary memory);
}
