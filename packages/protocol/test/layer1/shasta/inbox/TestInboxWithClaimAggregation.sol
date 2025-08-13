// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxWithClaimAggregation.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxWithClaimAggregation
/// @notice Test version of InboxWithClaimAggregation that exposes internal functions for testing
contract TestInboxWithClaimAggregation is InboxWithClaimAggregation {
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

    function exposed_setCoreStateHash(bytes32 _hash) external {
        coreStateHash = _hash;
    }

    function getCoreStateHash() external view returns (bytes32) {
        return coreStateHash;
    }

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
