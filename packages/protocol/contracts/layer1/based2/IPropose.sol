// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "./IInbox.sol";

/// @title IPropose
/// @notice Interface for proposing batches in the Taiko protocol.
/// @dev This interface defines the propose4 function for batch proposals.
/// @custom:security-contact security@taiko.xyz
interface IPropose {
    /// @notice Proposes and verifies batches
    /// @param _packedSummary The current summary, packed into bytes
    /// @param _packedBatches The batches to propose, packed into bytes
    /// @param _packedEvidence The batch proposal evidence, packed into bytes
    /// @param _packedTrans The packed transition metadata for verification
    /// @return The updated summary
    function propose4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTrans
    )
        external
        returns (I.Summary memory);
}
