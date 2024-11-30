// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../fixtures/BlocksFixtures.sol";

import "src/layer1/preconf/impl/LibPreconfConstants.sol";
import "src/layer1/preconf/iface/IPreconfTaskManager.sol";

contract BlockProposing is BlocksFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_newBlockProposal_preconferCanProposeBlockInAdvanced_Case1() external {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        // Warp to an arbitrary timestamp before the preconfer's slot
        uint256 currentSlotTimestamp =
            currentEpochStart + (10 * LibPreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 1 proposes the block
        vm.prank(addr_1);
        _proposeBlock(1, lookaheadSetParams);
    }

    function test_newBlockProposal_preconferCanProposeBlockInAdvanced_Case2() external {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        // Warp to an arbitrary timestamp after Address 1's slot but before Address 3's slot
        uint256 currentSlotTimestamp =
            currentEpochStart + (15 * LibPreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 3 proposes the block in advance
        vm.prank(addr_3);
        _proposeBlock(2, lookaheadSetParams);
    }

    function test_newBlockProposal_preconferCanProposeBlockAtDedicatedSlot() external {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        // Warp to the exact timestamp of the preconfer's dedicated slot
        uint256 currentSlotTimestamp =
            currentEpochStart + (12 * LibPreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 1 proposes the block at its dedicated slot
        vm.prank(addr_1);
        _proposeBlock(1, lookaheadSetParams);
    }

    function test_newBlockProposal_updatesLookaheadForNextEpoch() external {
        // Prepare initial lookahead
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        uint256 nextEpochStart = currentEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH;

        uint256 currentSlotTimestamp = currentEpochStart + (9 * LibPreconfConstants.SECONDS_IN_SLOT);
        // Warp to a slot where address 1 can propose a block
        vm.warp(currentSlotTimestamp);

        // Prepare lookahead set for the next epoch
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](2);
        // Slot 10
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + (9 * LibPreconfConstants.SECONDS_IN_SLOT),
            preconfer: addr_1
        });
        // Slot 20
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + (19 * LibPreconfConstants.SECONDS_IN_SLOT),
            preconfer: addr_2
        });

        // Address 1 proposes a block and updates the lookahead
        vm.prank(addr_1);
        _proposeBlock(1, lookaheadSetParams);

        // Verify that the lookahead for the next epoch has been updated
        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer =
            preconfTaskManager.getLookaheadBuffer();

        // Check the first entry
        assertEq(lookaheadBuffer[3].preconfer, addr_1);
        assertEq(
            lookaheadBuffer[3].timestamp, nextEpochStart + (9 * LibPreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(
            lookaheadBuffer[3].prevTimestamp,
            currentEpochStart + (22 * LibPreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(lookaheadBuffer[3].isFallback, false);

        // Check the second entry
        assertEq(lookaheadBuffer[4].preconfer, addr_2);
        assertEq(
            lookaheadBuffer[4].timestamp,
            nextEpochStart + (19 * LibPreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(
            lookaheadBuffer[4].prevTimestamp,
            nextEpochStart + (9 * LibPreconfConstants.SECONDS_IN_SLOT)
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
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        uint256 dedicatedSlotTimestamp =
            currentEpochStart + (12 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Warp to a timestamp after the dedicated slot
        vm.warp(dedicatedSlotTimestamp + LibPreconfConstants.SECONDS_IN_SLOT);

        vm.prank(addr_1);
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        _proposeBlock(1, new IPreconfTaskManager.LookaheadSetParam[](0));
    }

    function test_newBlockProposal_revertWhenTimestampBelowPrevTimestamp() external {
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        uint256 prevSlotTimestamp = currentEpochStart + (12 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Warp to a timestamp before the previous slot
        vm.warp(prevSlotTimestamp - LibPreconfConstants.SECONDS_IN_SLOT);

        vm.prank(addr_3);
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        _proposeBlock(2, new IPreconfTaskManager.LookaheadSetParam[](0));
    }

    function test_newBlockProposal_revertWhenTimestampEqualToPrevTimestamp() external {
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        uint256 prevSlotTimestamp = currentEpochStart + (12 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Warp to the exact timestamp of the previous slot
        vm.warp(prevSlotTimestamp);

        vm.prank(addr_3);
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        _proposeBlock(2, new IPreconfTaskManager.LookaheadSetParam[](0));
    }

    function test_newBlockProposal_revertWhenSenderIsNotThePreconfer() external {
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
        uint256 currentSlotTimestamp =
            currentEpochStart + (15 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Warp to a slot when Address 3 is the expected preconfer
        vm.warp(currentSlotTimestamp);

        // Try to propose with a different address than the expected preconfer
        vm.prank(addr_2); // addr_2 is not the expected preconfer (It is addr_3)
        vm.expectRevert(IPreconfTaskManager.SenderIsNotThePreconfer.selector);
        _proposeBlock(2, new IPreconfTaskManager.LookaheadSetParam[](0));
    }

    function _proposeBlock(
        uint256 lookaheadPointer,
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams
    )
        internal
    {
        ITaikoL1.BlockParamsV3 memory defaultParams;
        ITaikoL1.BlockParamsV3[] memory paramsArr = new ITaikoL1.BlockParamsV3[](1);
        paramsArr[0] = defaultParams;

        preconfTaskManager.proposeBlocksV3(
            msg.sender, new ITaikoL1.Signal[](0), paramsArr, lookaheadPointer, lookaheadSetParams
        );
    }
}
