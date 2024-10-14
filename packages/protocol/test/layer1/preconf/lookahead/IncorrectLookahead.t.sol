// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../fixtures/BeaconProofs.sol";
import "../fixtures/LookaheadFixtures.sol";

import "src/layer1/preconf/impl/LibPreconfConstants.sol";
import "src/layer1/preconf/iface/IPreconfTaskManager.sol";

/// @dev The beacon chain data used here is from slot 9000000 on Ethereum mainnet.
contract IncorrectLookahead is LookaheadFixtures {
    // Most tests in this file use a lookahead that has a preconfer (addr_1) set at slot 16 in epoch
    // 2.
    // Epoch 1 starts at the genesis timestamp.
    uint256 internal nextEpochStart =
        LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;
    uint256 internal slot16Timestamp = nextEpochStart + (15 * LibPreconfConstants.SECONDS_IN_SLOT);

    function setUp() public override {
        super.setUp();
    }

    function test_proveIncorrectLookahead_slashesPosterWhenLookaheadEntryIsIncorrect_Case1()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // This beacon proposer is not added as a validator for our preconfer in lookahead
        bytes memory beaconProposer = BeaconProofs.validator();

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        // Verify that storage has been updated
        assertEq(
            preconfTaskManager.getLookaheadPoster(
                LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH
            ),
            address(0)
        );

        // Poster i.e addr_1 must be slashed
        assertTrue(preconfServiceManager.operatorSlashed(addr_1));
    }

    function test_proveIncorrectLookahead_slashesPosterWhenLookaheadEntryIsIncorrect_Case2()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // The beacon proposer is added for the preconfer, but is not allowed to propose at slot 16
        bytes memory beaconProposer = BeaconProofs.validator();
        preconfRegistry.addValidator(
            beaconProposer, addr_1, slot16Timestamp + LibPreconfConstants.SECONDS_IN_SLOT, 0
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        // Verify that storage has been updated
        assertEq(
            preconfTaskManager.getLookaheadPoster(
                LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH
            ),
            address(0)
        );

        // Poster i.e addr_1 must be slashed
        assertTrue(preconfServiceManager.operatorSlashed(addr_1));
    }

    function test_proveIncorrectLookahead_slashesPosterWhenLookaheadEntryIsIncorrect_Case3()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // The beacon proposer is added for the preconfer, but is has lost proposal rights at slot
        // 16
        bytes memory beaconProposer = BeaconProofs.validator();
        preconfRegistry.addValidator(
            beaconProposer, addr_1, LibPreconfConstants.MAINNET_BEACON_GENESIS, slot16Timestamp
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        // Verify that storage has been updated
        assertEq(
            preconfTaskManager.getLookaheadPoster(
                LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH
            ),
            address(0)
        );

        // Poster i.e addr_1 must be slashed
        assertTrue(preconfServiceManager.operatorSlashed(addr_1));
    }

    function test_proveIncorrectLookahead_slashesPosterWhenLookaheadEntryIsIncorrect_Case4()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // The beacon proposer is added for the preconfer, but is has lost proposal rights before
        // slot 16
        bytes memory beaconProposer = BeaconProofs.validator();
        preconfRegistry.addValidator(
            beaconProposer,
            addr_1,
            LibPreconfConstants.MAINNET_BEACON_GENESIS,
            slot16Timestamp - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        // Verify that storage has been updated
        assertEq(
            preconfTaskManager.getLookaheadPoster(
                LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH
            ),
            address(0)
        );

        // Poster i.e addr_1 must be slashed
        assertTrue(preconfServiceManager.operatorSlashed(addr_1));
    }

    function test_proveIncorrectLookahead_slashesPosterWhenLookaheadEntryIsIncorrect_Case5()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // The beacon proposer belongs to another preconfer
        bytes memory beaconProposer = BeaconProofs.validator();
        preconfRegistry.addValidator(
            beaconProposer, addr_2, LibPreconfConstants.MAINNET_BEACON_GENESIS, 0
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        // Verify that storage has been updated
        assertEq(
            preconfTaskManager.getLookaheadPoster(
                LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH
            ),
            address(0)
        );

        // Poster i.e addr_1 must be slashed
        assertTrue(preconfServiceManager.operatorSlashed(addr_1));
    }

    function test_proveIncorrectLookahead_slashesPosterWhenLookaheadEntryIsIncorrect_Case6()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // Take a slot for which their is no dedicated lookahead entry and set it's beacon block
        // root
        // containing a proposer mapped to a valid preconfer
        uint256 slot15Timestamp = slot16Timestamp - LibPreconfConstants.SECONDS_IN_SLOT;
        beaconBlockRootContract.set(slot16Timestamp, BeaconProofs.beaconBlockRoot());

        // The beacon proposer belongs to a valid preconfer who is not in the lookahead at slot 15
        bytes memory beaconProposer = BeaconProofs.validator();
        preconfRegistry.addValidator(
            beaconProposer, addr_2, LibPreconfConstants.MAINNET_BEACON_GENESIS, 0
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot15Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        // Verify that storage has been updated
        assertEq(
            preconfTaskManager.getLookaheadPoster(
                LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH
            ),
            address(0)
        );

        // Poster i.e addr_1 must be slashed
        assertTrue(preconfServiceManager.operatorSlashed(addr_1));
    }

    function test_proveIncorrectLookahead_slashesPosterWhenLookaheadEntryIsIncorrect_Case7()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts empty lookahead for next epoch to set fallback preconfer
        postEmptyLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // Take the last slot in the lookahead with the fallback preconfer and set it's beacon block
        // root
        // containing a proposer mapped to an active preconfer
        beaconBlockRootContract.set(nextEpochEnd, BeaconProofs.beaconBlockRoot());

        // The beacon proposer belongs to a valid preconfer who is not in the lookahead at slot 32
        // as the lookahead has the fallback preconfer
        bytes memory beaconProposer = BeaconProofs.validator();
        preconfRegistry.addValidator(
            beaconProposer, addr_2, LibPreconfConstants.MAINNET_BEACON_GENESIS, 0
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            1,
            nextEpochEnd - LibPreconfConstants.SECONDS_IN_SLOT,
            beaconProposer,
            BeaconProofs.eip4788ValidatorInclusionProof()
        );

        // Verify that storage has been updated
        assertEq(
            preconfTaskManager.getLookaheadPoster(
                LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH
            ),
            address(0)
        );

        // Poster i.e addr_1 must be slashed
        assertTrue(preconfServiceManager.operatorSlashed(addr_1));
    }

    function test_proveIncorrectLookahead_setsFallbackPreconfer_Case1() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to an arbitrary timestamp after the incorrect slot in the next epoch
        vm.warp(slot16Timestamp + (2 * LibPreconfConstants.SECONDS_IN_SLOT));

        // This beacon proposer is not added as a validator for our preconfer in lookahead
        bytes memory beaconProposer = BeaconProofs.validator();

        bytes32 randomness = bytes32(uint256(4));

        // Set beacon block root such that addr_4 is randomly selected
        beaconBlockRootContract.set(
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_SLOT, randomness
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        uint256 lastSlotTimestamp =
            nextEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH - LibPreconfConstants.SECONDS_IN_SLOT;

        // Verify that the lookahead has the fallback preconfer
        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer =
            preconfTaskManager.getLookaheadBuffer();
        assertEq(
            lookaheadBuffer[3].preconfer,
            computeFallbackPreconfer(randomness, preconfRegistry.getNextPreconferIndex())
        );
        assertEq(lookaheadBuffer[3].timestamp, lastSlotTimestamp);
        assertEq(
            lookaheadBuffer[3].prevTimestamp, nextEpochStart - LibPreconfConstants.SECONDS_IN_SLOT
        );
        assertEq(lookaheadBuffer[3].isFallback, true);

        // Verify that the remaining entries for the  epoch have been removed
        assertEq(lookaheadBuffer[2].preconfer, address(0));
        assertEq(lookaheadBuffer[2].timestamp, 0);
        assertEq(lookaheadBuffer[2].prevTimestamp, 0);
        assertEq(lookaheadBuffer[2].isFallback, false);

        assertEq(lookaheadBuffer[1].preconfer, address(0));
        assertEq(lookaheadBuffer[1].timestamp, 0);
        assertEq(lookaheadBuffer[1].prevTimestamp, 0);
        assertEq(lookaheadBuffer[1].isFallback, false);
    }

    function test_proveIncorrectLookahead_setsFallbackPreconfer_Case2() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to an arbitrary timestamp after the incorrect slot in the next epoch
        vm.warp(slot16Timestamp + (2 * LibPreconfConstants.SECONDS_IN_SLOT));

        // Force push lookahead for next epoch
        // This to ensure if the first entry in the following epoch connects correctly to the newly
        // inserted
        // fallback preconfer
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](2);

        uint256 nextToNextEpochStart = nextEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Slot 13
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_1,
            timestamp: nextToNextEpochStart + (12 * LibPreconfConstants.SECONDS_IN_SLOT)
        });
        // Slot 22
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: nextToNextEpochStart + (21 * LibPreconfConstants.SECONDS_IN_SLOT)
        });

        // Address 1 pushes the lookahead
        vm.prank(addr_1);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);

        // This beacon proposer is not added as a validator for our preconfer in lookahead
        bytes memory beaconProposer = BeaconProofs.validator();

        bytes32 randomness = bytes32(uint256(4));

        // Set beacon block root such that addr_4 is randomly selected
        beaconBlockRootContract.set(
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_SLOT, randomness
        );

        // Prove the lookahead to be incorrect
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );

        uint256 lastSlotTimestamp =
            nextEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH - LibPreconfConstants.SECONDS_IN_SLOT;

        // Verify that the lookahead has the fallback preconfer
        IPreconfTaskManager.LookaheadBufferEntry[128] memory lookaheadBuffer =
            preconfTaskManager.getLookaheadBuffer();
        assertEq(
            lookaheadBuffer[3].preconfer,
            computeFallbackPreconfer(randomness, preconfRegistry.getNextPreconferIndex())
        );
        assertEq(lookaheadBuffer[3].timestamp, lastSlotTimestamp);
        assertEq(
            lookaheadBuffer[3].prevTimestamp, nextEpochStart - LibPreconfConstants.SECONDS_IN_SLOT
        );
        assertEq(lookaheadBuffer[3].isFallback, true);

        // Verify that the remaining entries for the epoch have been removed
        assertEq(lookaheadBuffer[2].preconfer, address(0));
        assertEq(lookaheadBuffer[2].timestamp, 0);
        assertEq(lookaheadBuffer[2].prevTimestamp, 0);
        assertEq(lookaheadBuffer[2].isFallback, false);

        assertEq(lookaheadBuffer[1].preconfer, address(0));
        assertEq(lookaheadBuffer[1].timestamp, 0);
        assertEq(lookaheadBuffer[1].prevTimestamp, 0);
        assertEq(lookaheadBuffer[1].isFallback, false);

        // Verify that the first entry in the following epoch is connected to the fallback preconfer
        assertEq(lookaheadBuffer[4].preconfer, addr_1);
        assertEq(
            lookaheadBuffer[4].timestamp,
            nextToNextEpochStart + (12 * LibPreconfConstants.SECONDS_IN_SLOT)
        );
        assertEq(lookaheadBuffer[4].prevTimestamp, lastSlotTimestamp);
        assertEq(lookaheadBuffer[4].isFallback, false);
    }

    function test_proveIncorrectLookahead_revertsWhenPosterIsAlreadySlashedOrLookaheadIsEmpty()
        external
    {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // Reverts when the timestamp belongs to an epoch that does not have a lookahead yet
        vm.expectRevert(IPreconfTaskManager.PosterAlreadySlashedOrLookaheadIsEmpty.selector);
        preconfTaskManager.proveIncorrectLookahead(
            2,
            // Epoch does not have a poster yet
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (4 * LibPreconfConstants.SECONDS_IN_EPOCH),
            BeaconProofs.validator(),
            BeaconProofs.eip4788ValidatorInclusionProof()
        );
    }

    function test_proveIncorrectLookahead_revertsWhenDisputeWindowIsMissed() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // Wrap into the future when the dispute window is missed
        vm.warp(
            slot16Timestamp + LibPreconfConstants.DISPUTE_PERIOD + LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Reverts when the dispute period is over
        vm.expectRevert(IPreconfTaskManager.MissedDisputeWindow.selector);
        preconfTaskManager.proveIncorrectLookahead(
            2,
            slot16Timestamp,
            BeaconProofs.validator(),
            BeaconProofs.eip4788ValidatorInclusionProof()
        );
    }

    function test_proveIncorrectLookahead_revertsWhenLookaheadPointerIsInvalid_Case1() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // Reverts because the pointer is in the past and slot timestamp in future
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        preconfTaskManager.proveIncorrectLookahead(
            1,
            slot16Timestamp,
            BeaconProofs.validator(),
            BeaconProofs.eip4788ValidatorInclusionProof()
        );
    }

    function test_proveIncorrectLookahead_revertsWhenLookaheadPointerIsInvalid_Case2() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // Reverts because the pointer is in the future (slotTimestamp == pointer.prevTimestamp)
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        preconfTaskManager.proveIncorrectLookahead(
            3,
            slot16Timestamp,
            BeaconProofs.validator(),
            BeaconProofs.eip4788ValidatorInclusionProof()
        );
    }

    function test_proveIncorrectLookahead_revertsWhenLookaheadPointerIsInvalid_Case3() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // Wrap to arbitrary timestamp in next epoch
        vm.warp(slot16Timestamp + (2 * LibPreconfConstants.SECONDS_IN_SLOT));

        // Push a lookahead for the following epoch
        // This will enable simulating the condition slotTimestamp < pointer.prevTimestamps
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        uint256 nextToNextEpochStart = nextEpochStart + LibPreconfConstants.SECONDS_IN_EPOCH;
        // Slot 13
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_1,
            timestamp: nextToNextEpochStart + (12 * LibPreconfConstants.SECONDS_IN_SLOT)
        });

        // Address 1 pushes the lookahead
        vm.prank(addr_1);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);

        // Reverts because the pointer is in the future (slotTimestamp < pointer.prevTimestamp)
        vm.expectRevert(IPreconfTaskManager.InvalidLookaheadPointer.selector);
        preconfTaskManager.proveIncorrectLookahead(
            4,
            slot16Timestamp,
            BeaconProofs.validator(),
            BeaconProofs.eip4788ValidatorInclusionProof()
        );
    }

    function test_proveIncorrectLookahead_revertsWhenLookaheadEntryIsCorrect() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        // Sets slot 16 to its own address
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // Add the validator for addr_1 in registry
        // This is also the proposer for the beacon block whose root we have stored (see
        // `postLookahead()`)
        bytes memory beaconProposer = BeaconProofs.validator();
        preconfRegistry.addValidator(
            beaconProposer, addr_1, LibPreconfConstants.MAINNET_BEACON_GENESIS, 0
        );

        // Reverts when the lookahead is tried to be proven incorrect
        vm.expectRevert(IPreconfTaskManager.LookaheadEntryIsCorrect.selector);
        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );
    }

    function test_proveIncorrectLookahead_emitsProvedIncorrectLookaheadEvent() external {
        addPreconfersToRegistry(10);
        // addr_1 posts lookahead for next epoch
        postLookahead();

        // We wrap to a timestamp in next to next epoch because invalidating the lookahead of an
        // ongoing epoch
        // sets a random preconfer for the epoch which is not intended for this test.
        uint256 nextEpochEnd =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + (2 * LibPreconfConstants.SECONDS_IN_EPOCH);
        vm.warp(nextEpochEnd + (3 * LibPreconfConstants.SECONDS_IN_SLOT));

        // This beacon proposer is not added as a validator for our preconfer in lookahead
        bytes memory beaconProposer = BeaconProofs.validator();

        // Prove the lookahead to be incorrect
        vm.expectEmit();
        emit IPreconfTaskManager.ProvedIncorrectLookahead(addr_1, slot16Timestamp, address(this));

        preconfTaskManager.proveIncorrectLookahead(
            2, slot16Timestamp, beaconProposer, BeaconProofs.eip4788ValidatorInclusionProof()
        );
    }

    //=========
    // Helpers
    //=========

    /// @dev Makes addr_1 push a fixed lookeahead
    function postLookahead() internal {
        // Arbitrary slot in current epoch
        uint256 currentSlotTimestamp =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + 2 * LibPreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](3);

        // Slot 5
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: nextEpochStart + (4 * LibPreconfConstants.SECONDS_IN_SLOT)
        });
        // Slot 16 (Slot used for fault proofs)
        lookaheadSetParams[1] =
            IPreconfTaskManager.LookaheadSetParam({ preconfer: addr_1, timestamp: slot16Timestamp });
        // Slot 25
        lookaheadSetParams[2] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_3,
            timestamp: nextEpochStart + (24 * LibPreconfConstants.SECONDS_IN_SLOT)
        });

        // Address 1 pushes the lookahead
        vm.prank(addr_1);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);

        // Set the beacon block root for slot 16 (in the timestamp of slot 17)
        beaconBlockRootContract.set(
            slot16Timestamp + LibPreconfConstants.SECONDS_IN_SLOT, BeaconProofs.beaconBlockRoot()
        );
    }

    /// @dev Makes addr_1 push an empty lookeahead
    function postEmptyLookahead() internal {
        // Arbitrary slot in current epoch
        uint256 currentSlotTimestamp =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + 2 * LibPreconfConstants.SECONDS_IN_SLOT;
        vm.warp(currentSlotTimestamp);

        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](0);

        beaconBlockRootContract.set(
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_SLOT,
            bytes32(uint256(4))
        );

        // Address 1 pushes the lookahead
        vm.prank(addr_1);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }
}
