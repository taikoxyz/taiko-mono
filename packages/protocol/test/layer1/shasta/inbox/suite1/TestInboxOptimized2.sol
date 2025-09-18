// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized2.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/shared/based/iface/ICheckpointManager.sol";
import "./ITestInbox.sol";

/// @title TestInboxOptimized2
/// @notice Concrete implementation of InboxOptimized2 for testing
/// @custom:security-contact security@taiko.xyz
contract TestInboxOptimized2 is InboxOptimized2, ITestInbox, IProposerChecker {
    // Storage to track checkpoint for test purposes
    mapping(uint48 => ICheckpointManager.Checkpoint) public testcheckpoints;

    constructor(
        address _bondToken,
        address _checkpointManager,
        address _proofVerifier
    )
        InboxOptimized2(
            IInbox.Config({
                bondToken: _bondToken,
                checkpointManager: _checkpointManager,
                proofVerifier: _proofVerifier,
                proposerChecker: address(this), // proposerChecker - use this contract as stub
                provingWindow: 1 hours,
                extendedProvingWindow: 2 hours,
                maxFinalizationCount: 10,
                finalizationGracePeriod: 5 minutes,
                ringBufferSize: 100,
                basefeeSharingPctg: 10,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 100,
                forcedInclusionFeeInGwei: 10_000_000 // 0.01 ETH
             })
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

    function exposed_setTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        IInbox.Transition memory _transition,
        IInbox.TransitionRecord memory _transitionRecord
    )
        external
    {
        // Create dummy metadata for test purposes
        IInbox.TransitionMetadata memory metadata =
            IInbox.TransitionMetadata({ designatedProver: address(0), actualProver: address(0) });
        _setTransitionRecordHashAndDeadline(_proposalId, _transition, metadata, _transitionRecord);
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
