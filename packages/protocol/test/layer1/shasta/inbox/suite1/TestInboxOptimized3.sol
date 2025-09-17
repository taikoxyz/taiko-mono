// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized3.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import { LibCheckpoints } from "src/layer1/shasta/libs/LibCheckpoints.sol";
import "./ITestInbox.sol";

/// @title TestInboxOptimized3
/// @notice Concrete implementation of InboxOptimized3 for testing
/// @custom:security-contact security@taiko.xyz
contract TestInboxOptimized3 is InboxOptimized3, ITestInbox, IProposerChecker {
    // Storage to track checkpoint for test purposes
    mapping(uint48 => LibCheckpoints.Checkpoint) public testcheckpoints;

    constructor(
        address _bondToken,
        uint48 _maxCheckpointStackSize,
        address _proofVerifier
    )
        InboxOptimized3(
            IInbox.Config({
                bondToken: _bondToken,
                maxCheckpointStackSize: _maxCheckpointStackSize,
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
        LibCheckpoints.Checkpoint memory _checkpoint
    )
        external
    {
        testcheckpoints[_proposalId] = _checkpoint;
    }

    // Helper function to get the stored checkpoint
    function getStoredcheckpoint(uint48 _proposalId)
        external
        view
        returns (LibCheckpoints.Checkpoint memory)
    {
        return testcheckpoints[_proposalId];
    }
}
