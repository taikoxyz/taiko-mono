// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/shared/based/iface/ICheckpointManager.sol";
import "./ITestInbox.sol";

/// @title TestInboxCore
/// @notice Concrete implementation of base Inbox for testing
/// @custom:security-contact security@taiko.xyz
contract TestInboxCore is Inbox, ITestInbox, IProposerChecker {
    // Storage to track checkpoint for test purposes
    mapping(uint48 => ICheckpointManager.Checkpoint) public testcheckpoints;

    constructor(
        address _bondToken,
        address _checkpointManager,
        address _proofVerifier
    )
        Inbox(
            _bondToken,
            _checkpointManager,
            _proofVerifier,
            address(this), // proposerChecker - use this contract as stub
            1 hours, // provingWindow
            2 hours, // extendedProvingWindow
            10, // maxFinalizationCount
            100, // ringBufferSize
            10, // basefeeSharingPctg
            1, // minForcedInclusionCount
            100, // forcedInclusionDelay
            10_000_000 // forcedInclusionFeeInGwei (0.01 ETH)
        )
    { }

    // Implement IProposerChecker for test purposes
    function checkProposer(address) external pure returns (uint48) {
        return 0; // Return 0 lookahead slot timestamp for tests
    }

    // Expose internal functions for testing
    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external {
        _setProposalHash(_proposalId, _hash);
    }

    function exposed_setTransitionRecordExcerpt(
        uint48 _proposalId,
        IInbox.Transition memory _transition,
        IInbox.TransitionRecord memory _transitionRecord
    )
        external
    {
        _setTransitionRecordExcerpt(testConfig, _proposalId, _transition, _transitionRecord);
    }

    // Function to store checkpoint for test purposes
    function storeCheckpoint(
        uint48 _proposalId,
        ICheckpointManager.Checkpoint memory _checkpoint
    )
        external
    {
        testcheckpoints[_proposalId] = _checkpoint;
    }

    // Helper function to get the stored checkpoint
    function getStoredcheckpoint(uint48 _proposalId)
        external
        view
        returns (ICheckpointManager.Checkpoint memory)
    {
        return testcheckpoints[_proposalId];
    }
}
