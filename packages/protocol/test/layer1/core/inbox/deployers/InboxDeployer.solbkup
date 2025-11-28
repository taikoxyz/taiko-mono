// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { TestInbox } from "../implementations/TestInbox.sol";
import { IInboxDeployer } from "./IInboxDeployer.sol";
import { CodecSimple } from "src/layer1/core/impl/CodecSimple.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @title InboxDeployer
/// @notice Deployer for the standard Inbox implementation
contract InboxDeployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "Inbox";
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
        address impl =
            address(new TestInbox(codec, bondToken, signalService, proofVerifier, proposerChecker));

        TestInbox inbox = TestInbox(
            deploy({ name: "", impl: impl, data: abi.encodeCall(Inbox.init, (Alice)) })
        );

        // Activate the inbox with Alice as the activator
        vm.prank(Alice);
        inbox.activate(bytes32(uint256(1)));

        return inbox;
    }
}
