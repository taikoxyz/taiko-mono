// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1 } from "src/layer1/shasta/impl/InboxOptimized1.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxOptimized1
/// @notice Test wrapper for TestInboxOptimized1 contract with configurable behavior
contract TestInboxOptimized1 is InboxOptimized1 {
    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        InboxOptimized1(
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
