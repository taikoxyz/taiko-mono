// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "./IInbox.sol";

/// @title IPropose
/// @notice Interface for proposing batches in the Taiko protocol.
/// @dev This interface defines the propose4 function for batch proposals.
/// @custom:security-contact security@taiko.xyz
interface IPropose {
    // /// @notice Proposes multiple batches to be proven and verified.
    // /// @dev This function allows proposers to submit batches of blocks for processing.
    // /// @param _packedSummary The current state summary of the protocol packed as bytes.
    // /// @param _batches Array of batches to be proposed.
    // /// @param _packedTrans The packed transition metadata for verification
    // /// @return The updated summary
    // function propose4(
    //     bytes memory _packedSummary,
    //     I.Batch[] calldata _batches,
    //     I.BatchProposeMetadataEvidence memory _evidence,
    //     bytes calldata _packedTrans
    // )
    //     external
    //     returns (I.Summary memory);
}
