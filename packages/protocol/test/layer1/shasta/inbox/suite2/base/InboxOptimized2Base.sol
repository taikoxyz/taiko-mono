// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInboxOptimized2 } from "../implementations/TestInboxOptimized2.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized2Base
/// @notice Base contract providing deployment logic for InboxOptimized2 implementation
abstract contract InboxOptimized2Base is CommonTest {

    function getTestContractName() internal pure virtual returns (string memory) {
        return "InboxOptimized2";
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
            new TestInboxOptimized2(
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