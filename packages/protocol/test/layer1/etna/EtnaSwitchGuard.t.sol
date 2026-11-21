// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaSwitchGuard } from "src/layer1/etna/switch/EtnaSwitchGuard.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { InboxTestBase } from "test/layer1/core/inbox/InboxTestBase.sol";

/// @title EtnaSwitchGuardTest
/// @notice Each `EtnaSwitchGuard` check over the real Unzen Inbox upgraded to
/// `InboxWithEtnaCutoffs` and a real switching `EtnaInbox` implementation, whose unwritten start
/// reads as zero: it passes at its boundary and reverts one second or one unit past it, and every
/// failure reverts with its own error (SWITCH.md sections 3 and 7, vectors 5d.j and 5d.k).
contract EtnaSwitchGuardTest is InboxTestBase {
    uint48 private constant _FORK_TIME = 1_000_000;
    uint48 private constant _PROPOSE_MARGIN = 12;
    uint48 private constant _FI_MARGIN = 500;
    uint48 private constant _LEAD = 10_000;
    /// @dev The postponement's deadline B, before both installed cutoffs.
    uint48 private constant _DEADLINE = 999_400;
    uint48 private constant _NEW_FORK_TIME = 1_005_000;
    /// @dev The new lead is exactly available one second before B.
    uint48 private constant _NEW_LEAD = _NEW_FORK_TIME - (_DEADLINE - 1);
    /// @dev Slot 273: the start block hash, zero until the start write.
    bytes32 private constant _START_HASH_SLOT = bytes32(uint256(273));

    EtnaSwitchGuard private _guard;
    EtnaInbox private _etna;

    function setUp() public override {
        super.setUp();
        _guard = new EtnaSwitchGuard();
        _etna = _deployEtna(address(inbox), _FORK_TIME);
        _installCutoffs(_FORK_TIME, address(_etna));
    }

    // ---------------------------------------------------------------
    // checkDeadline (SWITCH.md section 3, action 0)
    // ---------------------------------------------------------------

    function test_checkDeadline_OnTimeExactlyAtTheLead() external {
        vm.warp(_FORK_TIME - _LEAD);
        _guard.checkDeadline(_FORK_TIME, _LEAD);
    }

    function test_checkDeadline_RevertWhen_OneSecondPastTheLead() external {
        vm.warp(_FORK_TIME - _LEAD + 1);
        vm.expectRevert(EtnaSwitchGuard.ProposalLeadMissed.selector);
        _guard.checkDeadline(_FORK_TIME, _LEAD);
    }

    function test_checkDeadline_RevertWhen_LeadExceedsTheForkTime() external {
        vm.expectRevert(EtnaSwitchGuard.ProposalLeadMissed.selector);
        _guard.checkDeadline(_LEAD, _LEAD + 1);
    }

    // ---------------------------------------------------------------
    // checkL1SignalService (SWITCH.md section 3, action 2)
    // ---------------------------------------------------------------

    function test_checkL1SignalService_AcceptsTheL1Implementation() external view {
        address impl = signalService.impl();
        _guard.checkL1SignalService(address(signalService), impl, impl.codehash);
    }

    function test_checkL1SignalService_RevertWhen_UnexpectedImplementation() external {
        address impl = signalService.impl();
        vm.expectRevert(EtnaSwitchGuard.UnexpectedImplementation.selector);
        _guard.checkL1SignalService(address(signalService), address(_etna), impl.codehash);
    }

    /// @dev The installed implementation is the expected address, but its code is not the one the
    /// builder rebuilt: here, another syncer.
    function test_checkL1SignalService_RevertWhen_UnexpectedCodeHash() external {
        address impl = signalService.impl();
        address otherSyncer =
            address(new SignalService(Bob, REMOTE_SIGNAL_SERVICE, address(0), false));
        vm.expectRevert(EtnaSwitchGuard.UnexpectedCodeHash.selector);
        _guard.checkL1SignalService(address(signalService), impl, otherSyncer.codehash);
    }

    function test_checkL1SignalService_RevertWhen_UsesBeaconRoots() external {
        address impl =
            address(new SignalService(address(_etna), REMOTE_SIGNAL_SERVICE, address(0), true));
        signalService.upgradeTo(impl);
        vm.expectRevert(EtnaSwitchGuard.BeaconRootsUsed.selector);
        _guard.checkL1SignalService(address(signalService), impl, impl.codehash);
    }

    // ---------------------------------------------------------------
    // checkSchedule (the fork-time cross-check)
    // ---------------------------------------------------------------

    function test_checkSchedule_AcceptsTheInstalledSchedule() external view {
        _guard.checkSchedule(address(inbox), address(_etna), _schedule());
    }

    function test_checkSchedule_RevertWhen_EtnaInboxNamesAnotherUnzenInbox() external {
        EtnaInbox other = _deployEtna(address(signalService), _FORK_TIME);
        vm.expectRevert(EtnaSwitchGuard.UnzenInboxMismatch.selector);
        _guard.checkSchedule(address(inbox), address(other), _schedule());
    }

    function test_checkSchedule_RevertWhen_EtnaForkTimeDiffers() external {
        EtnaSwitchGuard.Schedule memory schedule = _schedule();
        schedule.etnaForkTime += 1;
        vm.expectRevert(EtnaSwitchGuard.EtnaForkTimeMismatch.selector);
        _guard.checkSchedule(address(inbox), address(_etna), schedule);
    }

    function test_checkSchedule_RevertWhen_UnzenForkTimeDiffers() external {
        _installCutoffs(_FORK_TIME + 1, address(_etna));
        vm.expectRevert(EtnaSwitchGuard.UnzenForkTimeMismatch.selector);
        _guard.checkSchedule(address(inbox), address(_etna), _schedule());
    }

    function test_checkSchedule_RevertWhen_ProposeCutoffDiffers() external {
        EtnaSwitchGuard.Schedule memory schedule = _schedule();
        schedule.proposeMargin += 1;
        vm.expectRevert(EtnaSwitchGuard.ProposeCutoffMismatch.selector);
        _guard.checkSchedule(address(inbox), address(_etna), schedule);
    }

    function test_checkSchedule_RevertWhen_ForcedInclusionCutoffDiffers() external {
        EtnaSwitchGuard.Schedule memory schedule = _schedule();
        schedule.fiMargin += 1;
        vm.expectRevert(EtnaSwitchGuard.ForcedInclusionCutoffMismatch.selector);
        _guard.checkSchedule(address(inbox), address(_etna), schedule);
    }

    function test_checkSchedule_RevertWhen_UnzenSavesCheckpointsElsewhere() external {
        _installCutoffs(_FORK_TIME, address(signalService));
        vm.expectRevert(EtnaSwitchGuard.CheckpointPathMismatch.selector);
        _guard.checkSchedule(address(inbox), address(_etna), _schedule());
    }

    // ---------------------------------------------------------------
    // checkPostponement (SWITCH.md section 7)
    // ---------------------------------------------------------------

    /// @dev 5d.j: one second before B, with the new lead exactly available.
    function test_checkPostponement_AcceptsUntilTheDeadline() external {
        vm.warp(_DEADLINE - 1);
        _checkPostponement(_schedule(), _NEW_FORK_TIME, _NEW_LEAD, _DEADLINE);
    }

    /// @dev 5d.k: submitted before B, included at it.
    function test_checkPostponement_RevertWhen_IncludedAtTheDeadline() external {
        vm.warp(_DEADLINE);
        vm.expectRevert(EtnaSwitchGuard.PostponementDeadlinePassed.selector);
        _checkPostponement(_schedule(), _NEW_FORK_TIME, _NEW_LEAD - 1, _DEADLINE);
    }

    /// @dev 5d.k: after the start write.
    function test_checkPostponement_RevertWhen_StartWritten() external {
        vm.store(address(_etna), _START_HASH_SLOT, bytes32(uint256(1)));
        (, bytes32 startHash) = _etna.etnaStart();
        assertEq(startHash, bytes32(uint256(1)), "start hash");
        vm.warp(_DEADLINE - 1);
        vm.expectRevert(EtnaSwitchGuard.StartAlreadyWritten.selector);
        _checkPostponement(_schedule(), _NEW_FORK_TIME, _NEW_LEAD, _DEADLINE);
    }

    /// @dev 5d.k: the batch names a different old schedule.
    function test_checkPostponement_RevertWhen_OldScheduleDiffers() external {
        vm.warp(_DEADLINE - 1);
        EtnaSwitchGuard.Schedule memory old = _schedule();
        old.etnaForkTime -= 1;
        vm.expectRevert(EtnaSwitchGuard.EtnaForkTimeMismatch.selector);
        _checkPostponement(old, _NEW_FORK_TIME, _NEW_LEAD, _DEADLINE);

        old = _schedule();
        old.fiMargin -= 1;
        vm.expectRevert(EtnaSwitchGuard.ForcedInclusionCutoffMismatch.selector);
        _checkPostponement(old, _NEW_FORK_TIME, _NEW_LEAD, _DEADLINE);
    }

    /// @dev B may equal the earlier installed cutoff C but not exceed it.
    function test_checkPostponement_RevertWhen_DeadlineAfterTheEarlierCutoff() external {
        uint48 cutoff = _FORK_TIME - _FI_MARGIN;
        vm.warp(cutoff - 1);
        _checkPostponement(_schedule(), _NEW_FORK_TIME, 1, cutoff);
        vm.expectRevert(EtnaSwitchGuard.DeadlineAfterCutoff.selector);
        _checkPostponement(_schedule(), _NEW_FORK_TIME, 1, cutoff + 1);
    }

    function test_checkPostponement_RevertWhen_NewForkTimeNotLater() external {
        vm.warp(_DEADLINE - 1);
        vm.expectRevert(EtnaSwitchGuard.ForkTimeNotLater.selector);
        _checkPostponement(_schedule(), _FORK_TIME, 1, _DEADLINE);
    }

    /// @dev 5d.k: the new schedule lacks its lead.
    function test_checkPostponement_RevertWhen_NewLeadMissed() external {
        vm.warp(_DEADLINE - 1);
        vm.expectRevert(EtnaSwitchGuard.ProposalLeadMissed.selector);
        _checkPostponement(_schedule(), _NEW_FORK_TIME, _NEW_LEAD + 1, _DEADLINE);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _checkPostponement(
        EtnaSwitchGuard.Schedule memory _old,
        uint48 _newForkTime,
        uint48 _newLead,
        uint48 _deadline
    )
        private
        view
    {
        _guard.checkPostponement(
            address(inbox), address(_etna), _old, _newForkTime, _newLead, _deadline
        );
    }

    function _schedule() private pure returns (EtnaSwitchGuard.Schedule memory) {
        return EtnaSwitchGuard.Schedule({
            etnaForkTime: _FORK_TIME, proposeMargin: _PROPOSE_MARGIN, fiMargin: _FI_MARGIN
        });
    }

    /// @dev Upgrades the Unzen Inbox to cutoffs for `_forkTime` whose `prove` saves its
    /// checkpoints in `_checkpointStore`.
    function _installCutoffs(uint48 _forkTime, address _checkpointStore) private {
        IInbox.Config memory cutoffConfig = config;
        cutoffConfig.signalService = _checkpointStore;
        inbox.upgradeTo(
            address(new InboxWithEtnaCutoffs(cutoffConfig, _forkTime, _PROPOSE_MARGIN, _FI_MARGIN))
        );
    }

    /// @dev A switching implementation; the guard reads only its immutables and its start.
    function _deployEtna(address _unzenInbox, uint48 _forkTime) private returns (EtnaInbox) {
        return new EtnaInbox(
            IEtnaInbox.Config({
                proofVerifier: address(verifier),
                signalService: address(signalService),
                stakingRegistry: address(bondToken),
                l2ChainId: 167_001,
                maxBatchBlocks: 1000,
                forcedInclusionFeeInGwei: 1,
                forcedInclusionFeeDoubleThreshold: 1,
                protocolFeeRecipient: Emma,
                unzenInbox: _unzenInbox,
                etnaForkTime: _forkTime,
                recoveryCapacity: 131
            })
        );
    }
}
