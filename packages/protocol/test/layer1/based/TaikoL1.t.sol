// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

contract TaikoL1Test is Test {
    modifier givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5() {
        _;
    }

    modifier whenTest1() {
        _;
    }

    function test_WhenCase_1() external givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5 whenTest1 {
        // It initializes the genesis block
        // It initializes the first transition
        // It finalizes the genesis block
        // It counts total blocks as 1
        // It retrieves correct data for the genesis block
        // It retrieves correct data for the genesis block's first transition
        // It fails to retrieve block 1, indicating block not found
        // It returns the genesis block and its first transition for getLastVerifiedTransitionV3
        // It returns empty data for getLastSyncedTransitionV3 but does not revert
        vm.skip(true);
    }

    modifier whenProposingOneMoreBlockWithCustomParameters() {
        _;
    }

    function test_WhenCase_2()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposingOneMoreBlockWithCustomParameters
    {
        // It places the block in the first slot
        // It sets the block's next transition id to 1
        // It the returned metahash should match the block's metahash
        // It matches the block's timestamp and anchor block id with the parameters
        // It total block count is 2
        // It retrieves correct data for block 1
        vm.skip(true);
    }

    modifier whenProposingOneMoreBlockWithDefaultParameters() {
        _;
    }

    function test_WhenCase_3()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposingOneMoreBlockWithDefaultParameters
    {
        // It places the block in the first slot
        // It sets the block's next transition id to 1
        // It the returned metahash should match the block's metahash
        // It sets the block's timestamp to the current timestamp
        // It sets the block's anchor block id to block.number - 1
        // It total block count is 2
        // It retrieves correct data for block 1
        vm.skip(true);
    }

    modifier whenProposingOneMoreBlockWithDefaultParametersButNonzeroParentMetaHash() {
        _;
    }

    function test_WhenCase_4()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposingOneMoreBlockWithDefaultParametersButNonzeroParentMetaHash
    {
        // It does not revert when the first block's parentMetaHash matches the genesis block's metahash
        // It reverts when proposing a second block with a random parentMetaHash
        vm.skip(true);
    }

    modifier whenProposing9BlocksAsABatchToFillAllSlots() {
        _;
    }

    modifier whenProposeThe11thBlockBeforePreviousBlocksAreVerified() {
        _;
    }

    function test_WhenCase_5()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposing9BlocksAsABatchToFillAllSlots
        whenProposeThe11thBlockBeforePreviousBlocksAreVerified
    {
        // It reverts indicating no more slots available
        vm.skip(true);
    }

    modifier whenProveAllExistingBlocksWithCorrectFirstTransitions() {
        _;
    }

    modifier whenProposingThe11thBlockAfterPreviousBlocksAreVerified() {
        _;
    }

    function test_WhenCase_6()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposing9BlocksAsABatchToFillAllSlots
        whenProveAllExistingBlocksWithCorrectFirstTransitions
        whenProposingThe11thBlockAfterPreviousBlocksAreVerified
    {
        // It total block count is 12
        // It getBlockV3(0) reverts indicating block not found
        vm.skip(true);
    }

    function test_WhenCase_7()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposing9BlocksAsABatchToFillAllSlots
        whenProveAllExistingBlocksWithCorrectFirstTransitions
    {
        // It total block count is 10
        // It returns the block 9 and its first transition for getLastVerifiedTransitionV3
        // It returns the block 5 and its first transition for getLastSyncedTransitionV3
        vm.skip(true);
    }

    modifier whenProveAllExistingBlocksWithWrongFirstTransitions() {
        _;
    }

    modifier whenProveAllExistingBlocksWithCorrectFirstTransitionsInReverseOrder() {
        _;
    }

    function test_WhenCase_8()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposing9BlocksAsABatchToFillAllSlots
        whenProveAllExistingBlocksWithWrongFirstTransitions
        whenProveAllExistingBlocksWithCorrectFirstTransitionsInReverseOrder
    {
        // It total block count is 10
        // It returns the block 9 and its first transition for getLastVerifiedTransitionV3
        // It returns the block 5 and its first transition for getLastSyncedTransitionV3
        vm.skip(true);
    }

    function test_WhenCase_9()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposing9BlocksAsABatchToFillAllSlots
        whenProveAllExistingBlocksWithWrongFirstTransitions
    {
        // It total block count is 10
        // It returns the genesis block and its first transition for getLastVerifiedTransitionV3
        // It returns empty data for getLastSyncedTransitionV3 but does not revert
        vm.skip(true);
    }

    function test_WhenCase_10()
        external
        givenANewTaikoL1With10BlockSlotsAndASyncIntervalOf5
        whenProposing9BlocksAsABatchToFillAllSlots
    {
        // It total block count is 10
        vm.skip(true);
    }
}
