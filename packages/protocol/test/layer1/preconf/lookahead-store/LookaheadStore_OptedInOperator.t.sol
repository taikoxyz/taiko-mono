// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LookaheadStoreBase } from "./LookaheadStoreBase.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibLookaheadEncoder as Encoder } from "src/layer1/preconf/libs/LibLookaheadEncoder.sol";

contract TestLookaheadStore_OptedInOperator is LookaheadStoreBase {
    // Proposer Validation tests (passing)
    // ------------------------------------

    function test_sameEpochDedicatedSlotProposal_case1() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // When operator at slot 0 proposes
        vm.warp(currLookahead[0].timestamp);
        uint48 submissionWindowEnd = _checkProposer(
            0, // slot index
            currLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, currLookahead[0].timestamp);
    }

    function test_sameEpochDedicatedSlotProposal_case2() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // The next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // When operator at slot 4 proposes
        vm.warp(currLookahead[1].timestamp);
        uint48 submissionWindowEnd = _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, currLookahead[1].timestamp);
    }

    function test_sameEpochAdvancedProposal() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // When operator at slot 12 proposes in advanced in slot 10

        // Slot 9 timestamp + seconds in a slot
        vm.warp(currLookahead[2].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            3, // slot index
            currLookahead[3].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, currLookahead[3].timestamp);
    }

    function test_crossEpochProposalOperatorInSlot0_case1() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead slots: 0, 3
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // When operator at slot 0 (next epoch) proposes in advanced in slot 20 (current epoch)

        // Slot 12 timestamp + 8 slots
        vm.warp(currLookahead[3].timestamp + 8 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            nextLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    function test_crossEpochProposalOperatorInSlot0_case2() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead slots: 0, 3
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // When operator at slot 0 (next epoch) proposes in advanced in last
        // slot of the current epoch

        // Slot 12 timestamp + 19 slots
        vm.warp(currLookahead[3].timestamp + 19 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            nextLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    function test_crossEpochProposalOperatorNotInSlot0_case1() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead slots: 3, 6
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 3;
        nextLookaheadSlotPositions[1] = 6;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // When operator at slot 3 (next epoch) proposes in advanced in slot 20

        // Slot 12 timestamp + 8 slots
        vm.warp(currLookahead[3].timestamp + 8 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            nextLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    function test_crossEpochProposalOperatorNotInSlot0_case2() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead slots: 3, 6
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 3;
        nextLookaheadSlotPositions[1] = 6;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // When operator at slot 3 (next epoch) proposes in advanced in last
        // slot of the current epoch

        // Slot 12 timestamp + 19 slots
        vm.warp(currLookahead[3].timestamp + 19 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            nextLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    // Proposer Validation tests (reverts)
    // ------------------------------------

    function test_revertsIfProposerIsNotThePreconferInDedicatedSlot() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // Slot 0
        vm.warp(currLookahead[0].timestamp);
        vm.expectRevert(ILookaheadStore.ProposerIsNotPreconfer.selector);
        _checkProposer(
            0, // slot index
            currLookahead[1].committer, // Operator of slot 4, wrongly proposing in slot 0
            currLookahead,
            nextLookahead,
            bytes("")
        );
    }

    function test_revertsIfProposerIsNotThePreconferInAdvancedSlot() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // Slot 1
        vm.warp(currLookahead[0].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        vm.expectRevert(ILookaheadStore.ProposerIsNotPreconfer.selector);
        _checkProposer(
            1, // slot index
            currLookahead[0].committer, // Operator of slot 0, wrong proposing in slot 1
            currLookahead,
            nextLookahead,
            bytes("")
        );
    }

    function test_revertsIfPreconfingPeriodIsIncorrect() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        // Slot 1
        vm.warp(currLookahead[0].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        vm.expectRevert(ILookaheadStore.InvalidLookaheadTimestamp.selector);
        _checkProposer(
            0, // slot index (wrong, since we have moved passed slot 0)
            currLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );
    }

    // Next epoch lookahead update test (passing)
    // -------------------------------------------

    function test_updateLookaheadDoesNotExpectLookaheadInSlot0() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        ILookaheadStore.LookaheadSlot[] memory nextLookahead =
            new ILookaheadStore.LookaheadSlot[](0);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 0 proposes
        vm.warp(currLookahead[0].timestamp);
        _checkProposer(
            0, // slot index
            currLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Lookahead is still not set
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));
    }

    function test_lookaheadIsNotUpdatedWhenAlreadyPosted() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is already posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            nextLookaheadSlotPositions,
            true // Post
        );

        // Prepare a new lookahead for next epoch
        uint256[] memory newNextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory newNextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, newNextLookaheadSlotPositions, false
        );

        // Operator of slot 4 builds a commitment
        bytes memory signature =
            _signLookaheadCommitment(currLookahead[1].registrationRoot, nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Next lookahead is the one originally posted
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, Encoder.encode(nextLookahead))
        );

        // When operator of slot 4 proposes with a new next lookahead
        vm.warp(currLookahead[1].timestamp);
        _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            newNextLookahead,
            signature
        );

        // Next lookahead is still the original one
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, Encoder.encode(nextLookahead))
        );
    }

    function test_updateLookaheadInDedicatedSlot() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        // Operator of slot 4 builds a commitment
        bytes memory signature =
            _signLookaheadCommitment(currLookahead[1].registrationRoot, nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 4 proposes
        vm.warp(currLookahead[1].timestamp);
        _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );

        // Lookahead is updated correctly
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, Encoder.encode(nextLookahead))
        );
    }

    function test_updateLookaheadInAdvancedSlot() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        // Operator of slot 4 builds a commitment
        bytes memory signature =
            _signLookaheadCommitment(currLookahead[1].registrationRoot, nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 4 proposes in advanced
        vm.warp(currLookahead[0].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );

        // Lookahead is updated correctly
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, Encoder.encode(nextLookahead))
        );
    }

    function test_updateLookaheadAndCrossEpochProposal() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        // Operator of slot 0 (next epoch) builds a commitment
        bytes memory signature =
            _signLookaheadCommitment(nextLookahead[0].registrationRoot, nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 0 (next epoch) proposes in advanced in slot 13
        vm.warp(currLookahead[3].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        _checkProposer(
            type(uint256).max, // slot index
            nextLookahead[0].committer,
            currLookahead,
            nextLookahead,
            signature
        );

        // Lookahead is updated correctly
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, Encoder.encode(nextLookahead))
        );
    }

    // Next epoch lookahead update test (reverts)
    // -------------------------------------------

    function test_revertsWhenSlotTimestampIsNotIncrementing() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 0; // same as previous -> non-incrementing
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature =
            _signLookaheadCommitment(currLookahead[1].registrationRoot, nextLookahead);

        // When operator of slot 4 proposes, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.SlotTimestampIsNotIncrementing.selector);
        _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenSlotTimestampIsDecreasing() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 5;
        nextLookaheadSlotPositions[1] = 3; // less than previous -> decreasing
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature =
            _signLookaheadCommitment(currLookahead[1].registrationRoot, nextLookahead);

        // When operator of slot 4 proposes, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.SlotTimestampIsNotIncrementing.selector);
        _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenInvalidLookaheadEpoch() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 33; // 1 slot beyond the epoch (32 slots per epoch)
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature =
            _signLookaheadCommitment(currLookahead[1].registrationRoot, nextLookahead);

        // When operator of slot 4 proposes, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.InvalidLookaheadEpoch.selector);
        _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenCommitmentSignerMismatch() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        // Build commitment signed by a different operator than the proposer
        bytes memory wrongSignature =
            _signLookaheadCommitment(currLookahead[2].registrationRoot, nextLookahead);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.CommitmentSignerMismatch.selector);
        _checkProposer(
            1, // slot index
            currLookahead[1].committer,
            currLookahead,
            nextLookahead,
            wrongSignature
        );
    }

    function test_revertsWhenNextLookaheadEvidenceDataIsInvalid() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is already posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            nextLookaheadSlotPositions,
            true // Post
        );

        // Prepare a new lookahead for next epoch
        uint256[] memory newNextLookaheadSlotPositions = new uint256[](1);
        newNextLookaheadSlotPositions[0] = 0;
        ILookaheadStore.LookaheadSlot[] memory newNextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, newNextLookaheadSlotPositions, false
        );

        // Operator of slot 0 from next lookahead builds a commitment
        bytes memory signature =
            _signLookaheadCommitment(nextLookahead[1].registrationRoot, nextLookahead);

        // Warp ahead of last operator in current lookahead
        vm.warp(currLookahead[3].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        // When first proposer from next epoch proposes with an invalid lookahead,
        // the transaction reverts
        vm.expectRevert(ILookaheadStore.InvalidLookahead.selector);
        _checkProposer(
            type(uint256).max, // slot index
            nextLookahead[0].committer,
            currLookahead,
            newNextLookahead,
            signature
        );
    }

    function test_revertsWhenNextLookaheadIsPostedWithoutCommitment() external useMainnet {
        // Current lookahead slots: 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 1;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is not posted
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        vm.warp(currLookahead[0].timestamp);
        // When first proposer from current epoch epoch proposes and tries to post lookahead
        // without a commitment, the transaction reverts (only the fallback can do this)
        vm.expectRevert(ILookaheadStore.ProposerIsNotFallbackPreconfer.selector);
        _checkProposer(
            0, // slot index
            currLookahead[0].committer,
            currLookahead,
            nextLookahead,
            bytes("") // No commitment
        );
    }
}
