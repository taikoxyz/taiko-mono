// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PreconfRouter2TestBase.sol";

contract PreconfRouter2Test is PreconfRouter2TestBase {
    // Proposals by URC Operators
    // ---------------------------------------------------------------

    // Current Epoch Lookahead Structure
    // ----------------------------------
    //
    // Slot Id:   [. . .  6 . . . 11 . . . 16 . . . 21 . . . 26 . . . 31]   * not to scale *
    // Lookahead: [x x x P1 x x x P2 x x x P3 x x x P4 x x x P5 x x x P6]
    //
    // Our preconfer will propose w.r.t positions P1 to P5 in various tests

    // Next Epoch Lookahead Structure
    // ----------------------------------
    //
    // Slot Id:   [. . . . . 6 . . . . . . . . . . . . . . . . . . . 31]   * not to scale *
    // Lookahead: [x x x x x P x x x x x x x x x x xx x x x x x x x x x]
    //
    // Our preconfer will propose w.r.t position P in various tests

    function test_proposeInAdvancedWhenSlotIsInSameEpoch_case1(uint256 _slotIndex)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Wrap to 1 slot before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_proposeInAdvancedWhenSlotIsInSameEpoch_case2(uint256 _slotIndex)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Wrap to 2 slots before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - 2 * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_proposeInSlotItself(uint256 _slotIndex)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Wrap to the lookahead slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_proposeInAdvancedWhenSlotIsInNextEpoch(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    // Proposals by whitelisted or fallback operators
    // ---------------------------------------------------------------

    function test_whitelistPreconferProposesWhenCurrentLookaheadIsEmpty_case1(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupEmptyCurrentLookahead
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        _slotOffset = bound(_slotOffset, 0, 30);

        // Wrap to an arbitrary proposal slot
        vm.warp(EPOCH_START + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT);

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesWhenCurrentLookaheadIsEmpty_case2(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        _slotOffset = bound(_slotOffset, 0, 30);

        // Wrap to an arbitrary proposal slot
        vm.warp(EPOCH_START + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT);

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesWhenCurrentLookaheadIsEmpty_case1(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupEmptyCurrentLookahead
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        _slotOffset = bound(_slotOffset, 0, 30);

        // Wrap to an arbitrary proposal slot
        vm.warp(EPOCH_START + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT);

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesWhenCurrentLookaheadIsEmpty_case2(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        _slotOffset = bound(_slotOffset, 0, 30);

        // Wrap to an arbitrary proposal slot
        vm.warp(EPOCH_START + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT);

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesWhenNextLookaheadIsEmpty(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(4)
        setupEmptyNextLookahead
        transactBy(whitelistOperator)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesWhenNextLookaheadIsEmpty(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(4)
        setupEmptyNextLookahead
        transactBy(fallbackPreconfer)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferHasUnregistered_case1(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Wrap to one slot before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferHasUnregistered_case1(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Wrap to one slot before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferHasUnregistered_case2(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Wrap to two slots before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - 2 * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferHasUnregistered_case2(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Wrap to two slots before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - 2 * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInSlotItselfWhenPreconferHasUnregistered(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInSlotItselfWhenPreconferHasUnregistered(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferFromNextEpochHasUnregistered(
        uint256 _slotOffset
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferFromNextEpochHasUnregistered(
        uint256 _slotOffset
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferHasBeenSlashed_case1(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Wrap to one slot before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferHasBeenSlashed_case1(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Wrap to one slot before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferHasBeenSlashed_case2(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Wrap to two slots before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - 2 * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferHasBeenSlashed_case2(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Wrap to two slots before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - 2 * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInSlotItselfWhenPreconferHasBeenSlashed(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInSlotItselfWhenPreconferHasBeenSlashed(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferFromNextEpochHasBeenSlashed(
        uint256 _slotOffset
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferFromNextEpochHasBeenSlashed(
        uint256 _slotOffset
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Setup a preconfing operator that is slashed
        _setupOperator(false, true, false);

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferHasOptedOut_case1(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Wrap to one slot before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferHasOptedOut_case1(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Wrap to one slot before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferHasOptedOut_case2(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Wrap to two slots before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - 2 * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferHasOptedOut_case2(
        uint256 _slotIndex
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Wrap to two slots before the preconfer's slot to make it an advanced proposal
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                - 2 * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInSlotItselfWhenPreconferHasOptedOut(uint256 _slotIndex)
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInSlotItselfWhenPreconferHasOptedOut(uint256 _slotIndex)
        external
        useMainnet
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_whitelistPreconferProposesInAdvancedWhenPreconferFromNextEpochHasOptedOut(
        uint256 _slotOffset
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        transactBy(whitelistOperator)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    function test_fallbackPreconferProposesInAdvancedWhenPreconferFromNextEpochHasOptedOut(
        uint256 _slotOffset
    )
        external
        useMainnet
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        transactBy(fallbackPreconfer)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Setup a preconfing operator that is opted out
        _setupOperator(false, false, true);

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // Batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    // Proposals with pushing of lookahead
    // ---------------------------------------------------------------

    /// @dev The test sets up the lookahead for the next epoch to cache a valid set of slots, but
    /// then immediately clears the next lookahead from the store, allowing the router to push
    // it.
    function test_proposeAndPushLookahead(uint256 _slotIndex)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        clearNextLookahead
        transactBy(committer)
    {
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp);

        // There is no lookahead for the next epoch yet
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH), 0
        );

        // Propose a batch
        _proposeBatch();

        // The lookahead is pushed
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadStore.calculateLookaheadHash(
                EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, cachedNextLookaheadSlots
            )
        );
    }

    function test_whitelistPreconferProposesAndPushesLookahead(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupEmptyCurrentLookahead
        setupNextLookaheadSlots
        clearNextLookahead
        transactBy(whitelistOperator)
    {
        _slotOffset = bound(_slotOffset, 0, 30);

        // Wrap to an arbitrary slot in current epoch
        vm.warp(EPOCH_START + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT);

        // There is no lookahead for the next epoch yet
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH), 0
        );

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        _proposeBatch();

        // The lookahead is pushed
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadStore.calculateLookaheadHash(
                EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, cachedNextLookaheadSlots
            )
        );
    }

    function test_fallbackPreconferProposesAndPushesLookahead(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupEmptyCurrentLookahead
        setupNextLookaheadSlots
        clearNextLookahead
        transactBy(fallbackPreconfer)
    {
        _slotOffset = bound(_slotOffset, 0, 30);

        // Wrap to an arbitrary slot in current epoch
        vm.warp(EPOCH_START + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT);

        // There is no lookahead for the next epoch yet
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH), 0
        );

        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        _proposeBatch();

        // The lookahead is pushed
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadStore.calculateLookaheadHash(
                EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, cachedNextLookaheadSlots
            )
        );
    }

    function test_pushLookaheadAndUseItToPropose(uint256 _slotOffset)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(4)
        setupNextLookaheadSlots
        clearNextLookahead
        transactBy(committer)
    {
        _slotOffset = bound(_slotOffset, 1, 5);

        // Wrap to an arbitrary slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + _slotOffset * LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Direct the router to use the next lookahead
        cachedSlotIndex = type(uint256).max;

        // Propose a batch
        (, ITaikoInbox.BatchMetadata memory meta) = _proposeBatch();

        // The lookahead is pushed
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadStore.calculateLookaheadHash(
                EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, cachedNextLookaheadSlots
            )
        );
        // The batch is proposed successfully
        assertTrue(meta.infoHash != bytes32(0));
    }

    // Revert cases
    // ---------------------------------------------------------------

    function test_revertProvidedSlotIndexIsOutOfBounds()
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        // Set the slot index to greater than the number of slots in the current epoch
        cachedSlotIndex = cachedCurrentLookaheadSlots.length;

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.InvalidSlotIndex.selector);
        _proposeBatch();
    }

    function test_revertWhenProvidedCurrentLookaheadIsInvalid_case1()
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        // Mess up the current lookahead data
        cachedCurrentLookaheadSlots[0].slotTimestamp += 1;

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.InvalidLookahead.selector);
        _proposeBatch();
    }

    function test_revertWhenProvidedCurrentLookaheadIsInvalid_case2()
        external
        useMainnet
        setupValidPreconfOperator
        transactBy(committer)
    {
        // Wrap to an arbitrary slot in current epoch
        vm.warp(EPOCH_START + LibPreconfConstants.SECONDS_IN_SLOT);

        // Make the current lookahead non-empty
        cachedCurrentLookaheadSlots.push(
            ILookaheadStore.LookaheadSlot({
                slotTimestamp: 0,
                registrationRoot: bytes32(0),
                validatorLeafIndex: 0,
                committer: address(0)
            })
        );

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.InvalidLookahead.selector);
        _proposeBatch();
    }

    function test_revertWhenProvidedNextLookaheadIsInvalid()
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(4)
        setupEmptyNextLookahead
        transactBy(committer)
    {
        // Wrap to a slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + LibPreconfConstants.SECONDS_IN_SLOT
        );

        // Make the next lookahead non-empty
        cachedNextLookaheadSlots.push(
            ILookaheadStore.LookaheadSlot({
                slotTimestamp: 0,
                registrationRoot: bytes32(0),
                validatorLeafIndex: 0,
                committer: address(0)
            })
        );

        cachedSlotIndex = type(uint256).max;

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.InvalidLookahead.selector);
        _proposeBatch();
    }

    function test_revertWhenPreconfingPeriodIsInvalid_case1(uint256 _slotIndex)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        vm.assume(cachedSlotIndex != 0);

        // Wrap to a last preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex - 1].slotTimestamp);

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.InvalidLookaheadTimestamp.selector);
        _proposeBatch();
    }

    function test_revertWhenPreconfingPeriodIsInvalid_case2(uint256 _slotIndex)
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(_slotIndex)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        vm.assume(cachedSlotIndex < 5);

        // Wrap ahead of the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp + 1);

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.InvalidLookaheadTimestamp.selector);
        _proposeBatch();
    }

    function test_revertsWhenCurrentLookaheadIsEmptyAndSenderIsNotAWhitelistedOperator()
        external
        useMainnet
        setupValidPreconfOperator
        setupEmptyCurrentLookahead
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Wrap to an arbitrary slot in current epoch
        vm.warp(EPOCH_START + LibPreconfConstants.SECONDS_IN_SLOT);

        cachedSlotIndex = type(uint256).max;

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.NotWhitelistedOrFallbackPreconfer.selector);
        _proposeBatch();
    }

    function test_revertsWhenNextLookaheadIsEmptyAndSenderIsNotAWhitelistedOperator()
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(4)
        setupEmptyNextLookahead
        transactBy(committer)
    {
        // Wrap to a slot after the last preconfer's slot in current epoch
        vm.warp(
            cachedCurrentLookaheadSlots[cachedSlotIndex].slotTimestamp
                + LibPreconfConstants.SECONDS_IN_SLOT
        );

        cachedSlotIndex = type(uint256).max;

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.NotWhitelistedOrFallbackPreconfer.selector);
        _proposeBatch();
    }

    function test_revertsWhenNextLookaheadCommitmentSignatureIsEmptyAndSenderIsNotAWhitelistedOperator(
    )
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
        clearNextLookahead
        transactBy(committer)
    {
        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        // Mess up the committer so that helpers do not auto resolve to using
        // a non-empty signature when sender is the committer
        committer = address(0);

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.NotWhitelistedOrFallbackPreconfer.selector);
        _proposeBatch();
    }

    function test_revertsWhenPreconferHasUnregisteredAndSenderIsNotAWhitelistedOperator()
        external
        useMainnet
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Setup a preconfing operator that is unregistered
        _setupOperator(true, false, false);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.NotWhitelistedOrFallbackPreconfer.selector);
        _proposeBatch();
    }

    function test_revertsWhenPreconferHasBeenSlashedAndSenderIsNotAWhitelistedOperator()
        external
        useMainnet
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Setup a preconfing operator that has been slashed
        _setupOperator(false, true, false);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.NotWhitelistedOrFallbackPreconfer.selector);
        _proposeBatch();
    }

    function test_revertsWhenPreconferHasOptedOutAndSenderIsNotAWhitelistedOperator()
        external
        useMainnet
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Setup a preconfing operator that has opted out
        _setupOperator(false, false, true);

        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.NotWhitelistedOrFallbackPreconfer.selector);
        _proposeBatch();
    }

    function test_revertsWhenSenderIsNotThePreconfer()
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
    {
        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.ProposerIsNotPreconfer.selector);
        _proposeBatch();
    }

    function test_revertsWhenSenderDoesNotSetItselfAsTheProposer()
        external
        useMainnet
        setupValidPreconfOperator
        setupCurrentLookaheadSlots(0)
        setupNextLookaheadSlots
        transactBy(committer)
    {
        // Wrap to the preconfer's slot
        vm.warp(cachedCurrentLookaheadSlots[0].slotTimestamp);

        (
            ILookaheadStore.LookaheadSlot[] memory currLookahead,
            ILookaheadStore.LookaheadSlot[] memory nextLookahead
        ) = _loadLookaheads();

        // The proposer is not set
        ITaikoInbox.BatchParams memory batchParams;
        bytes memory params = abi.encode(batchParams);
        bytes memory lookaheadData =
            abi.encode(cachedSlotIndex, registrationRoot, currLookahead, nextLookahead, bytes(""));

        // Proposal of a batch reverts
        vm.expectRevert(PreconfRouter2.ProposerIsNotPreconfer.selector);
        preconfRouter.v4ProposeBatch(params, "", lookaheadData);
    }
}
