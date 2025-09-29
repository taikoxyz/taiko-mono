// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInboxOptimized2 } from "../implementations/TestInboxOptimized2.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { CodecOptimized } from "src/layer1/shasta/impl/CodecOptimized.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title InboxOptimized2Deployer
/// @notice Deployer for the InboxOptimized2 implementation
contract InboxOptimized2Deployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "InboxOptimized2";
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
        address codec = address(new CodecOptimized());
        address impl = address(
            new TestInboxOptimized2(codec, bondToken, signalService, proofVerifier, proposerChecker)
        );

        TestInboxOptimized2 inbox = TestInboxOptimized2(
            deploy({ name: "", impl: impl, data: abi.encodeCall(Inbox.init, (Alice, Alice)) })
        );

        // Activate the inbox with Alice as the activator
        vm.prank(Alice);
        inbox.activate(bytes32(uint256(1)));

        return inbox;
    }
}
