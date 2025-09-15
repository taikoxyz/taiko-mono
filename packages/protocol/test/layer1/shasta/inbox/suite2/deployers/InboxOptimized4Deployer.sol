// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInboxOptimized4 } from "../implementations/TestInboxOptimized4.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title InboxOptimized4Deployer
/// @notice Deployer for the InboxOptimized4 implementation
contract InboxOptimized4Deployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "InboxOptimized4";
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
            new TestInboxOptimized4(bondToken, checkpointManager, proofVerifier, proposerChecker)
        );

        TestInboxOptimized4 inbox = TestInboxOptimized4(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.initV3, (Alice, bytes32(uint256(1))))
            })
        );

        return inbox;
    }
}