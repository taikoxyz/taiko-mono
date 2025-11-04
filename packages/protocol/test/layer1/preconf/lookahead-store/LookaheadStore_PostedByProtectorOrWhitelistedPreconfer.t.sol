// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LookaheadStoreBase.sol";

contract TestLookaheadStore_PostedByProtectorOrWhitelistedPreconfer is LookaheadStoreBase {
    /**
     * // Lookahead posting accepted
     *     //
     * ------------------------------------------------------------------------------------------------
     *
     *     function test_acceptsValidLookaheadByWhitelist(
     *         SetupOperator memory _lookaheadPostingOperator,
     *         SetupOperator[] memory _lookaheadOperators,
     *         ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
     *     )
     *         external
     *         useMainnet
     *         transactBy(preconfRouter)
     *         setupURCAndPrepareInputsFuzz(_lookaheadPostingOperator, _lookaheadOperators,
     * _lookaheadSlots)
     *     {
     *         // Push the next epoch's lookahead to the store
     *         bytes26 lookaheadHash = _updateLookahead(_lookaheadSlots,
     * _lookaheadOperators.length);
     *
     *         // The next epoch's lookahead hash is correctly added to the lookahead store
     *         assertEq(
     *             lookaheadStore.getLookaheadHash(EPOCH_START +
     * LibPreconfConstants.SECONDS_IN_EPOCH),
     *             lookaheadHash
     *         );
     *     }
     *
     *     // Lookahead posting reverts
     *     //
     * ------------------------------------------------------------------------------------------------
     *
     *     function test_revertsWhenWhitelistedPreconferTriesToOverrideExistingLookahead()
     *         external
     *         useMainnet
     *         transactBy(preconfRouter)
     *     {
     *         (
     *             ,
     *             SetupOperator[] memory _lookaheadOperators,
     *             ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
     *         ) = _setupURCAndPrepareInputs(1);
     *
     *         // Push the next epoch's lookahead to the store
     *         bytes26 lookaheadHash = _updateLookahead(_lookaheadSlots,
     * _lookaheadOperators.length);
     *
     *         // The next epoch's lookahead hash is correctly added to the lookahead store
     *         assertEq(
     *             lookaheadStore.getLookaheadHash(EPOCH_START +
     * LibPreconfConstants.SECONDS_IN_EPOCH),
     *             lookaheadHash
     *         );
     *
     *         // Attempt to post the lookahead for the next epoch again reverts
     *         vm.expectRevert(ILookaheadStore.LookaheadNotRequired.selector);
     *         _updateLookahead(_lookaheadSlots, _lookaheadOperators.length);
     *     }
     */

    }
