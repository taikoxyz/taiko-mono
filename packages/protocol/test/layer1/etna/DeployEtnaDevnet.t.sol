// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployEtnaSwitchScenarios } from "./DeployEtnaSwitchScenarios.sol";
import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { LibEtnaLandStatement } from "./LibEtnaLandStatement.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { DeployEtnaDevnet } from "script/layer1/etna/DeployEtnaDevnet.s.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title DeployEtnaDevnetTest
/// @notice Runs `DeployEtnaDevnet` in the owner-initialized order (spec 10 steps 1 and 5): the
/// Inbox proxy on its bootstrap implementation with the SignalService authorizing it, then the
/// Inbox implementation, with the proxy owner's upgrade-and-initialize call.
/// @dev The base stack stays on its bootstrap implementation and is not used.
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
    /// deploy the stack about ten times, beyond one test's 80M block gas limit, so gas is not
    /// metered; the gas suites measure the contracts.
    function test_deployment_OrderAndRejections() external {
        vm.pauseGasMetering();
        DeployEtnaSwitchScenarios switching = DeployEtnaSwitchScenarios(
            deployCode("DeployEtnaSwitchScenarios.sol:DeployEtnaSwitchScenarios")
        );
        switching.setUp();
        switching.run();
        _deploysTheBootstrapProxyFirst();
        _ownerInitializesAndLandsBlockSix();
        _nonOwnerDeployerLeavesInitToTheOwner();
        _RevertWhen_EtnaStakingIsNotTheGeneratorAddress();
        _RevertWhen_L1ChainIdMismatch();
        _RevertWhen_ProxyStepOnAnotherL1OrRemote();
        _RevertWhen_ProofVerifierHasNoCode();
        _RevertWhen_SignalServiceHasNoCode();
        _RevertWhen_UnsettledLimitInvalid();
        _RevertWhen_OptionalVariableMalformed();
        _initCallReadsFallbackKeysAndMinTotalStake();
    }

    modifier withEnvironment() {
        uint256 snapshot = vm.snapshotState();
        _setEnvironment();
        _;
        assertTrue(vm.revertToState(snapshot));
    }

    /// @dev Sets every variable the script reads. `ETNA_UNSETTLED_LIMIT` is empty, which the
    /// script reads as unset; `INBOX_PROXY` and `SIGNAL_SERVICE` are zero until a scenario
    /// deploys the proxy. The fallback keys and `minTotalStake` are `_defaultInitParams()`'s.
    function _setEnvironment() private {
        vm.setEnv("PRIVATE_KEY", vm.toString(_DEPLOYER_PK));
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        vm.setEnv("INBOX_PROXY", vm.toString(address(0)));
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(0)));
        vm.setEnv("L2_CHAIN_ID", vm.toString(L2_CHAIN_ID));
        vm.setEnv("ETNA_STAKING", vm.toString(ETNA_STAKING));
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "");
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(address(landVerifier)));
        vm.setEnv(
            "REMOTE_SIGNAL_SERVICE", vm.toString(_deployment.l2SignalServiceAddress(L2_CHAIN_ID))
        );
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
        vm.setEnv("ETNA_FALLBACK_KEYS", _hexKey(_defaultFallbackKeys()[0]));
        vm.setEnv("ETNA_MIN_TOTAL_STAKE", vm.toString(MIN_TOTAL_STAKE));
        vm.setEnv("FORCED_INCLUSION_DELAY", vm.toString(FORCED_INCLUSION_DELAY));
        vm.setEnv("MAX_ANCHOR_AGE", vm.toString(MAX_ANCHOR_AGE));
    }

    // ---------------------------------------------------------------
    // Scenarios
    // ---------------------------------------------------------------

    function _deploysTheBootstrapProxyFirst() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(Bob));
        uint64 nonce = vm.getNonce(_scriptDeployer);
        (address proxy, address signals) = _deployment.deployInboxProxy();
        assertEq(vm.getNonce(_scriptDeployer), nonce + 4, "four CREATEs");
        assertEq(_implementation(proxy), vm.computeCreateAddress(_scriptDeployer, nonce));
        assertEq(proxy, vm.computeCreateAddress(_scriptDeployer, nonce + 1), "then the proxy");
        assertEq(signals, vm.computeCreateAddress(_scriptDeployer, nonce + 3), "SignalService");
        assertEq(EssentialContract(proxy).owner(), Bob, "configured owner");
        assertEq(SignalService(signals).owner(), Bob, "SignalService owner");
        assertEq(SignalService(signals).pauser(), address(0), "no pauser besides the owner");
        // Only the Inbox proxy may save checkpoints, before and after its upgrade.
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 1, blockHash: bytes32(uint256(1)), stateRoot: bytes32(uint256(2))
        });
        vm.prank(Alice);
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        SignalService(signals).saveCheckpoint(checkpoint);
        vm.prank(proxy);
        SignalService(signals).saveCheckpoint(checkpoint);
        assertFalse(IEtnaInbox(proxy).isInitialized(), "bootstrap reports uninitialized");
        assertEq(vm.load(proxy, bytes32(INITIALIZATION_STATUS_SLOT)), 0, "slot 258 zero");
        assertEq(vm.load(proxy, bytes32(CONFIG_HASH_SLOT)), 0, "slot 269 zero");
        vm.expectRevert("Initializable: contract is already initialized");
        EtnaInboxBootstrap(proxy).init(Alice);

        vm.setEnv("CONTRACT_OWNER", vm.toString(address(0)));
        (address defaultOwned, address defaultSignals) = _deployment.deployInboxProxy();
        assertEq(EssentialContract(defaultOwned).owner(), _scriptDeployer, "default owner");
        assertEq(SignalService(defaultSignals).owner(), _scriptDeployer, "default owner");
    }

    function _ownerInitializesAndLandsBlockSix() private withEnvironment {
        address proxy = _deployProxy();
        address signals = vm.envAddress("SIGNAL_SERVICE");
        // The landing below references the block before the Inbox's.
        vm.roll(block.number + 1);

        uint64 nonce = vm.getNonce(_scriptDeployer);
        address impl = _deployment.deployInbox();
        assertEq(vm.getNonce(_scriptDeployer), nonce + 2, "one CREATE and the upgrade call");
        assertEq(impl, vm.computeCreateAddress(_scriptDeployer, nonce), "the Inbox");

        EtnaInbox inbox = EtnaInbox(proxy);
        assertTrue(inbox.isInitialized(), "initialized by the upgrade call");
        assertEq(_implementation(proxy), impl, "proxy runs EtnaInbox");
        assertEq(inbox.owner(), _scriptDeployer, "owner kept");
        assertEq(SignalService(signals).owner(), _scriptDeployer, "SignalService owner");
        _assertImmutables(inbox, signals);
        _assertGenesis(inbox, SignalService(signals));
        _landBlockSix(inbox, SignalService(signals));
    }

    function _nonOwnerDeployerLeavesInitToTheOwner() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", vm.toString(Bob));
        address proxy = _deployProxy();
        address signals = vm.envAddress("SIGNAL_SERVICE");
        address bootstrap = _implementation(proxy);

        uint64 nonce = vm.getNonce(_scriptDeployer);
        address impl = _deployment.deployInbox();
        assertEq(vm.getNonce(_scriptDeployer), nonce + 1, "one CREATE and no upgrade call");
        assertFalse(IEtnaInbox(proxy).isInitialized(), "proxy stays on the bootstrap");
        assertEq(_implementation(proxy), bootstrap, "bootstrap implementation kept");
        assertEq(SignalService(signals).owner(), Bob, "SignalService owner");

        bytes memory ownerCall = _deployment.ownerInitCall(impl);
        assertEq(
            ownerCall,
            abi.encodeCall(
                EtnaInbox.upgradeToAndCall,
                (impl, abi.encodeCall(EtnaInbox.init, (_defaultInitParams())))
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
        _assertImmutables(EtnaInbox(proxy), signals);
        _assertGenesis(EtnaInbox(proxy), SignalService(signals));
    }

    /// @dev On a new network the EtnaStaking proxy is the genesis predeploy, so ETNA_STAKING must
    /// be the generator's address for L2_CHAIN_ID: another chain's address, the zero address and
    /// a changed L2_CHAIN_ID are all rejected before anything is broadcast.
    function _RevertWhen_EtnaStakingIsNotTheGeneratorAddress() private withEnvironment {
        address proxy = _deployProxy();
        bytes4 mismatch = DeployEtnaDevnet.EtnaStakingMismatch.selector;
        vm.setEnv("ETNA_STAKING", vm.toString(_deployment.l2EtnaStakingAddress(L2_CHAIN_ID + 1)));
        _expectRejectedBeforeBroadcast(proxy, mismatch);
        vm.setEnv("ETNA_STAKING", vm.toString(address(0)));
        _expectRejectedBeforeBroadcast(proxy, mismatch);

        vm.setEnv("ETNA_STAKING", vm.toString(ETNA_STAKING));
        vm.setEnv("L2_CHAIN_ID", vm.toString(L2_CHAIN_ID + 1));
        _expectRejectedBeforeBroadcast(proxy, mismatch);
    }

    function _RevertWhen_L1ChainIdMismatch() private withEnvironment {
        address proxy = _deployProxy();
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid + 1));
        _expectRejectedBeforeBroadcast(proxy, DeployEtnaDevnet.L1ChainIdMismatch.selector);
    }

    /// @dev Step 1 fixes the L2 SignalService in the L1 SignalService, so it runs only on the
    /// configured L1 and only with the generator's SignalService address for L2_CHAIN_ID.
    function _RevertWhen_ProxyStepOnAnotherL1OrRemote() private withEnvironment {
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid + 1));
        vm.expectRevert(DeployEtnaDevnet.L1ChainIdMismatch.selector);
        _deployment.deployInboxProxy();

        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("REMOTE_SIGNAL_SERVICE", vm.toString(REMOTE_SIGNAL_SERVICE));
        vm.expectRevert(DeployEtnaDevnet.RemoteSignalServiceMismatch.selector);
        _deployment.deployInboxProxy();

        vm.setEnv(
            "REMOTE_SIGNAL_SERVICE",
            vm.toString(_deployment.l2SignalServiceAddress(L2_CHAIN_ID + 1))
        );
        vm.expectRevert(DeployEtnaDevnet.RemoteSignalServiceMismatch.selector);
        _deployment.deployInboxProxy();
    }

    /// @dev The derivation matches the generator's addresses and the live networks'.
    function test_l2SignalServiceAddress_MatchesTheGenerator() external {
        assertEq(
            _deployment.l2SignalServiceAddress(L2_CHAIN_ID),
            0x1670010000000000000000000000000000000005,
            "167001"
        );
        assertEq(_deployment.l2SignalServiceAddress(167_000), LibL2Addrs.SIGNAL_SERVICE, "mainnet");
        assertEq(
            _deployment.l2SignalServiceAddress(167_013),
            LibL2HoodiAddrs.HOODI_SIGNAL_SERVICE,
            "Hoodi"
        );
        assertEq(
            _deployment.l2SignalServiceAddress(167),
            0x1670000000000000000000000000000000000005,
            "genesis test config"
        );
        vm.expectRevert(DeployEtnaDevnet.RemoteSignalServiceMismatch.selector);
        _deployment.l2SignalServiceAddress(0);
    }

    /// @dev The EtnaStaking proxy address matches the genesis generator's
    /// `getConstantAddress(chainId, 10003)`.
    function test_l2EtnaStakingAddress_MatchesTheGenerator() external {
        assertEq(
            _deployment.l2EtnaStakingAddress(167_001),
            0x1670010000000000000000000000000000010003,
            "167001"
        );
        assertEq(
            _deployment.l2EtnaStakingAddress(167_000),
            0x1670000000000000000000000000000000010003,
            "167000"
        );
        vm.expectRevert(DeployEtnaDevnet.EtnaStakingMismatch.selector);
        _deployment.l2EtnaStakingAddress(0);
    }

    function _RevertWhen_ProofVerifierHasNoCode() private withEnvironment {
        address proxy = _deployProxy();
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(Carol));
        _expectRejectedBeforeBroadcast(proxy, DeployEtnaDevnet.ProofVerifierHasNoCode.selector);
    }

    function _RevertWhen_SignalServiceHasNoCode() private withEnvironment {
        address proxy = _deployProxy();
        vm.setEnv("SIGNAL_SERVICE", vm.toString(Carol));
        _expectRejectedBeforeBroadcast(proxy, DeployEtnaDevnet.SignalServiceHasNoCode.selector);
    }

    /// @dev U defaults to 151,200 when ETNA_UNSETTLED_LIMIT is unset, empty or zero, and the
    /// implementation's constructor rejects a set value above 262,144; then 3,601, which is not a
    /// multiple of 6, initializes, so the limit was the only fault.
    function _RevertWhen_UnsettledLimitInvalid() private withEnvironment {
        assertEq(_deployment.DEFAULT_UNSETTLED_LIMIT(), 151_200, "default U");
        address proxy = _deployProxy();
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "0");
        _deployment.deployInbox();
        assertEq(EtnaInbox(proxy).unsettledLimit(), 151_200, "zero means the default");

        proxy = _deployProxy();
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "262145");
        _expectInitRejected(proxy, IEtnaInbox.InvalidUnsettledLimit.selector);

        vm.setEnv("ETNA_UNSETTLED_LIMIT", "3601");
        _deployment.deployInbox();
        assertTrue(IEtnaInbox(proxy).isInitialized(), "a valid limit initializes");
        assertEq(EtnaInbox(proxy).unsettledLimit(), 3601, "explicit U");
    }

    /// @dev A set but malformed CONTRACT_OWNER or ETNA_UNSETTLED_LIMIT reverts before anything is
    /// broadcast instead of falling back to the deployer or to the default U; an empty
    /// CONTRACT_OWNER still means the deployer.
    function _RevertWhen_OptionalVariableMalformed() private withEnvironment {
        vm.setEnv("CONTRACT_OWNER", "0xB0b");
        _expectMalformedRejected(
            abi.encodeCall(DeployEtnaDevnet.deployInboxProxy, ()), "CONTRACT_OWNER"
        );

        vm.setEnv("CONTRACT_OWNER", "");
        (address proxy,) = _deployment.deployInboxProxy();
        assertEq(EssentialContract(proxy).owner(), _scriptDeployer, "empty means the deployer");

        vm.setEnv("INBOX_PROXY", vm.toString(proxy));
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "12abc");
        _expectMalformedRejected(
            abi.encodeCall(DeployEtnaDevnet.deployInbox, ()), "ETNA_UNSETTLED_LIMIT"
        );
    }

    /// @dev `init`'s fallback key list comes from ETNA_FALLBACK_KEYS, comma-separated 33-byte
    /// compressed keys in hex, and its threshold from ETNA_MIN_TOTAL_STAKE; an entry of 32 bytes
    /// reverts.
    function _initCallReadsFallbackKeysAndMinTotalStake() private withEnvironment {
        uint256[] memory pks = new uint256[](2);
        (pks[0], pks[1]) = (1, 2);
        IEtnaInbox.FallbackKey[] memory keys = _keys(pks);
        vm.setEnv("ETNA_FALLBACK_KEYS", string.concat(_hexKey(keys[0]), ",", _hexKey(keys[1])));
        vm.setEnv("ETNA_MIN_TOTAL_STAKE", "1000000000000000000000000000");

        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.fallbackKeys = keys;
        params.minTotalStake = 1e27;
        address impl = address(0x1234);
        bytes memory initCall = abi.encodeCall(EtnaInbox.init, (params));
        assertEq(
            _deployment.ownerInitCall(impl),
            abi.encodeCall(EtnaInbox.upgradeToAndCall, (impl, initCall)),
            "[K1, K2] and 10^27"
        );

        vm.setEnv("ETNA_FALLBACK_KEYS", string.concat(_hexKey(keys[0]), ",", vm.toString(K1_X)));
        vm.expectRevert(DeployEtnaDevnet.InvalidFallbackKeyLength.selector);
        _deployment.ownerInitCall(impl);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The 33-byte compressed form `ckPrefix ‖ ckX` of `_key` in 0x-prefixed hex.
    function _hexKey(IEtnaInbox.FallbackKey memory _key) private pure returns (string memory) {
        return vm.toString(abi.encodePacked(_key.ckPrefix, _key.ckX));
    }

    /// @dev Runs the first deployment step, the Inbox proxy with its SignalService, and exports
    /// both addresses.
    function _deployProxy() private returns (address proxy_) {
        address signals;
        (proxy_, signals) = _deployment.deployInboxProxy();
        vm.setEnv("INBOX_PROXY", vm.toString(proxy_));
        vm.setEnv("SIGNAL_SERVICE", vm.toString(signals));
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

    /// @dev Expects `deployInbox`, the implementation's constructor or the owner's
    /// upgrade-and-initialize call, to revert with `_error`, leaving the proxy on its bootstrap
    /// implementation.
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
    function _assertImmutables(EtnaInbox _inbox, address _signals) private view {
        assertEq(_inbox.proofVerifier(), address(landVerifier), "proof verifier");
        assertEq(_inbox.signalService(), _signals, "SignalService");
        assertEq(_inbox.etnaStaking(), ETNA_STAKING, "EtnaStaking proxy");
        assertEq(_inbox.l2ChainId(), L2_CHAIN_ID, "L2 chain id");
        assertEq(_inbox.maxBatchBlocks(), MAX_BATCH_BLOCKS, "max batch blocks");
        assertEq(_inbox.forcedInclusionFeeInGwei(), FORCED_INCLUSION_FEE_GWEI, "fee");
        assertEq(
            _inbox.forcedInclusionFeeDoubleThreshold(),
            FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            "fee threshold"
        );
        assertEq(_inbox.protocolFeeRecipient(), PROTOCOL_FEE_RECIPIENT, "protocol fee recipient");
        assertEq(_inbox.unsettledLimit(), _deployment.DEFAULT_UNSETTLED_LIMIT(), "default U");
        // A new network: no switch from Unzen.
        assertEq(_inbox.unzenInbox(), address(0), "no Unzen Inbox");
        assertEq(_inbox.etnaForkTime(), 0, "no fork time");
    }

    /// @dev Checks the initialized genesis state against the environment, with the config hash
    /// rebuilt from L2_CHAIN_ID, ETNA_STAKING and the default U.
    function _assertGenesis(EtnaInbox _inbox, SignalService _signals) private view {
        IEtnaInbox.GenesisRecord memory record = _inbox.genesis();
        assertEq(record.genesisHeight, 0, "the start is block 0");
        assertEq(record.l1Block, block.number, "L1_0");
        assertEq(record.startBlockHash, GENESIS_BLOCK_HASH, "genesis hash");
        assertEq(record.startStateRoot, GENESIS_STATE_ROOT, "genesis state root");
        assertEq(_inbox.configHash(), _configHash(), "config hash");
        assertEq(_inbox.forcedInclusionDelay(), FORCED_INCLUSION_DELAY, "forced inclusion delay");
        assertEq(_inbox.maxAnchorAge(), MAX_ANCHOR_AGE, "maximum anchor age");
        assertEq(_inbox.fallbackKeysHash(), DEFAULT_FALLBACK_KEYS_HASH, "fallback keys [K1]");
        assertEq(_inbox.origins(0).fallbackKeysHash, DEFAULT_FALLBACK_KEYS_HASH, "origins(0)");
        assertEq(_inbox.minTotalStake(), MIN_TOTAL_STAKE, "minTotalStake");
        ICheckpointStore.Checkpoint memory checkpoint = _signals.getCheckpoint(0);
        assertEq(checkpoint.blockHash, GENESIS_BLOCK_HASH, "block-0 checkpoint hash");
        assertEq(checkpoint.stateRoot, GENESIS_STATE_ROOT, "block-0 checkpoint root");
    }

    /// @dev Carol lands (0, 6] with five zero cut leaves and one blob; the mock verifier must
    /// receive the appendix A statement rebuilt from the environment.
    function _landBlockSix(EtnaInbox _inbox, SignalService _signals) private {
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            parentHeight: 0,
            lastHeight: 6,
            lastBlockHash: keccak256("Etna L2 block 6"),
            lastCometHash: keccak256("Etna Comet block 6"),
            lastStateRoot: keccak256("Etna L2 state 6"),
            l1ReferenceBlockNumber: block.number - 1,
            forcedInclusionHead: 0
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
        _inbox.land(input, new bytes32[](5), _PROOF);

        IEtnaInbox.LandedCheckpoint memory landed = _inbox.lastCheckpoint();
        assertEq(landed.height, 6, "block six landed");
        assertEq(landed.blockHash, input.lastBlockHash, "block six hash");
        assertEq(_inbox.landings(6).parentHeight, 0, "settled on genesis");
        ICheckpointStore.Checkpoint memory saved = _signals.getCheckpoint(6);
        assertEq(saved.blockHash, input.lastBlockHash, "SignalService accepts the proxy");
        assertEq(saved.stateRoot, input.lastStateRoot, "block six state root");
    }

    /// @dev The landing statement of `_input` over `landings(0)`, with a reference hash set for
    /// its block and five zero cut leaves.
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
            LibEtnaLandStatement.statement(
                LibEtnaLandStatement.Context({
                    l2ChainId: L2_CHAIN_ID,
                    inbox: address(_inbox),
                    generation: 0,
                    configHash: _configHash()
                }),
                _input,
                _inbox.landings(0),
                referenceHash,
                _blobs,
                LibEtnaLandStatement.cutHash(0, 0, 6, new bytes32[](5))
            )
        );
    }

    /// @dev The config hash over the environment's L2 chain id and EtnaStaking proxy and the
    /// default U (appendix A).
    function _configHash() private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32("ETNA_CONFIG_V1"),
                uint256(L2_CHAIN_ID),
                ETNA_STAKING,
                uint256(UNSETTLED_LIMIT)
            )
        );
    }

    /// @dev The implementation in `_proxy`'s ERC-1967 slot.
    function _implementation(address _proxy) private view returns (address) {
        return address(uint160(uint256(vm.load(_proxy, _IMPLEMENTATION_SLOT))));
    }
}
