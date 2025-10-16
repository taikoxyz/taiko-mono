// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LookaheadStoreBase.sol";

contract TestLookaheadStore_OptedInOperator is LookaheadStoreBase {
    // Proposer Validation tests (passing)
    // ------------------------------------

    function test_sameEpochDedicatedSlotProposal_case1(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // When operator at slot 0 proposes
        vm.warp(currLookahead[0].timestamp);
        uint48 submissionWindowEnd = _checkProposer(
            0, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, currLookahead[0].timestamp);
    }

    function test_sameEpochDedicatedSlotProposal_case2(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // When operator at slot 4 proposes
        vm.warp(currLookahead[1].timestamp);
        uint48 submissionWindowEnd = _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, currLookahead[1].timestamp);
    }

    function test_sameEpochAdvancedProposal(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // When operator at slot 12 proposes in advanced in slot 10

        // Slot 9 timestamp + seconds in a slot
        vm.warp(currLookahead[2].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            3, // slot index
            _operators[3].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, currLookahead[3].timestamp);
    }

    function test_crossEpochProposalOperatorInSlot0_case1(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead has operators at slots 0, 3
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // When operator at slot 0 (next epoch) proposes in advanced in slot 20 (current epoch)

        // Slot 12 timestamp + 8 slots
        vm.warp(currLookahead[3].timestamp + 8 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    function test_crossEpochProposalOperatorInSlot0_case2(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead has operators at slots 0, 3
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // When operator at slot 0 (next epoch) proposes in advanced in last
        // slot of the current epoch

        // Slot 12 timestamp + 19 slots
        vm.warp(currLookahead[3].timestamp + 19 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    function test_crossEpochProposalOperatorNotInSlot0_case1(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead has operators at slots 3, 6
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 3;
        nextLookaheadSlotPositions[1] = 6;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // When operator at slot 3 (next epoch) proposes in advanced in slot 20

        // Slot 12 timestamp + 8 slots
        vm.warp(currLookahead[3].timestamp + 8 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    function test_crossEpochProposalOperatorNotInSlot0_case2(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead has operators at slots 3, 6
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 3;
        nextLookaheadSlotPositions[1] = 6;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // When operator at slot 3 (next epoch) proposes in advanced in last
        // slot of the current epoch

        // Slot 12 timestamp + 19 slots
        vm.warp(currLookahead[3].timestamp + 19 * LibPreconfConstants.SECONDS_IN_SLOT);
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Correct `submissionWindowEnd` is returned
        assertEq(submissionWindowEnd, nextLookahead[0].timestamp);
    }

    // Proposer Validation tests (reverts)
    // ------------------------------------

    function test_revertsIfProposerIsNotThePreconferInDedicatedSlot(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // Slot 0
        vm.warp(currLookahead[0].timestamp);
        vm.expectRevert(ILookaheadStore.ProposerIsNotPreconfer.selector);
        _checkProposer(
            0, // slot index
            _operators[1].committer, // Operator of slot 4, wrongly proposing in slot 0
            currLookahead,
            nextLookahead,
            bytes("")
        );
    }

    function test_revertsIfProposerIsNotThePreconferInAdvancedSlot(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // Slot 1
        vm.warp(currLookahead[0].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        vm.expectRevert(ILookaheadStore.ProposerIsNotPreconfer.selector);
        _checkProposer(
            1, // slot index
            _operators[0].committer, // Operator of slot 0, wrong proposing in slot 1
            currLookahead,
            nextLookahead,
            bytes("")
        );
    }

    function test_revertsIfPreconfingPeriodIsIncorrect(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is empty
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // Slot 1
        vm.warp(currLookahead[0].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        vm.expectRevert(ILookaheadStore.InvalidLookaheadTimestamp.selector);
        _checkProposer(
            0, // slot index (wrong, since we have moved passed slot 0)
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );
    }

    // Next epoch lookahead update test (passing)
    // -------------------------------------------

    function test_updateLookaheadDoesNotExpectLookaheadInSlot0(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is not posted
        ILookaheadStore.LookaheadSlot[] memory nextLookahead =
            new ILookaheadStore.LookaheadSlot[](0);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 0 proposes
        vm.warp(currLookahead[0].timestamp);
        _checkProposer(
            0, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("")
        );

        // Lookahead is still not set
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));
    }

    function test_lookaheadIsNotUpdatedWhenAlreadyPosted(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (already posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true // Post
        );

        // Prepare a new lookahead for next epoch
        uint256[] memory newNextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory newNextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            newNextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Next lookahead is the one originally posted
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead)
        );

        // When operator of slot 4 proposes with a new next lookahead
        vm.warp(currLookahead[1].timestamp);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            newNextLookahead,
            signature
        );

        // Next lookahead is still the original one
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead)
        );
    }

    function test_updateLookaheadInDedicatedSlot(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 4 proposes
        vm.warp(currLookahead[1].timestamp);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );

        // Lookahead is updated correctly
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead)
        );
    }

    function test_updateLookaheadInAdvancedSlot(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 4 proposes in advanced
        vm.warp(currLookahead[0].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );

        // Lookahead is updated correctly
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead)
        );
    }

    function test_updateLookaheadAndCrossEpochProposal(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 0 (next epoch) builds a commitment
        bytes memory signature = _signLookaheadCommitment(_operators[0], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // When operator of slot 0 (next epoch) proposes in advanced in slot 13
        vm.warp(currLookahead[3].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        _checkProposer(
            type(uint256).max, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            signature
        );

        // Lookahead is updated correctly
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead)
        );
    }

    // Next epoch lookahead update test (reverts)
    // -------------------------------------------

    function test_revertsWhenOperatorHasNotRegistered(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Manipulate registration of the second operator (in next lookahead) to be invalid
        urc.setOperatorData(
            _operators[1].registrationRoot,
            _operators[1].committer,
            _operators[1].collateralWei,
            _operators[1].numKeys,
            0, // Not registered
            _operators[1].unregisteredAt,
            _operators[1].slashedAt
        );

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasNotRegistered.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenOperatorHasUnregistered(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Manipulate unregisteredAt of the second operator to be before prev epoch start
        urc.setOperatorData(
            _operators[1].registrationRoot,
            _operators[1].committer,
            _operators[1].collateralWei,
            _operators[1].numKeys,
            _operators[1].registeredAt,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH - 1, // Unregistered too early
            _operators[1].slashedAt
        );

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasUnregistered.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenOperatorHasBeenSlashed(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Manipulate slashedAt of the second operator to be before prev epoch start
        urc.setOperatorData(
            _operators[1].registrationRoot,
            _operators[1].committer,
            _operators[1].collateralWei,
            _operators[1].numKeys,
            _operators[1].registeredAt,
            _operators[1].unregisteredAt,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH - 1 // Slashed too early
        );

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasBeenSlashed.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenOperatorHasInsufficientCollateral(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Set historical collateral at previous epoch start to below minimum
        urc.setHistoricalCollateral(
            _operators[1].registrationRoot,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH,
            lookaheadStore.getLookaheadStoreConfig().minCollateral - 1
        );

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasInsufficientCollateral.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenOperatorHasNotOptedIn(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Clear optedInAt to 0 (not opted in before previous epoch)
        urc.setSlasherCommitment(
            _operators[1].registrationRoot,
            _operators[1].slasher,
            0,
            _operators[1].optedOutAt,
            _operators[1].committer
        );

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenOperatorHasOptedOut(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        urc.setSlasherCommitment(
            _operators[1].registrationRoot,
            _operators[1].slasher,
            _operators[1].optedInAt,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH - 1, // Opted out too early
            _operators[1].committer
        );

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasOptedOut.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenOperatorHasBeenBlacklisted(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Blacklist the first operator before the start of the previous epoch (causes revert)
        vm.warp(EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH - 1);
        vm.prank(overseer);
        lookaheadStore.blacklistOperator(_operators[0].registrationRoot);
        vm.warp(EPOCH_START);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasBeenBlacklisted.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenOperatorWasUnblacklistedTooLate(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Blacklist, then unblacklist too late (at prev epoch start)
        uint256 prevEpochStart = EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH;
        vm.warp(lookaheadStore.getBlacklistConfig().blacklistDelay + 1);
        vm.prank(overseer);
        lookaheadStore.blacklistOperator(_operators[0].registrationRoot);
        vm.warp(prevEpochStart); // unblacklisted at start of prev epoch (too late)
        vm.prank(overseer);
        lookaheadStore.unblacklistOperator(_operators[0].registrationRoot);
        vm.warp(EPOCH_START);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.OperatorHasBeenBlacklisted.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenSlotTimestampIsNotIncrementing(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted) with invalid non-incrementing timestamps
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 0; // same as previous -> non-incrementing
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.SlotTimestampIsNotIncrementing.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenSlotTimestampIsDecreasing(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted) with decreasing timestamps
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 5;
        nextLookaheadSlotPositions[1] = 3; // less than previous -> decreasing
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.SlotTimestampIsNotIncrementing.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenInvalidLookaheadEpoch(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 33; // 1 slot beyond the epoch (32 slots per epoch)
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.InvalidLookaheadEpoch.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenInvalidValidatorLeafIndex(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Set invalid validatorLeafIndex for the second lookahead slot
        nextLookahead[1].validatorLeafIndex = _operators[1].numKeys + 1;

        // Operator of slot 4 builds a commitment for the next epoch lookahead
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.InvalidValidatorLeafIndex.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenCommitmentSignerMismatch(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Build commitment signed by a DIFFERENT operator than the proposer/slot committer
        bytes memory wrongSignature = _signLookaheadCommitment(_operators[2], nextLookahead);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.CommitmentSignerMismatch.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            wrongSignature
        );
    }

    function test_revertsWhenCommitterMismatch(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](2);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        // Corrupt committer for one of the next lookahead slots so it mismatches URC committer
        nextLookahead[1].committer = vm.addr(999);

        // Signature by the correct proposer operator
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        // When operator of slot 4 proposes in its window, updating next lookahead should revert
        vm.warp(currLookahead[1].timestamp);
        vm.expectRevert(ILookaheadStore.CommitterMismatch.selector);
        _checkProposer(
            1, // slot index
            _operators[1].committer,
            currLookahead,
            nextLookahead,
            signature
        );
    }

    function test_revertsWhenNextLookaheadEvidenceDataIsInvalid(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (already posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true // Post
        );

        // Prepare a new lookahead for next epoch
        uint256[] memory newNextLookaheadSlotPositions = new uint256[](1);
        newNextLookaheadSlotPositions[0] = 0;
        ILookaheadStore.LookaheadSlot[] memory newNextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            newNextLookaheadSlotPositions,
            false
        );

        // Operator of slot 0 from next lookahead builds a commitment
        bytes memory signature = _signLookaheadCommitment(_operators[1], nextLookahead);

        // Warp ahead of last operator in current lookahead
        vm.warp(currLookahead[3].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        // When first proposer from next epoch proposes with an invalid lookahead,
        // the transaction reverts
        vm.expectRevert(ILookaheadStore.InvalidLookahead.selector);
        _checkProposer(
            type(uint256).max, // slot index
            _operators[0].committer,
            currLookahead,
            newNextLookahead,
            signature
        );
    }

    function test_revertsWhenNextLookaheadIsPostedWithoutCommitment(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead has operators at slots 0, 4, 9, 12
        uint256[] memory currLookaheadSlotPositions = new uint256[](4);
        currLookaheadSlotPositions[0] = 1;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 9;
        currLookaheadSlotPositions[3] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 0;
        nextLookaheadSlotPositions[1] = 3;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        vm.warp(currLookahead[0].timestamp);
        // When first proposer from current epoch epoch proposes and tries to post lookahead
        // without a commitment, the transaction reverts (only the fallback can do this)
        vm.expectRevert(ILookaheadStore.ProposerIsNotFallbackPreconfer.selector);
        _checkProposer(
            0, // slot index
            _operators[0].committer,
            currLookahead,
            nextLookahead,
            bytes("") // No commitment
        );
    }
}
