// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

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
        vm.skip(true);
    }

    modifier when10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks() {
        _;
    }

    function test_WhenAll10BlocksAreProvedAndVerified()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        when10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks
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

    function test_WhenOneMoreBlockIsProposed()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        when10BlocksAreProposedIndividuallyWithDifferentTimestampInDifferentL1Blocks
    {
        // It should revert indicating no slot is available
        vm.skip(true);
    }

    modifier givenCallingInitialize() {
        _;
    }

    function test_GivenCallingInitialize()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        givenCallingInitialize
    {
        // It should initialize the first time
        // It should refuse to initialize again
        // It should set the DAO address
        // It should set the minApprovals
        // It should set onlyListed
        // It should set signerList
        // It should set destinationProposalDuration
        // It should set proposalExpirationPeriod
        // It should emit MultisigSettingsUpdated
        vm.skip(true);
    }

    function test_RevertWhen_MinApprovalsIsGreaterThanSignerListLengthOnInitialize()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        givenCallingInitialize
    {
        // It should revert
        // It should revert (with onlyListed false)
        // It should not revert otherwise
        vm.skip(true);
    }

    function test_RevertWhen_MinApprovalsIsZeroOnInitialize()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        givenCallingInitialize
    {
        // It should revert
        // It should revert (with onlyListed false)
        // It should not revert otherwise
        vm.skip(true);
    }

    function test_RevertWhen_SignerListIsInvalidOnInitialize()
        external
        givenANewTaikoL1With10SlotsForBlocksAndSyncInternvalAs5
        givenCallingInitialize
    {
        // It should revert
        vm.skip(true);
    }

    function test_WhenCallingUpgradeTo() external {
        // It should revert when called without the permission
        // It should work when called with the permission
        vm.skip(true);
    }

    function test_WhenCallingUpgradeToAndCall() external {
        // It should revert when called without the permission
        // It should work when called with the permission
        vm.skip(true);
    }

    function test_WhenCallingSupportsInterface() external {
        // It does not support the empty interface
        // It supports IERC165Upgradeable
        // It supports IPlugin
        // It supports IProposal
        // It supports IMultisig
        vm.skip(true);
    }

    modifier whenCallingUpdateSettings() {
        _;
    }

    function test_WhenCallingUpdateSettings() external whenCallingUpdateSettings {
        // It should set the minApprovals
        // It should set onlyListed
        // It should set signerList
        // It should set destinationProposalDuration
        // It should set proposalExpirationPeriod
        // It should emit MultisigSettingsUpdated
        vm.skip(true);
    }

    function test_RevertGiven_CallerHasNoPermission() external whenCallingUpdateSettings {
        // It should revert
        // It otherwise it should just work
        vm.skip(true);
    }

    function test_RevertWhen_MinApprovalsIsGreaterThanSignerListLengthOnUpdateSettings()
        external
        whenCallingUpdateSettings
    {
        // It should revert
        // It should revert (with onlyListed false)
        // It should not revert otherwise
        vm.skip(true);
    }

    function test_RevertWhen_MinApprovalsIsZeroOnUpdateSettings() external whenCallingUpdateSettings {
        // It should revert
        // It should revert (with onlyListed false)
        // It should not revert otherwise
        vm.skip(true);
    }

    function test_RevertWhen_SignerListIsInvalidOnUpdateSettings() external whenCallingUpdateSettings {
        // It should revert
        vm.skip(true);
    }

    modifier whenCallingCreateProposal() {
        _;
    }

    function test_WhenCallingCreateProposal() external whenCallingCreateProposal {
        // It increments the proposal counter
        // It creates and return unique proposal IDs
        // It emits the ProposalCreated event
        // It creates a proposal with the given values
        vm.skip(true);
    }

    function test_GivenSettingsChangedOnTheSameBlock() external whenCallingCreateProposal {
        // It reverts
        // It does not revert otherwise
        vm.skip(true);
    }

    function test_GivenOnlyListedIsFalse() external whenCallingCreateProposal {
        // It allows anyone to create
        vm.skip(true);
    }

    modifier givenOnlyListedIsTrue() {
        _;
    }

    function test_GivenCreationCallerIsNotListedOrAppointed()
        external
        whenCallingCreateProposal
        givenOnlyListedIsTrue
    {
        // It reverts
        // It reverts if listed before but not now
        vm.skip(true);
    }

    function test_GivenCreationCallerIsAppointedByAFormerSigner()
        external
        whenCallingCreateProposal
        givenOnlyListedIsTrue
    {
        // It reverts
        vm.skip(true);
    }

    function test_GivenCreationCallerIsListedAndSelfAppointed()
        external
        whenCallingCreateProposal
        givenOnlyListedIsTrue
    {
        // It creates the proposal
        vm.skip(true);
    }

    function test_GivenCreationCallerIsListedAppointingSomeoneElseNow()
        external
        whenCallingCreateProposal
        givenOnlyListedIsTrue
    {
        // It creates the proposal
        vm.skip(true);
    }

    function test_GivenCreationCallerIsAppointedByACurrentSigner()
        external
        whenCallingCreateProposal
        givenOnlyListedIsTrue
    {
        // It creates the proposal
        vm.skip(true);
    }

    function test_GivenApproveProposalIsTrue() external whenCallingCreateProposal {
        // It creates and calls approval in one go
        vm.skip(true);
    }

    function test_GivenApproveProposalIsFalse() external whenCallingCreateProposal {
        // It only creates the proposal
        vm.skip(true);
    }

    modifier givenTheProposalIsNotCreated() {
        _;
    }

    function test_WhenCallingGetProposalBeingUncreated() external givenTheProposalIsNotCreated {
        // It should return empty values
        vm.skip(true);
    }

    function test_WhenCallingCanApproveOrApproveBeingUncreated() external givenTheProposalIsNotCreated {
        // It canApprove should return false (when listed and self appointed)
        // It approve should revert (when listed and self appointed)
        // It canApprove should return false (when listed, appointing someone else now)
        // It approve should revert (when listed, appointing someone else now)
        // It canApprove should return false (when appointed by a listed signer)
        // It approve should revert (when appointed by a listed signer)
        // It canApprove should return false (when unlisted and unappointed)
        // It approve should revert (when unlisted and unappointed)
        vm.skip(true);
    }

    function test_WhenCallingHasApprovedBeingUncreated() external givenTheProposalIsNotCreated {
        // It hasApproved should always return false
        vm.skip(true);
    }

    function test_WhenCallingCanExecuteOrExecuteBeingUncreated() external givenTheProposalIsNotCreated {
        // It canExecute should return false (when listed and self appointed)
        // It execute should revert (when listed and self appointed)
        // It canExecute should return false (when listed, appointing someone else now)
        // It execute should revert (when listed, appointing someone else now)
        // It canExecute should return false (when appointed by a listed signer)
        // It execute should revert (when appointed by a listed signer)
        // It canExecute should return false (when unlisted and unappointed)
        // It execute should revert (when unlisted and unappointed)
        vm.skip(true);
    }

    modifier givenTheProposalIsOpen() {
        _;
    }

    function test_WhenCallingGetProposalBeingOpen() external givenTheProposalIsOpen {
        // It should return the right values
        vm.skip(true);
    }

    function test_WhenCallingCanApproveOrApproveBeingOpen() external givenTheProposalIsOpen {
        // It canApprove should return true (when listed on creation, self appointed now)
        // It approve should work (when listed on creation, self appointed now)
        // It approve should emit an event (when listed on creation, self appointed now)
        // It canApprove should return false (when listed on creation, appointing someone else now)
        // It approve should revert (when listed on creation, appointing someone else now)
        // It canApprove should return true (when currently appointed by a signer listed on creation)
        // It approve should work (when currently appointed by a signer listed on creation)
        // It approve should emit an event (when currently appointed by a signer listed on creation)
        // It canApprove should return false (when unlisted on creation, unappointed now)
        // It approve should revert (when unlisted on creation, unappointed now)
        vm.skip(true);
    }

    function test_WhenCallingApproveWithTryExecutionAndAlmostPassedBeingOpen() external givenTheProposalIsOpen {
        // It approve should also execute the proposal
        // It approve should emit an Executed event
        // It approve recreates the proposal on the destination plugin
        // It The parameters of the recreated proposal match those of the approved one
        // It A ProposalCreated event is emitted on the destination plugin
        vm.skip(true);
    }

    function test_WhenCallingHasApprovedBeingOpen() external givenTheProposalIsOpen {
        // It hasApproved should return false until approved
        vm.skip(true);
    }

    function test_WhenCallingCanExecuteOrExecuteBeingOpen() external givenTheProposalIsOpen {
        // It canExecute should return false (when listed on creation, self appointed now)
        // It execute should revert (when listed on creation, self appointed now)
        // It canExecute should return false (when listed on creation, appointing someone else now)
        // It execute should revert (when listed on creation, appointing someone else now)
        // It canExecute should return false (when currently appointed by a signer listed on creation)
        // It execute should revert (when currently appointed by a signer listed on creation)
        // It canExecute should return false (when unlisted on creation, unappointed now)
        // It execute should revert (when unlisted on creation, unappointed now)
        vm.skip(true);
    }

    modifier givenTheProposalWasApprovedByTheAddress() {
        _;
    }

    function test_WhenCallingGetProposalBeingApproved() external givenTheProposalWasApprovedByTheAddress {
        // It should return the right values
        vm.skip(true);
    }

    function test_WhenCallingCanApproveOrApproveBeingApproved() external givenTheProposalWasApprovedByTheAddress {
        // It canApprove should return false (when listed on creation, self appointed now)
        // It approve should revert (when listed on creation, self appointed now)
        // It canApprove should return false (when currently appointed by a signer listed on creation)
        // It approve should revert (when currently appointed by a signer listed on creation)
        vm.skip(true);
    }

    function test_WhenCallingHasApprovedBeingApproved() external givenTheProposalWasApprovedByTheAddress {
        // It hasApproved should return false until approved
        vm.skip(true);
    }

    function test_WhenCallingCanExecuteOrExecuteBeingApproved() external givenTheProposalWasApprovedByTheAddress {
        // It canExecute should return false (when listed on creation, self appointed now)
        // It execute should revert (when listed on creation, self appointed now)
        // It canExecute should return false (when currently appointed by a signer listed on creation)
        // It execute should revert (when currently appointed by a signer listed on creation)
        vm.skip(true);
    }

    modifier givenTheProposalPassed() {
        _;
    }

    function test_WhenCallingGetProposalBeingPassed() external givenTheProposalPassed {
        // It should return the right values
        vm.skip(true);
    }

    function test_WhenCallingCanApproveOrApproveBeingPassed() external givenTheProposalPassed {
        // It canApprove should return false (when listed on creation, self appointed now)
        // It approve should revert (when listed on creation, self appointed now)
        // It canApprove should return false (when listed on creation, appointing someone else now)
        // It approve should revert (when listed on creation, appointing someone else now)
        // It canApprove should return false (when currently appointed by a signer listed on creation)
        // It approve should revert (when currently appointed by a signer listed on creation)
        // It canApprove should return false (when unlisted on creation, unappointed now)
        // It approve should revert (when unlisted on creation, unappointed now)
        vm.skip(true);
    }

    function test_WhenCallingHasApprovedBeingPassed() external givenTheProposalPassed {
        // It hasApproved should return false until approved
        vm.skip(true);
    }

    function test_WhenCallingCanExecuteOrExecuteBeingPassed() external givenTheProposalPassed {
        // It canExecute should return true, always
        // It execute should work, when called by anyone
        // It execute should emit an event, when called by anyone
        // It execute recreates the proposal on the destination plugin
        // It The parameters of the recreated proposal match those of the executed one
        // It The proposal duration on the destination plugin matches the multisig settings
        // It A ProposalCreated event is emitted on the destination plugin
        vm.skip(true);
    }

    function test_GivenTaikoL1IsIncompatible() external givenTheProposalPassed {
        // It executes successfully, regardless
        vm.skip(true);
    }

    modifier givenTheProposalIsAlreadyExecuted() {
        _;
    }

    function test_WhenCallingGetProposalBeingExecuted() external givenTheProposalIsAlreadyExecuted {
        // It should return the right values
        vm.skip(true);
    }

    function test_WhenCallingCanApproveOrApproveBeingExecuted() external givenTheProposalIsAlreadyExecuted {
        // It canApprove should return false (when listed on creation, self appointed now)
        // It approve should revert (when listed on creation, self appointed now)
        // It canApprove should return false (when listed on creation, appointing someone else now)
        // It approve should revert (when listed on creation, appointing someone else now)
        // It canApprove should return false (when currently appointed by a signer listed on creation)
        // It approve should revert (when currently appointed by a signer listed on creation)
        // It canApprove should return false (when unlisted on creation, unappointed now)
        // It approve should revert (when unlisted on creation, unappointed now)
        vm.skip(true);
    }

    function test_WhenCallingHasApprovedBeingExecuted() external givenTheProposalIsAlreadyExecuted {
        // It hasApproved should return false until approved
        vm.skip(true);
    }

    function test_WhenCallingCanExecuteOrExecuteBeingExecuted() external givenTheProposalIsAlreadyExecuted {
        // It canExecute should return false (when listed on creation, self appointed now)
        // It execute should revert (when listed on creation, self appointed now)
        // It canExecute should return false (when listed on creation, appointing someone else now)
        // It execute should revert (when listed on creation, appointing someone else now)
        // It canExecute should return false (when currently appointed by a signer listed on creation)
        // It execute should revert (when currently appointed by a signer listed on creation)
        // It canExecute should return false (when unlisted on creation, unappointed now)
        // It execute should revert (when unlisted on creation, unappointed now)
        vm.skip(true);
    }

    modifier givenTheProposalExpired() {
        _;
    }

    function test_WhenCallingGetProposalBeingExpired() external givenTheProposalExpired {
        // It should return the right values
        vm.skip(true);
    }

    function test_WhenCallingCanApproveOrApproveBeingExpired() external givenTheProposalExpired {
        // It canApprove should return false (when listed on creation, self appointed now)
        // It approve should revert (when listed on creation, self appointed now)
        // It canApprove should return false (when listed on creation, appointing someone else now)
        // It approve should revert (when listed on creation, appointing someone else now)
        // It canApprove should return false (when currently appointed by a signer listed on creation)
        // It approve should revert (when currently appointed by a signer listed on creation)
        // It canApprove should return false (when unlisted on creation, unappointed now)
        // It approve should revert (when unlisted on creation, unappointed now)
        vm.skip(true);
    }

    function test_WhenCallingHasApprovedBeingExpired() external givenTheProposalExpired {
        // It hasApproved should return false until approved
        vm.skip(true);
    }

    function test_WhenCallingCanExecuteOrExecuteBeingExpired() external givenTheProposalExpired {
        // It canExecute should return false (when listed on creation, self appointed now)
        // It execute should revert (when listed on creation, self appointed now)
        // It canExecute should return false (when listed on creation, appointing someone else now)
        // It execute should revert (when listed on creation, appointing someone else now)
        // It canExecute should return false (when currently appointed by a signer listed on creation)
        // It execute should revert (when currently appointed by a signer listed on creation)
        // It canExecute should return false (when unlisted on creation, unappointed now)
        // It execute should revert (when unlisted on creation, unappointed now)
        vm.skip(true);
    }
}
