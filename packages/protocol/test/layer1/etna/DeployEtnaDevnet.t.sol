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
        _deployInbox_DefaultsBothOwnersToTheDeployer();
        _deployInbox_RevertWhen_GenesisCutoffIsNotPast();
        _deployInbox_RevertWhen_GenesisBlockHashIsZero();
        _deployInbox_RevertWhen_GenesisStateRootIsZero();
        _deployInbox_RevertWhen_ProofVerifierHasNoCode();
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
        vm.setEnv("STAKING_REGISTRY", vm.toString(address(registry)));
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(address(landVerifier)));
        vm.setEnv("REMOTE_SIGNAL_SERVICE", vm.toString(REMOTE_SIGNAL_SERVICE));
        vm.setEnv("L2_CHAIN_ID", vm.toString(L2_CHAIN_ID));
        vm.setEnv("MAX_BATCH_BLOCKS", vm.toString(MAX_BATCH_BLOCKS));
        vm.setEnv("GENESIS_BLOCK_HASH", vm.toString(genesisBlockHash));
        vm.setEnv("GENESIS_STATE_ROOT", vm.toString(genesisStateRoot));
        vm.setEnv("EPOCH_LEN_L2", vm.toString(EPOCH_LEN_L2));
        vm.setEnv("EPOCH_LEN_L1", vm.toString(EPOCH_LEN_L1));
        vm.setEnv("GENESIS_CUTOFF", vm.toString(registryCheckpointBlock));
        vm.setEnv("COMMITTEE_RECORD_HASH", vm.toString(COMMITTEE_RECORD_0));
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

        EtnaInbox deployed = EtnaInbox(deployedInbox);
        SignalService deployedSignals = SignalService(deployedSignalService);
        assertEq(deployed.owner(), Bob, "Inbox owner");
        assertEq(deployedSignals.owner(), Bob, "signal service owner");
        assertEq(deployed.migrationState(), 3, "initialized");
        assertEq(deployed.lastCheckpoint().height, 0, "L2 block zero");
        assertEq(deployed.lastCheckpoint().blockHash, genesisBlockHash, "genesis parent");
        assertEq(deployed.committee(0), COMMITTEE_RECORD_0, "committee zero");
        ICheckpointStore.Checkpoint memory checkpoint = deployedSignals.getCheckpoint(0);
        assertEq(checkpoint.blockHash, genesisBlockHash, "checkpoint zero hash");
        assertEq(checkpoint.stateRoot, genesisStateRoot, "checkpoint zero root");

        IEtnaInbox.CommitteeRecord[] memory records = new IEtnaInbox.CommitteeRecord[](1);
        records[0] =
            IEtnaInbox.CommitteeRecord({ epoch: 1, recordHash: keccak256("committee one") });
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: 1,
            lastBlockHash: keccak256("first Etna block"),
            lastStateRoot: keccak256("first Etna state"),
            anchorNumber: uint64(block.number - 1),
            records: records
        });
        bytes32 anchorHash = keccak256("genesis anchor");
        vm.setBlockhash(input.anchorNumber, anchorHash);
        bytes32[] memory blobHashes = _getBlobHashes(1);
        vm.blobhashes(blobHashes);
        bytes32 statement = deployed.hashLandStatement(
            0, 0, genesisBlockHash, COMMITTEE_RECORD_0, input, anchorHash, blobHashes
        );
        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statement, bytes("proof")))
        );
        deployed.land(input, "proof");
        assertEq(deployed.lastCheckpoint().height, 1, "first landed block");
        assertEq(
            deployedSignals.getCheckpoint(1).blockHash, input.lastBlockHash, "new syncer authorized"
        );
    }

    function _deployInbox_DefaultsBothOwnersToTheDeployer() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        (address deployedInbox, address deployedSignalService) = _deployment.deployInbox();
        assertEq(EtnaInbox(deployedInbox).owner(), _scriptDeployer, "default Inbox owner");
        assertEq(
            SignalService(deployedSignalService).owner(), _scriptDeployer, "default signal owner"
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
