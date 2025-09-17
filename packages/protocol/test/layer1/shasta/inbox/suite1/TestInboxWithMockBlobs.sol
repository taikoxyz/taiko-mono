// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/InboxOptimized2.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxWithMockBlobs
/// @notice Test version of InboxOptimized that exposes internal functions for testing
contract TestInboxWithMockBlobs is InboxOptimized2 {
    mapping(uint256 => bytes32) private mockBlobHashes;
    bool private useMockBlobHashes;

    constructor()
        InboxOptimized2(
            IInbox.Config({
                bondToken: address(0),
                checkpointManager: address(0),
                proofVerifier: address(0),
                proposerChecker: address(0),
                provingWindow: 1 hours,
                extendedProvingWindow: 2 hours,
                maxFinalizationCount: 10,
                finalizationGracePeriod: 48 hours,
                ringBufferSize: 100,
                basefeeSharingPctg: 10,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 100,
                forcedInclusionFeeInGwei: 10_000_000 // 0.01 ETH
             })
        )
    { }

    // Removed coreStateHash related functions as it no longer exists

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
}
