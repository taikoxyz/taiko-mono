// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxOptimized2 } from "src/layer1/core/impl/InboxOptimized2.sol";

/// @title TestInboxOptimized2
/// @notice Test wrapper for TestInboxOptimized2 contract with configurable behavior
contract TestInboxOptimized2 is InboxOptimized2 {
    constructor(
        address codec,
        address bondToken,
        address checkpointStore,
        address proofVerifier,
        address proposerChecker
    )
        InboxOptimized2(IInbox.Config({
                codec: codec,
                bondToken: bondToken,
                checkpointStore: checkpointStore,
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
                forcedInclusionFeeInGwei: 10_000_000, // 0.01 ETH base fee
                forcedInclusionFeeDoubleThreshold: 100,
                minCheckpointDelay: 0,
                permissionlessInclusionMultiplier: 5,
                compositeKeyVersion: 1
            }))
    { }
}
