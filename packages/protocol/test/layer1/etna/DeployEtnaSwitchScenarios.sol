// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BuildEtnaSwitchProposals } from "script/layer1/etna/BuildEtnaSwitchProposals.s.sol";
import { DeployEtnaSwitch } from "script/layer1/etna/DeployEtnaSwitch.s.sol";
import { DeployEtnaVerifiers } from "script/layer1/etna/DeployEtnaVerifiers.s.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaSwitchGuard } from "src/layer1/etna/switch/EtnaSwitchGuard.sol";
import { MainnetDAOController } from "src/layer1/mainnet/MainnetDAOController.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibBytes } from "src/shared/libs/LibBytes.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { InboxTestBase } from "test/layer1/core/inbox/InboxTestBase.sol";

/// @dev Exercises the real switch scripts over a live Unzen Inbox and SignalService owned by a
/// real `MainnetDAOController`: the deployment entry points, then the readiness, scheduling and
/// postponement action lists, executed through the controller (SWITCH.md sections 3 and 7,
/// vectors 5d.h-5d.l). The scripts install nothing themselves.
contract DeployEtnaSwitchScenarios is InboxTestBase {
    uint256 private constant _DEPLOYER_KEY = 0xe7aa;
    uint64 private constant _L2_CHAIN_ID = 167_001;
    uint48 private constant _FORK_TIME = 1_000_000;
    uint48 private constant _PROPOSE_MARGIN = 12;
    uint48 private constant _FI_MARGIN = 500;
    uint48 private constant _LEAD = 10_000;
    /// @dev The first postponement's fork time and its inclusion deadline B, before the installed
    /// forced inclusion cutoff `_FORK_TIME - _FI_MARGIN`.
    uint48 private constant _NEW_FORK_TIME = 1_010_000;
    uint48 private constant _DEADLINE = 999_000;
    /// @dev A further fork time, installed from either schedule.
    uint48 private constant _LATER_FORK_TIME = 1_020_000;
    uint48 private constant _LATER_DEADLINE = 1_009_000;
    uint256 private constant _VALIDATOR_KEY = 0xC0A;
    /// @dev Bounds K at the scripts' default recovery capacity F = 131 (START-10-14).
    uint256 private constant _MIN_STAKE = 7_600_000 ether;
    uint256 private constant _EPOCH_LEN = 5;
    bytes32 private constant _COMMITTEE_RECORD_HASH = bytes32(uint256(123));

    /// @dev Unzen images: trusted before the readiness proposal, the readiness images that read
    /// both checkpoint layouts, and the ones the scheduling and postponement batches pin.
    bytes32 private constant _UNZEN_LEGACY_R0 = keccak256("unzen legacy risc0");
    bytes32 private constant _UNZEN_DUAL_R0 = keccak256("unzen dual-layout risc0");
    bytes32 private constant _UNZEN_DUAL_SP1 = keccak256("unzen dual-layout sp1");
    bytes32 private constant _UNZEN_DUAL_SGX = keccak256("unzen dual-layout mrenclave");
    bytes32 private constant _UNZEN_SCHEDULED_R0 = keccak256("unzen scheduled risc0");
    bytes32 private constant _UNZEN_POSTPONED_R0 = keccak256("unzen postponed risc0");
    /// @dev Etna images under the first and the postponed schedule.
    bytes32 private constant _ETNA_R0 = keccak256("etna risc0");
    bytes32 private constant _ETNA_SP1 = keccak256("etna sp1");
    bytes32 private constant _ETNA_SGX = keccak256("etna mrenclave");
    bytes32 private constant _ETNA_POSTPONED_R0 = keccak256("etna postponed risc0");

    DeployEtnaSwitch private _switch;
    BuildEtnaSwitchProposals private _proposals;
    DeployEtnaVerifiers private _verifiers;
    MainnetDAOController private _dao;
    address private _guard;
    address private _stakingRegistry;
    /// @dev Unzen's image-trusting sub-verifiers: SGX_GETH, SGX_RETH, RISC0 and SP1.
    address[4] private _unzenSubs;
    DeployEtnaVerifiers.VerifierAddresses private _etnaVerifiers;
    /// @dev The last Unzen block, whose checkpoint `_proveThroughEtna` saves.
    uint48 private _unzenTip;

    function _buildConfig() internal override returns (IInbox.Config memory config_) {
        config_ = super._buildConfig();
        for (uint256 i; i < 2; ++i) {
            _unzenSubs[i] = address(
                new SecureSgxVerifier(
                    _L2_CHAIN_ID, address(this), address(verifier), address(0), 1 days
                )
            );
        }
        _unzenSubs[2] = address(new Risc0Verifier(_L2_CHAIN_ID, address(verifier), address(this)));
        _unzenSubs[3] = address(new SP1Verifier(_L2_CHAIN_ID, address(verifier), address(this)));
        Risc0Verifier(_unzenSubs[2]).setImageIdTrusted(_UNZEN_LEGACY_R0, true);
        config_.proofVerifier = address(
            new ZkRequiredVerifier(_unzenSubs[0], _unzenSubs[1], _unzenSubs[2], _unzenSubs[3])
        );
    }

    /// @dev Called by the devnet script test in its serial environment-variable scenarios.
    function run() external {
        vm.pauseGasMetering();
        // Deployed from their artifacts, so this contract does not embed the scripts' code.
        _switch = DeployEtnaSwitch(deployCode("DeployEtnaSwitch.s.sol:DeployEtnaSwitch"));
        _proposals = BuildEtnaSwitchProposals(
            deployCode("BuildEtnaSwitchProposals.s.sol:BuildEtnaSwitchProposals")
        );
        _verifiers =
            DeployEtnaVerifiers(deployCode("DeployEtnaVerifiers.s.sol:DeployEtnaVerifiers"));
        _dao = MainnetDAOController(
            payable(address(
                    new ERC1967Proxy(
                        address(new MainnetDAOController()),
                        abi.encodeCall(MainnetDAOController.init, (address(this)))
                    )
                ))
        );
        _handOver(address(inbox));
        _handOver(address(signalService));
        for (uint256 i; i < _unzenSubs.length; ++i) {
            _handOver(_unzenSubs[i]);
        }
        _setEnvironment();

        _assertOwnerRequired("");
        _assertOwnerRequired(vm.toString(address(0)));
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(_dao)));

        (address proxy, address implementation, address cutoff, address signalImpl) = _deploy();
        IInbox.ProveInput memory input = _buildBatchInput(1);
        _readiness();
        _schedule(proxy, implementation, cutoff, signalImpl);
        _assertPreparersAfterScheduling(proxy);
        _postpone(proxy, input);
    }

    // ---------------------------------------------------------------
    // Deployment entry points
    // ---------------------------------------------------------------

    /// @dev Deploys every switch contract with `DeployEtnaSwitch` and `DeployEtnaVerifiers`. Each
    /// new control surface is owned by the DAO controller; nothing is installed.
    function _deploy()
        private
        returns (address proxy_, address implementation_, address cutoff_, address signalImpl_)
    {
        address retainedSignal;
        (proxy_, retainedSignal) = _switch.deployInboxProxy();
        assertEq(retainedSignal, address(signalService));
        assertEq(EssentialContract(proxy_).owner(), address(_dao));
        assertEq(EssentialContract(proxy_).pendingOwner(), address(0));
        vm.setEnv("INBOX_PROXY", vm.toString(proxy_));
        address registry = _switch.deployRegistry();
        _stakingRegistry = registry;
        vm.setEnv("STAKING_REGISTRY", vm.toString(registry));
        _registerValidator(IEtnaStakingRegistry(registry));
        _etnaVerifiers = _verifiers.run();
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(_etnaVerifiers.proofVerifier));
        cutoff_ = _switch.deployUnzenInboxImplementation();
        _assertCutoff(cutoff_, proxy_, _FORK_TIME);
        vm.setEnv("UNZEN_INBOX_IMPLEMENTATION", vm.toString(cutoff_));

        address[5] memory controlled = [
            proxy_,
            registry,
            _etnaVerifiers.sgxReth,
            _etnaVerifiers.risc0Reth,
            _etnaVerifiers.sp1Reth
        ];
        for (uint256 i; i < controlled.length; ++i) {
            assertEq(EssentialContract(controlled[i]).owner(), address(_dao));
            assertEq(EssentialContract(controlled[i]).pendingOwner(), address(0));
            uint256 snapshot = vm.snapshotState();
            vm.prank(address(_dao));
            EssentialContract(controlled[i]).transferOwnership(Bob);
            vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
            _switch.deployInbox();
            vm.prank(Bob);
            EssentialContract(controlled[i]).acceptOwnership();
            vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
            _switch.deployInbox();
            assertTrue(vm.revertToState(snapshot));
        }

        // The preflight requires the cutoff implementation's live cutoffs to sit the configured
        // margins before the fork time.
        vm.setEnv("PROPOSE_MARGIN", "13");
        vm.expectRevert(DeployEtnaSwitch.ScheduleMismatch.selector);
        _switch.deployInbox();
        vm.setEnv("PROPOSE_MARGIN", vm.toString(_PROPOSE_MARGIN));

        implementation_ = _switch.deployInbox();
        vm.setEnv("ETNA_INBOX_IMPLEMENTATION", vm.toString(implementation_));
        assertEq(EtnaInbox(implementation_).stakingRegistry(), registry);
        assertEq(EtnaInbox(implementation_).proofVerifier(), _etnaVerifiers.proofVerifier);
        assertEq(EtnaInbox(implementation_).etnaForkTime(), _FORK_TIME);
        assertFalse(EtnaInbox(proxy_).isInitialized());

        signalImpl_ = _switch.deploySignalServiceImplementation();
        vm.setEnv("SIGNAL_SERVICE_IMPLEMENTATION", vm.toString(signalImpl_));
        assertFalse(SignalService(signalImpl_).usesBeaconRoots());
        assertEq(SignalService(signalImpl_).VERSION(), 1);

        _guard = _switch.deploySwitchGuard();
        assertEq(_guard.codehash, address(new EtnaSwitchGuard()).codehash);
        vm.setEnv("SWITCH_GUARD", vm.toString(_guard));

        // Before the scheduling proposal executes, every preparer refuses an Etna target that is
        // the Unzen Inbox or the retained store, or that the DAO does not own without a pending
        // transfer.
        address[2] memory wrongTargets = [address(inbox), address(signalService)];
        for (uint256 i; i < wrongTargets.length; ++i) {
            vm.setEnv("INBOX_PROXY", vm.toString(wrongTargets[i]));
            _assertPreparersRefuse();
        }
        vm.setEnv("INBOX_PROXY", vm.toString(proxy_));
        uint256 ownerSnapshot = vm.snapshotState();
        vm.prank(address(_dao));
        EssentialContract(proxy_).transferOwnership(Bob);
        _assertPreparersRefuse();
        vm.prank(Bob);
        EssentialContract(proxy_).acceptOwnership();
        _assertPreparersRefuse();
        assertTrue(vm.revertToState(ownerSnapshot));
    }

    /// @dev Every preparer that depends on INBOX_PROXY and SIGNAL_SERVICE refuses them before
    /// broadcasting.
    function _assertPreparersRefuse() private {
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _switch.deployRegistry();
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _switch.deployUnzenInboxImplementation();
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _switch.deploySignalServiceImplementation();
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _switch.deployInbox();
    }

    // ---------------------------------------------------------------
    // Proposal 1: readiness
    // ---------------------------------------------------------------

    /// @dev The readiness proposal's L1 actions trust the Unzen images that read both checkpoint
    /// layouts while Unzen stays unscheduled; its L2 message is built separately.
    function _readiness() private {
        vm.setEnv("UNZEN_SGX_RETH_TRUST", vm.toString(_UNZEN_DUAL_SGX));
        vm.setEnv("UNZEN_RISC0_TRUST", vm.toString(_UNZEN_DUAL_R0));
        vm.setEnv("UNZEN_SP1_TRUST", vm.toString(_UNZEN_DUAL_SP1));

        // An id may not be both trusted and untrusted, and a slot Unzen lacks has no trust.
        vm.setEnv("UNZEN_RISC0_UNTRUST", vm.toString(_UNZEN_DUAL_R0));
        vm.expectRevert(
            abi.encodeWithSelector(
                BuildEtnaSwitchProposals.ConflictingTrust.selector, _UNZEN_DUAL_R0
            )
        );
        _proposals.readinessActions();
        vm.setEnv("UNZEN_RISC0_UNTRUST", "");

        Controller.Action[] memory actions = _proposals.readinessActions();
        assertEq(actions.length, 3);
        assertEq(actions[0].target, _unzenSubs[1]);
        assertEq(actions[1].target, _unzenSubs[2]);
        assertEq(actions[2].target, _unzenSubs[3]);
        _execute(actions);
        assertTrue(SecureSgxVerifier(_unzenSubs[1]).trustedUserMrEnclave(_UNZEN_DUAL_SGX));
        assertTrue(Risc0Verifier(_unzenSubs[2]).isImageTrusted(_UNZEN_DUAL_R0));
        assertTrue(SP1Verifier(_unzenSubs[3]).isProgramTrusted(_UNZEN_DUAL_SP1));
        assertEq(inbox.getConfig().signalService, address(signalService), "still unscheduled");
        _setTrust("UNZEN", "", "", "", "");
    }

    // ---------------------------------------------------------------
    // Proposal 2: scheduling
    // ---------------------------------------------------------------

    /// @dev Builds the scheduling proposal, shows that a late inclusion reverts as a whole (5d.k),
    /// then executes it exactly `_LEAD` before the fork time (5d.h, 5d.i).
    function _schedule(
        address _proxy,
        address _implementation,
        address _cutoff,
        address _signalImpl
    )
        private
    {
        vm.setEnv("PROPOSAL_LEAD", vm.toString(_FI_MARGIN));
        vm.expectRevert(BuildEtnaSwitchProposals.InvalidProposalLead.selector);
        _proposals.schedulingActions();
        vm.setEnv("PROPOSAL_LEAD", vm.toString(_LEAD));
        // The Etna composite has no SGX_GETH sub-verifier to trust.
        vm.setEnv("ETNA_SGX_GETH_TRUST", vm.toString(_ETNA_SGX));
        vm.expectRevert(
            abi.encodeWithSelector(
                BuildEtnaSwitchProposals.MissingSubVerifier.selector, "ETNA_SGX_GETH_TRUST"
            )
        );
        _proposals.schedulingActions();
        vm.setEnv("ETNA_SGX_GETH_TRUST", "");
        _setTrust("UNZEN", "", "", vm.toString(_UNZEN_SCHEDULED_R0), "");
        vm.setEnv("UNZEN_RISC0_UNTRUST", vm.toString(_UNZEN_LEGACY_R0));
        _setTrust("ETNA", "", vm.toString(_ETNA_SGX), vm.toString(_ETNA_R0), vm.toString(_ETNA_SP1));
        _assertIdentitiesRefused(_proxy, _signalImpl);

        Controller.Action[] memory actions = _proposals.schedulingActions();
        assertEq(actions.length, 11);
        assertEq(actions[0].target, _guard);
        assertEq(actions[1].target, address(inbox));
        assertEq(actions[1].data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_cutoff)));
        assertEq(actions[2].target, address(signalService));
        assertEq(actions[2].data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_signalImpl)));
        assertEq(actions[3].target, _guard);
        assertEq(
            actions[3].data,
            abi.encodeCall(
                EtnaSwitchGuard.checkL1SignalService,
                (address(signalService), _signalImpl, _signalImpl.codehash)
            )
        );
        assertEq(actions[4].target, _proxy);
        assertEq(actions[4].data, _switch.ownerUpgradeCall(_implementation));
        assertEq(actions[10].target, _guard);
        _setTrust("UNZEN", "", "", "", "");
        vm.setEnv("UNZEN_RISC0_UNTRUST", "");
        _setTrust("ETNA", "", "", "", "");

        address unzenImpl = _unzenImplementation();
        address signalImpl = signalService.impl();
        uint256 snapshot = vm.snapshotState();
        vm.warp(_FORK_TIME - _LEAD + 1);
        _expectGuardRevert(EtnaSwitchGuard.ProposalLeadMissed.selector);
        _execute(actions);
        assertEq(_unzenImplementation(), unzenImpl);
        assertEq(signalService.impl(), signalImpl);
        assertFalse(EtnaInbox(_proxy).isInitialized());
        assertFalse(Risc0Verifier(_unzenSubs[2]).isImageTrusted(_UNZEN_SCHEDULED_R0));
        assertFalse(Risc0Verifier(_etnaVerifiers.risc0Reth).isImageTrusted(_ETNA_R0));
        // The builder refuses to prepare a proposal that is already late.
        vm.expectRevert(BuildEtnaSwitchProposals.ScheduleTooLate.selector);
        _proposals.schedulingActions();
        assertTrue(vm.revertToState(snapshot));

        // The guard pins the implementation's code hash: a batch that names the installed address
        // with another hash reverts as a whole.
        bytes memory pinned = actions[3].data;
        actions[3].data = abi.encodeCall(
            EtnaSwitchGuard.checkL1SignalService,
            (address(signalService), _signalImpl, keccak256("other code"))
        );
        vm.warp(_FORK_TIME - _LEAD);
        _expectGuardRevert(EtnaSwitchGuard.UnexpectedCodeHash.selector);
        _execute(actions);
        assertEq(signalService.impl(), signalImpl);
        assertTrue(vm.revertToState(snapshot));
        actions[3].data = pinned;

        vm.warp(_FORK_TIME - _LEAD);
        _execute(actions);
        assertEq(_unzenImplementation(), _cutoff);
        assertEq(signalService.impl(), _signalImpl);
        assertFalse(signalService.usesBeaconRoots());
        EtnaInbox etna = EtnaInbox(_proxy);
        assertEq(EssentialContract(_proxy).impl(), _implementation);
        assertTrue(etna.isInitialized());
        assertEq(etna.etnaForkTime(), _FORK_TIME);
        assertEq(etna.genesis().epochLenL2, _EPOCH_LEN);
        assertEq(etna.genesisCommitteeRecordHash(), _COMMITTEE_RECORD_HASH);
        _assertStartUnwritten(etna);
        assertEq(inbox.getConfig().signalService, _proxy);
        assertEq(InboxWithEtnaCutoffs(address(inbox)).proposeCutoff(), _FORK_TIME - 12);
        assertTrue(Risc0Verifier(_unzenSubs[2]).isImageTrusted(_UNZEN_SCHEDULED_R0));
        assertFalse(Risc0Verifier(_unzenSubs[2]).isImageTrusted(_UNZEN_LEGACY_R0));
        assertTrue(Risc0Verifier(_unzenSubs[2]).isImageTrusted(_UNZEN_DUAL_R0));
        assertTrue(SecureSgxVerifier(_etnaVerifiers.sgxReth).trustedUserMrEnclave(_ETNA_SGX));
        assertTrue(Risc0Verifier(_etnaVerifiers.risc0Reth).isImageTrusted(_ETNA_R0));
        assertTrue(SP1Verifier(_etnaVerifiers.sp1Reth).isProgramTrusted(_ETNA_SP1));

        // Neither proposal can be prepared again.
        vm.expectRevert(BuildEtnaSwitchProposals.ScheduleAlreadyInstalled.selector);
        _proposals.readinessActions();
        vm.expectRevert(BuildEtnaSwitchProposals.ScheduleAlreadyInstalled.selector);
        _proposals.schedulingActions();
    }

    /// @dev The scheduling builder compares the L1 SignalService implementation's runtime code with
    /// one rebuilt from the expected syncer, remote, pauser and flag, which have no getters, and
    /// the guard's code with this build's: each other identity is refused.
    function _assertIdentitiesRefused(address _proxy, address _signalImpl) private {
        address remote = _switch.l2SignalServiceAddress(_L2_CHAIN_ID);
        address pauser = signalService.pauser();
        address[4] memory wrong = [
            address(new SignalService(Bob, remote, pauser, false)),
            address(new SignalService(_proxy, Carol, pauser, false)),
            address(new SignalService(_proxy, remote, Bob, false)),
            address(new SignalService(_proxy, remote, pauser, true))
        ];
        for (uint256 i; i < wrong.length; ++i) {
            vm.setEnv("SIGNAL_SERVICE_IMPLEMENTATION", vm.toString(wrong[i]));
            vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
            _proposals.schedulingActions();
        }
        vm.setEnv("SIGNAL_SERVICE_IMPLEMENTATION", vm.toString(_signalImpl));

        vm.setEnv("SWITCH_GUARD", vm.toString(_signalImpl));
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _proposals.schedulingActions();
        vm.setEnv("SWITCH_GUARD", vm.toString(_guard));
    }

    /// @dev Once the proposal has executed, the live Unzen Inbox reports the Etna Inbox, and a
    /// postponement can still be prepared from it (SWITCH.md section 7); any other store is
    /// refused.
    function _assertPreparersAfterScheduling(address _proxy) private {
        vm.setEnv("INBOX_PROXY", vm.toString(_stakingRegistry));
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _switch.deployUnzenInboxImplementation();
        vm.setEnv("INBOX_PROXY", vm.toString(_proxy));
        // So is another DAO-owned version-1 store: the installed Etna Inbox saves into the
        // retained one.
        address otherStore = address(_deploySignalService(_proxy));
        _handOver(otherStore);
        vm.setEnv("SIGNAL_SERVICE", vm.toString(otherStore));
        _assertPreparersRefuse();
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(signalService)));
        // A replacement fork time must be later than the installed one.
        vm.expectRevert(DeployEtnaSwitch.ForkTimeNotLater.selector);
        _switch.deployUnzenInboxImplementation();
        vm.expectRevert(DeployEtnaSwitch.ForkTimeNotLater.selector);
        _switch.deployInbox();
    }

    // ---------------------------------------------------------------
    // Postponement
    // ---------------------------------------------------------------

    /// @dev Prepares postponements to `_NEW_FORK_TIME` and `_LATER_FORK_TIME` from the freshly
    /// scheduled state, shows each rejection of 5d.k, then postpones from that state and again
    /// from the postponed state after Unzen's tip has been proven through the Etna Inbox (5d.j,
    /// 5d.l). Finally the start latches the tip at the last fork time.
    function _postpone(address _proxy, IInbox.ProveInput memory _input) private {
        (address newCutoff, address newImpl) = _deployReplacement(_NEW_FORK_TIME);
        (address laterCutoff, address laterImpl) = _deployReplacement(_LATER_FORK_TIME);

        // The batch's own preflight.
        _setPostponement(_NEW_FORK_TIME, newCutoff, newImpl, _LEAD, _FORK_TIME - _FI_MARGIN + 1);
        vm.expectRevert(BuildEtnaSwitchProposals.InvalidPostponementDeadline.selector);
        _proposals.postponementActions();

        _setPostponement(_NEW_FORK_TIME, newCutoff, newImpl, 15_000, _DEADLINE);
        Controller.Action[] memory leadless = _proposals.postponementActions();
        _setPostponement(_LATER_FORK_TIME, laterCutoff, laterImpl, _LEAD, _DEADLINE);
        Controller.Action[] memory competing = _proposals.postponementActions();
        _setPostponement(_NEW_FORK_TIME, newCutoff, newImpl, _LEAD, _DEADLINE);
        _setTrust("UNZEN", "", "", vm.toString(_UNZEN_POSTPONED_R0), "");
        vm.setEnv("UNZEN_RISC0_UNTRUST", vm.toString(_UNZEN_SCHEDULED_R0));
        _setTrust("ETNA", "", "", vm.toString(_ETNA_POSTPONED_R0), "");
        vm.setEnv("ETNA_RISC0_UNTRUST", vm.toString(_ETNA_R0));
        Controller.Action[] memory postponement = _proposals.postponementActions();
        _setTrust("UNZEN", "", "", "", "");
        vm.setEnv("UNZEN_RISC0_UNTRUST", "");
        _setTrust("ETNA", "", "", "", "");
        vm.setEnv("ETNA_RISC0_UNTRUST", "");
        assertEq(postponement.length, 8);
        assertEq(postponement[1].data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (newCutoff)));
        assertEq(postponement[2].data, _switch.ownerUpgradeCall(newImpl));
        _assertNoL2Action(postponement, _proxy);
        _assertNoL2Action(competing, _proxy);

        uint256 snapshot = vm.snapshotState();
        // 5d.k: run after the start write, which latches the proven tip at the fork time.
        _proveThroughEtna(_proxy, _input);
        EtnaInbox etna = EtnaInbox(_proxy);
        vm.warp(_FORK_TIME - 1);
        vm.expectRevert(IEtnaInbox.BeforeEtnaForkTime.selector);
        etna.setOrigin(_unzenTip);
        vm.warp(_FORK_TIME);
        vm.prank(Carol);
        etna.setOrigin(_unzenTip);
        assertEq(etna.generationStartHeight(), _unzenTip);
        _expectGuardRevert(EtnaSwitchGuard.StartAlreadyWritten.selector);
        _execute(postponement);
        vm.expectRevert(DeployEtnaSwitch.SwitchAlreadyStarted.selector);
        _proposals.postponementActions();
        assertTrue(vm.revertToState(snapshot));

        // 5d.k: submitted before B, included at it.
        vm.warp(_DEADLINE);
        _expectGuardRevert(EtnaSwitchGuard.PostponementDeadlinePassed.selector);
        _execute(postponement);
        assertTrue(vm.revertToState(snapshot));

        // 5d.k: the new schedule lacks its lead when the batch is included.
        vm.warp(_NEW_FORK_TIME - 15_000 + 1);
        _expectGuardRevert(EtnaSwitchGuard.ProposalLeadMissed.selector);
        _execute(leadless);
        assertTrue(vm.revertToState(snapshot));

        // 5d.k: the batch names an old schedule that another postponement has replaced.
        _execute(competing);
        _expectGuardRevert(EtnaSwitchGuard.EtnaForkTimeMismatch.selector);
        _execute(postponement);
        assertTrue(vm.revertToState(snapshot));

        // 5d.j: from the freshly scheduled state, preserving the Inbox state.
        vm.prank(address(_dao));
        etna.invalidateRecoveryNonce(0);
        bytes32 committeeConfigHash = etna.committeeConfigHash();
        _execute(postponement);
        _assertSchedule(_proxy, newCutoff, newImpl, _NEW_FORK_TIME);
        assertEq(etna.recoveryNonce(), 1);
        assertEq(etna.committeeConfigHash(), committeeConfigHash);
        assertEq(etna.genesis().epochLenL2, _EPOCH_LEN);
        assertTrue(Risc0Verifier(_unzenSubs[2]).isImageTrusted(_UNZEN_POSTPONED_R0));
        assertFalse(Risc0Verifier(_unzenSubs[2]).isImageTrusted(_UNZEN_SCHEDULED_R0));
        assertTrue(Risc0Verifier(_etnaVerifiers.risc0Reth).isImageTrusted(_ETNA_POSTPONED_R0));
        assertFalse(Risc0Verifier(_etnaVerifiers.risc0Reth).isImageTrusted(_ETNA_R0));

        // 5d.j: again from the postponed state, after Unzen's tip has been proven through the
        // Etna Inbox, with no trust change.
        _proveThroughEtna(_proxy, _input);
        _setPostponement(_LATER_FORK_TIME, laterCutoff, laterImpl, _LEAD, _LATER_DEADLINE);
        Controller.Action[] memory again = _proposals.postponementActions();
        assertEq(again.length, 4);
        _assertNoL2Action(again, _proxy);
        _execute(again);
        _assertSchedule(_proxy, laterCutoff, laterImpl, _LATER_FORK_TIME);

        // The start latches the tip only from the installed fork time on.
        vm.warp(_NEW_FORK_TIME);
        vm.expectRevert(IEtnaInbox.BeforeEtnaForkTime.selector);
        etna.setOrigin(_unzenTip);
        vm.warp(_LATER_FORK_TIME);
        vm.prank(Carol);
        etna.setOrigin(_unzenTip);
        assertEq(etna.generationStartHeight(), _unzenTip);
        vm.expectRevert(DeployEtnaSwitch.SwitchAlreadyStarted.selector);
        _switch.ownerUpgradeCall(laterImpl);
    }

    /// @dev Deploys the cutoff and Etna implementations of a postponement to `_forkTime`.
    function _deployReplacement(uint48 _forkTime)
        private
        returns (address cutoff_, address implementation_)
    {
        vm.setEnv("ETNA_FORK_TIME", vm.toString(_forkTime));
        cutoff_ = _switch.deployUnzenInboxImplementation();
        _assertCutoff(cutoff_, vm.envAddress("INBOX_PROXY"), _forkTime);
        vm.setEnv("UNZEN_INBOX_IMPLEMENTATION", vm.toString(cutoff_));
        implementation_ = _switch.deployInbox();
        assertEq(EtnaInbox(implementation_).etnaForkTime(), _forkTime);
    }

    function _setPostponement(
        uint48 _forkTime,
        address _cutoff,
        address _implementation,
        uint48 _lead,
        uint48 _deadline
    )
        private
    {
        vm.setEnv("ETNA_FORK_TIME", vm.toString(_forkTime));
        vm.setEnv("UNZEN_INBOX_IMPLEMENTATION", vm.toString(_cutoff));
        vm.setEnv("ETNA_INBOX_IMPLEMENTATION", vm.toString(_implementation));
        vm.setEnv("PROPOSAL_LEAD", vm.toString(_lead));
        vm.setEnv("POSTPONEMENT_DEADLINE", vm.toString(_deadline));
    }

    /// @dev Both L1 configurations hold `_forkTime`, and the start is still unwritten.
    function _assertSchedule(
        address _proxy,
        address _cutoff,
        address _implementation,
        uint48 _forkTime
    )
        private
    {
        assertEq(_unzenImplementation(), _cutoff);
        assertEq(EssentialContract(_proxy).impl(), _implementation);
        assertEq(EtnaInbox(_proxy).etnaForkTime(), _forkTime);
        assertEq(InboxWithEtnaCutoffs(address(inbox)).ETNA_FORK_TIME(), _forkTime);
        assertEq(InboxWithEtnaCutoffs(address(inbox)).proposeCutoff(), _forkTime - 12);
        assertEq(inbox.getConfig().signalService, _proxy);
        assertTrue(EtnaInbox(_proxy).isInitialized());
        _assertStartUnwritten(EtnaInbox(_proxy));
    }

    /// @dev 5d.l, 5d.m: the batch only calls the guard, the two Inboxes and image-trusting L1
    /// sub-verifiers, so it sends no L2 message.
    function _assertNoL2Action(
        Controller.Action[] memory _actions,
        address _proxy
    )
        private
        view
    {
        for (uint256 i; i < _actions.length; ++i) {
            address target = _actions[i].target;
            assertEq(_actions[i].value, 0);
            assertTrue(
                target == _guard || target == address(inbox) || target == _proxy
                    || target == _unzenSubs[2] || target == _etnaVerifiers.risc0Reth,
                "L1 target"
            );
        }
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Has the Unzen Inbox prove a proposal made before the switch: its `prove` saves the
    /// checkpoint through the Etna Inbox (vectors 5d.h, 5d.i and 5.u).
    function _proveThroughEtna(address _proxy, IInbox.ProveInput memory _input) private {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: _input.commitment.endBlockNumber,
            blockHash: _input.commitment.transitions[0].blockHash,
            stateRoot: _input.commitment.endStateRoot
        });
        _unzenTip = checkpoint.blockNumber;
        vm.mockCall(
            config.proofVerifier, abi.encodeWithSelector(IProofVerifier.verifyProof.selector), ""
        );
        vm.expectCall(_proxy, abi.encodeCall(EtnaInbox.saveCheckpoint, (checkpoint)));
        _prove(_input);
        ICheckpointStore.Checkpoint memory saved =
            signalService.getCheckpoint(checkpoint.blockNumber);
        assertEq(saved.blockHash, checkpoint.blockHash);
        assertEq(saved.stateRoot, checkpoint.stateRoot);
        assertEq(inbox.getCoreState().lastFinalizedProposalId, _input.commitment.firstProposalId);

        // The L1 SignalService accepts no checkpoint from the Unzen Inbox directly.
        checkpoint.blockNumber += 1;
        vm.prank(address(inbox));
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        signalService.saveCheckpoint(checkpoint);
    }

    function _execute(Controller.Action[] memory _actions) private {
        _dao.execute(abi.encode(_actions));
    }

    /// @dev The controller wraps a failed action's custom error in `INNER_ERROR`.
    function _expectGuardRevert(bytes4 _selector) private {
        vm.expectRevert(
            abi.encodeWithSelector(LibBytes.INNER_ERROR.selector, abi.encodePacked(_selector))
        );
    }

    /// @dev Transfers `_controlled` to the DAO controller, which accepts it.
    function _handOver(address _controlled) private {
        Ownable2Step(_controlled).transferOwnership(address(_dao));
        _dao.acceptOwnershipOf(_controlled);
        assertEq(Ownable2Step(_controlled).owner(), address(_dao));
    }

    function _setTrust(
        string memory _prefix,
        string memory _sgxGeth,
        string memory _sgxReth,
        string memory _risc0,
        string memory _sp1
    )
        private
    {
        vm.setEnv(string.concat(_prefix, "_SGX_GETH_TRUST"), _sgxGeth);
        vm.setEnv(string.concat(_prefix, "_SGX_RETH_TRUST"), _sgxReth);
        vm.setEnv(string.concat(_prefix, "_RISC0_TRUST"), _risc0);
        vm.setEnv(string.concat(_prefix, "_SP1_TRUST"), _sp1);
    }

    function _unzenImplementation() private view returns (address) {
        return EssentialContract(address(inbox)).impl();
    }

    function _assertStartUnwritten(EtnaInbox _etna) private {
        (uint48 height, bytes32 blockHash) = _etna.etnaStart();
        assertEq(height, 0);
        assertEq(blockHash, bytes32(0));
        assertEq(_etna.genesis().startStateRoot, bytes32(0));
        vm.expectRevert(IEtnaInbox.StartNotWritten.selector);
        _etna.generationStartHeight();
    }

    function _registerValidator(IEtnaStakingRegistry _registry) private {
        bondToken.mint(Alice, _MIN_STAKE);
        bytes memory key = EtnaTestKeys.publicKey(_VALIDATOR_KEY);
        bytes memory pop = EtnaTestKeys.popSig(_VALIDATOR_KEY, _registry, Alice);
        vm.startPrank(Alice);
        bondToken.approve(address(_registry), _MIN_STAKE);
        _registry.register(key, _MIN_STAKE, pop);
        vm.stopPrank();
        vm.setEnv("GENESIS_CUTOFF", vm.toString(block.number));
        vm.roll(block.number + 10);
    }

    /// @dev The cutoff implementation keeps every live `getConfig()` field except
    /// `signalService`, which names the Etna Inbox proxy (START-10-5d).
    function _assertCutoff(address _cutoff, address _proxy, uint48 _forkTime) private view {
        IInbox.Config memory expected = inbox.getConfig();
        expected.signalService = _proxy;
        assertEq(
            keccak256(abi.encode(InboxWithEtnaCutoffs(_cutoff).getConfig())),
            keccak256(abi.encode(expected))
        );
        assertEq(InboxWithEtnaCutoffs(_cutoff).ETNA_FORK_TIME(), _forkTime);
        assertEq(InboxWithEtnaCutoffs(_cutoff).proposeCutoff(), _forkTime - _PROPOSE_MARGIN);
        assertEq(InboxWithEtnaCutoffs(_cutoff).FI_CUTOFF(), _forkTime - _FI_MARGIN);
    }

    function _assertOwnerRequired(string memory _value) private {
        vm.setEnv("CONTRACT_OWNER", _value);
        vm.expectRevert(bytes4(keccak256("ExplicitOwnerRequired()")));
        _switch.deployInboxProxy();
        vm.expectRevert(DeployEtnaVerifiers.InvalidOwner.selector);
        _verifiers.run();
    }

    function _setEnvironment() private {
        vm.setEnv("PRIVATE_KEY", vm.toString(_DEPLOYER_KEY));
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("L2_CHAIN_ID", vm.toString(_L2_CHAIN_ID));
        vm.setEnv("UNZEN_INBOX", vm.toString(address(inbox)));
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(signalService)));
        vm.setEnv("ETNA_FORK_TIME", vm.toString(_FORK_TIME));
        vm.setEnv("PROPOSE_MARGIN", vm.toString(_PROPOSE_MARGIN));
        vm.setEnv("FI_MARGIN", vm.toString(_FI_MARGIN));
        vm.setEnv(
            "REMOTE_SIGNAL_SERVICE", vm.toString(_switch.l2SignalServiceAddress(_L2_CHAIN_ID))
        );
        vm.setEnv("TAIKO_TOKEN", vm.toString(address(bondToken)));
        vm.setEnv("REGISTRY_MIN_STAKE", vm.toString(_MIN_STAKE));
        vm.setEnv("REGISTRY_ACTIVATION_DELAY", "10");
        vm.setEnv("REGISTRY_EXIT_DELAY", "20");
        vm.setEnv("REGISTRY_WITHDRAWAL_DELAY", "30");
        vm.setEnv("SLASH_BOUNTY_BPS", "1000");
        vm.setEnv("REGISTRY_FORFEIT_BPS", "1000");
        vm.setEnv("SLASH_SINK", vm.toString(David));
        vm.setEnv("MAX_BATCH_BLOCKS", "1000");
        vm.setEnv("EPOCH_LEN_L2", vm.toString(_EPOCH_LEN));
        vm.setEnv("COMMITTEE_RECORD_HASH", vm.toString(_COMMITTEE_RECORD_HASH));
        vm.setEnv("ETNA_VP_UNIT", "1000000000");
        vm.setEnv("ETNA_N_MAX", "32");
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "64");
        vm.setEnv("FORCED_INCLUSION_DELAY", "1200");
        vm.setEnv("MAX_ANCHOR_AGE", "1152");
        vm.setEnv("FORCED_INCLUSION_FEE_GWEI", "10000000");
        vm.setEnv("FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD", "50");
        vm.setEnv("PROTOCOL_FEE_RECIPIENT", vm.toString(Emma));
        vm.setEnv("DCAP_ATTESTATION", vm.toString(address(verifier)));
        vm.setEnv("SGX_REGISTRAR", vm.toString(address(0)));
        vm.setEnv("SGX_INSTANCE_VALIDITY_DELAY", "1");
        vm.setEnv("R0_GROTH16_VERIFIER", vm.toString(address(verifier)));
        vm.setEnv("SP1_PLONK_VERIFIER", vm.toString(address(verifier)));
        _setTrust("UNZEN", "", "", "", "");
        _setTrust("ETNA", "", "", "", "");
        string[4] memory slots = ["SGX_GETH", "SGX_RETH", "RISC0", "SP1"];
        for (uint256 i; i < slots.length; ++i) {
            vm.setEnv(string.concat("UNZEN_", slots[i], "_UNTRUST"), "");
            vm.setEnv(string.concat("ETNA_", slots[i], "_UNTRUST"), "");
        }
        vm.deal(vm.addr(_DEPLOYER_KEY), 100 ether);
    }
}
