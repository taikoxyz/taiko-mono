// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxWithClaimAggregation
/// @notice Test version of InboxOptimized that exposes internal functions for testing
contract TestInboxWithClaimAggregation is InboxOptimized {
    IInbox.Config private testConfig;

    function setTestConfig(IInbox.Config memory _config) external {
        testConfig = _config;
    }

    function setMockBlobValidation(bool) external {
        // No-op for compatibility
    }

    function getConfig() public view override returns (IInbox.Config memory) {
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
