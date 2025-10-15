// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

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
        Inbox(
            IInbox.Config({
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
                forcedInclusionDelay: 100,
                forcedInclusionFeeInGwei: 10_000_000, // 0.01 ETH
                minCheckpointDelay: 0,
                permissionlessInclusionMultiplier: 5,
                compositeKeyVersion: 1
            })
        )
    { }
}
