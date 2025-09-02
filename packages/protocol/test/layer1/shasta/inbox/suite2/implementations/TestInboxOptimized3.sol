// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized3 } from "src/layer1/shasta/impl/InboxOptimized3.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInboxOptimized3
/// @notice Test wrapper for TestInboxOptimized3 contract with configurable behavior
contract TestInboxOptimized3 is InboxOptimized3 {
    address private immutable _bondToken;
    address private immutable _checkpointManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;

    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        InboxOptimized3()
    {
        _bondToken = bondToken;
        _checkpointManager = checkpointManager;
        _proofVerifier = proofVerifier;
        _proposerChecker = proposerChecker;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return IInbox.Config({
            bondToken: _bondToken,
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            effectiveAt: 0,
            maxFinalizationCount: 16,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            checkpointManager: _checkpointManager,
            proofVerifier: _proofVerifier,
            proposerChecker: _proposerChecker,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 100,
            forcedInclusionFeeInGwei: 10_000_000 // 0.01 ETH
         });
    }
}
