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

    constructor() InboxOptimized2(7 days, 10) { }

    function setTestConfig(IInbox.Config memory _config) external {
        testConfig = _config;
        configSet = true;
    }

    function setMockBlobValidation(bool _useMock) external {
        useMockBlobHashes = _useMock;
    }

    function setMockBlobHash(uint256 _index, bytes32 _hash) external {
        mockBlobHashes[_index] = _hash;
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
                minForcedInclusionCount: 1
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
        _setTransitionRecordHash(testConfig, _proposalId, _transition, _transitionRecord);
    }

    /// @dev Override _getBlobHash to support mock blob hashes in tests
    function _getBlobHash(uint256 _blobIndex) internal view override returns (bytes32) {
        if (useMockBlobHashes) {
            // Check if we have a specific mock hash set for this index
            bytes32 mockHash = mockBlobHashes[_blobIndex];
            if (mockHash != bytes32(0)) {
                return mockHash;
            }
            // If no mock hash is set, generate a deterministic one for testing
            // unless the test explicitly wants to test missing blobs at specific indices
            // For index 100 specifically, return bytes32(0) to test BlobNotFound error
            if (_blobIndex == 100) {
                return bytes32(0);
            }
            return keccak256(abi.encode("blob", _blobIndex));
        }
        // Fall back to the real blobhash opcode
        return blobhash(_blobIndex);
    }
}
