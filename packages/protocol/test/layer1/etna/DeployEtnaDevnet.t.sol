// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { DeployEtnaDevnet } from "script/layer1/etna/DeployEtnaDevnet.s.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaRewardPool } from "src/layer1/etna/impl/EtnaRewardPool.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract DeployEtnaDevnetTest is EtnaInboxTestBase {
    uint256 private constant _TEST_PRIVATE_KEY = 0xe7aa;
    DeployEtnaDevnet private _deployment;
    address private _scriptDeployer;

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
        _setEnvironment();
        _;
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
        vm.setEnv("REGISTRY_CHURN_WINDOW", "100");
        vm.setEnv("REGISTRY_CHURN_BPS", "500");
        vm.setEnv("REGISTRY_MIN_CHURN_PER_WINDOW", vm.toString(MIN_STAKE));
        vm.setEnv("STAKING_REGISTRY", vm.toString(address(registry)));
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(address(landVerifier)));
        vm.setEnv("REMOTE_SIGNAL_SERVICE", vm.toString(REMOTE_SIGNAL_SERVICE));
        vm.setEnv("L2_CHAIN_ID", vm.toString(L2_CHAIN_ID));
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
        vm.setEnv("L1_BRIDGE", vm.toString(L1_BRIDGE));
        vm.setEnv("L2_FEE_VAULT", vm.toString(L2_FEE_VAULT));
        vm.setEnv("ALLOC_VALIDATOR_PPM", "700000");
        vm.setEnv("ALLOC_PROVER_PPM", "250000");
        vm.setEnv("LANDING_REWARD_PER_BLOCK", "2000000000000000");
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
        assertEq(deployed.churnWindow(), 100, "churn window");
        assertEq(deployed.churnBps(), 500, "churn bps");
        assertEq(deployed.minChurnPerWindow(), MIN_STAKE, "churn floor");
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
        address predictedPool = vm.computeCreateAddress(_scriptDeployer, nonce + 5);
        (address deployedInbox, address deployedSignalService, address deployedPool) =
            _deployment.deployInbox();
        assertEq(deployedInbox, predictedInbox, "fourth CREATE");
        assertEq(deployedSignalService, predictedSignalService, "second CREATE");
        assertEq(deployedPool, predictedPool, "sixth CREATE");
        assertEq(vm.getNonce(_scriptDeployer), nonce + 6, "six CREATEs");
        assertNotEq(deployedInbox, address(etnaInbox), "fresh Inbox");
        assertNotEq(deployedSignalService, address(signalService), "fresh signal service");
        assertNotEq(deployedPool, address(rewardPool), "fresh reward pool");

        EtnaInbox deployed = EtnaInbox(payable(deployedInbox));
        SignalService deployedSignals = SignalService(deployedSignalService);
        assertEq(deployed.owner(), Bob, "Inbox owner");
        assertEq(deployedSignals.owner(), Bob, "signal service owner");
        assertEq(deployed.migrationState(), 3, "initialized");
        assertEq(deployed.lastCheckpoint().height, 0, "L2 block zero");
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
        assertEq(deployed.rewardPool(), deployedPool, "the Inbox names the pool proxy");
        assertEq(deployed.landingRewardPerBlock(), 0.002 ether, "landing reward per block");
        assertEq(deployed.proverRewardLedger(), 0, "empty prover ledger");

        EtnaRewardPool pool = EtnaRewardPool(payable(deployedPool));
        assertEq(pool.owner(), Bob, "reward pool owner");
        assertEq(pool.inbox(), deployedInbox, "the pool reports to the Inbox proxy");
        assertEq(pool.stakingRegistry(), address(registry), "pool registry");
        assertEq(pool.l1Bridge(), L1_BRIDGE, "pool L1 bridge");
        assertEq(pool.l2FeeVault(), L2_FEE_VAULT, "pool L2 fee vault");
        assertEq(pool.l2ChainId(), L2_CHAIN_ID, "pool L2 chain id");
        assertEq(pool.allocValidatorPpm(), 700_000, "validator share");
        assertEq(pool.allocProverPpm(), 250_000, "proving share");
        vm.expectRevert("Initializable: contract is already initialized");
        pool.init(Alice);

        ICheckpointStore.Checkpoint memory checkpoint = deployedSignals.getCheckpoint(0);
        assertEq(checkpoint.blockHash, genesisBlockHash, "checkpoint zero hash");
        assertEq(checkpoint.stateRoot, genesisStateRoot, "checkpoint zero root");

        vm.deal(Alice, 1 ether);
        vm.blobhashes(_getBlobHashes(1));
        vm.prank(Alice);
        deployed.saveForcedInclusion{ value: uint256(FORCED_INCLUSION_FEE_GWEI) * 1 gwei }(hex"c0");

        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: 1,
            lastBlockHash: keccak256("first Etna block"),
            lastStateRoot: keccak256("first Etna state"),
            l1ReferenceBlockNumber: uint64(block.number - 1),
            forcedInclusionHead: 1,
            feeRecipient: Carol
        });
        bytes32 l1ReferenceBlockHash = keccak256("genesis anchor");
        vm.setBlockhash(input.l1ReferenceBlockNumber, l1ReferenceBlockHash);
        bytes32[] memory blobHashes = _getBlobHashes(1);
        vm.blobhashes(blobHashes);
        // Block 1 carries no commit, so the first landing reports no participation.
        IEtnaInbox.EpochParticipation[] memory parts = new IEtnaInbox.EpochParticipation[](0);
        IEtnaInbox.CommitteeMember[][] memory settlements = new IEtnaInbox.CommitteeMember[][](0);
        bytes32 statement = deployed.hashLandStatement(
            0, 0, genesisBlockHash, 0, input, parts, l1ReferenceBlockHash, blobHashes
        );
        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statement, bytes("proof")))
        );
        uint256 recipientBefore = Carol.balance;
        deployed.land(input, parts, settlements, "proof");
        assertEq(deployed.lastCheckpoint().height, 1, "first landed block");
        assertEq(
            deployedSignals.getCheckpoint(1).blockHash, input.lastBlockHash, "new syncer authorized"
        );
        (uint48 head,) = deployed.getForcedInclusionState();
        assertEq(head, 1, "forced inclusion consumed");
        assertEq(
            Carol.balance - recipientBefore,
            uint256(FORCED_INCLUSION_FEE_GWEI) * 1 gwei,
            "fee paid to the bound recipient"
        );
    }

    function _deployInbox_DefaultsEveryOwnerToTheDeployer() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        (address deployedInbox, address deployedSignalService, address deployedPool) =
            _deployment.deployInbox();
        assertEq(EtnaInbox(payable(deployedInbox)).owner(), _scriptDeployer, "default Inbox owner");
        assertEq(
            SignalService(deployedSignalService).owner(), _scriptDeployer, "default signal owner"
        );
        assertEq(
            EtnaRewardPool(payable(deployedPool)).owner(), _scriptDeployer, "default pool owner"
        );
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
