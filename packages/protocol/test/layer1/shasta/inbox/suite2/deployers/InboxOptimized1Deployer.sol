// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInboxOptimized1 } from "../implementations/TestInboxOptimized1.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

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
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox)
    {
        address impl = address(
            new TestInboxOptimized1(bondToken, checkpointManager, proofVerifier, proposerChecker)
        );

        TestInboxOptimized1 inbox = TestInboxOptimized1(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init2, (Alice, bytes32(uint256(1))))
            })
        );

        inbox.fillTransitionRecordBuffer();

        return inbox;
    }
}
