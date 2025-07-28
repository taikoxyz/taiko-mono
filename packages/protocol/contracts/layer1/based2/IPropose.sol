// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IInbox.sol";

/// @title IPropose
/// @notice Interface for proposing batches in the Taiko protocol.
/// @dev This interface defines the propose4 function for batch proposals.
/// @custom:security-contact security@taiko.xyz
interface IPropose {
    /// @notice Proposes and verifies batches
    /// @param _inputs The inputs to propose and verify batches that can be decoded into
    /// (IInbox.Summary memory, IInbox.Batch[] memory, IInbox.ProposeBatchEvidence memory,
    /// IInbox.TransitionMeta[] memory)
    /// @return The updated summary
    function propose4(bytes calldata _inputs) external returns (IInbox.Summary memory);
}
