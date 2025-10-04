// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { CodecSimple } from "src/layer1/shasta/impl/CodecSimple.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title CheckpointDelayInbox
/// @notice Test inbox with configurable minCheckpointDelay for testing checkpoint sync modes
contract CheckpointDelayInbox is Inbox {
    constructor(
        address codec,
        address bondToken,
        uint16 maxCheckpointHistory,
        address proofVerifier,
        address proposerChecker,
        uint16 minCheckpointDelay
    )
        Inbox(
            IInbox.Config({
                codec: codec,
                bondToken: bondToken,
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
                forcedInclusionFeeInGwei: 10_000_000,
                maxCheckpointHistory: maxCheckpointHistory,
                minCheckpointDelay: minCheckpointDelay, // Configurable for testing
                permissionlessInclusionMultiplier: 5
            })
        )
    { }
}

/// @title CheckpointDelayInboxDeployer
/// @notice Deployer for test inbox with configurable checkpoint delay
contract CheckpointDelayInboxDeployer is InboxTestHelper, IInboxDeployer {
    uint16 internal minCheckpointDelay;

    constructor(uint16 _minCheckpointDelay) {
        minCheckpointDelay = _minCheckpointDelay;
    }

    function getTestContractName() external pure returns (string memory) {
        return "CheckpointDelayInbox";
    }

    function deployInbox(
        address bondToken,
        uint16 maxCheckpointHistory,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox)
    {
        address codec = address(new CodecSimple());
        address impl = address(
            new CheckpointDelayInbox(
                codec,
                bondToken,
                maxCheckpointHistory,
                proofVerifier,
                proposerChecker,
                minCheckpointDelay
            )
        );

        CheckpointDelayInbox inbox = CheckpointDelayInbox(
            deploy({ name: "", impl: impl, data: abi.encodeCall(Inbox.init, (Alice, Alice)) })
        );

        vm.prank(Alice);
        inbox.activate(bytes32(uint256(1)));

        return inbox;
    }
}
