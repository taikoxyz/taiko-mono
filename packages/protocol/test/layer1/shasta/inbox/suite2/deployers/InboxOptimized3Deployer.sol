// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInboxOptimized3 } from "../implementations/TestInboxOptimized3.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title InboxOptimized3Deployer
/// @notice Deployer for the InboxOptimized3 implementation
contract InboxOptimized3Deployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "InboxOptimized3";
    }

    /// @inheritdoc IInboxDeployer
    function deployInbox(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox)
    {
        address impl = address(
            new TestInboxOptimized3(bondToken, checkpointManager, proofVerifier, proposerChecker)
        );

        TestInboxOptimized3 inbox = TestInboxOptimized3(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (Alice, bytes32(uint256(1))))
            })
        );

        inbox.fillTransitionRecordBuffer();

        return inbox;
    }
}
