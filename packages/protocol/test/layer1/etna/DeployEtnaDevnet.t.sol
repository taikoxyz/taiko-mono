// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { LibEtnaLandStatement } from "./LibEtnaLandStatement.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { DeployEtnaDevnet } from "script/layer1/etna/DeployEtnaDevnet.s.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title DeployEtnaDevnetTest
/// @notice Runs `DeployEtnaDevnet` in the owner-initialized order (spec 10 steps 1 and 5): the
/// Inbox proxy on its bootstrap implementation, the registry fixed to it, a validator registration,
/// then the SignalService and the Inbox implementation, with the proxy owner's
/// upgrade-and-initialize call.
/// @dev The base stack stays on its bootstrap implementation; only its registry is used, as a
/// registry fixed to another Inbox.
contract DeployEtnaDevnetTest is EtnaInboxTestBase {
    /// @dev The script's deployment key.
    uint256 private constant _DEPLOYER_PK = 0xe7aa;

    /// @dev The ERC-1967 implementation slot.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    /// @dev The proof bytes of the landing; the mock verifier ignores them.
    bytes private constant _PROOF = "etna proof";

    DeployEtnaDevnet private _deployment;
    address private _scriptDeployer;

    function setUp() public override {
        super.setUp();
        _deployment = new DeployEtnaDevnet();
        _scriptDeployer = vm.addr(_DEPLOYER_PK);
        vm.deal(_scriptDeployer, 100 ether);
    }

    function _initializeOnSetUp() internal pure override returns (bool) {
        return false;
    }

    /// @dev Environment variables are process-wide, so these script scenarios run serially in
    /// one test instead of racing each other in Foundry's parallel test executor. Together they
    /// deploy the stack nine times, beyond one test's 80M block gas limit, so gas is not metered;
    /// the gas suites measure the contracts.
    function test_deployment_C2OrderAndRejections() external {
        vm.pauseGasMetering();
        _deploysTheBootstrapProxyFirst();
        _deploysTheRegistryFixedToTheProxy();
        _registersThenOwnerInitializesAndLandsBlockSix();
        _nonOwnerDeployerLeavesInitToTheOwner();
        _RevertWhen_RegistryFixedToAnotherInbox();
        _RevertWhen_L2ChainIdDiffersFromTheRegistry();
        _RevertWhen_L1ChainIdMismatch();
        _RevertWhen_ProofVerifierHasNoCode();
        _RevertWhen_UnsettledLimitInvalid();
        _RevertWhen_OptionalVariableMalformed();
    }

    modifier withEnvironment() {
        uint256 snapshot = vm.snapshotState();
        _setEnvironment();
        _;
        assertTrue(vm.revertToState(snapshot));
    }

    /// @dev Sets every variable the script reads. `REGISTRY_MIN_STAKE` is empty, which the script
    /// reads as unset; `INBOX_PROXY`, `STAKING_REGISTRY` and `GENESIS_CUTOFF` are zero until a
    /// scenario deploys and registers.
    function _setEnvironment() private {
        vm.setEnv("PRIVATE_KEY", vm.toString(_DEPLOYER_PK));
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        vm.setEnv("INBOX_PROXY", vm.toString(address(0)));
        vm.setEnv("TAIKO_TOKEN", vm.toString(address(taikoToken)));
        vm.setEnv("REGISTRY_MIN_STAKE", "");
        vm.setEnv("REGISTRY_ACTIVATION_DELAY", vm.toString(ACTIVATION_DELAY));
        vm.setEnv("REGISTRY_EXIT_DELAY", vm.toString(EXIT_DELAY));
        vm.setEnv("REGISTRY_WITHDRAWAL_DELAY", vm.toString(WITHDRAWAL_DELAY));
        vm.setEnv("SLASH_BOUNTY_BPS", vm.toString(SLASH_BOUNTY_BPS));
        vm.setEnv("REGISTRY_FORFEIT_BPS", vm.toString(FORFEIT_BPS));
        vm.setEnv("SLASH_SINK", vm.toString(SLASH_SINK));
        vm.setEnv("L2_CHAIN_ID", vm.toString(L2_CHAIN_ID));
        vm.setEnv("STAKING_REGISTRY", vm.toString(address(0)));
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(address(landVerifier)));
        vm.setEnv("REMOTE_SIGNAL_SERVICE", vm.toString(REMOTE_SIGNAL_SERVICE));
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("MAX_BATCH_BLOCKS", vm.toString(MAX_BATCH_BLOCKS));
        vm.setEnv("FORCED_INCLUSION_FEE_GWEI", vm.toString(FORCED_INCLUSION_FEE_GWEI));
        vm.setEnv(
            "FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD",
            vm.toString(FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD)
        );
        vm.setEnv("PROTOCOL_FEE_RECIPIENT", vm.toString(PROTOCOL_FEE_RECIPIENT));
        vm.setEnv("GENESIS_BLOCK_HASH", vm.toString(GENESIS_BLOCK_HASH));
        vm.setEnv("GENESIS_STATE_ROOT", vm.toString(GENESIS_STATE_ROOT));
        vm.setEnv("EPOCH_LEN_L2", vm.toString(EPOCH_LEN_L2));
        vm.setEnv("GENESIS_CUTOFF", "0");
        vm.setEnv("COMMITTEE_RECORD_HASH", vm.toString(COMMITTEE_RECORD_HASH));
        vm.setEnv("ETNA_VP_UNIT", vm.toString(VP_UNIT));
        vm.setEnv("ETNA_S_MIN", vm.toString(S_MIN));
        vm.setEnv("ETNA_N_MAX", vm.toString(N_MAX));
        vm.setEnv("ETNA_UNSETTLED_LIMIT", vm.toString(UNSETTLED_LIMIT));
        vm.setEnv("FORCED_INCLUSION_DELAY", vm.toString(FORCED_INCLUSION_DELAY));
        vm.setEnv("MAX_ANCHOR_AGE", vm.toString(MAX_ANCHOR_AGE));
    }

    // ---------------------------------------------------------------
    // Scenarios
    // ---------------------------------------------------------------

    function _deploysTheBootstrapProxyFirst() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(Bob));
        uint64 nonce = vm.getNonce(_scriptDeployer);
        address proxy = _deployment.deployInboxProxy();
        assertEq(vm.getNonce(_scriptDeployer), nonce + 2, "two CREATEs");
        assertEq(_implementation(proxy), vm.computeCreateAddress(_scriptDeployer, nonce));
        assertEq(proxy, vm.computeCreateAddress(_scriptDeployer, nonce + 1), "proxy last");
        assertEq(EssentialContract(proxy).owner(), Bob, "configured owner");
        assertFalse(IEtnaInbox(proxy).isInitialized(), "bootstrap reports uninitialized");
        assertEq(vm.load(proxy, bytes32(INITIALIZATION_STATUS_SLOT)), 0, "slot 258 zero");
        assertEq(vm.load(proxy, bytes32(COMMITTEE_CONFIG_HASH_SLOT)), 0, "slot 269 zero");
        vm.expectRevert("Initializable: contract is already initialized");
        EtnaInboxBootstrap(proxy).init(Alice);

        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        address defaultOwned = _deployment.deployInboxProxy();
        assertEq(EssentialContract(defaultOwned).owner(), _scriptDeployer, "default owner");
    }

    function _deploysTheRegistryFixedToTheProxy() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(Bob));
        uint256 sMin = 1234 ether;
        vm.setEnv("ETNA_S_MIN", vm.toString(sMin));
        (address proxy, EtnaStakingRegistry deployed) = _deployProxyAndRegistry();
        assertEq(deployed.inbox(), proxy, "fixed to the bootstrap proxy");
        assertFalse(IEtnaInbox(deployed.inbox()).isInitialized(), "Inbox not initialized yet");
        assertEq(deployed.l2ChainId(), L2_CHAIN_ID, "L2 chain id");
        assertEq(deployed.forfeitBps(), FORFEIT_BPS, "explicit forfeiture rate");
        assertEq(deployed.minStake(), sMin, "minimum stake defaults to s_min");
        assertEq(address(deployed.token()), address(taikoToken), "stake token");
        assertEq(deployed.activationDelay(), ACTIVATION_DELAY, "activation delay");
        assertEq(deployed.exitDelay(), EXIT_DELAY, "exit delay");
        assertEq(deployed.withdrawalDelay(), WITHDRAWAL_DELAY, "withdrawal delay");
        assertEq(deployed.slashBountyBps(), SLASH_BOUNTY_BPS, "slash bounty");
        assertEq(deployed.slashSink(), SLASH_SINK, "slash sink");
        assertEq(deployed.owner(), Bob, "registry owner");
        assertEq(deployed.checkpointCount(), 0, "fresh registry");
        vm.expectRevert("Initializable: contract is already initialized");
        deployed.init(Alice);

        vm.setEnv("REGISTRY_MIN_STAKE", vm.toString(2 * sMin));
        EtnaStakingRegistry explicitStake = EtnaStakingRegistry(_deployment.deployRegistry());
        assertEq(explicitStake.minStake(), 2 * sMin, "explicit minimum stake");
        assertEq(explicitStake.inbox(), proxy, "same proxy");
    }

    function _registersThenOwnerInitializesAndLandsBlockSix() private withEnvironment {
        (address proxy, EtnaStakingRegistry deployedRegistry) = _deployProxyAndRegistry();
        uint256 cutoff = block.number;
        _registerAndPickCutoff(deployedRegistry);

        uint64 nonce = vm.getNonce(_scriptDeployer);
        (address impl, address signals) = _deployment.deployInbox();
        assertEq(vm.getNonce(_scriptDeployer), nonce + 4, "three CREATEs and the upgrade call");
        assertEq(signals, vm.computeCreateAddress(_scriptDeployer, nonce + 1), "SignalService");
        assertEq(impl, vm.computeCreateAddress(_scriptDeployer, nonce + 2), "then the Inbox");

        EtnaInbox inbox = EtnaInbox(proxy);
        assertTrue(inbox.isInitialized(), "initialized by the upgrade call");
        assertEq(_implementation(proxy), impl, "proxy runs EtnaInbox");
        assertEq(inbox.owner(), _scriptDeployer, "owner kept");
        assertEq(SignalService(signals).owner(), _scriptDeployer, "SignalService owner");
        _assertImmutables(inbox, signals, address(deployedRegistry));
        _assertGenesis(inbox, SignalService(signals), cutoff);
        _landBlockSix(inbox, SignalService(signals), cutoff);
    }

    function _nonOwnerDeployerLeavesInitToTheOwner() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(Bob));
        (address proxy, EtnaStakingRegistry deployedRegistry) = _deployProxyAndRegistry();
        uint256 cutoff = block.number;
        uint256 bondId = _registerAndPickCutoff(deployedRegistry);
        address bootstrap = _implementation(proxy);

        uint64 nonce = vm.getNonce(_scriptDeployer);
        (address impl, address signals) = _deployment.deployInbox();
        assertEq(vm.getNonce(_scriptDeployer), nonce + 3, "three CREATEs and no upgrade call");
        assertFalse(IEtnaInbox(proxy).isInitialized(), "proxy stays on the bootstrap");
        assertEq(_implementation(proxy), bootstrap, "bootstrap implementation kept");
        assertEq(SignalService(signals).owner(), Bob, "SignalService owner");
        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        deployedRegistry.confirmExit(bondId);

        bytes memory ownerCall = _deployment.ownerInitCall(impl);
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisCutoff = cutoff;
        assertEq(
            ownerCall,
            abi.encodeCall(
                EtnaInbox.upgradeToAndCall, (impl, abi.encodeCall(EtnaInbox.init, (params)))
            ),
            "logged call"
        );

        vm.prank(_scriptDeployer);
        (bool success,) = proxy.call(ownerCall);
        assertFalse(success, "only the owner can send it");
        vm.prank(Bob);
        (success,) = proxy.call(ownerCall);
        assertTrue(success, "the owner's call succeeds");

        assertTrue(IEtnaInbox(proxy).isInitialized(), "initialized by the owner");
        assertEq(_implementation(proxy), impl, "proxy runs EtnaInbox");
        _assertImmutables(EtnaInbox(proxy), signals, address(deployedRegistry));
        _assertGenesis(EtnaInbox(proxy), SignalService(signals), cutoff);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotSet.selector);
        deployedRegistry.confirmExit(bondId);
    }

    function _RevertWhen_RegistryFixedToAnotherInbox() private withEnvironment {
        (address proxy,) = _deployProxyAndRegistry();
        // The base stack's registry is fixed to the base Inbox proxy and has Alice's checkpoint at
        // `registryCheckpointBlock`, a valid cutoff for it.
        assertNotEq(registry.inbox(), proxy, "another Inbox");
        assertEq(registry.l2ChainId(), L2_CHAIN_ID, "same L2 chain id");
        vm.setEnv("STAKING_REGISTRY", vm.toString(address(registry)));
        vm.setEnv("GENESIS_CUTOFF", vm.toString(registryCheckpointBlock));
        _expectInitRejected(proxy, IEtnaInbox.RegistryMismatch.selector);
    }

    /// @dev The Inbox takes `L2_CHAIN_ID` from the environment, not from the registry, so `init`
    /// rejects a registry deployed for another L2 chain.
    function _RevertWhen_L2ChainIdDiffersFromTheRegistry() private withEnvironment {
        (address proxy, EtnaStakingRegistry deployedRegistry) = _deployProxyAndRegistry();
        _registerAndPickCutoff(deployedRegistry);
        vm.setEnv("L2_CHAIN_ID", vm.toString(L2_CHAIN_ID + 1));
        _expectInitRejected(proxy, IEtnaInbox.RegistryMismatch.selector);
    }

    function _RevertWhen_L1ChainIdMismatch() private withEnvironment {
        (address proxy, EtnaStakingRegistry deployedRegistry) = _deployProxyAndRegistry();
        _registerAndPickCutoff(deployedRegistry);
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid + 1));
        _expectRejectedBeforeBroadcast(proxy, DeployEtnaDevnet.L1ChainIdMismatch.selector);
    }

    function _RevertWhen_ProofVerifierHasNoCode() private withEnvironment {
        (address proxy, EtnaStakingRegistry deployedRegistry) = _deployProxyAndRegistry();
        _registerAndPickCutoff(deployedRegistry);
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(Carol));
        _expectRejectedBeforeBroadcast(proxy, DeployEtnaDevnet.ProofVerifierHasNoCode.selector);
    }

    /// @dev U must be a multiple of 6 in [6, 65,532]; the valid 3,600 then initializes, so the
    /// limit was the only fault.
    function _RevertWhen_UnsettledLimitInvalid() private withEnvironment {
        (address proxy, EtnaStakingRegistry deployedRegistry) = _deployProxyAndRegistry();
        _registerAndPickCutoff(deployedRegistry);
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "3601");
        _expectInitRejected(proxy, IEtnaInbox.InvalidCommitteeConfig.selector);
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "0");
        _expectInitRejected(proxy, IEtnaInbox.InvalidCommitteeConfig.selector);
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "65538");
        _expectInitRejected(proxy, IEtnaInbox.InvalidCommitteeConfig.selector);

        vm.setEnv("ETNA_UNSETTLED_LIMIT", vm.toString(UNSETTLED_LIMIT));
        _deployment.deployInbox();
        assertTrue(IEtnaInbox(proxy).isInitialized(), "a valid limit initializes");
    }

    /// @dev A set but malformed CONTRACT_OWNER or REGISTRY_MIN_STAKE reverts before anything is
    /// broadcast instead of falling back to the deployer or to ETNA_S_MIN; an empty
    /// CONTRACT_OWNER still means the deployer.
    function _RevertWhen_OptionalVariableMalformed() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", "0xB0b");
        _expectMalformedRejected(
            abi.encodeCall(DeployEtnaDevnet.deployInboxProxy, ()), "CONTRACT_OWNER"
        );

        vm.setEnv("CONTRACT_OWNER", "");
        address proxy = _deployment.deployInboxProxy();
        assertEq(EssentialContract(proxy).owner(), _scriptDeployer, "empty means the deployer");

        vm.setEnv("INBOX_PROXY", vm.toString(proxy));
        vm.setEnv("REGISTRY_MIN_STAKE", "12abc");
        _expectMalformedRejected(
            abi.encodeCall(DeployEtnaDevnet.deployRegistry, ()), "REGISTRY_MIN_STAKE"
        );
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Runs the first two deployment steps, the Inbox proxy and then the registry fixed to it,
    /// and exports both addresses.
    function _deployProxyAndRegistry()
        private
        returns (address proxy_, EtnaStakingRegistry registry_)
    {
        proxy_ = _deployment.deployInboxProxy();
        vm.setEnv("INBOX_PROXY", vm.toString(proxy_));
        registry_ = EtnaStakingRegistry(_deployment.deployRegistry());
        vm.setEnv("STAKING_REGISTRY", vm.toString(address(registry_)));
    }

    /// @dev Alice registers `VALIDATOR_PK` with its proof of possession; that block, the
    /// registry's first checkpoint, becomes the genesis cutoff and L1 moves one block on.
    function _registerAndPickCutoff(EtnaStakingRegistry _registry)
        private
        returns (uint256 bondId_)
    {
        bondId_ = _registerValidator(_registry, Alice, VALIDATOR_PK);
        assertEq(_registry.checkpointAt(0).l1Block, block.number, "first registry checkpoint");
        vm.setEnv("GENESIS_CUTOFF", vm.toString(block.number));
        vm.roll(block.number + 1);
    }

    /// @dev Expects `deployInbox` to revert with `_error` before broadcasting anything.
    function _expectRejectedBeforeBroadcast(address _proxy, bytes4 _error) private {
        uint64 nonce = vm.getNonce(_scriptDeployer);
        vm.expectRevert(_error);
        _deployment.deployInbox();
        (VmSafe.CallerMode mode,,) = vm.readCallers();
        assertEq(uint256(mode), uint256(VmSafe.CallerMode.None), "broadcast never started");
        assertEq(vm.getNonce(_scriptDeployer), nonce, "nothing deployed");
        assertFalse(IEtnaInbox(_proxy).isInitialized(), "proxy stays on the bootstrap");
    }

    /// @dev Expects the script call `_call` to revert with a reason naming the malformed variable
    /// `_name`, before it broadcasts or deploys anything.
    function _expectMalformedRejected(bytes memory _call, string memory _name) private {
        uint64 nonce = vm.getNonce(_scriptDeployer);
        (bool success, bytes memory reason) = address(_deployment).call(_call);
        assertFalse(success, "malformed value rejected");
        assertTrue(vm.contains(_revertString(reason), _name), "the reason names the variable");
        (VmSafe.CallerMode mode,,) = vm.readCallers();
        assertEq(uint256(mode), uint256(VmSafe.CallerMode.None), "broadcast never started");
        assertEq(vm.getNonce(_scriptDeployer), nonce, "nothing deployed");
    }

    /// @dev Decodes a failed cheatcode's `CheatcodeError(string)` revert data into its message.
    function _revertString(bytes memory _reason) private pure returns (string memory) {
        assertEq(bytes4(_reason), bytes4(keccak256("CheatcodeError(string)")), "a cheatcode error");
        uint256 length = _reason.length;
        assembly {
            _reason := add(_reason, 4)
            mstore(_reason, sub(length, 4))
        }
        return abi.decode(_reason, (string));
    }

    /// @dev Expects the owner's upgrade-and-initialize call, and so `deployInbox`, to revert with
    /// `_error`, leaving the proxy on its bootstrap implementation.
    function _expectInitRejected(address _proxy, bytes4 _error) private {
        address bootstrap = _implementation(_proxy);
        vm.expectRevert(_error);
        _deployment.deployInbox();
        (VmSafe.CallerMode mode,,) = vm.readCallers();
        if (mode == VmSafe.CallerMode.RecurrentBroadcast) vm.stopBroadcast();
        assertFalse(IEtnaInbox(_proxy).isInitialized(), "proxy stays on the bootstrap");
        assertEq(_implementation(_proxy), bootstrap, "bootstrap implementation kept");
    }

    /// @dev Checks the Inbox implementation's immutables against the environment.
    function _assertImmutables(EtnaInbox _inbox, address _signals, address _registry) private view {
        assertEq(_inbox.proofVerifier(), address(landVerifier), "proof verifier");
        assertEq(_inbox.signalService(), _signals, "SignalService");
        assertEq(_inbox.stakingRegistry(), _registry, "registry");
        assertEq(_inbox.l2ChainId(), L2_CHAIN_ID, "L2 chain id");
        assertEq(_inbox.maxBatchBlocks(), MAX_BATCH_BLOCKS, "max batch blocks");
        assertEq(_inbox.forcedInclusionFeeInGwei(), FORCED_INCLUSION_FEE_GWEI, "fee");
        assertEq(
            _inbox.forcedInclusionFeeDoubleThreshold(),
            FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            "fee threshold"
        );
        assertEq(_inbox.protocolFeeRecipient(), PROTOCOL_FEE_RECIPIENT, "protocol fee recipient");
    }

    /// @dev Checks the initialized genesis state against the environment, with the committee
    /// configuration hash rebuilt from the `ETNA_*` values.
    function _assertGenesis(
        EtnaInbox _inbox,
        SignalService _signals,
        uint256 _cutoff
    )
        private
        view
    {
        IEtnaInbox.GenesisRecord memory record = _inbox.genesis();
        assertEq(record.l1Block, block.number, "L1_0");
        assertEq(record.epochLenL2, EPOCH_LEN_L2, "epoch length");
        assertEq(record.genesisBlockHash, GENESIS_BLOCK_HASH, "genesis hash");
        assertEq(record.genesisStateRoot, GENESIS_STATE_ROOT, "genesis state root");
        assertEq(_inbox.genesisCutoff(), _cutoff, "genesis cutoff");
        assertEq(_inbox.activeCommitteeSnapshot(), _cutoff, "snapshot starts at the cutoff");
        assertEq(_inbox.genesisCommitteeRecordHash(), COMMITTEE_RECORD_HASH, "committee 0");
        assertEq(
            _inbox.committeeConfigHash(),
            _committeeConfigHash(_inbox.stakingRegistry()),
            "committee configuration"
        );
        assertEq(_inbox.forcedInclusionDelay(), FORCED_INCLUSION_DELAY, "forced inclusion delay");
        assertEq(_inbox.maxAnchorAge(), MAX_ANCHOR_AGE, "maximum anchor age");
        ICheckpointStore.Checkpoint memory checkpoint = _signals.getCheckpoint(0);
        assertEq(checkpoint.blockHash, GENESIS_BLOCK_HASH, "block-0 checkpoint hash");
        assertEq(checkpoint.stateRoot, GENESIS_STATE_ROOT, "block-0 checkpoint root");
    }

    /// @dev Carol lands (0, 6] with no cut leaves and one blob; the mock verifier must receive the
    /// appendix A statement rebuilt from the environment.
    function _landBlockSix(EtnaInbox _inbox, SignalService _signals, uint256 _cutoff) private {
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            parentHeight: 0,
            lastHeight: 6,
            lastBlockHash: keccak256("Etna L2 block 6"),
            lastCometHash: keccak256("Etna Comet block 6"),
            lastStateRoot: keccak256("Etna L2 state 6"),
            l1ReferenceBlockNumber: block.number - 1,
            forcedInclusionHead: 0,
            activeCommitteeSnapshot: _cutoff
        });
        bytes32[] memory blobs = new bytes32[](1);
        blobs[0] = bytes32((uint256(1) << 248) | 6);
        bytes32 statement = _statement(_inbox, input, blobs);

        vm.blobhashes(blobs);
        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statement, _PROOF))
        );
        vm.prank(Carol);
        _inbox.land(input, new bytes32[](0), _PROOF);

        IEtnaInbox.LandedCheckpoint memory landed = _inbox.lastCheckpoint();
        assertEq(landed.height, 6, "block six landed");
        assertEq(landed.blockHash, input.lastBlockHash, "block six hash");
        assertEq(_inbox.landings(6).parentHeight, 0, "settled on genesis");
        ICheckpointStore.Checkpoint memory saved = _signals.getCheckpoint(6);
        assertEq(saved.blockHash, input.lastBlockHash, "SignalService accepts the proxy");
        assertEq(saved.stateRoot, input.lastStateRoot, "block six state root");
    }

    /// @dev The landing statement of `_input` over `landings(0)`, with a reference hash set for
    /// its block and no cut leaves.
    function _statement(
        EtnaInbox _inbox,
        IEtnaInbox.LandInput memory _input,
        bytes32[] memory _blobs
    )
        private
        returns (bytes32)
    {
        bytes32 referenceHash = keccak256("Etna L1 reference block");
        vm.setBlockhash(_input.l1ReferenceBlockNumber, referenceHash);
        return keccak256(
            LibEtnaLandStatement.preimage(
                LibEtnaLandStatement.Context({
                    l2ChainId: L2_CHAIN_ID,
                    inbox: address(_inbox),
                    stakingRegistry: _inbox.stakingRegistry(),
                    generation: 0,
                    committeeConfigHash: _committeeConfigHash(_inbox.stakingRegistry())
                }),
                _input,
                _inbox.landings(0),
                referenceHash,
                _blobs,
                LibEtnaLandStatement.cutHash(0, 0, 6, new bytes32[](0))
            )
        );
    }

    /// @dev `committeeConfigHash` over the environment's L2 chain id and `ETNA_*` values for
    /// `_registry` (appendix A).
    function _committeeConfigHash(address _registry) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32("ETNA_PARENT_ANCHOR_V1"),
                uint256(L2_CHAIN_ID),
                _registry,
                VP_UNIT,
                S_MIN,
                N_MAX,
                UNSETTLED_LIMIT
            )
        );
    }

    /// @dev The implementation in `_proxy`'s ERC-1967 slot.
    function _implementation(address _proxy) private view returns (address) {
        return address(uint160(uint256(vm.load(_proxy, _IMPLEMENTATION_SLOT))));
    }
}
