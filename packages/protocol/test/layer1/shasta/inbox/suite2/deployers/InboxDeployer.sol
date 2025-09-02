// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInbox } from "../implementations/TestInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

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
        address checkpointManager,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox)
    {
        address impl =
            address(new TestInbox(bondToken, checkpointManager, proofVerifier, proposerChecker));

        TestInbox inbox =
            TestInbox(deploy({ name: "", impl: impl, data: abi.encodeCall(Inbox.init, (Alice)) }));

        // Initialize with genesis block hash (must be called as owner)
        vm.prank(Alice);
        inbox.init2(bytes32(uint256(1)));

        return inbox;
    }
}
