// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

contract MultisigTest is Test {
    modifier givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5() {
        _;
    }

    function test_GivenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
    {
        // It should initialize the genesis block
        // It should initialize the first transition
        // It should finalize the genesis block
        // It the total number of block should be 1
        // It get the genesis block should not revert
        // It get the block 1 should revert indicating block not found
        vm.skip(true);
    }

    modifier when10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks() {
        _;
    }

    function test_When10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        when10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks
    {
        // It propose another block will revert indicating no slot is available
        vm.skip(true);
    }

    modifier whenAll10BlocksAreProvedAndVerified() {
        _;
    }

    function test_WhenAll10BlocksAreProvedAndVerified()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        when10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks
        whenAll10BlocksAreProvedAndVerified
    {
        // It should not revert
        // It the last verified block id should be 10
        // It the last synced block id should be 5
        // It the last synced stateroot should be the one from block 5
        // It the last synced timestamp should be the timestamp when block 5 is proposed
        // It the total number of block should be 11
        // It lastProposedIn should be the L1 block number when the last block is proposed
        // It lastProposedAt should be the timestamp when the last block is proposed
        vm.skip(true);
    }

    function test_WhenTheBlock11IsProposed()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        when10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks
        whenAll10BlocksAreProvedAndVerified
    {
        // It should not revert
        // It the last verified block id should be 10
        // It the last synced block id should be 5
        // It the last synced stateroot should be the one from block 5
        // It the last synced timestamp should be the timestamp when block 5 is proposed
        // It the total number of block should be 12
        // It lastProposedIn should be the L1 block number when the last block is proposed
        // It lastProposedAt should be the timestamp when the last block is proposed
        vm.skip(true);
    }

    modifier whenProposeOneMoreBlock() {
        _;
    }

    function test_WhenItIsStillInsideTheLastBlocksProvingWindow()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        whenProposeOneMoreBlock
    {
        // It should revert if someone other than the proposer tries to prove the block
        vm.skip(true);
    }
}
