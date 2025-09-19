// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized4 } from "src/layer1/shasta/impl/InboxOptimized4.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxOptimized4
/// @notice Test wrapper for InboxOptimized4 contract with configurable behavior
contract TestInboxOptimized4 is InboxOptimized4 {
    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        InboxOptimized4(
            IInbox.Config({
                bondToken: bondToken,
                checkpointManager: checkpointManager,
                proofVerifier: proofVerifier,
                proposerChecker: proposerChecker,
                provingWindow: 2 hours,
                extendedProvingWindow: 4 hours,
                maxFinalizationCount: 16,
                finalizationGracePeriod: 5 minutes,
                ringBufferSize: 100,
                basefeeSharingPctg: 0,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 100,
                forcedInclusionFeeInGwei: 10_000_000 // 0.01 ETH
             })
        )
    { }
}