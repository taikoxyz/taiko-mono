// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2 } from "src/layer1/shasta/impl/InboxOptimized2.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInboxOptimized2
/// @notice Test wrapper for TestInboxOptimized2 contract with configurable behavior
contract TestInboxOptimized2 is InboxOptimized2 {
    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        InboxOptimized2(
            bondToken,
            checkpointManager,
            proofVerifier,
            proposerChecker,
            2 hours, // provingWindow
            4 hours, // extendedProvingWindow
            16, // maxFinalizationCount
            100, // ringBufferSize
            0, // basefeeSharingPctg
            1, // minForcedInclusionCount
            100, // forcedInclusionDelay
            10_000_000 // forcedInclusionFeeInGwei (0.01 ETH)
        )
    { }
}
