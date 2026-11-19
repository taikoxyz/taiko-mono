// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { DeployEtnaSwitch } from "script/layer1/etna/DeployEtnaSwitch.s.sol";
import { DeployEtnaVerifiers } from "script/layer1/etna/DeployEtnaVerifiers.s.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { InboxTestBase } from "test/layer1/core/inbox/InboxTestBase.sol";

/// @dev Exercises the real scripts over a live Unzen Inbox and SignalService. No trust or
/// initialization is installed by the switching script; the DAO owns each new control surface.
contract DeployEtnaSwitchScenarios is InboxTestBase {
    uint256 private constant _DEPLOYER_KEY = 0xe7aa;
    uint48 private constant _FORK_TIME = 1_000_000;
    uint48 private constant _NEW_FORK_TIME = _FORK_TIME + 5000;
    uint256 private constant _VALIDATOR_KEY = 0xC0A;
    uint256 private constant _MIN_STAKE = 250_000 ether;
    uint256 private constant _EPOCH_LEN = 5;
    bytes32 private constant _COMMITTEE_RECORD_HASH = bytes32(uint256(123));

    DeployEtnaSwitch private _switch;
    DeployEtnaVerifiers private _verifiers;

    function _buildConfig() internal override returns (IInbox.Config memory config_) {
        config_ = super._buildConfig();
        config_.proofVerifier =
            address(new ZkRequiredVerifier(address(0), address(0), address(0), address(0)));
    }

    /// @dev Called by the devnet script test in its serial environment-variable scenarios.
    function run() external {
        vm.pauseGasMetering();
        _switch = new DeployEtnaSwitch();
        _verifiers = new DeployEtnaVerifiers();
        _setEnvironment();

        _assertOwnerRequired("");
        _assertOwnerRequired(vm.toString(address(0)));
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(this)));

        (address proxy, address retainedSignal) = _switch.deployInboxProxy();
        assertEq(retainedSignal, address(signalService));
        assertEq(EssentialContract(proxy).owner(), address(this));
        assertEq(EssentialContract(proxy).pendingOwner(), address(0));
        vm.setEnv("INBOX_PROXY", vm.toString(proxy));
        address registry = _switch.deployRegistry();
        vm.setEnv("STAKING_REGISTRY", vm.toString(registry));
        _registerValidator(IEtnaStakingRegistry(registry));
        DeployEtnaVerifiers.VerifierAddresses memory verifiers = _verifiers.run();
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(verifiers.proofVerifier));
        address cutoff = _switch.deployUnzenInboxImplementation();
        _assertCutoffConfig(cutoff, proxy, _FORK_TIME);
        vm.setEnv("UNZEN_INBOX_IMPLEMENTATION", vm.toString(cutoff));

        address[5] memory controlled =
            [proxy, registry, verifiers.sgxReth, verifiers.risc0Reth, verifiers.sp1Reth];
        for (uint256 i; i < controlled.length; ++i) {
            assertEq(EssentialContract(controlled[i]).owner(), address(this));
            assertEq(EssentialContract(controlled[i]).pendingOwner(), address(0));
            uint256 snapshot = vm.snapshotState();
            EssentialContract(controlled[i]).transferOwnership(Bob);
            vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
            _switch.deployInbox();
            vm.prank(Bob);
            EssentialContract(controlled[i]).acceptOwnership();
            vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
            _switch.deployInbox();
            assertTrue(vm.revertToState(snapshot));
        }

        address implementation = _switch.deployInbox();
        assertEq(EtnaInbox(implementation).stakingRegistry(), registry);
        assertEq(EtnaInbox(implementation).proofVerifier(), verifiers.proofVerifier);
        assertFalse(EtnaInbox(proxy).isInitialized());
        assertEq(EssentialContract(proxy).owner(), address(this));

        address signalImpl = _switch.deploySignalServiceImplementation();
        assertEq(SignalService(signalImpl).beaconRootsFrom(), 0);
        assertEq(SignalService(signalImpl).VERSION(), 1);

        // Before the first proposal executes, every preparer refuses an Etna target that is the
        // Unzen Inbox or the retained store, or that the DAO does not own without a pending
        // transfer.
        address[2] memory wrongTargets = [address(inbox), address(signalService)];
        for (uint256 i; i < wrongTargets.length; ++i) {
            vm.setEnv("INBOX_PROXY", vm.toString(wrongTargets[i]));
            _assertPreparersRefuse();
        }
        vm.setEnv("INBOX_PROXY", vm.toString(proxy));
        uint256 ownerSnapshot = vm.snapshotState();
        EssentialContract(proxy).transferOwnership(Bob);
        _assertPreparersRefuse();
        vm.prank(Bob);
        EssentialContract(proxy).acceptOwnership();
        _assertPreparersRefuse();
        assertTrue(vm.revertToState(ownerSnapshot));

        _switchAndProve(proxy, cutoff, signalImpl, implementation);

        // Once the proposal has executed, the live Unzen Inbox reports the Etna Inbox, and a
        // replacement proposal can still be prepared from it (SWITCH.md section 7).
        assertEq(inbox.getConfig().signalService, proxy);
        _reschedule(proxy);
        // Any third value is refused.
        vm.setEnv("INBOX_PROXY", vm.toString(registry));
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _switch.deployUnzenInboxImplementation();
        vm.setEnv("INBOX_PROXY", vm.toString(proxy));
        // So is another DAO-owned version-1 store: the installed Etna Inbox saves into the
        // retained one.
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(_deploySignalService(proxy))));
        _assertPreparersRefuse();
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(signalService)));
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

    /// @dev Models the DAO proposal's L1 actions (SWITCH.md section 3), then has the Unzen
    /// Inbox prove a proposal made before the switch (vectors 5d.h, 5d.i and 5.u).
    function _switchAndProve(
        address _proxy,
        address _cutoff,
        address _signalImpl,
        address _etnaImpl
    )
        private
    {
        IInbox.ProveInput memory input = _buildBatchInput(1);
        bytes memory data = _switch.ownerUpgradeCall(_etnaImpl);
        inbox.upgradeTo(_cutoff);
        signalService.upgradeTo(_signalImpl);
        _executeUpgrade(_proxy, data);
        EtnaInbox etna = EtnaInbox(_proxy);
        assertTrue(etna.isInitialized());
        assertEq(etna.genesis().epochLenL2, _EPOCH_LEN);
        assertEq(etna.genesisCommitteeRecordHash(), _COMMITTEE_RECORD_HASH);
        _assertStartUnwritten(etna);
        assertEq(inbox.getConfig().signalService, _proxy);

        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: input.commitment.endBlockNumber,
            blockHash: input.commitment.transitions[0].blockHash,
            stateRoot: input.commitment.endStateRoot
        });
        vm.mockCall(
            config.proofVerifier, abi.encodeWithSelector(IProofVerifier.verifyProof.selector), ""
        );
        vm.expectCall(_proxy, abi.encodeCall(EtnaInbox.saveCheckpoint, (checkpoint)));
        _prove(input);
        ICheckpointStore.Checkpoint memory saved =
            signalService.getCheckpoint(checkpoint.blockNumber);
        assertEq(saved.blockHash, checkpoint.blockHash);
        assertEq(saved.stateRoot, checkpoint.stateRoot);
        assertEq(inbox.getCoreState().lastFinalizedProposalId, input.commitment.firstProposalId);

        // The L1 SignalService accepts no checkpoint from the Unzen Inbox directly.
        checkpoint.blockNumber += 1;
        vm.prank(address(inbox));
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        signalService.saveCheckpoint(checkpoint);
    }

    /// @dev A replacement proposal updates the fork immutables and preserves initialized state.
    function _reschedule(address _proxy) private {
        vm.setEnv("ETNA_FORK_TIME", vm.toString(_NEW_FORK_TIME));
        address cutoff = _switch.deployUnzenInboxImplementation();
        _assertCutoffConfig(cutoff, _proxy, _NEW_FORK_TIME);
        vm.setEnv("UNZEN_INBOX_IMPLEMENTATION", vm.toString(cutoff));
        address implementation = _switch.deployInbox();

        EtnaInbox etna = EtnaInbox(_proxy);
        etna.invalidateRecoveryNonce(0);
        bytes32 committeeConfigHash = etna.committeeConfigHash();
        bytes memory data = _switch.ownerUpgradeCall(implementation);
        assertEq(data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (implementation)));
        inbox.upgradeTo(cutoff);
        _executeUpgrade(_proxy, data);
        assertEq(etna.etnaForkTime(), _NEW_FORK_TIME);
        assertTrue(etna.isInitialized());
        assertEq(etna.recoveryNonce(), 1);
        assertEq(etna.genesis().epochLenL2, _EPOCH_LEN);
        assertEq(etna.genesisCommitteeRecordHash(), _COMMITTEE_RECORD_HASH);
        assertEq(etna.committeeConfigHash(), committeeConfigHash);
        _assertStartUnwritten(etna);

        uint256 snapshot = vm.snapshotState();
        bytes32 startHash = bytes32(uint256(456));
        bytes32 startRoot = bytes32(uint256(789));
        vm.warp(_FORK_TIME);
        vm.expectRevert(IEtnaInbox.BeforeEtnaForkTime.selector);
        vm.prank(Carol);
        etna.setOrigin(100, startHash, startRoot);

        vm.warp(_NEW_FORK_TIME);
        vm.prank(Carol);
        etna.setOrigin(100, startHash, startRoot);
        assertEq(etna.generationStartHeight(), 100);
        vm.expectRevert(DeployEtnaSwitch.SwitchAlreadyStarted.selector);
        _switch.ownerUpgradeCall(implementation);
        assertTrue(vm.revertToState(snapshot));
    }

    function _executeUpgrade(address _proxy, bytes memory _data) private {
        (bool success, bytes memory result) = _proxy.call(_data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
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
    function _assertCutoffConfig(
        address _cutoff,
        address _proxy,
        uint48 _forkTime
    )
        private
        view
    {
        IInbox.Config memory expected = inbox.getConfig();
        expected.signalService = _proxy;
        assertEq(
            keccak256(abi.encode(InboxWithEtnaCutoffs(_cutoff).getConfig())),
            keccak256(abi.encode(expected))
        );
        assertEq(InboxWithEtnaCutoffs(_cutoff).ETNA_FORK_TIME(), _forkTime);
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
        vm.setEnv("L2_CHAIN_ID", "167001");
        vm.setEnv("UNZEN_INBOX", vm.toString(address(inbox)));
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(signalService)));
        vm.setEnv("ORIGIN_WRITER", vm.toString(Carol));
        vm.setEnv("ETNA_FORK_TIME", vm.toString(_FORK_TIME));
        vm.setEnv("PROPOSE_MARGIN", "12");
        vm.setEnv("FI_MARGIN", "500");
        vm.setEnv("REMOTE_SIGNAL_SERVICE", vm.toString(_switch.l2SignalServiceAddress(167_001)));
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
        vm.setEnv("ETNA_S_MIN", "1000000000");
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
        vm.deal(vm.addr(_DEPLOYER_KEY), 100 ether);
    }
}
