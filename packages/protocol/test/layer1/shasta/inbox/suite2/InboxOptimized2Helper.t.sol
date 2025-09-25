// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { InboxOptimized2 } from "src/layer1/shasta/impl/InboxOptimized2.sol";
import { InboxHelper } from "src/layer1/shasta/impl/InboxHelper.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

contract InboxOptimized2HelperTest is Test {
    InboxOptimized2 inbox;
    InboxHelper helper;

    function setUp() public {
        // Deploy the helper first
        helper = new InboxHelper();

        IInbox.Config memory config = IInbox.Config({
            bondToken: address(0),
            signalService: address(1),
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
            forcedInclusionFeeInGwei: 100
        });

        inbox = new InboxOptimized2(config, address(helper));
    }

    function test_helperAddressIsSet() public view {
        address helperAddr = inbox.helper();
        assertNotEq(helperAddr, address(0), "Helper address should not be zero");

        // Verify the helper is a valid InboxHelper contract by checking it has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(helperAddr)
        }
        assertGt(codeSize, 0, "Helper should be a deployed contract");

        // Verify it's the same helper we passed in
        assertEq(helperAddr, address(helper), "Helper should be the one we passed in");
    }

    function test_helperFunctionsWork() public view {
        address helperAddr = inbox.helper();
        InboxHelper helperContract = InboxHelper(helperAddr);

        // Test that we can call a function on the helper
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            nextProposalBlockId: 2,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        bytes32 hash = helperContract.hashCoreState(coreState);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");
    }
}
