// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInboxOptimized3 } from "../implementations/TestInboxOptimized3.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized3Base
/// @notice Base contract providing deployment logic for InboxOptimized3 implementation
/// @dev This contract inherits from CommonTest to access the deploy() function directly.
///      Since CommonTest is already in the inheritance chain via AbstractProveTest,
///      this creates a simple multiple inheritance scenario that Solidity handles fine.
abstract contract InboxOptimized3Base is CommonTest {

    function getTestContractName() internal pure virtual returns (string memory) {
        return "InboxOptimized3";
    }

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        virtual
        returns (Inbox)
    {
        address impl = address(
            new TestInboxOptimized3(
                bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );
        
        return Inbox(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (Alice, bytes32(uint256(1))))
            })
        );
    }
}