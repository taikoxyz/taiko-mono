// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized2.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxWithMockBlobs
/// @notice Test version of InboxOptimized that exposes internal functions for testing
contract TestInboxWithMockBlobs is InboxOptimized2 {
    mapping(uint256 => bytes32) private mockBlobHashes;
    bool private useMockBlobHashes;

    constructor() InboxOptimized2(
        address(0), // bondToken
        address(0), // checkpointManager
        address(0), // proofVerifier
        address(0), // proposerChecker
        1 hours, // provingWindow
        2 hours, // extendedProvingWindow
        10, // maxFinalizationCount
        100, // ringBufferSize
        10, // basefeeSharingPctg
        1, // minForcedInclusionCount
        100, // forcedInclusionDelay
        10_000_000 // forcedInclusionFeeInGwei (0.01 ETH)
    ) { }

    // Removed coreStateHash related functions as it no longer exists

    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external {
        _setProposalHash(_proposalId, _hash);
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
