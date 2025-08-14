// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxWithMockBlobs
/// @notice Test version of InboxOptimized that exposes internal functions for testing
contract TestInboxWithMockBlobs is InboxOptimized {
    IInbox.Config private testConfig;
    bool private configSet;

    constructor() InboxOptimized() { }

    function setTestConfig(IInbox.Config memory _config) external {
        testConfig = _config;
        configSet = true;
    }

    function setMockBlobValidation(bool) external {
        // No-op for compatibility
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        // During initialization, provide a minimal valid config to avoid division by zero
        if (!configSet) {
            return IInbox.Config({
                bondToken: address(0),
                provingWindow: 1 hours,
                extendedProvingWindow: 2 hours,
                maxFinalizationCount: 10,
                ringBufferSize: 100, // Ensure this is not zero
                basefeeSharingPctg: 10,
                syncedBlockManager: address(0),
                proofVerifier: address(0),
                proposerChecker: address(0),
                forcedInclusionStore: address(0)
            });
        }
        return testConfig;
    }

    // Removed coreStateHash related functions as it no longer exists

    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external {
        _setProposalHash(testConfig, _proposalId, _hash);
    }


  

    function exposed_setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        external
    {
        _setClaimRecordHash(testConfig, _proposalId, _parentClaimHash, _claimRecordHash);
    }
}
