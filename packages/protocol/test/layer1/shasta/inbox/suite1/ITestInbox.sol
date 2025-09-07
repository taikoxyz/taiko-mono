// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title ITestInbox
/// @notice Common interface for all test Inbox implementations
/// @custom:security-contact security@taiko.xyz
interface ITestInbox is IInbox {
    /// @notice Expose internal function for testing - set proposal hash
    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external;

    /// @notice Expose internal function for testing - set transition record hash
    function exposed_setTransitionRecordHash(
        uint48 _proposalId,
        IInbox.Transition memory _transition,
        IInbox.TransitionRecord memory _transitionRecord
    )
        external;

    /// @notice Store checkpoint for test purposes
    function storeCheckpoint(
        uint48 _proposalId,
        ICheckpointManager.Checkpoint memory _checkpoint
    )
        external;

    /// @notice Get stored checkpoint for test purposes
    function getStoredcheckpoint(uint48 _proposalId)
        external
        view
        returns (ICheckpointManager.Checkpoint memory);
}
