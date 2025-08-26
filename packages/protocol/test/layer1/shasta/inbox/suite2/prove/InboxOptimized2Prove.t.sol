// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { TestInboxOptimized2 } from "../implementations/TestInboxOptimized2.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized2Prove
/// @notice Test suite for prove functionality on InboxOptimized2 implementation
contract InboxOptimized2Prove is AbstractProveTest {
    function getTestContractName() internal pure override returns (string memory) {
        return "InboxOptimized2";
    }

    function _getExpectedAggregationBehavior(uint256 proposalCount, bool consecutive) 
        internal pure override returns (uint256 expectedEvents, uint256 expectedMaxSpan) {
        if (consecutive) {
            return (1, proposalCount); // One event with span=proposalCount
        } else {
            return (proposalCount, 1); // Individual events for gaps
        }
    }

    function _getExpectedMixedScenarioEvents() internal pure override returns (uint256) {
        // Optimized: 2 events (groups 1-2 and 4-6)
        return 2;
    }

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override
        returns (Inbox)
    {
        // Deploy implementation
        address impl = address(
            new TestInboxOptimized2(
                bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );

        // Deploy proxy using the helper function
        return Inbox(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (owner, GENESIS_BLOCK_HASH))
            })
        );
    }
}