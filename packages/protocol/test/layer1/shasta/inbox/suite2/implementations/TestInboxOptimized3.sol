// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized3 } from "src/layer1/shasta/impl/InboxOptimized3.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInboxOptimized3
/// @notice Test wrapper for TestInboxOptimized3 contract with configurable behavior
contract TestInboxOptimized3 is InboxOptimized3 {
    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        InboxOptimized3(
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
