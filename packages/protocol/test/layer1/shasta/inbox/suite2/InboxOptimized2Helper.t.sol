// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { InboxOptimized2 } from "src/layer1/shasta/impl/InboxOptimized2.sol";
import { InboxOptimized2Helper } from "src/layer1/shasta/impl/InboxOptimized2Helper.sol";
import { IInboxHelper } from "src/layer1/shasta/iface/IInboxHelper.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

contract InboxOptimized2HelperTest is Test {
    InboxOptimized2 inbox;
    IInboxHelper helper;

    function setUp() public {
        // Deploy helper first
        InboxOptimized2Helper inboxHelper = new InboxOptimized2Helper();

        IInbox.Config memory config = IInbox.Config({
            bondToken: address(0),
            proofVerifier: address(0),
            proposerChecker: address(0),
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            finalizationGracePeriod: 30 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 10,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 100,
            forcedInclusionFeeInGwei: 100,
            maxCheckpointHistory: 10,
            helper: address(inboxHelper)
        });

        inbox = new InboxOptimized2(config);

        // Get the helper from the inbox
        helper = IInboxHelper(inbox.helper());
    }

    function test_helperAddressIsSet() public view {
        address helperAddr = inbox.helper();
        assertNotEq(helperAddr, address(0), "Helper address should not be zero");

        // Verify the helper is a valid IInboxHelper contract by checking it has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(helperAddr)
        }
        assertGt(codeSize, 0, "Helper should be a deployed contract");

        // Verify it's the same helper we retrieved
        assertEq(helperAddr, address(helper), "Helper should be the one from inbox");
    }

    function test_helperFunctionsWork() public view {

        // Test that we can call a function on the helper
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            nextProposalBlockId: 2,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        bytes32 hash = helper.hashCoreState(coreState);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");
    }
}
