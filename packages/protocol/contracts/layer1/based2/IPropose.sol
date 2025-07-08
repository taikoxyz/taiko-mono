// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "./IInbox.sol";

/// @title IPropose
/// @notice Interface for proposing batches in the Taiko protocol.
/// @dev This interface defines the propose4 function for batch proposals.
/// @custom:security-contact security@taiko.xyz
interface IPropose {
    /// @notice Proposes and verifies batches
    /// @param _summary The current summary
    /// @param _batches The batches to propose
    /// @param _evidence The batch proposal evidence
    /// @param _packedTrans The packed transition metadata for verification
    /// @return The updated summary
    function propose4(
        I.Summary memory _summary,
        I.Batch[] calldata _batches,
        I.BatchProposeMetadataEvidence memory _evidence,
        bytes calldata _packedTrans
    )
        external
        returns (I.Summary memory);
}
