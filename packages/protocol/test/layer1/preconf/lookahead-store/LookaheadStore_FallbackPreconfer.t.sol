// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LookaheadStoreBase.sol";

contract TestLookaheadStore_FallbackPreconfer is LookaheadStoreBase {
    // Fallback preconfer validation and lookahead posting tests (passing)
    // --------------------------------------------------------------------

    function test_sameEpochFallbackNoNextLookaheadRequiredInFirstSlot(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // No current lookahead posted (fallback preconfer path)
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            new ILookaheadStore.LookaheadSlot[](0);

        // No next lookahead provided
        ILookaheadStore.LookaheadSlot[] memory nextLookahead =
            new ILookaheadStore.LookaheadSlot[](0);

        // Fallback preconfer proposes
        uint48 submissionWindowEnd =
            _checkProposer(0, fallbackPreconfer, currLookahead, nextLookahead, bytes(""));

        // Correct `submissionWindowEnd` is returned (last slot of the epoch)
        assertEq(
            submissionWindowEnd,
            uint48(
                EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH
                    - LibPreconfConstants.SECONDS_IN_SLOT
            )
        );

        // Next epoch lookahead remains unset
        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));
    }

    function test_sameEpochFallbackPostsNextLookaheadWithoutSignature(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // No current lookahead posted (fallback preconfer path)
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            new ILookaheadStore.LookaheadSlot[](0);

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

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Lookahead is not set yet
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // Second slot of the epoch
        vm.warp(EPOCH_START + LibPreconfConstants.SECONDS_IN_SLOT);
        // When fallback preconfer proposes
        uint48 submissionWindowEnd =
            _checkProposer(0, fallbackPreconfer, currLookahead, nextLookahead, bytes(""));

        // Correct `submissionWindowEnd` is returned (last slot of the epoch)
        assertEq(
            submissionWindowEnd, uint48(nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT)
        );

        // Lookahead is updated
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead)
        );
    }

    function test_crossEpochFallbackPostsNextLookahead(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead
        uint256[] memory currLookaheadSlotPositions = new uint256[](2);
        currLookaheadSlotPositions[0] = 0;
        currLookaheadSlotPositions[1] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead is empty (not posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            false
        );

        uint256 nextEpochTimestamp = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;

        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        // One slot after the last operator's slot
        vm.warp(currLookahead[1].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);
        // When the fallback preconfer proposes
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, fallbackPreconfer, currLookahead, nextLookahead, bytes("")
        );

        // Correct `submissionWindowEnd` is returned (last slot of the epoch)
        assertEq(submissionWindowEnd, nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT);

        // Lookahead for the next epoch is updated
        assertEq(
            lookaheadStore.getLookaheadHash(nextEpochTimestamp),
            lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead)
        );
    }

    function test_sameEpochBlacklistedOperatorForcesFallbackInDedicatedSlot(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead with a single operator
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // Blacklist that operator
        vm.prank(overseer);
        lookaheadStore.blacklistOperator(_operators[0].registrationRoot);

        // The next lookahead
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // Warp to the blacklisted operator's slot timestamp
        vm.warp(currLookahead[0].timestamp);
        // When fallback proposer proposes
        uint48 submissionWindowEnd =
            _checkProposer(0, fallbackPreconfer, currLookahead, nextLookahead, bytes(""));

        // Correct `submissionWindowEnd` is returned (the blacklisted operator's slot timestamp)
        assertEq(submissionWindowEnd, uint48(currLookahead[0].timestamp));
    }

    function test_sameEpochBlacklistedOperatorForcesFallbackInAdvancedSlot(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead with a single operator
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // Blacklist that operator
        vm.prank(overseer);
        lookaheadStore.blacklistOperator(_operators[0].registrationRoot);

        // The next lookahead
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // We are at EPOCH_START
        // When fallback proposer proposes
        uint48 submissionWindowEnd =
            _checkProposer(0, fallbackPreconfer, currLookahead, nextLookahead, bytes(""));

        // Correct `submissionWindowEnd` is returned (the blacklisted operator's slot timestamp)
        assertEq(submissionWindowEnd, uint48(currLookahead[0].timestamp));
    }

    function test_crossEpochBlacklistedOperatorForcesFallback(SetupOperator[] memory _operators)
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // Empty next lookahead with a single operator
        uint256[] memory nextLookaheadSlotPositions = new uint256[](1);
        nextLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // Blacklist that operator
        vm.prank(overseer);
        lookaheadStore.blacklistOperator(_operators[0].registrationRoot);

        // We wrap ahead of the last preconfer in current epoch
        vm.warp(currLookahead[0].timestamp + 4 * LibPreconfConstants.SECONDS_IN_SLOT);
        // When fallback proposer proposes
        uint48 submissionWindowEnd = _checkProposer(
            type(uint256).max, fallbackPreconfer, currLookahead, nextLookahead, bytes("")
        );

        // Correct `submissionWindowEnd` is returned (end of current epoch)
        assertEq(
            submissionWindowEnd,
            uint48(
                EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH
                    - LibPreconfConstants.SECONDS_IN_SLOT
            )
        );
    }

    // Fallback preconfer validation test (reverts)
    // ---------------------------------------------

    function test_sameEpochProposalRevertsWhenProposerIsNotFallback(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead is empty
        uint256[] memory currLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, _operators, currLookaheadSlotPositions, true);

        // The next lookahead
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH,
            _operators,
            nextLookaheadSlotPositions,
            true
        );

        // We are at EPOCH_START
        // When a non-fallback preconfer proposes, the transaction reverts
        vm.expectRevert(ILookaheadStore.ProposerIsNotPreconfer.selector);
        _checkProposer(0, _operators[0].committer, currLookahead, nextLookahead, bytes(""));
    }

    function test_crossEpochProposalRevertsWhenProposerIsNotFallback(
        SetupOperator[] memory _operators
    )
        external
        useMainnet
        setupOperators(_operators)
    {
        // The current lookahead
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
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

        // We wrap ahead of the last preconfer in current epoch
        vm.warp(currLookahead[0].timestamp + 4 * LibPreconfConstants.SECONDS_IN_SLOT);
        // When a non-fallback preconfer proposes, the transaction reverts
        vm.expectRevert(ILookaheadStore.ProposerIsNotPreconfer.selector);
        _checkProposer(
            type(uint256).max, _operators[0].committer, currLookahead, nextLookahead, bytes("")
        );
    }
}
