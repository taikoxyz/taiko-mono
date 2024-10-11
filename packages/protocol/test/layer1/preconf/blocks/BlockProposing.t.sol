// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../fixtures/BlocksFixtures.sol";

import "src/layer1/preconf/avs/PreconfConstants.sol";
import "src/layer1/preconf/interfaces/IPreconfTaskManager.sol";

contract BlockProposing is BlocksFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_newBlockProposal_preconferCanProposeBlockInAdvanced_Case1() external {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        // Warp to an arbitrary timestamp before the preconfer's slot
        uint256 currentSlotTimestamp = currentEpochStart + (10 * PreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Force set the block id to an arbitrary value
        taikoL1.setBlockId(4);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + PreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 1 proposes the block
        vm.prank(addr_1);
        preconfTaskManager.newBlockProposal("Block Params", "Txn List", 1, lookaheadSetParams);

        // Check that the block proposer has been set correctly
        assertEq(preconfTaskManager.getBlockProposer(4), addr_1);

        // Verify that Taiko has received the block proposal
        assertEq(taikoL1.params(), bytes("Block Params"));
        assertEq(taikoL1.txList(), bytes("Txn List"));
    }

    function test_newBlockProposal_preconferCanProposeBlockInAdvanced_Case2() external {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        // Warp to an arbitrary timestamp after Address 1's slot but before Address 3's slot
        uint256 currentSlotTimestamp = currentEpochStart + (15 * PreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Force set the block id to an arbitrary value
        taikoL1.setBlockId(5);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + PreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 3 proposes the block in advance
        vm.prank(addr_3);
        preconfTaskManager.newBlockProposal("Block Params 2", "Txn List 2", 2, lookaheadSetParams);

        // Check that the block proposer has been set correctly
        assertEq(preconfTaskManager.getBlockProposer(5), addr_3);

        // Verify that Taiko has received the block proposal
        assertEq(taikoL1.params(), bytes("Block Params 2"));
        assertEq(taikoL1.txList(), bytes("Txn List 2"));
    }

    function test_newBlockProposal_preconferCanProposeBlockAtDedicatedSlot() external {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        // Warp to the exact timestamp of the preconfer's dedicated slot
        uint256 currentSlotTimestamp = currentEpochStart + (12 * PreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Force set the block id to an arbitrary value
        taikoL1.setBlockId(6);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + PreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 1 proposes the block at its dedicated slot
        vm.prank(addr_1);
        preconfTaskManager.newBlockProposal("Block Params 3", "Txn List 3", 1, lookaheadSetParams);

        // Check that the block proposer has been set correctly
        assertEq(preconfTaskManager.getBlockProposer(6), addr_1);

        // Verify that Taiko has received the block proposal
        assertEq(taikoL1.params(), bytes("Block Params 3"));
        assertEq(taikoL1.txList(), bytes("Txn List 3"));
    }

    function test_newBlockProposal_forwardsAllValueToTaikoL1() external {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        // Warp to an arbitrary timestamp before the preconfer's slot
        uint256 currentSlotTimestamp = currentEpochStart + (10 * PreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Force set the block id to an arbitrary value
        taikoL1.setBlockId(4);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + PreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 1 proposes the block
        vm.prank(addr_1);
        vm.deal(addr_1, 1 ether);
        preconfTaskManager.newBlockProposal{ value: 1 ether }(
            "Block Params", "Txn List", 1, lookaheadSetParams
        );

        // Verify Taiko's balance
        assertEq(address(taikoL1).balance, 1 ether);
    }

    function test_newBlockProposal_updatesLookaheadForNextEpoch() external {
        // Prepare initial lookahead
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 nextEpochStart = currentEpochStart + PreconfConstants.SECONDS_IN_EPOCH;

        uint256 currentSlotTimestamp = currentEpochStart + (9 * PreconfConstants.SECONDS_IN_SLOT);
        // Warp to a slot where address 1 can propose a block
        vm.warp(currentSlotTimestamp);

        // Prepare lookahead set for the next epoch
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](2);
        // Slot 10
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + (9 * PreconfConstants.SECONDS_IN_SLOT),
            preconfer: addr_1
        });
        // Slot 20
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + (19 * PreconfConstants.SECONDS_IN_SLOT),
            preconfer: addr_2
        });

        // Address 1 proposes a block and updates the lookahead
        vm.prank(addr_1);
        preconfTaskManager.newBlockProposal("Block Params", "Txn List", 1, lookaheadSetParams);

        // Verify that the lookahead for the next epoch has been updated
        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer =
            preconfTaskManager.getLookaheadBuffer();

        // Check the first entry
        assertEq(lookaheadBuffer[3].preconfer, addr_1);
        assertEq(
            lookaheadBuffer[3].timestamp, nextEpochStart + (9 * PreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(
            lookaheadBuffer[3].prevTimestamp,
            currentEpochStart + (22 * PreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(lookaheadBuffer[3].isFallback, false);

        // Check the second entry
        assertEq(lookaheadBuffer[4].preconfer, addr_2);
        assertEq(
            lookaheadBuffer[4].timestamp, nextEpochStart + (19 * PreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(
            lookaheadBuffer[4].prevTimestamp,
            nextEpochStart + (9 * PreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(lookaheadBuffer[4].isFallback, false);

        // Verify that the lookahead tail has been updated
        assertEq(preconfTaskManager.getLookaheadTail(), 4);

        // Verify that the lookahead poster for the next epoch has been set
        assertEq(preconfTaskManager.getLookaheadPoster(nextEpochStart), addr_1);
    }

    function test_newBlockProposal_revertWhenTimestampAboveDedicatedSlot() external {
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 dedicatedSlotTimestamp = currentEpochStart + (12 * PreconfConstants.SECONDS_IN_SLOT);

        // Warp to a timestamp after the dedicated slot
        vm.warp(dedicatedSlotTimestamp + PreconfConstants.SECONDS_IN_SLOT);

        vm.prank(addr_1);
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        preconfTaskManager.newBlockProposal(
            "Block Params", "Txn List", 1, new IPreconfTaskManager.LookaheadSetParam[](0)
        );
    }

    function test_newBlockProposal_revertWhenTimestampBelowPrevTimestamp() external {
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 prevSlotTimestamp = currentEpochStart + (12 * PreconfConstants.SECONDS_IN_SLOT);

        // Warp to a timestamp before the previous slot
        vm.warp(prevSlotTimestamp - PreconfConstants.SECONDS_IN_SLOT);

        vm.prank(addr_3);
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        preconfTaskManager.newBlockProposal(
            "Block Params", "Txn List", 2, new IPreconfTaskManager.LookaheadSetParam[](0)
        );
    }

    function test_newBlockProposal_revertWhenTimestampEqualToPrevTimestamp() external {
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 prevSlotTimestamp = currentEpochStart + (12 * PreconfConstants.SECONDS_IN_SLOT);

        // Warp to the exact timestamp of the previous slot
        vm.warp(prevSlotTimestamp);

        vm.prank(addr_3);
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        preconfTaskManager.newBlockProposal(
            "Block Params", "Txn List", 2, new IPreconfTaskManager.LookaheadSetParam[](0)
        );
    }

    function test_newBlockProposal_revertWhenSenderIsNotThePreconfer() external {
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 currentSlotTimstamp = currentEpochStart + (15 * PreconfConstants.SECONDS_IN_SLOT);

        // Warp to a slot when Address 3 is the expected preconfer
        vm.warp(currentSlotTimstamp);

        // Try to propose with a different address than the expected preconfer
        vm.prank(addr_2); // addr_2 is not the expected preconfer (It is addr_3)
        vm.expectRevert(IPreconfTaskManager.SenderIsNotThePreconfer.selector);
        preconfTaskManager.newBlockProposal(
            "Block Params", "Txn List", 2, new IPreconfTaskManager.LookaheadSetParam[](0)
        );
    }
}
