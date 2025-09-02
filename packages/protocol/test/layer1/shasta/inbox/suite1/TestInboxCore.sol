// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "./ITestInbox.sol";

/// @title TestInboxCore
/// @notice Concrete implementation of base Inbox for testing
/// @custom:security-contact security@taiko.xyz
contract TestInboxCore is Inbox, ITestInbox {
    IInbox.Config private testConfig;
    bool private configSet;
    // Storage to track checkpoint for test purposes
    mapping(uint48 => ICheckpointManager.Checkpoint) public testcheckpoints;

    constructor() Inbox() { }

    function setTestConfig(IInbox.Config memory _config) external {
        testConfig = _config;
        configSet = true;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        if (!configSet) {
            return IInbox.Config({
                bondToken: address(0),
                provingWindow: 1 hours,
                extendedProvingWindow: 2 hours,
                maxFinalizationCount: 10,
                ringBufferSize: 100,
                basefeeSharingPctg: 10,
                checkpointManager: address(0),
                proofVerifier: address(0),
                proposerChecker: address(0),
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 100,
                forcedInclusionFeeInGwei: 10_000_000 // 0.01 ETH
             });
        }
        return testConfig;
    }

    // Expose internal functions for testing
    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external {
        _setProposalHash(testConfig, _proposalId, _hash);
    }

    function exposed_setTransitionRecordHash(
        uint48 _proposalId,
        IInbox.Transition memory _transition,
        IInbox.TransitionRecord memory _transitionRecord
    )
        external
    {
        _setTransitionRecordHash(getConfig(), _proposalId, _transition, _transitionRecord);
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
