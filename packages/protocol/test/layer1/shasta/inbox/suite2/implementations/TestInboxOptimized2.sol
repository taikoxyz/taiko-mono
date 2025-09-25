// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2 } from "src/layer1/shasta/impl/InboxOptimized2.sol";
import { InboxHelper } from "src/layer1/shasta/impl/InboxHelper.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxOptimized2
/// @notice Test wrapper for TestInboxOptimized2 contract with configurable behavior
contract TestInboxOptimized2 is InboxOptimized2 {
    constructor(
        address bondToken,
        address signalService,
        address proofVerifier,
        address proposerChecker
    )
        InboxOptimized2(
            IInbox.Config({
                bondToken: bondToken,
                signalService: signalService,
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
             }),
            address(new InboxHelper())
        )
    { }
}
