// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title EtnaSwitchGuard
/// @notice Read-only checks that the L1 DAO batches of an Unzen to Etna switch run as actions
/// (Etna SWITCH.md sections 3 and 7, START-10-5d). The DAO controller checks only call success, so
/// every check reverts with a named error, and a failed check reverts the whole batch.
/// @dev Holds no state. Every time, deadline and schedule it checks is a parameter fixed in the
/// batch.
/// @custom:security-contact security@taiko.xyz
contract EtnaSwitchGuard {
    /// @notice A switch schedule: the Etna fork time and the two margins before it at which the
    /// Unzen Inbox stops accepting proposals and forced inclusions (PARAM-11-12b).
    struct Schedule {
        /// @notice `ETNA_FORK_TIME` in L1 Unix seconds.
        uint48 etnaForkTime;
        /// @notice `PROPOSE_MARGIN`: proposals revert from `etnaForkTime - proposeMargin` on.
        uint48 proposeMargin;
        /// @notice `FI_MARGIN`: forced inclusions revert from `etnaForkTime - fiMargin` on.
        uint48 fiMargin;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice The scheduling proposal's first action (SWITCH.md section 3, action 0): reverts if
    /// `block.timestamp > _etnaForkTime - _proposalLead`. Executing exactly `_proposalLead` before
    /// the fork time is on time.
    /// @param _etnaForkTime The fork time the batch installs.
    /// @param _proposalLead `PROPOSAL_LEAD` in seconds.
    function checkDeadline(uint48 _etnaForkTime, uint48 _proposalLead) external view {
        _checkLead(_etnaForkTime, _proposalLead);
    }

    /// @notice Runs after the L1 SignalService upgrade (SWITCH.md section 3, action 2): reverts
    /// unless `_signalService` uses `_expectedImpl`, whose runtime code hashes to
    /// `_expectedCodeHash`, and reports `usesBeaconRoots()` false. The syncer and remote are
    /// immutables without getters; the builder computes the hash from the implementation rebuilt
    /// with the expected syncer, remote, pauser and flag, so the batch itself rejects any other
    /// code. With the flag set on L1, every `saveCheckpoint` would read L1's own EIP-4788 roots and
    /// revert.
    /// @param _signalService The L1 SignalService proxy.
    /// @param _expectedImpl The SignalService implementation the batch installs.
    /// @param _expectedCodeHash `keccak256` of that implementation's runtime code.
    function checkL1SignalService(
        address _signalService,
        address _expectedImpl,
        bytes32 _expectedCodeHash
    )
        external
        view
    {
        require(
            EssentialContract(_signalService).impl() == _expectedImpl, UnexpectedImplementation()
        );
        require(_expectedImpl.codehash == _expectedCodeHash, UnexpectedCodeHash());
        require(!SignalService(_signalService).usesBeaconRoots(), BeaconRootsUsed());
    }

    /// @notice The fork-time cross-check that ends the scheduling and postponement batches: reverts
    /// unless the Unzen Inbox's cutoffs and the EtnaInbox's `ETNA_FORK_TIME` derive from the same
    /// fork time, `_schedule`'s, and the Unzen Inbox saves its checkpoints through the EtnaInbox.
    /// @param _unzenInbox The Unzen Inbox proxy, on an `InboxWithEtnaCutoffs` implementation.
    /// @param _etnaInbox The EtnaInbox proxy.
    /// @param _schedule The schedule both must hold.
    function checkSchedule(
        address _unzenInbox,
        address _etnaInbox,
        Schedule calldata _schedule
    )
        external
        view
    {
        _checkSchedule(_unzenInbox, _etnaInbox, _schedule);
    }

    /// @notice The postponement batch's first action (SWITCH.md section 7): reverts unless the
    /// Etna start is unwritten, the live schedule is exactly `_old`, `block.timestamp < _deadline`,
    /// the deadline is no later than the earlier of `_old`'s two cutoffs, `_newForkTime` is later
    /// than `_old`'s and `block.timestamp <= _newForkTime - _newProposalLead`.
    /// @param _unzenInbox The Unzen Inbox proxy.
    /// @param _etnaInbox The EtnaInbox proxy.
    /// @param _old The installed schedule the batch replaces.
    /// @param _newForkTime The fork time the batch installs.
    /// @param _newProposalLead The `PROPOSAL_LEAD` the new fork time must keep.
    /// @param _deadline B, the batch's exclusive inclusion deadline.
    function checkPostponement(
        address _unzenInbox,
        address _etnaInbox,
        Schedule calldata _old,
        uint48 _newForkTime,
        uint48 _newProposalLead,
        uint48 _deadline
    )
        external
        view
    {
        (, bytes32 startHash) = IEtnaInbox(_etnaInbox).etnaStart();
        require(startHash == 0, StartAlreadyWritten());
        _checkSchedule(_unzenInbox, _etnaInbox, _old);
        require(block.timestamp < _deadline, PostponementDeadlinePassed());
        uint256 maxMargin = _old.fiMargin > _old.proposeMargin ? _old.fiMargin : _old.proposeMargin;
        require(uint256(_deadline) + maxMargin <= _old.etnaForkTime, DeadlineAfterCutoff());
        require(_newForkTime > _old.etnaForkTime, ForkTimeNotLater());
        _checkLead(_newForkTime, _newProposalLead);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Reverts if `block.timestamp > _etnaForkTime - _proposalLead`, without underflow.
    /// @param _etnaForkTime The fork time.
    /// @param _proposalLead The lead the batch must keep.
    function _checkLead(uint48 _etnaForkTime, uint48 _proposalLead) private view {
        require(block.timestamp + _proposalLead <= _etnaForkTime, ProposalLeadMissed());
    }

    /// @dev Requires the EtnaInbox's Unzen Inbox and fork time, the Unzen Inbox's fork time and
    /// live cutoffs, and the Unzen Inbox's checkpoint path to match `_schedule` and each other.
    /// @param _unzenInbox The Unzen Inbox proxy.
    /// @param _etnaInbox The EtnaInbox proxy.
    /// @param _schedule The expected schedule.
    function _checkSchedule(
        address _unzenInbox,
        address _etnaInbox,
        Schedule calldata _schedule
    )
        private
        view
    {
        uint256 forkTime = _schedule.etnaForkTime;
        require(IEtnaInbox(_etnaInbox).unzenInbox() == _unzenInbox, UnzenInboxMismatch());
        require(IEtnaInbox(_etnaInbox).etnaForkTime() == forkTime, EtnaForkTimeMismatch());
        InboxWithEtnaCutoffs unzen = InboxWithEtnaCutoffs(_unzenInbox);
        require(unzen.ETNA_FORK_TIME() == forkTime, UnzenForkTimeMismatch());
        require(
            uint256(unzen.proposeCutoff()) + _schedule.proposeMargin == forkTime,
            ProposeCutoffMismatch()
        );
        require(
            uint256(unzen.FI_CUTOFF()) + _schedule.fiMargin == forkTime,
            ForcedInclusionCutoffMismatch()
        );
        require(
            IInbox(_unzenInbox).getConfig().signalService == _etnaInbox, CheckpointPathMismatch()
        );
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error BeaconRootsUsed();
    error CheckpointPathMismatch();
    error DeadlineAfterCutoff();
    error EtnaForkTimeMismatch();
    error ForcedInclusionCutoffMismatch();
    error ForkTimeNotLater();
    error PostponementDeadlinePassed();
    error ProposalLeadMissed();
    error ProposeCutoffMismatch();
    error StartAlreadyWritten();
    error UnexpectedCodeHash();
    error UnexpectedImplementation();
    error UnzenForkTimeMismatch();
    error UnzenInboxMismatch();
}
