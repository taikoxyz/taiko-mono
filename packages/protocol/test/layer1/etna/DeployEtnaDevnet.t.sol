// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { DeployEtnaDevnet } from "script/layer1/etna/DeployEtnaDevnet.s.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract DeployEtnaDevnetTest is EtnaInboxTestBase {
    uint256 private constant _TEST_PRIVATE_KEY = 0xe7aa;
    DeployEtnaDevnet private _deployment;
    address private _scriptDeployer;

    function _bindRegistryOnDeploy() internal pure override returns (bool) {
        return false;
    }

    function setUp() public override {
        super.setUp();
        _deployment = new DeployEtnaDevnet();
        _scriptDeployer = vm.addr(_TEST_PRIVATE_KEY);
        vm.deal(_scriptDeployer, 100 ether);
    }

    /// @dev Environment variables are process-wide, so these script scenarios run serially in
    /// one test instead of racing each other in Foundry's parallel test executor.
    function test_deployment_FromGenesisAndInvalidParameterRejection() external {
        _run_DeploysAnInitializedRegistryWithTheConfiguredOwner();
        _run_DefaultsTheRegistryOwnerToTheDeployer();
        _deployInbox_InitializesThePredictedFreshProxyAndLandsFromBlockZero();
        _deployInbox_DefaultsEveryOwnerToTheDeployer();
        _deployInbox_ReplacesAnUnverifiedCandidateBeforeExplicitBinding();
        _deployInbox_RevertWhen_RegistryAlreadyBound();
        _deployInbox_RevertWhen_ExportedIdentityIsStale();
        _deployInbox_RevertWhen_ExportedIdentityIsWrong();
        _deployInbox_RevertWhen_GenesisCutoffIsNotPast();
        _deployInbox_RevertWhen_GenesisBlockHashIsZero();
        _deployInbox_RevertWhen_GenesisStateRootIsZero();
        _deployInbox_RevertWhen_ProofVerifierHasNoCode();
        _deployInbox_RevertWhen_CommitteeConfigHashIsZero();
        _deployInbox_RevertWhen_ForcedInclusionFeeIsZero();
        _deployInbox_RevertWhen_ForcedInclusionFeeDoubleThresholdIsZero();
        _deployInbox_RevertWhen_ForcedInclusionDelayIsZero();
        _deployInbox_RevertWhen_MaxAnchorAgeIsZero();
    }

    modifier withEnvironment() {
        uint256 snapshot = vm.snapshotState();
        _setEnvironment();
        _;
        assertTrue(vm.revertToState(snapshot));
    }

    function _setEnvironment() private {
        vm.setEnv("PRIVATE_KEY", vm.toString(_TEST_PRIVATE_KEY));
        vm.setEnv("CONTRACT_OWNER", vm.toString(Bob));
        vm.setEnv("TAIKO_TOKEN", vm.toString(address(taikoToken)));
        vm.setEnv("REGISTRY_MIN_STAKE", vm.toString(MIN_STAKE));
        vm.setEnv("REGISTRY_ACTIVATION_DELAY", "10");
        vm.setEnv("REGISTRY_EXIT_DELAY", "20");
        vm.setEnv("REGISTRY_WITHDRAWAL_DELAY", "30");
        vm.setEnv("REGISTRY_HEARTBEAT_WINDOW", "50");
        vm.setEnv("STAKING_REGISTRY", vm.toString(address(registry)));
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(address(landVerifier)));
        vm.setEnv("REMOTE_SIGNAL_SERVICE", vm.toString(REMOTE_SIGNAL_SERVICE));
        vm.setEnv("L2_CHAIN_ID", vm.toString(L2_CHAIN_ID));
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv(
            "L1_INBOX",
            vm.toString(vm.computeCreateAddress(_scriptDeployer, vm.getNonce(_scriptDeployer) + 3))
        );
        vm.setEnv("MAX_BATCH_BLOCKS", vm.toString(MAX_BATCH_BLOCKS));
        vm.setEnv("FORCED_INCLUSION_FEE_GWEI", vm.toString(FORCED_INCLUSION_FEE_GWEI));
        vm.setEnv(
            "FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD",
            vm.toString(FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD)
        );
        vm.setEnv("GENESIS_BLOCK_HASH", vm.toString(genesisBlockHash));
        vm.setEnv("GENESIS_STATE_ROOT", vm.toString(genesisStateRoot));
        vm.setEnv("EPOCH_LEN_L2", vm.toString(EPOCH_LEN_L2));
        vm.setEnv("EPOCH_LEN_L1", vm.toString(EPOCH_LEN_L1));
        vm.setEnv("GENESIS_CUTOFF", vm.toString(registryCheckpointBlock));
        vm.setEnv("COMMITTEE_RECORD_HASH", vm.toString(COMMITTEE_RECORD_0));
        vm.setEnv("COMMITTEE_CONFIG_HASH", vm.toString(COMMITTEE_CONFIG_HASH));
        vm.setEnv("FORCED_INCLUSION_DELAY", vm.toString(FORCED_INCLUSION_DELAY));
        vm.setEnv("MAX_ANCHOR_AGE", vm.toString(MAX_ANCHOR_AGE));
    }

    function _run_DeploysAnInitializedRegistryWithTheConfiguredOwner() private withEnvironment {
        EtnaStakingRegistry deployed = EtnaStakingRegistry(_deployment.run());
        assertEq(deployed.owner(), Bob, "registry owner");
        assertEq(address(deployed.taikoToken()), address(taikoToken), "stake token");
        assertEq(deployed.minStake(), MIN_STAKE, "minimum stake");
        assertEq(deployed.activationDelay(), 10, "activation delay");
        assertEq(deployed.exitDelay(), 20, "exit delay");
        assertEq(deployed.withdrawalDelay(), 30, "withdrawal delay");
        assertEq(deployed.heartbeatWindow(), 50, "heartbeat window");
        assertEq(deployed.checkpointCount(), 0, "fresh registry");
        vm.expectRevert("Initializable: contract is already initialized");
        deployed.init(Alice);
    }

    function _run_DefaultsTheRegistryOwnerToTheDeployer() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        EtnaStakingRegistry deployed = EtnaStakingRegistry(_deployment.run());
        assertEq(deployed.owner(), _scriptDeployer, "default registry owner");
    }

    function _deployInbox_InitializesThePredictedFreshProxyAndLandsFromBlockZero()
        private
        withEnvironment
    {
        uint64 nonce = vm.getNonce(_scriptDeployer);
        address predictedInbox = vm.computeCreateAddress(_scriptDeployer, nonce + 3);
        address predictedSignalService = vm.computeCreateAddress(_scriptDeployer, nonce + 1);
        (address deployedInbox, address deployedSignalService) = _deployment.deployInbox();
        assertEq(deployedInbox, predictedInbox, "fourth CREATE");
        assertEq(deployedSignalService, predictedSignalService, "second CREATE");
        assertEq(vm.getNonce(_scriptDeployer), nonce + 4, "four CREATEs");
        assertNotEq(deployedInbox, address(etnaInbox), "fresh Inbox");
        assertNotEq(deployedSignalService, address(signalService), "fresh signal service");

        EtnaInbox deployed = EtnaInbox(payable(deployedInbox));
        SignalService deployedSignals = SignalService(deployedSignalService);
        assertEq(deployed.owner(), Bob, "Inbox owner");
        assertEq(deployedSignals.owner(), Bob, "signal service owner");
        assertEq(deployed.migrationState(), 3, "initialized");
        assertEq(deployed.lastCheckpoint().height, 0, "L2 block zero");
        assertEq(registry.inbox(), address(0), "separate registry owner must bind explicitly");
        assertEq(deployed.activeCommitteeSnapshot(), registryCheckpointBlock);
        assertEq(deployed.lastCheckpoint().blockHash, genesisBlockHash, "genesis parent");
        assertEq(deployed.genesisCommitteeRecordHash(), COMMITTEE_RECORD_0, "committee zero");
        assertEq(deployed.committeeConfigHash(), COMMITTEE_CONFIG_HASH, "committee config");
        assertEq(
            deployed.getCurrentForcedInclusionFee(),
            FORCED_INCLUSION_FEE_GWEI,
            "forced inclusion fee"
        );
        assertEq(deployed.forcedInclusionDelay(), FORCED_INCLUSION_DELAY, "forced inclusion delay");
        assertEq(deployed.maxAnchorAge(), MAX_ANCHOR_AGE, "maximum anchor age");

        ICheckpointStore.Checkpoint memory checkpoint = deployedSignals.getCheckpoint(0);
        assertEq(checkpoint.blockHash, genesisBlockHash, "checkpoint zero hash");
        assertEq(checkpoint.stateRoot, genesisStateRoot, "checkpoint zero root");

        _landFirstBlock(deployed, deployedSignals, genesisBlockHash);
        assertEq(registry.inbox(), address(0), "landing does not require binding");
        registry.bindInbox(deployedInbox);
        assertEq(registry.inbox(), deployedInbox, "owner binds after validating startup");
    }

    /// @dev Exercises first landing while the registry remains unbound. The mock proof checks
    /// plumbing only; production startup validation requires a real guest and finalized landing.
    function _landFirstBlock(
        EtnaInbox _inbox,
        SignalService _signals,
        bytes32 _genesisHash
    )
        private
    {
        vm.deal(Alice, 1 ether);
        vm.blobhashes(_getBlobHashes(1));
        vm.prank(Alice);
        _inbox.saveForcedInclusion{ value: uint256(FORCED_INCLUSION_FEE_GWEI) * 1 gwei }(hex"c0");

        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: 1,
            lastBlockHash: keccak256("first Etna block"),
            lastStateRoot: keccak256("first Etna state"),
            l1ReferenceBlockNumber: uint64(block.number - 1),
            forcedInclusionHead: 1,
            feeRecipient: Carol,
            l2RewardRecipient: Alice,
            baseFeeAmount: 0,
            activeCommitteeSnapshot: _inbox.genesisCutoff()
        });
        bytes32 l1ReferenceBlockHash = keccak256("genesis anchor");
        vm.setBlockhash(input.l1ReferenceBlockNumber, l1ReferenceBlockHash);
        bytes32[] memory blobHashes = _getBlobHashes(1);
        vm.blobhashes(blobHashes);
        bytes32 statement = _inbox.hashLandStatement(
            0, 0, _genesisHash, 0, input, l1ReferenceBlockHash, blobHashes
        );
        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statement, bytes("proof")))
        );
        uint256 recipientBefore = Carol.balance;
        _inbox.land(input, "proof");
        assertEq(_inbox.lastCheckpoint().height, 1, "first landed block");
        assertEq(_signals.getCheckpoint(1).blockHash, input.lastBlockHash, "new syncer authorized");
        (uint48 head,) = _inbox.getForcedInclusionState();
        assertEq(head, 1, "forced inclusion consumed");
        assertEq(
            Carol.balance - recipientBefore,
            uint256(FORCED_INCLUSION_FEE_GWEI) * 1 gwei,
            "fee paid to the bound recipient"
        );
    }

    function _deployInbox_DefaultsEveryOwnerToTheDeployer() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        registry.transferOwnership(_scriptDeployer);
        vm.prank(_scriptDeployer);
        registry.acceptOwnership();
        uint64 nonce = vm.getNonce(_scriptDeployer);
        (address deployedInbox, address deployedSignalService) = _deployment.deployInbox();
        assertEq(EtnaInbox(payable(deployedInbox)).owner(), _scriptDeployer, "default Inbox owner");
        assertEq(
            registry.inbox(), address(0), "owner-deployer must bind explicitly after validation"
        );
        assertEq(vm.getNonce(_scriptDeployer), nonce + 4, "only four CREATEs, no binding call");
        assertEq(
            SignalService(deployedSignalService).owner(), _scriptDeployer, "default signal owner"
        );
    }

    /// @dev A syntactically initialized candidate can have the wrong node config. The operator
    /// can discard it, rebuild genesis for the new prediction and verify the intended deployment
    /// before making the one-time withdrawal binding. This models the operator's choice;
    /// actual semantic startup validation belongs to the client integration checks.
    function _deployInbox_ReplacesAnUnverifiedCandidateBeforeExplicitBinding()
        private
        withEnvironment
    {
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        registry.transferOwnership(_scriptDeployer);
        vm.prank(_scriptDeployer);
        registry.acceptOwnership();
        vm.setEnv("COMMITTEE_CONFIG_HASH", vm.toString(keccak256("unverified config opening")));
        (address abandonedInbox,) = _deployment.deployInbox();
        assertNotEq(EtnaInbox(payable(abandonedInbox)).committeeConfigHash(), COMMITTEE_CONFIG_HASH);
        assertEq(registry.inbox(), address(0), "unverified deployment does not lock the registry");

        taikoToken.mint(Bob, MIN_STAKE);
        vm.startPrank(Bob);
        taikoToken.approve(address(registry), MIN_STAKE);
        uint256 bond = registry.register(bytes32(uint256(0xb2)), MIN_STAKE, Bob);
        registry.requestExit(bond);
        vm.stopPrank();
        vm.roll(registry.entryAt(bond).exitEffectiveL1 + registry.withdrawalDelay());
        vm.prank(Bob);
        vm.expectRevert(EtnaStakingRegistry.InboxNotBound.selector);
        registry.withdraw(bond, Bob);

        uint64 nonce = vm.getNonce(_scriptDeployer);
        address predictedInbox = vm.computeCreateAddress(_scriptDeployer, nonce + 3);
        bytes32 rebuiltGenesisHash = keccak256("rebuilt genesis for intended Inbox");
        vm.setEnv("L1_INBOX", vm.toString(predictedInbox));
        vm.setEnv("GENESIS_BLOCK_HASH", vm.toString(rebuiltGenesisHash));
        vm.setEnv("GENESIS_STATE_ROOT", vm.toString(keccak256("rebuilt genesis state")));
        vm.setEnv("COMMITTEE_CONFIG_HASH", vm.toString(COMMITTEE_CONFIG_HASH));
        (address intendedInbox, address intendedSignals) = _deployment.deployInbox();
        assertNotEq(intendedInbox, abandonedInbox, "fresh candidate");
        assertEq(intendedInbox, predictedInbox, "rebuilt genesis identity");
        assertEq(vm.getNonce(_scriptDeployer), nonce + 4, "four CREATEs remain consecutive");
        EtnaInbox intended = EtnaInbox(payable(intendedInbox));
        assertEq(intended.lastCheckpoint().blockHash, rebuiltGenesisHash);
        assertEq(intended.committeeConfigHash(), COMMITTEE_CONFIG_HASH);
        assertEq(registry.inbox(), address(0), "redeployment still requires explicit approval");
        _landFirstBlock(intended, SignalService(intendedSignals), rebuiltGenesisHash);
        assertEq(registry.inbox(), address(0), "landing succeeds before withdrawal binding");

        vm.prank(_scriptDeployer);
        registry.bindInbox(intendedInbox);
        assertEq(registry.inbox(), intendedInbox, "bind intended deployment once");
        vm.prank(_scriptDeployer);
        vm.expectRevert(EtnaStakingRegistry.InboxAlreadyBound.selector);
        registry.bindInbox(abandonedInbox);
    }

    function _deployInbox_RevertWhen_RegistryAlreadyBound() private withEnvironment {
        registry.bindInbox(address(etnaInbox));
        _expectIdentityRejected(DeployEtnaDevnet.RegistryAlreadyBound.selector);
    }

    /// @dev Rejects an exported Inbox identity after the deployer nonce advances.
    function _deployInbox_RevertWhen_ExportedIdentityIsStale() private withEnvironment {
        // The exported identity stays fixed while another transaction consumes the sender nonce.
        vm.setNonce(_scriptDeployer, vm.getNonce(_scriptDeployer) + 1);
        _expectIdentityRejected(bytes4(keccak256("InboxAddressMismatch()")));
    }

    /// @dev Rejects zero or mismatched exported L1 chain and Inbox identities.
    function _deployInbox_RevertWhen_ExportedIdentityIsWrong() private {
        _setEnvironment();
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid + 1));
        _expectIdentityRejected(bytes4(keccak256("L1ChainIdMismatch()")));
        vm.setEnv("L1_CHAIN_ID", "0");
        _expectIdentityRejected(bytes4(keccak256("L1ChainIdMismatch()")));
        _setEnvironment();
        vm.setEnv("L1_INBOX", vm.toString(Alice));
        _expectIdentityRejected(bytes4(keccak256("InboxAddressMismatch()")));
        vm.setEnv("L1_INBOX", vm.toString(address(0)));
        _expectIdentityRejected(bytes4(keccak256("InboxAddressMismatch()")));
    }

    /// @dev Checks identity rejection before broadcast, nonce consumption or deployment.
    /// @param _error Expected identity validation error selector.
    function _expectIdentityRejected(bytes4 _error) private {
        uint64 nonce = vm.getNonce(_scriptDeployer);
        vm.expectRevert(_error);
        _deployment.deployInbox();
        (VmSafe.CallerMode mode,,) = vm.readCallers();
        assertEq(uint256(mode), uint256(VmSafe.CallerMode.None), "broadcast never started");
        assertEq(vm.getNonce(_scriptDeployer), nonce, "rejection consumes no nonce");
        for (uint64 i; i < 4; ++i) {
            assertEq(vm.computeCreateAddress(_scriptDeployer, nonce + i).code.length, 0);
        }
    }

    function _deployInbox_RevertWhen_GenesisCutoffIsNotPast() private withEnvironment {
        vm.setEnv("GENESIS_CUTOFF", vm.toString(block.number));
        _expectRejectedDeployment(EtnaInbox.InvalidGenesisCutoff.selector);
    }

    function _deployInbox_RevertWhen_GenesisBlockHashIsZero() private withEnvironment {
        vm.setEnv("GENESIS_BLOCK_HASH", vm.toString(bytes32(0)));
        _expectRejectedDeployment(EtnaInbox.InvalidGenesis.selector);
    }

    function _deployInbox_RevertWhen_GenesisStateRootIsZero() private withEnvironment {
        vm.setEnv("GENESIS_STATE_ROOT", vm.toString(bytes32(0)));
        _expectRejectedDeployment(EtnaInbox.InvalidGenesis.selector);
    }

    function _deployInbox_RevertWhen_ProofVerifierHasNoCode() private withEnvironment {
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(Alice));
        _expectRejectedDeployment(DeployEtnaDevnet.ProofVerifierHasNoCode.selector);
    }

    function _deployInbox_RevertWhen_CommitteeConfigHashIsZero() private withEnvironment {
        vm.setEnv("COMMITTEE_CONFIG_HASH", vm.toString(bytes32(0)));
        _expectRejectedDeployment(EtnaInbox.ZeroCommitteeConfigHash.selector);
    }

    function _deployInbox_RevertWhen_ForcedInclusionFeeIsZero() private withEnvironment {
        vm.setEnv("FORCED_INCLUSION_FEE_GWEI", "0");
        _expectRejectedDeployment(EtnaInbox.ForcedInclusionFeeZero.selector);
    }

    function _deployInbox_RevertWhen_ForcedInclusionFeeDoubleThresholdIsZero()
        private
        withEnvironment
    {
        vm.setEnv("FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD", "0");
        _expectRejectedDeployment(EtnaInbox.ForcedInclusionFeeDoubleThresholdZero.selector);
    }

    function _deployInbox_RevertWhen_ForcedInclusionDelayIsZero() private withEnvironment {
        vm.setEnv("FORCED_INCLUSION_DELAY", "0");
        _expectRejectedDeployment(EtnaInbox.InvalidForcedInclusionDelay.selector);
    }

    function _deployInbox_RevertWhen_MaxAnchorAgeIsZero() private withEnvironment {
        vm.setEnv("MAX_ANCHOR_AGE", "0");
        _expectRejectedDeployment(EtnaInbox.InvalidMaxAnchorAge.selector);
    }

    function _expectRejectedDeployment(bytes4 _error) private {
        address predictedInbox =
            vm.computeCreateAddress(_scriptDeployer, vm.getNonce(_scriptDeployer) + 3);
        vm.expectRevert(_error);
        _deployment.deployInbox();
        (VmSafe.CallerMode mode,,) = vm.readCallers();
        if (mode == VmSafe.CallerMode.RecurrentBroadcast) vm.stopBroadcast();
        assertEq(predictedInbox.code.length, 0, "no uninitialized Inbox proxy published");
    }
}
