// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized2.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxWithMockBlobs
/// @notice Test version of InboxOptimized that exposes internal functions for testing
contract TestInboxWithMockBlobs is InboxOptimized2 {
    IInbox.Config private testConfig;
    bool private configSet;
    mapping(uint256 => bytes32) private mockBlobHashes;
    bool private useMockBlobHashes;

    constructor() InboxOptimized2() { }

    function setTestConfig(IInbox.Config memory _config) external {
        testConfig = _config;
        configSet = true;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        // During initialization, provide a minimal valid config to avoid division by zero
        if (!configSet) {
            return IInbox.Config({
                bondToken: address(0),
                provingWindow: 1 hours,
                extendedProvingWindow: 2 hours,
                cooldownWindow: 5 minutes,
                maxFinalizationCount: 10,
                ringBufferSize: 100, // Ensure this is not zero
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

    // Removed coreStateHash related functions as it no longer exists

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
        _setTransitionRecordHash(_proposalId, _transition, _transitionRecord);
    }
}
