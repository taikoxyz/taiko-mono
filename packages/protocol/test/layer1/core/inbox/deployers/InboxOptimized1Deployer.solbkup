// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { TestInboxOptimized1 } from "../implementations/TestInboxOptimized1.sol";
import { IInboxDeployer } from "./IInboxDeployer.sol";
import { CodecSimple } from "src/layer1/core/impl/CodecSimple.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @title InboxOptimized1Deployer
/// @notice Deployer for the InboxOptimized1 implementation
contract InboxOptimized1Deployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "InboxOptimized1";
    }

    /// @inheritdoc IInboxDeployer
    function deployInbox(
        address bondToken,
        address signalService,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox)
    {
        address codec = address(new CodecSimple());
        address impl = address(
            new TestInboxOptimized1(codec, bondToken, signalService, proofVerifier, proposerChecker)
        );

        TestInboxOptimized1 inbox = TestInboxOptimized1(
            deploy({ name: "", impl: impl, data: abi.encodeCall(Inbox.init, (Alice)) })
        );

        // Activate the inbox with Alice as the activator
        vm.prank(Alice);
        inbox.activate(bytes32(uint256(1)));

        return inbox;
    }
}
