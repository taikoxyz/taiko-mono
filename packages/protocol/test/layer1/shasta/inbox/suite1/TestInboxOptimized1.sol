// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized1.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import "./ITestInbox.sol";

/// @title TestInboxOptimized1
/// @notice Concrete implementation of InboxOptimized1 for testing
/// @custom:security-contact security@taiko.xyz
contract TestInboxOptimized1 is InboxOptimized1, ITestInbox, IProposerChecker {
    // Storage to track checkpoint for test purposes
    mapping(uint48 => ICheckpointStore.Checkpoint) public testcheckpoints;

    constructor(
        address _bondToken,
        uint16 _maxCheckpointHistory,
        address _proofVerifier
    )
        InboxOptimized1(
            IInbox.Config({
                bondToken: _bondToken,
                maxCheckpointHistory: _maxCheckpointHistory,
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
        _setTransitionRecordHashAndDeadline(_proposalId, _transition, _transitionRecord);
    }

    // Function to store checkpoint for test purposes
    function storeCheckpoint(
        uint48 _proposalId,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        external
    {
        testcheckpoints[_proposalId] = _checkpoint;
    }

    // Helper function to get the stored checkpoint
    function getStoredcheckpoint(uint48 _proposalId)
        external
        view
        returns (ICheckpointStore.Checkpoint memory)
    {
        return testcheckpoints[_proposalId];
    }
}
