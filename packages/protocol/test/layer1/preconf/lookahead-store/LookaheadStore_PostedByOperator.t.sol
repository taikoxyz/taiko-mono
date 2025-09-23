// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LookaheadStoreBase.sol";

contract TestLookaheadStore_PostedByOperator is LookaheadStoreBase {
/*
    // Lookahead posting accepted
    // -------------------------------------------------------------------

    function test_acceptsValidLookaheadCommitment(
        SetupOperator memory _lookaheadPostingOperator,
        SetupOperator[] memory _lookaheadOperators,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        external
        useMainnet
setupURCAndPrepareInputsFuzz(_lookaheadPostingOperator, _lookaheadOperators, _lookaheadSlots)
    {
        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Push the next epoch's lookahead to the store
        bytes26 lookaheadHash = _updateLookahead(signedCommitment);

        // The next epoch's lookahead hash is correctly added to the lookahead store
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadHash
        );
    }

    // Lookahead posting reverts (Issues with the poster)
    // -------------------------------------------------------------------

    function test_revertsWhenCommitmentIsNotSignedByThePostersCommitter() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate the committer for the lookahead poster
        urc.setSlasherCommitment(
            _lookaheadPostingOperator.registrationRoot,
            lookaheadSlasher,
            _lookaheadPostingOperator.optedInAt,
            _lookaheadPostingOperator.optedOutAt,
            address(0) // Wrong committer
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.CommitmentSignerMismatch.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasNotRegistered_Case1() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate the registration of the poster
        urc.setOperatorData(
            _lookaheadPostingOperator.registrationRoot,
            _lookaheadPostingOperator.committer,
            _lookaheadPostingOperator.collateralWei,
            _lookaheadPostingOperator.numKeys,
            0, // Not registered
            _lookaheadPostingOperator.unregisteredAt,
            _lookaheadPostingOperator.slashedAt
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotRegistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasNotRegistered_Case2() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate the registration of the poster
        urc.setOperatorData(
            _lookaheadPostingOperator.registrationRoot,
            _lookaheadPostingOperator.committer,
            _lookaheadPostingOperator.collateralWei,
            _lookaheadPostingOperator.numKeys,
            block.timestamp, // Registered in the posting slot itself
            _lookaheadPostingOperator.unregisteredAt,
            _lookaheadPostingOperator.slashedAt
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotRegistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasUnregistered_Case1() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate the registration of the poster
        urc.setOperatorData(
            _lookaheadPostingOperator.registrationRoot,
            _lookaheadPostingOperator.committer,
            _lookaheadPostingOperator.collateralWei,
            _lookaheadPostingOperator.numKeys,
            _lookaheadPostingOperator.registeredAt,
            EPOCH_START - 1, // Unregistered before the epoch
            _lookaheadPostingOperator.slashedAt
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasUnregistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasUnregistered_Case2() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate the registration of the poster
        urc.setOperatorData(
            _lookaheadPostingOperator.registrationRoot,
            _lookaheadPostingOperator.committer,
            _lookaheadPostingOperator.collateralWei,
            _lookaheadPostingOperator.numKeys,
            _lookaheadPostingOperator.registeredAt,
            block.timestamp, // Unregistered in the posting slot itself
            _lookaheadPostingOperator.slashedAt
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasUnregistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasBeenSlashed_Case1() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate slashing status of the poster
        urc.setOperatorData(
            _lookaheadPostingOperator.registrationRoot,
            _lookaheadPostingOperator.committer,
            _lookaheadPostingOperator.collateralWei,
            _lookaheadPostingOperator.numKeys,
            _lookaheadPostingOperator.registeredAt,
            _lookaheadPostingOperator.unregisteredAt,
            EPOCH_START - 1 // Slashed before the epoch
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasBeenSlashed.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasBeenSlashed_Case2() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate slashing status of the poster
        urc.setOperatorData(
            _lookaheadPostingOperator.registrationRoot,
            _lookaheadPostingOperator.committer,
            _lookaheadPostingOperator.collateralWei,
            _lookaheadPostingOperator.numKeys,
            _lookaheadPostingOperator.registeredAt,
            _lookaheadPostingOperator.unregisteredAt,
            block.timestamp // Slashed in the posting slot itself
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasBeenSlashed.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasInsufficientCollateral() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Manipulate the collateral of the poster
        urc.setOperatorData(
            _lookaheadPostingOperator.registrationRoot,
            _lookaheadPostingOperator.committer,
            lookaheadStore.getLookaheadStoreConfig().minCollateralForPosting - 1, // Insufficient
                // collateral
            _lookaheadPostingOperator.numKeys,
            _lookaheadPostingOperator.registeredAt,
            _lookaheadPostingOperator.unregisteredAt,
            _lookaheadPostingOperator.slashedAt
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasInsufficientCollateral.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasNotOptedIn_Case1() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Manipulate the slasher commitment of the poster
        urc.setSlasherCommitment(
            _lookaheadPostingOperator.registrationRoot,
            lookaheadSlasher,
            0, // Not opted in
            _lookaheadPostingOperator.optedOutAt,
            _lookaheadPostingOperator.committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasNotOptedIn_Case2() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Manipulate the slasher commitment of the poster
        urc.setSlasherCommitment(
            _lookaheadPostingOperator.registrationRoot,
            lookaheadSlasher,
            block.timestamp, // Opted in in the posting slot itself
            _lookaheadPostingOperator.optedOutAt,
            _lookaheadPostingOperator.committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasOptedOut_Case1() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Manipulate the slasher commitment of the poster
        urc.setSlasherCommitment(
            _lookaheadPostingOperator.registrationRoot,
            lookaheadSlasher,
            _lookaheadPostingOperator.optedInAt,
            EPOCH_START - 1, // Opted out before the epoch
            _lookaheadPostingOperator.committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenThePosterHasOptedOut_Case2() external useMainnet {
        (
            SetupOperator memory _lookaheadPostingOperator,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Manipulate the slasher commitment of the poster
        urc.setSlasherCommitment(
            _lookaheadPostingOperator.registrationRoot,
            lookaheadSlasher,
            _lookaheadPostingOperator.optedInAt,
            block.timestamp, // Opted out in the posting slot itself
            _lookaheadPostingOperator.committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    // Lookahead posting reverts (Invalid inputs)
    // -------------------------------------------------------------------

    function test_revertsWhenLookaheadIsAlreadyPostedForNextEpoch() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Push the next epoch's lookahead to the store
        _updateLookahead(signedCommitment);

        // Attempt to post the lookahead for the next epoch again reverts
        vm.expectRevert(ILookaheadStore.LookaheadNotRequired.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenSlotTimestampIsNotIncrementing_Case1() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Set the first slot timestamp to be in the current epoch
        _lookaheadSlots[0].timestamp = EPOCH_START;

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.SlotTimestampIsNotIncrementing.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenSlotTimestampIsNotIncrementing_Case2() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Set the second slot timestamp to be equal to the first slot timestamp
        _lookaheadSlots[1].timestamp =
            _lookaheadSlots[0].timestamp - LibPreconfConstants.SECONDS_IN_SLOT;

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.SlotTimestampIsNotIncrementing.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenSlotTimestampIsNotValid() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Set the second slot timestamp to be some invalid value (not a multiple of the slot
        // duration)s
        _lookaheadSlots[1].timestamp += 1;

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.InvalidSlotTimestamp.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenValidatorLeafIndexIsInvalid() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Set the second slot validator leaf index to be invalid
        _lookaheadSlots[1].validatorLeafIndex = _lookaheadOperators[1].numKeys + 1;

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.InvalidValidatorLeafIndex.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenSlotTimestampGoesBeyondNextEpoch() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Set the second slot timestamp to overshoot the next epoch
        _lookaheadSlots[1].timestamp = EPOCH_START + 2 * LibPreconfConstants.SECONDS_IN_EPOCH;

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.InvalidLookaheadEpoch.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenCommitterDoesNotMatch() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Set the second slot committer to be invalid
        _lookaheadSlots[1].committer = address(0);

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.CommitterMismatch.selector);
        _updateLookahead(signedCommitment);
    }

    // Lookahead posting reverts (Issues with the operators)
    // -------------------------------------------------------------------

    function test_revertsWhenTheOperatorHasNotRegistered_Case1() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the registration of the second operator
        urc.setOperatorData(
            _lookaheadOperators[1].registrationRoot,
            _lookaheadOperators[1].committer,
            _lookaheadOperators[1].collateralWei,
            _lookaheadOperators[1].numKeys,
            0, // Not registered
            _lookaheadOperators[1].unregisteredAt,
            _lookaheadOperators[1].slashedAt
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotRegistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasNotRegistered_Case2() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the registration of the second operator
        urc.setOperatorData(
            _lookaheadOperators[1].registrationRoot,
            _lookaheadOperators[1].committer,
            _lookaheadOperators[1].collateralWei,
            _lookaheadOperators[1].numKeys,
            EPOCH_START, // Registered when epoch started
            _lookaheadOperators[1].unregisteredAt,
            _lookaheadOperators[1].slashedAt
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotRegistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasNotRegistered_Case3() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the registration of the second operator
        urc.setOperatorData(
            _lookaheadOperators[1].registrationRoot,
            _lookaheadOperators[1].committer,
            _lookaheadOperators[1].collateralWei,
            _lookaheadOperators[1].numKeys,
            EPOCH_START + 1, // Registered after the epoch started
            _lookaheadOperators[1].unregisteredAt,
            _lookaheadOperators[1].slashedAt
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotRegistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasUnregistered() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the registration of the second operator
        urc.setOperatorData(
            _lookaheadOperators[1].registrationRoot,
            _lookaheadOperators[1].committer,
            _lookaheadOperators[1].collateralWei,
            _lookaheadOperators[1].numKeys,
            _lookaheadOperators[1].registeredAt,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_SLOT, // Unregistered before the epoch
            _lookaheadOperators[1].slashedAt
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasUnregistered.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasBeenSlashed() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the registration of the second operator
        urc.setOperatorData(
            _lookaheadOperators[1].registrationRoot,
            _lookaheadOperators[1].committer,
            _lookaheadOperators[1].collateralWei,
            _lookaheadOperators[1].numKeys,
            _lookaheadOperators[1].registeredAt,
            _lookaheadOperators[1].unregisteredAt,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_SLOT // Slashed before the epoch
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasBeenSlashed.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasInsufficientCollateral() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the collateral of the second operator at the beginning of the current epoch
        urc.setHistoricalCollateral(
            _lookaheadOperators[1].registrationRoot,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_SLOT,
            lookaheadStore.getLookaheadStoreConfig().minCollateralForPreconfing - 1 // Insufficient
                // collateral
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasInsufficientCollateral.selector);
        _updateLookahead(signedCommitment);

        // Increasing collateral in current epoch does not help
        urc.setHistoricalCollateral(
            _lookaheadOperators[1].registrationRoot,
            EPOCH_START + 1,
            lookaheadStore.getLookaheadStoreConfig().minCollateralForPreconfing
        );

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasInsufficientCollateral.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasNotOptedIn_Case1() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the slasher commitment of the second operator
        urc.setSlasherCommitment(
            _lookaheadOperators[1].registrationRoot,
            preconfSlasher,
            0, // Not opted in
            _lookaheadOperators[1].optedOutAt,
            _lookaheadOperators[1].committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasNotOptedIn_Case2() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the slasher commitment of the second operator
        urc.setSlasherCommitment(
            _lookaheadOperators[1].registrationRoot,
            preconfSlasher,
            EPOCH_START, // Opted in at the start of the epoch
            _lookaheadOperators[1].optedOutAt,
            _lookaheadOperators[1].committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasNotOptedIn_Case3() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the slasher commitment of the second operator
        urc.setSlasherCommitment(
            _lookaheadOperators[1].registrationRoot,
            preconfSlasher,
            EPOCH_START + 1, // Opted in after the epoch started
            _lookaheadOperators[1].optedOutAt,
            _lookaheadOperators[1].committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasOptedOut() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Manipulate the slasher commitment of the second operator
        urc.setSlasherCommitment(
            _lookaheadOperators[1].registrationRoot,
            preconfSlasher,
            _lookaheadOperators[1].optedInAt,
            EPOCH_START - LibPreconfConstants.SECONDS_IN_SLOT, // Opted out before the epoch
            _lookaheadOperators[1].committer
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasNotOptedIn.selector);
        _updateLookahead(signedCommitment);
    }

    function test_revertsWhenTheOperatorHasBeenBlacklisted() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Blacklist the second operator before the current epoch
        _setOperatorBlacklistStatus(
            _lookaheadOperators[1].registrationRoot,
            uint48(EPOCH_START - LibPreconfConstants.SECONDS_IN_SLOT), // Blacklisted before epoch
            0 // Never unblacklisted
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasBeenBlacklisted.selector);
        _updateLookahead(signedCommitment);
    }

    function test_acceptsWhenTheOperatorWasBlacklistedButUnblacklistedInTime()
        external
        useMainnet
    {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Blacklist and then unblacklist the second operator before the current epoch
        _setOperatorBlacklistStatus(
            _lookaheadOperators[1].registrationRoot,
            uint48(EPOCH_START - 3 * LibPreconfConstants.SECONDS_IN_SLOT), // Blacklisted early
            uint48(EPOCH_START - 2 * LibPreconfConstants.SECONDS_IN_SLOT) // Unblacklisted before
                // epoch
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Should succeed because operator was unblacklisted in time
        bytes26 lookaheadHash = _updateLookahead(signedCommitment);

        // The next epoch's lookahead hash is correctly added to the lookahead store
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadHash
        );
    }

    function test_revertsWhenTheOperatorWasUnblacklistedTooLate() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(2);

        // Blacklist and then unblacklist the second operator too late
        _setOperatorBlacklistStatus(
            _lookaheadOperators[1].registrationRoot,
            uint48(EPOCH_START - 3 * LibPreconfConstants.SECONDS_IN_SLOT), // Blacklisted early
            uint48(EPOCH_START) // Unblacklisted when epoch started (too late)
        );

        // Build a signed commitment on the lookahead slots for next epoch
        ISlasher.SignedCommitment memory signedCommitment =
            _buildLookaheadCommitment(_lookaheadSlots, _lookaheadOperators.length);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.OperatorHasBeenBlacklisted.selector);
        _updateLookahead(signedCommitment);
    }
    */
}
