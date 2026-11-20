// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployEtnaSwitch } from "./DeployEtnaSwitch.s.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaSwitchGuard } from "src/layer1/etna/switch/EtnaSwitchGuard.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SgxVerifier } from "src/layer1/verifiers/SgxVerifier.sol";
import { ComposeVerifier } from "src/layer1/verifiers/compose/ComposeVerifier.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title LibEtnaSwitchActions
/// @notice Builds the L1 DAO actions of an Unzen to Etna switch (Etna SWITCH.md sections 3 and 7):
/// the readiness proposal's verifier trust, the scheduling proposal and a postponement batch. The
/// DAO controller runs each list in order and reverts on the first failed call, so every list is
/// atomic.
/// @custom:security-contact security@taiko.xyz
library LibEtnaSwitchActions {
    /// @notice The sub-verifier setter a trust change calls; each takes `(bytes32, bool)`.
    enum TrustKind {
        SgxMrEnclave,
        Risc0ImageId,
        Sp1ProgramVKey
    }

    /// @notice One image-trust change on a sub-verifier.
    struct TrustChange {
        /// @notice The sub-verifier holding the trust.
        address verifier;
        /// @notice Its setter: `setMrEnclave`, `setImageIdTrusted` or `setProgramTrusted`.
        TrustKind kind;
        /// @notice The MRENCLAVE, RISC0 image id or SP1 program verification key.
        bytes32 id;
        /// @notice Whether the id becomes trusted or untrusted.
        bool trusted;
    }

    /// @notice The inputs of the scheduling proposal (SWITCH.md section 3, proposal 2).
    struct Scheduling {
        /// @notice The `EtnaSwitchGuard`.
        address guard;
        /// @notice The schedule the proposal installs.
        EtnaSwitchGuard.Schedule schedule;
        /// @notice `PROPOSAL_LEAD`: the proposal reverts if executed later than this before the
        /// fork time.
        uint48 proposalLead;
        /// @notice The Unzen Inbox proxy.
        address unzenInbox;
        /// @notice Its `InboxWithEtnaCutoffs` implementation.
        address unzenInboxImpl;
        /// @notice The L1 SignalService proxy.
        address signalService;
        /// @notice Its L1 implementation: syncer the EtnaInbox, `usesBeaconRoots` false.
        address signalServiceImpl;
        /// @notice The EtnaInbox proxy, on its bootstrap implementation.
        address etnaInbox;
        /// @notice The switching EtnaInbox implementation.
        address etnaInboxImpl;
        /// @notice The `EtnaInbox.init` calldata.
        bytes etnaInit;
        /// @notice The Unzen verifier pins for this schedule.
        TrustChange[] unzenTrust;
        /// @notice The EtnaInbox verifier's image trust.
        TrustChange[] etnaTrust;
    }

    /// @notice The inputs of a postponement batch (SWITCH.md section 7).
    struct Postponement {
        /// @notice The `EtnaSwitchGuard`.
        address guard;
        /// @notice The installed schedule the batch replaces.
        EtnaSwitchGuard.Schedule oldSchedule;
        /// @notice The schedule the batch installs.
        EtnaSwitchGuard.Schedule newSchedule;
        /// @notice The `PROPOSAL_LEAD` the new fork time keeps when the batch executes.
        uint48 newProposalLead;
        /// @notice B, the batch's exclusive inclusion deadline.
        uint48 deadline;
        /// @notice The Unzen Inbox proxy.
        address unzenInbox;
        /// @notice Its new `InboxWithEtnaCutoffs` implementation.
        address unzenInboxImpl;
        /// @notice The EtnaInbox proxy.
        address etnaInbox;
        /// @notice Its new implementation.
        address etnaInboxImpl;
        /// @notice The Unzen verifier changes the new schedule needs.
        TrustChange[] unzenTrust;
        /// @notice The EtnaInbox verifier changes the new schedule needs.
        TrustChange[] etnaTrust;
    }

    /// @dev The readiness proposal's L1 actions: the Unzen trust changes for guests that read both
    /// checkpoint layouts (ANCHORLESS.md section 8, steps 2 and 3). Its L2 message is
    /// `LibEtnaReadinessL2Message.buildActions`.
    /// @param _unzenTrust The Unzen verifier trust changes.
    /// @return actions_ One action per change.
    function readinessActions(TrustChange[] memory _unzenTrust)
        internal
        pure
        returns (Controller.Action[] memory actions_)
    {
        actions_ = new Controller.Action[](_unzenTrust.length);
        _appendTrust(actions_, 0, _unzenTrust);
    }

    /// @dev Returns `[guard.checkDeadline, UnzenInbox.upgradeTo(cutoff), SignalService.upgradeTo,
    /// guard.checkL1SignalService, EtnaInbox.upgradeToAndCall(impl, init), Unzen trust...,
    /// Etna trust..., guard.checkSchedule]`.
    /// @param _s The scheduling inputs.
    /// @return actions_ The actions, in execution order.
    function schedulingActions(Scheduling memory _s)
        internal
        pure
        returns (Controller.Action[] memory actions_)
    {
        actions_ = new Controller.Action[](6 + _s.unzenTrust.length + _s.etnaTrust.length);
        actions_[0] = _action(
            _s.guard,
            abi.encodeCall(
                EtnaSwitchGuard.checkDeadline, (_s.schedule.etnaForkTime, _s.proposalLead)
            )
        );
        actions_[1] =
            _action(_s.unzenInbox, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_s.unzenInboxImpl)));
        actions_[2] = _action(
            _s.signalService, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_s.signalServiceImpl))
        );
        actions_[3] = _action(
            _s.guard,
            abi.encodeCall(
                EtnaSwitchGuard.checkL1SignalService, (_s.signalService, _s.signalServiceImpl)
            )
        );
        actions_[4] = _action(
            _s.etnaInbox,
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (_s.etnaInboxImpl, _s.etnaInit))
        );
        uint256 next = _appendTrust(actions_, 5, _s.unzenTrust);
        next = _appendTrust(actions_, next, _s.etnaTrust);
        actions_[next] = _scheduleCheck(_s.guard, _s.unzenInbox, _s.etnaInbox, _s.schedule);
    }

    /// @dev Returns `[guard.checkPostponement, UnzenInbox.upgradeTo(cutoff),
    /// EtnaInbox.upgradeTo(impl), Unzen trust..., Etna trust..., guard.checkSchedule]`. No L2
    /// action: no L2 contract holds the fork time.
    /// @param _p The postponement inputs.
    /// @return actions_ The actions, in execution order.
    function postponementActions(Postponement memory _p)
        internal
        pure
        returns (Controller.Action[] memory actions_)
    {
        actions_ = new Controller.Action[](4 + _p.unzenTrust.length + _p.etnaTrust.length);
        actions_[0] = _action(
            _p.guard,
            abi.encodeCall(
                EtnaSwitchGuard.checkPostponement,
                (
                    _p.unzenInbox,
                    _p.etnaInbox,
                    _p.oldSchedule,
                    _p.newSchedule.etnaForkTime,
                    _p.newProposalLead,
                    _p.deadline
                )
            )
        );
        actions_[1] =
            _action(_p.unzenInbox, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_p.unzenInboxImpl)));
        actions_[2] =
            _action(_p.etnaInbox, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_p.etnaInboxImpl)));
        uint256 next = _appendTrust(actions_, 3, _p.unzenTrust);
        next = _appendTrust(actions_, next, _p.etnaTrust);
        actions_[next] = _scheduleCheck(_p.guard, _p.unzenInbox, _p.etnaInbox, _p.newSchedule);
    }

    /// @dev Writes one action per trust change from `_start` on.
    /// @param _actions The list being filled.
    /// @param _start The first index to write.
    /// @param _changes The trust changes.
    /// @return next_ The index after the last one written.
    function _appendTrust(
        Controller.Action[] memory _actions,
        uint256 _start,
        TrustChange[] memory _changes
    )
        private
        pure
        returns (uint256 next_)
    {
        next_ = _start;
        for (uint256 i; i < _changes.length; ++i) {
            TrustChange memory change = _changes[i];
            bytes memory data;
            if (change.kind == TrustKind.SgxMrEnclave) {
                data = abi.encodeCall(SgxVerifier.setMrEnclave, (change.id, change.trusted));
            } else if (change.kind == TrustKind.Risc0ImageId) {
                data = abi.encodeCall(Risc0Verifier.setImageIdTrusted, (change.id, change.trusted));
            } else {
                data = abi.encodeCall(SP1Verifier.setProgramTrusted, (change.id, change.trusted));
            }
            _actions[next_++] = _action(change.verifier, data);
        }
    }

    /// @dev The fork-time cross-check that ends both schedule batches.
    /// @param _guard The `EtnaSwitchGuard`.
    /// @param _unzenInbox The Unzen Inbox proxy.
    /// @param _etnaInbox The EtnaInbox proxy.
    /// @param _schedule The schedule the batch installs.
    /// @return The action.
    function _scheduleCheck(
        address _guard,
        address _unzenInbox,
        address _etnaInbox,
        EtnaSwitchGuard.Schedule memory _schedule
    )
        private
        pure
        returns (Controller.Action memory)
    {
        return _action(
            _guard,
            abi.encodeCall(EtnaSwitchGuard.checkSchedule, (_unzenInbox, _etnaInbox, _schedule))
        );
    }

    /// @dev A zero-value action.
    /// @param _target The call target.
    /// @param _data The calldata.
    /// @return The action.
    function _action(
        address _target,
        bytes memory _data
    )
        private
        pure
        returns (Controller.Action memory)
    {
        return Controller.Action({ target: _target, value: 0, data: _data });
    }
}

