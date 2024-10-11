// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LookaheadFixtures} from "../fixtures/LookaheadFixtures.sol";

import {PreconfConstants} from "src/layer1/preconf/avs/PreconfConstants.sol";
import {IPreconfTaskManager} from "src/layer1/preconf/interfaces/IPreconfTaskManager.sol";

contract LookaheadPosting is LookaheadFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_forcePushLookahead_setsNonEmptyLookaheadInNextEpoch_Case1() external {
        addPreconfersToRegistry(5);

        // Arbitrary slot in current epoch
        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;

        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);

        // Slot 1
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({preconfer: addr_1, timestamp: nextEpochStart});

        // Address 1 pushes the lookahead
        vm.prank(addr_1);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);

        // Verify storage is updated correctly
        uint256 lookaheadTail = preconfTaskManager.getLookaheadTail();
        assertEq(lookaheadTail, 1);

        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer = preconfTaskManager.getLookaheadBuffer();
        assertEq(lookaheadBuffer[1].preconfer, addr_1);
        assertEq(lookaheadBuffer[1].timestamp, nextEpochStart);
        assertEq(lookaheadBuffer[1].prevTimestamp, 0);
        assertEq(lookaheadBuffer[1].isFallback, false);

        assertEq(preconfTaskManager.getLookaheadPoster(nextEpochStart), addr_1);
    }

    function test_forcePushLookahead_setsNonEmptyLookaheadInNextEpoch_Case2() external {
        addPreconfersToRegistry(7);

        // Arbitrary slot in current epoch
        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 slot20Timestamp = nextEpochStart + (19 * PreconfConstants.SECONDS_IN_SLOT);

        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](2);

        // Slot 1
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({preconfer: addr_1, timestamp: nextEpochStart});
        // Slot 20
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({preconfer: addr_3, timestamp: slot20Timestamp});

        // Address 3 pushes the lookahead
        vm.prank(addr_3);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);

        // Storage is updated correctly
        uint256 lookaheadTail = preconfTaskManager.getLookaheadTail();
        assertEq(lookaheadTail, 2);

        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer = preconfTaskManager.getLookaheadBuffer();
        assertEq(lookaheadBuffer[1].preconfer, addr_1);
        assertEq(lookaheadBuffer[1].timestamp, nextEpochStart);
        assertEq(lookaheadBuffer[1].prevTimestamp, 0);
        assertEq(lookaheadBuffer[1].isFallback, false);

        assertEq(lookaheadBuffer[2].preconfer, addr_3);
        assertEq(lookaheadBuffer[2].timestamp, slot20Timestamp);
        assertEq(lookaheadBuffer[2].prevTimestamp, nextEpochStart);
        assertEq(lookaheadBuffer[2].isFallback, false);

        assertEq(preconfTaskManager.getLookaheadPoster(nextEpochStart), addr_3);
    }

    function test_forcePushLookahead_setsNonEmptyLookaheadInNextEpoch_Case3() external {
        addPreconfersToRegistry(10);

        // Arbitrary slot in current epoch
        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 slot14Timestamp = nextEpochStart + (13 * PreconfConstants.SECONDS_IN_SLOT);
        uint256 slot31Timestamp = nextEpochStart + (30 * PreconfConstants.SECONDS_IN_SLOT);

        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](3);

        // Slot 1
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({preconfer: addr_1, timestamp: nextEpochStart});
        // Slot 14
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({preconfer: addr_2, timestamp: slot14Timestamp});
        // Slot 31
        lookaheadSetParams[2] = IPreconfTaskManager.LookaheadSetParam({preconfer: addr_5, timestamp: slot31Timestamp});

        // Address 2 pushes the lookahead
        vm.prank(addr_2);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);

        // Storage is updated correctly
        uint256 lookaheadTail = preconfTaskManager.getLookaheadTail();
        assertEq(lookaheadTail, 3);

        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer = preconfTaskManager.getLookaheadBuffer();
        assertEq(lookaheadBuffer[1].preconfer, addr_1);
        assertEq(lookaheadBuffer[1].timestamp, nextEpochStart);
        assertEq(lookaheadBuffer[1].prevTimestamp, 0);
        assertEq(lookaheadBuffer[1].isFallback, false);

        assertEq(lookaheadBuffer[2].preconfer, addr_2);
        assertEq(lookaheadBuffer[2].timestamp, slot14Timestamp);
        assertEq(lookaheadBuffer[2].prevTimestamp, nextEpochStart);
        assertEq(lookaheadBuffer[2].isFallback, false);

        assertEq(lookaheadBuffer[3].preconfer, addr_5);
        assertEq(lookaheadBuffer[3].timestamp, slot31Timestamp);
        assertEq(lookaheadBuffer[3].prevTimestamp, slot14Timestamp);
        assertEq(lookaheadBuffer[3].isFallback, false);

        assertEq(preconfTaskManager.getLookaheadPoster(nextEpochStart), addr_2);
    }

    function test_forcePushLookahead_setsFallbackPreconfer_Case1() external {
        addPreconfersToRegistry(10);

        // Arbitrary slot in the current epoch
        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 lastSlotTimestampInNextEpoch =
            nextEpochStart + PreconfConstants.SECONDS_IN_EPOCH - PreconfConstants.SECONDS_IN_SLOT;

        // Create an empty lookahead set
        IPreconfTaskManager.LookaheadSetParam[] memory emptyLookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](0);

        bytes32 randomness = bytes32(uint256(4));

        // Push a required root to the mock beacon block root contract
        // This root as a source of randomness selects the preconfer with index 4
        beaconBlockRootContract.set(
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_SLOT, randomness
        );

        // Address 2 pushes the empty lookahead
        vm.prank(addr_2);
        preconfTaskManager.forcePushLookahead(emptyLookaheadSetParams);

        // Verify that the lookahead is empty
        uint256 lookaheadTail = preconfTaskManager.getLookaheadTail();
        assertEq(lookaheadTail, 1);

        // Verify that correct preconfer is inserted as fallback in lookahead buffer
        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer = preconfTaskManager.getLookaheadBuffer();
        assertEq(
            lookaheadBuffer[1].preconfer, computeFallbackPreconfer(randomness, preconfRegistry.getNextPreconferIndex())
        );
        assertEq(lookaheadBuffer[1].timestamp, lastSlotTimestampInNextEpoch);
        assertEq(lookaheadBuffer[1].prevTimestamp, 0);
        assertEq(lookaheadBuffer[1].isFallback, true);

        // Verify that the lookahead poster is set correctly
        assertEq(preconfTaskManager.getLookaheadPoster(nextEpochStart), addr_2);
    }

    function test_forcePushLookahead_setsFallbackPreconfer_Case2() external {
        addPreconfersToRegistry(10);

        // Arbitrary slot in the current epoch
        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        uint256 lastSlotTimestampInNextEpoch =
            nextEpochStart + PreconfConstants.SECONDS_IN_EPOCH - PreconfConstants.SECONDS_IN_SLOT;

        // Create an empty lookahead set
        IPreconfTaskManager.LookaheadSetParam[] memory emptyLookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](0);

        bytes32 randomness = bytes32(uint256(4));

        // Unlike Case 1, we push the root at a later timestamp to simulate "skipped blocks" and see
        // if the contract iterates forward and finds the required root
        beaconBlockRootContract.set(
            PreconfConstants.MAINNET_BEACON_GENESIS + 3 * PreconfConstants.SECONDS_IN_SLOT, randomness
        );

        // Address 2 pushes the empty lookahead
        vm.prank(addr_2);
        preconfTaskManager.forcePushLookahead(emptyLookaheadSetParams);

        // Verify that the lookahead is empty
        uint256 lookaheadTail = preconfTaskManager.getLookaheadTail();
        assertEq(lookaheadTail, 1);

        // Verify that correct preconfer is inserted as fallback in lookahead buffer
        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer = preconfTaskManager.getLookaheadBuffer();
        assertEq(
            lookaheadBuffer[1].preconfer, computeFallbackPreconfer(randomness, preconfRegistry.getNextPreconferIndex())
        );
        assertEq(lookaheadBuffer[1].timestamp, lastSlotTimestampInNextEpoch);
        assertEq(lookaheadBuffer[1].prevTimestamp, 0);
        assertEq(lookaheadBuffer[1].isFallback, true);

        // Verify that the lookahead poster is set correctly
        assertEq(preconfTaskManager.getLookaheadPoster(nextEpochStart), addr_2);
    }

    function test_forcePushLookahead_revertsWhenPreconferNotRegistered_Case1() external {
        // Add addr_1 through addr_5 to the registry
        addPreconfersToRegistry(5);

        IPreconfTaskManager.LookaheadSetParam[] memory emptyLookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](0);

        // Transaction is expected to revert as addr_6 is not registered in the preconfer registry
        vm.prank(addr_6);
        vm.expectRevert(IPreconfTaskManager.PreconferNotRegistered.selector);
        preconfTaskManager.forcePushLookahead(emptyLookaheadSetParams);
    }

    function test_forcePushLookahead_revertsWhenPreconferNotRegistered_Case2() external {
        // Add addr_1 through addr_5 to the registry
        addPreconfersToRegistry(5);

        // Arbitrary slot in the current epoch
        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;

        // Create a lookahead set with an unregistered preconfer (addr_6)
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + PreconfConstants.SECONDS_IN_SLOT,
            preconfer: addr_6 // addr_6 is not registered
        });

        // Transaction is expected to revert as addr_6 is not registered in the preconfer registry
        vm.prank(addr_1);
        vm.expectRevert(IPreconfTaskManager.PreconferNotRegistered.selector);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }

    function test_forcePushLookahead_revertsWhenLookaheadIsNotRequired() external {
        // Add addr_1 through addr_5 to the registry
        addPreconfersToRegistry(5);

        // Arbitrary slot in the current epoch
        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;

        // Create a valid lookahead set
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + PreconfConstants.SECONDS_IN_SLOT,
            preconfer: addr_1
        });

        // First push should succeed
        vm.prank(addr_1);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);

        // Verify that the lookahead poster is set correctly
        assertEq(preconfTaskManager.getLookaheadPoster(nextEpochStart), addr_1);

        // Attempt to push the lookahead again fails
        vm.prank(addr_2);
        vm.expectRevert(IPreconfTaskManager.LookaheadIsNotRequired.selector);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }

    function test_forcePushLookahead_revertsWhenInvalidSlotTimestamp_notMultipleOf12() external {
        // Add addr_1 to the registry
        addPreconfersToRegistry(1);

        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;

        // Create a lookahead set with an invalid timestamp (not a multiple of 12 seconds from epoch start)
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + 5, // Not a multiple of 12
            preconfer: addr_1
        });

        vm.prank(addr_1);
        vm.expectRevert(IPreconfTaskManager.InvalidSlotTimestamp.selector);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }

    function test_forcePushLookahead_revertsWhenInvalidSlotTimestamp_exceedsEpochEnd() external {
        // Add addr_1 to the registry
        addPreconfersToRegistry(1);

        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;

        // Create a lookahead set with a timestamp that exceeds the epoch end
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + PreconfConstants.SECONDS_IN_EPOCH, // Exactly one epoch later, which is the start of the next epoch
            preconfer: addr_1
        });

        vm.prank(addr_1);
        vm.expectRevert(IPreconfTaskManager.InvalidSlotTimestamp.selector);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }

    function test_forcePushLookahead_revertsWhenInvalidSlotTimestamp_notGreaterThanPrevious() external {
        // Add addr_1 and addr_2 to the registry
        addPreconfersToRegistry(2);

        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;

        // Create a lookahead set with timestamps in the wrong order
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](2);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + 2 * PreconfConstants.SECONDS_IN_SLOT,
            preconfer: addr_1
        });
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + PreconfConstants.SECONDS_IN_SLOT, // Earlier than the previous timestamp
            preconfer: addr_2
        });

        vm.prank(addr_1);
        vm.expectRevert(IPreconfTaskManager.InvalidSlotTimestamp.selector);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }

    function test_forcePushLookahead_emitsLookaheadUpdatedEvent() external {
        // Add addr_1 and addr_2 to the registry
        addPreconfersToRegistry(2);

        uint256 currentSlotTimestamp = PreconfConstants.MAINNET_BEACON_GENESIS + 2 * PreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        uint256 nextEpochStart = PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;

        // Create a valid lookahead set
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](2);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + PreconfConstants.SECONDS_IN_SLOT,
            preconfer: addr_1
        });
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({
            timestamp: nextEpochStart + 2 * PreconfConstants.SECONDS_IN_SLOT,
            preconfer: addr_2
        });

        vm.prank(addr_1);
        vm.expectEmit();
        emit IPreconfTaskManager.LookaheadUpdated(lookaheadSetParams);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }
}
