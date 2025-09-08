// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { InboxOptimized4 } from "contracts/layer1/shasta/impl/InboxOptimized4.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized4Deployer
/// @notice Deploys InboxOptimized4 for testing purposes
contract InboxOptimized4Deployer is IInboxDeployer {
    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker
    )
        external
        override
        returns (Inbox)
    {
        IInbox.Config memory config = IInbox.Config({
            bondToken: bondToken,
            checkpointManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            provingWindow: 3600,
            extendedProvingWindow: 7200,
            maxFinalizationCount: 10,
            finalizationGracePeriod: 1800,
            ringBufferSize: 1024,
            basefeeSharingPctg: 50,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 300,
            forcedInclusionFeeInGwei: 10
        });

        return Inbox(address(new TestInboxOptimized4(config)));
    }

    function getTestContractName() external pure override returns (string memory) {
        return "InboxOptimized4";
    }

    function deploy(IInbox.Config memory config) external returns (address) {
        return address(new TestInboxOptimized4(config));
    }
}

/// @title TestInboxOptimized4
/// @notice Test implementation of InboxOptimized4 with concrete instantiation
contract TestInboxOptimized4 is InboxOptimized4 {
    constructor(IInbox.Config memory _config) InboxOptimized4(_config) { }
}