/// @title BuildEtnaSwitchProposals
/// @notice Logs the L1 DAO actions of an Unzen to Etna switch and their `abi.encode`, the bytes
/// `MainnetDAOController.execute` takes, after checking every input against L1. It broadcasts
/// nothing; the reference contracts its checks create exist only in the script's local EVM.
/// @dev Entry points, each reading the `DeployEtnaSwitch` environment (CONTRACT_OWNER,
/// L1_CHAIN_ID, UNZEN_INBOX, SIGNAL_SERVICE and, after scheduling, INBOX_PROXY) plus:
/// - `readinessActions()`: the readiness proposal's L1 actions, the Unzen trust changes below.
///   Its one L2 message comes from `LibEtnaReadinessL2Message.buildActions`
///   (`script/layer2/etna/BuildEtnaReadinessL2Message.s.sol`).
/// - `schedulingActions()`: every `DeployEtnaSwitch.deployInbox` variable, including the `init`
///   parameters, plus SWITCH_GUARD, PROPOSAL_LEAD (more than FI_MARGIN and still available now),
///   UNZEN_INBOX_IMPLEMENTATION, SIGNAL_SERVICE_IMPLEMENTATION, ETNA_INBOX_IMPLEMENTATION and the
///   Unzen and Etna trust changes.
/// - `postponementActions()`: the new ETNA_FORK_TIME, PROPOSE_MARGIN and FI_MARGIN, PROPOSAL_LEAD
///   for the new fork time, POSTPONEMENT_DEADLINE (B: later than now and no later than the
///   earlier installed cutoff), SWITCH_GUARD, the new UNZEN_INBOX_IMPLEMENTATION and
///   ETNA_INBOX_IMPLEMENTATION, and the trust changes. The old schedule is read from L1.
/// Trust changes are optional comma-separated bytes32 lists named
/// `<UNZEN|ETNA>_<SGX_GETH|SGX_RETH|RISC0|SP1>_<TRUST|UNTRUST>`: MRENCLAVEs for `setMrEnclave`,
/// RISC0 image ids for `setImageIdTrusted` and SP1 program keys for `setProgramTrusted` on the
/// sub-verifier that Unzen's or the EtnaInbox's composite verifier names for that slot.
/// @custom:security-contact security@taiko.xyz
contract BuildEtnaSwitchProposals is DeployEtnaSwitch {
    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Builds the readiness proposal's L1 actions while Unzen is unscheduled.
    /// @return actions_ The Unzen verifier trust changes, in order.
    function readinessActions() external view returns (Controller.Action[] memory actions_) {
        IInbox.Config memory unzen = _liveUnzenConfig();
        require(unzen.signalService == vm.envAddress("SIGNAL_SERVICE"), ScheduleAlreadyInstalled());
        actions_ =
            LibEtnaSwitchActions.readinessActions(_trustChanges("UNZEN", unzen.proofVerifier));
        _logActions("Readiness proposal, L1 actions", actions_);
        console2.log("L2 message: LibEtnaReadinessL2Message.buildActions, logged by");
        console2.log("script/layer2/etna/BuildEtnaReadinessL2Message.s.sol.");
    }

    /// @notice Builds the scheduling proposal after checking every installed address.
    /// @return actions_ The proposal's actions, in execution order.
    function schedulingActions() external returns (Controller.Action[] memory actions_) {
        actions_ = LibEtnaSwitchActions.schedulingActions(_scheduling());
        _logActions("Scheduling proposal", actions_);
    }

    /// @notice Builds a postponement batch after checking it against the installed schedule.
    /// @return actions_ The batch's actions, in execution order.
    function postponementActions() external returns (Controller.Action[] memory actions_) {
        actions_ = LibEtnaSwitchActions.postponementActions(_postponement());
        _logActions("Postponement batch", actions_);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Checks and collects the scheduling inputs. The Unzen Inbox must still save into the
    /// L1 SignalService and the EtnaInbox must be on its bootstrap.
    /// @return s_ The scheduling inputs.
    function _scheduling() private returns (LibEtnaSwitchActions.Scheduling memory s_) {
        IInbox.Config memory unzen = _liveUnzenConfig();
        s_.signalService = vm.envAddress("SIGNAL_SERVICE");
        s_.etnaInbox = _etnaProxy();
        require(
            unzen.signalService == s_.signalService && !IEtnaInbox(s_.etnaInbox).isInitialized(),
            ScheduleAlreadyInstalled()
        );
        IEtnaInbox.Config memory config = _inboxConfig();
        _checkVerifierPolicy(config.proofVerifier);
        s_.guard = _guard();
        s_.schedule = _schedule();
        s_.proposalLead = _proposalLead(s_.schedule);
        s_.unzenInbox = vm.envAddress("UNZEN_INBOX");
        s_.unzenInboxImpl = vm.envAddress("UNZEN_INBOX_IMPLEMENTATION");
        s_.signalServiceImpl = _signalServiceImplementation(s_.signalService);
        s_.etnaInboxImpl = _etnaImplementation(config);
        s_.etnaInit = _initCall();
        s_.unzenTrust = _trustChanges("UNZEN", unzen.proofVerifier);
        s_.etnaTrust = _trustChanges("ETNA", config.proofVerifier);
    }

    /// @dev Checks and collects the postponement inputs. The scheduling proposal must have
    /// executed and the start must be unwritten. The new implementations keep every live
    /// configuration field except the schedule.
    /// @return p_ The postponement inputs.
    function _postponement() private returns (LibEtnaSwitchActions.Postponement memory p_) {
        IInbox.Config memory unzen = _liveUnzenConfig();
        p_.etnaInbox = _etnaProxy();
        require(
            unzen.signalService == p_.etnaInbox && _isReplacement(p_.etnaInbox),
            ScheduleNotInstalled()
        );
        p_.guard = _guard();
        p_.unzenInbox = vm.envAddress("UNZEN_INBOX");
        p_.oldSchedule = _liveSchedule(p_.unzenInbox, p_.etnaInbox);
        p_.newSchedule = _schedule();
        p_.newProposalLead = _proposalLead(p_.newSchedule);
        p_.deadline = SafeCast.toUint48(vm.envUint("POSTPONEMENT_DEADLINE"));
        uint256 maxMargin = p_.oldSchedule.fiMargin > p_.oldSchedule.proposeMargin
            ? p_.oldSchedule.fiMargin
            : p_.oldSchedule.proposeMargin;
        require(
            block.timestamp < p_.deadline
                && uint256(p_.deadline) + maxMargin <= p_.oldSchedule.etnaForkTime,
            InvalidPostponementDeadline()
        );
        p_.unzenInboxImpl = vm.envAddress("UNZEN_INBOX_IMPLEMENTATION");
        _checkCutoffImplementation(p_.unzenInboxImpl, unzen, p_.newSchedule);
        IEtnaInbox.Config memory config = _etnaConfigOf(p_.etnaInbox);
        config.etnaForkTime = p_.newSchedule.etnaForkTime;
        p_.etnaInboxImpl = _etnaImplementation(config);
        p_.unzenTrust = _trustChanges("UNZEN", unzen.proofVerifier);
        p_.etnaTrust = _trustChanges("ETNA", config.proofVerifier);
    }

    /// @dev Reads SWITCH_GUARD and requires this build's `EtnaSwitchGuard` code, which has no
    /// immutables.
    /// @return guard_ The guard.
    function _guard() private returns (address guard_) {
        guard_ = vm.envAddress("SWITCH_GUARD");
        require(
            guard_.code.length != 0 && guard_.codehash == address(new EtnaSwitchGuard()).codehash,
            SwitchIdentityMismatch()
        );
    }

    /// @dev Reads PROPOSAL_LEAD and requires it to exceed `_schedule`'s FI margin and to be still
    /// available now, so the batch is not already late.
    /// @param _schedule The schedule the batch installs.
    /// @return lead_ The lead.
    function _proposalLead(EtnaSwitchGuard.Schedule memory _schedule)
        private
        view
        returns (uint48 lead_)
    {
        lead_ = SafeCast.toUint48(vm.envUint("PROPOSAL_LEAD"));
        require(lead_ > _schedule.fiMargin, InvalidProposalLead());
        require(block.timestamp + lead_ <= _schedule.etnaForkTime, ScheduleTooLate());
    }

    /// @dev Reads the installed schedule from the Unzen Inbox's cutoff implementation and requires
    /// the EtnaInbox to hold the same fork time.
    /// @param _unzenInbox The Unzen Inbox proxy.
    /// @param _etnaInbox The EtnaInbox proxy.
    /// @return schedule_ The installed schedule.
    function _liveSchedule(
        address _unzenInbox,
        address _etnaInbox
    )
        private
        view
        returns (EtnaSwitchGuard.Schedule memory schedule_)
    {
        InboxWithEtnaCutoffs cutoff = InboxWithEtnaCutoffs(_unzenInbox);
        schedule_ = EtnaSwitchGuard.Schedule({
            etnaForkTime: cutoff.ETNA_FORK_TIME(),
            proposeMargin: cutoff.PROPOSE_MARGIN(),
            fiMargin: cutoff.FI_MARGIN()
        });
        require(IEtnaInbox(_etnaInbox).etnaForkTime() == schedule_.etnaForkTime, ScheduleMismatch());
    }

    /// @dev Reads SIGNAL_SERVICE_IMPLEMENTATION and requires the L1 configuration: `VERSION` 1,
    /// `usesBeaconRoots` false and the live proxy's pauser. Its syncer and remote have no getter;
    /// `deploySignalServiceImplementation` fixes them.
    /// @param _signalService The L1 SignalService proxy.
    /// @return impl_ The implementation.
    function _signalServiceImplementation(address _signalService)
        private
        view
        returns (address impl_)
    {
        impl_ = vm.envAddress("SIGNAL_SERVICE_IMPLEMENTATION");
        require(
            impl_.code.length != 0 && SignalService(impl_).VERSION() == 1
                && !SignalService(impl_).usesBeaconRoots()
                && SignalService(impl_).pauser() == _signalPauser(_signalService),
            SwitchIdentityMismatch()
        );
    }

    /// @dev Reads ETNA_INBOX_IMPLEMENTATION and requires it to report exactly `_config`.
    /// @param _config The configuration the implementation must hold.
    /// @return impl_ The implementation.
    function _etnaImplementation(IEtnaInbox.Config memory _config)
        private
        view
        returns (address impl_)
    {
        impl_ = vm.envAddress("ETNA_INBOX_IMPLEMENTATION");
        require(
            impl_.code.length != 0
                && keccak256(abi.encode(_etnaConfigOf(impl_))) == keccak256(abi.encode(_config)),
            SwitchIdentityMismatch()
        );
    }

    /// @dev Reads an EtnaInbox implementation's or proxy's immutable configuration.
    /// @param _inbox The implementation or proxy.
    /// @return config_ Its configuration.
    function _etnaConfigOf(address _inbox) private view returns (IEtnaInbox.Config memory config_) {
        IEtnaInbox inbox = IEtnaInbox(_inbox);
        config_ = IEtnaInbox.Config({
            proofVerifier: inbox.proofVerifier(),
            signalService: inbox.signalService(),
            stakingRegistry: inbox.stakingRegistry(),
            l2ChainId: inbox.l2ChainId(),
            maxBatchBlocks: inbox.maxBatchBlocks(),
            forcedInclusionFeeInGwei: inbox.forcedInclusionFeeInGwei(),
            forcedInclusionFeeDoubleThreshold: inbox.forcedInclusionFeeDoubleThreshold(),
            protocolFeeRecipient: inbox.protocolFeeRecipient(),
            unzenInbox: inbox.unzenInbox(),
            etnaForkTime: inbox.etnaForkTime(),
            recoveryCapacity: inbox.recoveryCapacity()
        });
    }

    /// @dev Reads the `<_prefix>_<slot>_TRUST` and `_UNTRUST` lists for the four image-trusting
    /// slots of `_composite`. A non-empty list needs that slot's sub-verifier, owned by the DAO
    /// without a pending transfer; every id is nonzero and no id is both trusted and untrusted.
    /// @param _prefix UNZEN or ETNA.
    /// @param _composite The composite verifier whose sub-verifiers hold the trust.
    /// @return changes_ Per slot, its trusted then its untrusted ids.
    function _trustChanges(
        string memory _prefix,
        address _composite
    )
        private
        view
        returns (LibEtnaSwitchActions.TrustChange[] memory changes_)
    {
        ComposeVerifier composite = ComposeVerifier(_composite);
        string[4] memory slots = ["SGX_GETH", "SGX_RETH", "RISC0", "SP1"];
        address[4] memory verifiers = [
            composite.sgxGethVerifier(),
            composite.sgxRethVerifier(),
            composite.risc0RethVerifier(),
            composite.sp1RethVerifier()
        ];
        LibEtnaSwitchActions.TrustKind[4] memory kinds = [
            LibEtnaSwitchActions.TrustKind.SgxMrEnclave,
            LibEtnaSwitchActions.TrustKind.SgxMrEnclave,
            LibEtnaSwitchActions.TrustKind.Risc0ImageId,
            LibEtnaSwitchActions.TrustKind.Sp1ProgramVKey
        ];
        // lists[2 * slot] are trusted, lists[2 * slot + 1] untrusted.
        bytes32[][8] memory lists;
        uint256 count;
        for (uint256 i; i < lists.length; ++i) {
            string memory name =
                string.concat(_prefix, "_", slots[i / 2], i % 2 == 0 ? "_TRUST" : "_UNTRUST");
            lists[i] = _envIds(name);
            if (lists[i].length == 0) continue;
            require(verifiers[i / 2] != address(0), MissingSubVerifier(name));
            _requireOwner(verifiers[i / 2]);
            count += lists[i].length;
        }
        changes_ = new LibEtnaSwitchActions.TrustChange[](count);
        uint256 next;
        for (uint256 i; i < lists.length; ++i) {
            bytes32[] memory opposite = lists[i ^ 1];
            for (uint256 j; j < lists[i].length; ++j) {
                bytes32 id = lists[i][j];
                require(id != 0, InvalidTrustId());
                for (uint256 k; k < opposite.length; ++k) {
                    require(opposite[k] != id, ConflictingTrust(id));
                }
                changes_[next++] = LibEtnaSwitchActions.TrustChange({
                    verifier: verifiers[i / 2], kind: kinds[i / 2], id: id, trusted: i % 2 == 0
                });
            }
        }
    }

    /// @dev Reads an optional comma-separated bytes32 list; unset or empty is the empty list.
    /// @param _name The variable name.
    /// @return ids_ The ids.
    function _envIds(string memory _name) private view returns (bytes32[] memory ids_) {
        if (!vm.envExists(_name) || bytes(vm.envString(_name)).length == 0) return ids_;
        return vm.envBytes32(_name, ",");
    }

    /// @dev Logs each action and the list's `abi.encode`.
    /// @param _title The list's name.
    /// @param _actions The actions.
    function _logActions(
        string memory _title,
        Controller.Action[] memory _actions
    )
        private
        pure
    {
        console2.log(_title);
        for (uint256 i; i < _actions.length; ++i) {
            console2.log("action", i);
            console2.log("  target:", _actions[i].target);
            console2.log("  value:", _actions[i].value);
            console2.log("  data:", vm.toString(_actions[i].data));
        }
        console2.log("abi.encode(actions):", vm.toString(abi.encode(_actions)));
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error ConflictingTrust(bytes32 id);
    error InvalidPostponementDeadline();
    error InvalidProposalLead();
    error InvalidTrustId();
    error MissingSubVerifier(string name);
    error ScheduleAlreadyInstalled();
    error ScheduleNotInstalled();
    error ScheduleTooLate();
}
