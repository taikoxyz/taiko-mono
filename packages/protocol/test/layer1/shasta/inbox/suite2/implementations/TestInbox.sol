// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInbox
/// @notice Test wrapper for Inbox contract with configurable behavior
contract TestInbox is Inbox {
    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        Inbox(
            bondToken,
            checkpointManager,
            proofVerifier,
            proposerChecker,
            2 hours, // provingWindow
            4 hours, // extendedProvingWindow
            48 hours, // finalizationGracePeriod
            16, // maxFinalizationCount
            100, // ringBufferSize
            0, // basefeeSharingPctg
            1, // minForcedInclusionCount
            100, // forcedInclusionDelay
            10_000_000 // forcedInclusionFeeInGwei (0.01 ETH)
        )
    { }
}
