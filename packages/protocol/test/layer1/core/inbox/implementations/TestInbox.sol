// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @title TestInbox
/// @notice Test wrapper for Inbox contract with configurable behavior
contract TestInbox is Inbox {
    constructor(
        address codec,
        address bondToken,
        address checkpointStore,
        address proofVerifier,
        address proposerChecker
    )
        Inbox(IInbox.Config({
                codec: codec,
                bondToken: bondToken,
                checkpointStore: checkpointStore,
                proofVerifier: proofVerifier,
                proposerChecker: proposerChecker,
                provingWindow: 2 hours,
                extendedProvingWindow: 4 hours,
                maxFinalizationCount: 16,
                finalizationGracePeriod: 48 hours,
                ringBufferSize: 100,
                basefeeSharingPctg: 0,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 384, // 1 epoch
                forcedInclusionFeeInGwei: 10_000_000, // 0.01 ETH base fee
                forcedInclusionFeeDoubleThreshold: 50,
                minCheckpointDelay: 0,
                permissionlessInclusionMultiplier: 5,
                compositeKeyVersion: 1
            }))
    { }
}
