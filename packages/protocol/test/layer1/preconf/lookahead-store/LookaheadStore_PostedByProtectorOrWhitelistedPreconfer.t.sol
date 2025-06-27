// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LookaheadStoreBase.sol";

contract TestLookaheadStore_PostedByProtectorOrWhitelistedPreconfer is LookaheadStoreBase {
    // Lookahead posting accepted
    // ------------------------------------------------------------------------------------------------

    function test_acceptsValidLookaheadByWhitelist(
        SetupOperator memory _lookaheadPostingOperator,
        SetupOperator[] memory _lookaheadOperators,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        external
        useMainnet
        transactBy(preconfRouter)
        setupURCAndPrepareInputsFuzz(_lookaheadPostingOperator, _lookaheadOperators, _lookaheadSlots)
    {
        // Push the next epoch's lookahead to the store
        bytes26 lookaheadHash = _updateLookahead(_lookaheadSlots, _lookaheadOperators.length);

        // The next epoch's lookahead hash is correctly added to the lookahead store
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadHash
        );
    }

    function test_acceptsValidLookaheadByProtector(
        SetupOperator memory _lookaheadPostingOperator,
        SetupOperator[] memory _lookaheadOperators,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        external
        useMainnet
        transactBy(protector)
        setupURCAndPrepareInputsFuzz(_lookaheadPostingOperator, _lookaheadOperators, _lookaheadSlots)
    {
        // Push the next epoch's lookahead to the store
        bytes26 lookaheadHash = _updateLookahead(_lookaheadSlots, _lookaheadOperators.length);

        // The next epoch's lookahead hash is correctly added to the lookahead store
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadHash
        );
    }

    function test_overridesExistingLookaheadWhenValidLookaheadIsPostedByProtector(
        SetupOperator memory _lookaheadPostingOperator,
        SetupOperator[] memory _lookaheadOperators,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots,
        ILookaheadStore.LookaheadSlot[] memory _updatedLookaheadSlots
    )
        external
        useMainnet
        transactBy(protector)
        setupURCAndPrepareInputsFuzz(_lookaheadPostingOperator, _lookaheadOperators, _lookaheadSlots)
    {
        // Push the next epoch's lookahead to the store
        bytes26 lookaheadHash = _updateLookahead(_lookaheadSlots, _lookaheadOperators.length);

        // The next epoch's lookahead hash is correctly added to the lookahead store
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadHash
        );

        // Prepare updated lookahead slots
        _validateLookaheadSlots(_updatedLookaheadSlots, _lookaheadOperators);

        // Ensure that the updated lookahead slots are different from the original lookahead slots
        bytes32 originalLookaheadHash =
            keccak256(abi.encode(_trimLookaheadSlots(_lookaheadSlots, _lookaheadOperators.length)));
        bytes32 updatedLookaheadHash = keccak256(
            abi.encode(_trimLookaheadSlots(_updatedLookaheadSlots, _lookaheadOperators.length))
        );
        vm.assume(originalLookaheadHash != updatedLookaheadHash);

        // Push the updated lookahead to the store
        bytes26 _updatedLookaheadHash =
            _updateLookahead(_updatedLookaheadSlots, _lookaheadOperators.length);

        // The updated lookahead hash is correctly added to the lookahead store
        assertNotEq(lookaheadHash, _updatedLookaheadHash);
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            _updatedLookaheadHash
        );
    }

    // Lookahead posting reverts
    // ------------------------------------------------------------------------------------------------

    function test_revertsWhenTheSenderIsNotTheProtectorOrPreconfRouter() external useMainnet {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Attempt to post the lookahead for the next epoch reverts
        vm.expectRevert(ILookaheadStore.NotProtectorOrPreconfRouter.selector);
        _updateLookahead(_lookaheadSlots, _lookaheadOperators.length);
    }

    function test_revertsWhenWhitelistedPreconferTriesToOverrideExistingLookahead()
        external
        useMainnet
        transactBy(preconfRouter)
    {
        (
            ,
            SetupOperator[] memory _lookaheadOperators,
            ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
        ) = _setupURCAndPrepareInputs(1);

        // Push the next epoch's lookahead to the store
        bytes26 lookaheadHash = _updateLookahead(_lookaheadSlots, _lookaheadOperators.length);

        // The next epoch's lookahead hash is correctly added to the lookahead store
        assertEq(
            lookaheadStore.getLookaheadHash(EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            lookaheadHash
        );

        // Attempt to post the lookahead for the next epoch again reverts
        vm.expectRevert(ILookaheadStore.LookaheadNotRequired.selector);
        _updateLookahead(_lookaheadSlots, _lookaheadOperators.length);
    }
}
