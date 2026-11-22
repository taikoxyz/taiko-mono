// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract EtnaInboxGenesisTest is EtnaInboxTestBase {
    /// @dev 2^48, the first value a 48-bit field cannot hold.
    uint256 private constant _TWO_POW_48 = 2 ** 48;

    /// @dev The largest `U` an implementation accepts.
    uint64 private constant _MAX_UNSETTLED_LIMIT = 262_144;

    /// @dev `keccak256(abi.encode(bytes32("ETNA_CONFIG_V1"), uint256(167_001), ETNA_STAKING,
    /// uint256(151_200)))`: the config hash of the default deployment.
    bytes32 private constant _DEFAULT_CONFIG_HASH =
        0xce98efd6a337c78d7b268a407f9cd0dbfeee0e8724f07bc924087437497b4650;

    /// @dev The proxy stays on its bootstrap implementation; each test initializes it itself.
    function _initializeOnSetUp() internal pure override returns (bool) {
        return false;
    }

    // ---------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------

    function test_constructor_SetsTheImmutableViews() external {
        EtnaInbox impl = _newInboxImpl(_defaultConfig());
        assertEq(impl.proofVerifier(), address(landVerifier), "verifier");
        assertEq(impl.signalService(), address(signalService), "signal service");
        assertEq(impl.etnaStaking(), ETNA_STAKING, "EtnaStaking proxy");
        assertEq(impl.l2ChainId(), L2_CHAIN_ID, "l2 chain id");
        assertEq(impl.maxBatchBlocks(), MAX_BATCH_BLOCKS, "max batch blocks");
        assertEq(impl.forcedInclusionFeeInGwei(), FORCED_INCLUSION_FEE_GWEI, "fee");
        assertEq(
            impl.forcedInclusionFeeDoubleThreshold(),
            FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            "fee threshold"
        );
        assertEq(impl.protocolFeeRecipient(), PROTOCOL_FEE_RECIPIENT, "protocol fee recipient");
        assertEq(impl.unzenInbox(), address(0), "new network: no Unzen Inbox");
        assertEq(impl.etnaForkTime(), 0, "new network: no fork time");
        assertEq(impl.unsettledLimit(), UNSETTLED_LIMIT, "U");
    }

    /// @dev PARAM-11-12a: the two switching immutables are both zero (a new network) or both
    /// non-zero (a switching network), and the Unzen Inbox must have code. There is no
    /// originWriter (vector 11 12a).
    function test_constructor_RevertWhen_SwitchConfigIsMixed() external {
        address unzen = address(landVerifier); // any contract
        IEtnaInbox.Config memory cfg = _defaultConfig();
        (cfg.unzenInbox, cfg.etnaForkTime) = (unzen, 1);
        EtnaInbox impl = _newInboxImpl(cfg);
        assertEq(impl.unzenInbox(), unzen, "Unzen Inbox");
        assertEq(impl.etnaForkTime(), 1, "fork time");

        cfg.etnaForkTime = 0;
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        _newInboxImpl(cfg);

        (cfg.etnaForkTime, cfg.unzenInbox) = (1, address(0));
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        _newInboxImpl(cfg);

        cfg.unzenInbox = address(0x1234); // no code
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        _newInboxImpl(cfg);
    }

    /// @dev U, the maximum number of unsettled L2 blocks, is an implementation immutable that
    /// accepts both ends of [1, 262,144].
    function test_constructor_AcceptsU1And262144() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.unsettledLimit = 1;
        assertEq(_newInboxImpl(cfg).unsettledLimit(), 1, "U = 1");
        cfg.unsettledLimit = _MAX_UNSETTLED_LIMIT;
        assertEq(_newInboxImpl(cfg).unsettledLimit(), _MAX_UNSETTLED_LIMIT, "U = 262,144");
    }

    /// @dev U = 0 and U = 262,145 are outside [1, 262,144], and so is the widest value.
    function test_constructor_RevertWhen_UIs0Or262145() external {
        uint64[3] memory rejected = [uint64(0), _MAX_UNSETTLED_LIMIT + 1, type(uint64).max];
        for (uint256 i; i < rejected.length; ++i) {
            IEtnaInbox.Config memory cfg = _defaultConfig();
            cfg.unsettledLimit = rejected[i];
            vm.expectRevert(IEtnaInbox.InvalidUnsettledLimit.selector);
            _newInboxImpl(cfg);
        }
    }

    function test_constructor_RevertWhen_AddressIsZero() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.proofVerifier = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.signalService = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.etnaStaking = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.protocolFeeRecipient = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);
    }

    function test_constructor_RevertWhen_L2ChainIdIsZero() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.l2ChainId = 0;
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        _newInboxImpl(cfg);
    }

    /// @dev START-10-18: maxBatchBlocks >= 1, and a one-block batch is allowed.
    function test_init_rejectsMaxBatchBlocks0() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.maxBatchBlocks = 0;
        vm.expectRevert(IEtnaInbox.InvalidMaxBatchBlocks.selector);
        _newInboxImpl(cfg);

        cfg.maxBatchBlocks = 1;
        assertEq(_newInboxImpl(cfg).maxBatchBlocks(), 1);
    }

    /// @dev PARAM-11-6: the cap is the largest batch whose landing fits one transaction
    /// (`test_maxBatchBlocksLimit_FitsOneTransaction`).
    function test_init_rejectsMaxBatchBlocksAboveCap() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.maxBatchBlocks = MAX_BATCH_BLOCKS_CAP + 1;
        vm.expectRevert(IEtnaInbox.InvalidMaxBatchBlocks.selector);
        _newInboxImpl(cfg);

        cfg.maxBatchBlocks = type(uint64).max;
        vm.expectRevert(IEtnaInbox.InvalidMaxBatchBlocks.selector);
        _newInboxImpl(cfg);

        cfg.maxBatchBlocks = MAX_BATCH_BLOCKS_CAP;
        assertEq(_newInboxImpl(cfg).maxBatchBlocks(), MAX_BATCH_BLOCKS_CAP);
    }

    /// @dev PARAM-11-6: a landing of B blocks carries B - 1 leaves. With a 4 KiB proof (generous
    /// for the two sub-proofs) and every calldata byte priced as non-zero at the EIP-7623 floor,
    /// the cap B = 12,952 (12,951 leaves, 418,884 bytes, 16,776,360 gas) stays below the EIP-7825
    /// cap of 2^24 gas, and B + 1 (32 more bytes) does not. `EtnaInboxLandTest` measures `land`
    /// at the cap and shows that this floor, not execution, sets the transaction's gas.
    function test_maxBatchBlocksLimit_FitsOneTransaction() external pure {
        assertEq(_landFloorGas(MAX_BATCH_BLOCKS_CAP - 1), 16_776_360, "floor at the cap");
        assertLt(_landFloorGas(MAX_BATCH_BLOCKS_CAP - 1), 2 ** 24, "the cap fits");
        assertGt(_landFloorGas(MAX_BATCH_BLOCKS_CAP), 2 ** 24, "one more block does not");
    }

    function test_constructor_RevertWhen_ForcedInclusionFeeOrThresholdIsZero() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.forcedInclusionFeeInGwei = 0;
        vm.expectRevert(IEtnaInbox.ForcedInclusionFeeZero.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.forcedInclusionFeeDoubleThreshold = 0;
        vm.expectRevert(IEtnaInbox.ForcedInclusionFeeDoubleThresholdZero.selector);
        _newInboxImpl(cfg);
    }

    // ---------------------------------------------------------------
    // bootstrap
    // ---------------------------------------------------------------

    function test_bootstrap_SetsOwnerAndReportsUninitialized() external view {
        assertEq(EssentialContract(inboxProxy).owner(), address(this), "owner");
        assertFalse(IEtnaInbox(inboxProxy).isInitialized(), "uninitialized");
        assertEq(
            uint256(vm.load(inboxProxy, bytes32(INITIALIZATION_STATUS_SLOT))),
            0,
            "slot 258 stays zero"
        );
    }

    function test_bootstrap_RevertWhen_InitializedTwice() external {
        vm.expectRevert("Initializable: contract is already initialized");
        EtnaInboxBootstrap(inboxProxy).init(Alice);
        assertEq(EssentialContract(inboxProxy).owner(), address(this), "owner unchanged");
    }

    function test_bootstrap_ImplementationCannotBeInitialized() external {
        EtnaInboxBootstrap impl = new EtnaInboxBootstrap();
        vm.expectRevert("Initializable: contract is already initialized");
        impl.init(address(this));
    }

    // ---------------------------------------------------------------
    // init
    // ---------------------------------------------------------------

    /// @dev `init` writes the config hash over the four words tag, L2 chain id, EtnaStaking proxy
    /// and U (slot 269) and announces it with both immutables.
    function test_init_WritesTheFourWordConfigHash() external {
        assertEq(
            keccak256(
                abi.encode(
                    bytes32("ETNA_CONFIG_V1"), uint256(167_001), ETNA_STAKING, uint256(151_200)
                )
            ),
            _DEFAULT_CONFIG_HASH,
            "four words"
        );

        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.EtnaInitialized(_DEFAULT_CONFIG_HASH, ETNA_STAKING, 151_200);
        _upgradeAndInit(inboxImpl, _defaultInitParams());

        assertEq(bytes32(_load(CONFIG_HASH_SLOT)), _DEFAULT_CONFIG_HASH, "slot 269");
        assertEq(IEtnaInbox(inboxProxy).configHash(), _DEFAULT_CONFIG_HASH, "configHash()");
    }

    /// @dev The config hash of an Inbox for L2 chain 167000 with EtnaStaking at 0x1111..1111 and
    /// U = 151,200 is the specification's literal.
    function test_configHash_MatchesTheSpecLiteral() external {
        bytes32 literal = 0x78f4b267763e0c4b58a0606e29530287b1761bf4155630c82e79d3e1215fe3b6;
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.l2ChainId = 167_000;
        cfg.etnaStaking = 0x1111111111111111111111111111111111111111;
        cfg.unsettledLimit = 151_200;
        _deployFreshInbox(cfg, _defaultInitParams(), true);

        assertEq(IEtnaInbox(inboxProxy).configHash(), literal, "configHash()");
        assertEq(bytes32(_load(CONFIG_HASH_SLOT)), literal, "slot 269");
    }

    function test_init_WritesAppendixBInitialValues() external {
        uint256 l1Block = block.number;

        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.EtnaInitialized(_DEFAULT_CONFIG_HASH, ETNA_STAKING, UNSETTLED_LIMIT);
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.StartWritten(0, GENESIS_BLOCK_HASH, GENESIS_STATE_ROOT);
        _upgradeAndInit(inboxImpl, _defaultInitParams());

        assertEq(_load(INITIALIZATION_STATUS_SLOT), 3, "258");
        assertEq(_load(RECOVERY_GENERATION_SLOT), 0, "268");
        assertEq(bytes32(_load(CONFIG_HASH_SLOT)), _DEFAULT_CONFIG_HASH, "269");
        assertEq(_load(LAST_CHECKPOINT_HEIGHT_SLOT), 0, "270");
        assertEq(bytes32(_load(LAST_CHECKPOINT_HASH_SLOT)), GENESIS_BLOCK_HASH, "271");
        assertEq(_load(GENESIS_PACKED_SLOT), 0 | l1Block << 48, "272");
        assertEq(_load(GENESIS_PACKED_SLOT) >> 96, 0, "272: every bit from 96 up is zero");
        assertEq(bytes32(_load(GENESIS_BLOCK_HASH_SLOT)), GENESIS_BLOCK_HASH, "273");
        assertEq(bytes32(_load(GENESIS_STATE_ROOT_SLOT)), GENESIS_STATE_ROOT, "274");
        assertEq(_load(278), 0, "278");
        assertEq(_load(279), 0, "279");
        assertEq(_load(FORCED_INCLUSION_HEAD_TAIL_SLOT), 0, "281");
        assertEq(_load(FORCED_INCLUSION_CONFIG_SLOT), 3600 | 7200 << 48, "282");
        assertEq(_load(RESERVED_SLOT_284), 0, "284");
        // Every other slot from 251 on stays zero, the reserved ones and the rules schedule
        // (slot 293) included.
        for (uint256 slot = 251; slot < 301; ++slot) {
            if (slot == INITIALIZATION_STATUS_SLOT || slot == CONFIG_HASH_SLOT) continue;
            if (slot >= LAST_CHECKPOINT_HASH_SLOT && slot <= GENESIS_STATE_ROOT_SLOT) continue;
            if (slot == FORCED_INCLUSION_CONFIG_SLOT) continue;
            assertEq(_load(slot), 0, string.concat("slot ", vm.toString(slot)));
        }
        // `reinitializer(2)`: the bootstrap's `initializer` left version 1.
        assertEq(uint8(_load(0)), 2, "initializer version");

        IEtnaInbox inbox = IEtnaInbox(inboxProxy);
        IEtnaInbox.Landing memory landing = inbox.landings(0);
        assertEq(landing.parentHeight, 0, "landings(0).parentHeight");
        assertEq(landing.generation, 0, "landings(0).generation");
        assertEq(landing.head, 0, "landings(0).head");
        assertEq(landing.elHash, GENESIS_BLOCK_HASH, "landings(0).elHash");
        assertEq(landing.cometHash, 0, "landings(0).cometHash");
        assertEq(
            vm.load(
                inboxProxy, bytes32(uint256(keccak256(abi.encode(uint256(0), LANDINGS_SLOT))) + 3)
            ),
            bytes32(0),
            "start fourth word"
        );
        IEtnaInbox.Origin memory origin = inbox.origins(0);
        assertEq(origin.startHeight, 0, "origins(0).startHeight");
        assertEq(origin.l1BlockNumber, l1Block, "origins(0).l1BlockNumber");
        assertEq(origin.l1Timestamp, block.timestamp, "origins(0).l1Timestamp");
        assertEq(inbox.generationStartHeight(), 0, "generationStartHeight");
        assertTrue(inbox.isInitialized(), "isInitialized");
        (uint48 startHeight, bytes32 startHash) = inbox.etnaStart();
        assertEq(startHeight, 0, "etnaStart height");
        assertEq(startHash, GENESIS_BLOCK_HASH, "etnaStart hash");
        IEtnaInbox.RulesSchedule memory schedule = inbox.rulesSchedule();
        assertEq(schedule.activeRules | schedule.nextRules | schedule.rulesTime, 0, "rules 0");
        assertEq(schedule.stopTime, 0, "no stop");

        ICheckpointStore.Checkpoint memory checkpoint = signalService.getCheckpoint(0);
        assertEq(checkpoint.blockNumber, 0, "checkpoint number");
        assertEq(checkpoint.blockHash, GENESIS_BLOCK_HASH, "checkpoint hash");
        assertEq(checkpoint.stateRoot, GENESIS_STATE_ROOT, "checkpoint state root");
    }

    function test_init_RevertWhen_CallerIsNotOwner() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();

        vm.prank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        EssentialContract(inboxProxy)
            .upgradeToAndCall(address(inboxImpl), abi.encodeCall(EtnaInbox.init, (params)));

        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        vm.prank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        IEtnaInbox(inboxProxy).init(params);
        assertFalse(IEtnaInbox(inboxProxy).isInitialized(), "not initialized by Bob");

        // A proxy deployed straight onto `EtnaInbox` has no owner, so nobody can initialize it.
        vm.expectRevert("Ownable: caller is not the owner");
        new ERC1967Proxy(address(inboxImpl), abi.encodeCall(EtnaInbox.init, (params)));

        IEtnaInbox(inboxProxy).init(params);
        assertTrue(IEtnaInbox(inboxProxy).isInitialized(), "initialized by the owner");
    }

    function test_init_RevertWhen_ImplementationIsCalledDirectly() external {
        vm.expectRevert("Initializable: contract is already initialized");
        inboxImpl.init(_defaultInitParams());
    }

    function test_init_RevertWhen_CalledTwice() external {
        _upgradeAndInit(inboxImpl, _defaultInitParams());

        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisBlockHash = keccak256("another genesis");
        vm.expectRevert("Initializable: contract is already initialized");
        IEtnaInbox(inboxProxy).init(params);
        EtnaInbox newImpl = _newInboxImpl(_defaultConfig());
        vm.expectRevert("Initializable: contract is already initialized");
        _upgradeAndInit(newImpl, params);

        assertEq(bytes32(_load(LAST_CHECKPOINT_HASH_SLOT)), GENESIS_BLOCK_HASH, "genesis kept");
    }

    /// @dev Each seeded field survives init today; upgrading an unrelated proxy must not make
    /// its old generation, authorization, queue, schedule or start look like fresh Etna state.
    function test_init_RevertWhen_ReliedOnInitialStorageIsDirty() external {
        uint256[12] memory slots =
            [uint256(258), 268, 269, 270, 271, 272, 273, 274, 281, 282, 292, 293];
        for (uint256 i; i < slots.length; ++i) {
            uint256 snapshot = vm.snapshotState();
            vm.store(inboxProxy, bytes32(slots[i]), bytes32(uint256(1)));
            vm.expectRevert(bytes4(keccak256("DirtyInitialState()")));
            _upgradeAndInit(inboxImpl, _defaultInitParams());
            assertEq(vm.load(inboxProxy, bytes32(slots[i])), bytes32(uint256(1)));
            assertTrue(vm.revertToState(snapshot));
        }
    }

    function test_init_RevertWhen_InitialOriginIsDirty() external {
        for (uint256 generation; generation < 2; ++generation) {
            uint256 originSlot = uint256(keccak256(abi.encode(generation, ORIGINS_SLOT)));
            for (uint256 i; i < 3; ++i) {
                vm.store(inboxProxy, bytes32(originSlot + i), bytes32(uint256(1)));
                vm.expectRevert(bytes4(keccak256("DirtyInitialState()")));
                _upgradeAndInit(inboxImpl, _defaultInitParams());
                vm.store(inboxProxy, bytes32(originSlot + i), 0);
            }
        }
    }

    function test_init_RevertWhen_ForcedInclusionDelayZeroOrWide() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.forcedInclusionDelay = 0;
        _assertInitRejects(params, IEtnaInbox.InvalidForcedInclusionDelay.selector);
        params.forcedInclusionDelay = _TWO_POW_48;
        _assertInitRejects(params, IEtnaInbox.InvalidForcedInclusionDelay.selector);
        params.forcedInclusionDelay = 1;
        _assertInitAccepts(params);
        params.forcedInclusionDelay = _TWO_POW_48 - 1;
        _assertInitAccepts(params);
    }

    function test_init_RevertWhen_MaxAnchorAgeOutOfRange() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.maxAnchorAge = 1151;
        _assertInitRejects(params, IEtnaInbox.InvalidMaxAnchorAge.selector);
        params.maxAnchorAge = _TWO_POW_48;
        _assertInitRejects(params, IEtnaInbox.InvalidMaxAnchorAge.selector);
        params.maxAnchorAge = 1152;
        _assertInitAccepts(params);
        params.maxAnchorAge = _TWO_POW_48 - 1;
        _assertInitAccepts(params);
    }

    function test_init_RevertWhen_GenesisHashOrStateRootZero() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisBlockHash = 0;
        _assertInitRejects(params, IEtnaInbox.InvalidGenesis.selector);

        params = _defaultInitParams();
        params.genesisStateRoot = 0;
        _assertInitRejects(params, IEtnaInbox.InvalidGenesis.selector);
    }

    function test_init_RevertWhen_L1BlockOverflows48Bits() external {
        vm.roll(_TWO_POW_48);
        _assertInitRejects(_defaultInitParams(), IEtnaInbox.ValueOverflow.selector);
        assertEq(_load(INITIALIZATION_STATUS_SLOT), 0, "no partial write");

        vm.roll(_TWO_POW_48 - 1);
        _upgradeAndInit(inboxImpl, _defaultInitParams());
        assertEq(IEtnaInbox(inboxProxy).genesis().l1Block, _TWO_POW_48 - 1, "L1_0");
        assertEq(IEtnaInbox(inboxProxy).origins(0).l1BlockNumber, _TWO_POW_48 - 1, "origin");
    }

    function test_init_RevertWhen_TimestampOverflows48Bits() external {
        vm.warp(_TWO_POW_48);
        _assertInitRejects(_defaultInitParams(), IEtnaInbox.ValueOverflow.selector);
        assertEq(_load(INITIALIZATION_STATUS_SLOT), 0, "no partial write");

        vm.warp(_TWO_POW_48 - 1);
        _upgradeAndInit(inboxImpl, _defaultInitParams());
        assertEq(IEtnaInbox(inboxProxy).origins(0).l1Timestamp, _TWO_POW_48 - 1, "origin");
    }

    function test_init_RollsBackIfSignalCheckpointCannotBeSaved() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.signalService = address(_deploySignalService(Bob));
        EssentialContract(inboxProxy).upgradeTo(address(_newInboxImpl(cfg)));

        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        IEtnaInbox(inboxProxy).init(_defaultInitParams());

        assertFalse(IEtnaInbox(inboxProxy).isInitialized(), "isInitialized");
        assertEq(_load(INITIALIZATION_STATUS_SLOT), 0, "258");
        assertEq(_load(CONFIG_HASH_SLOT), 0, "269");
        assertEq(_load(LAST_CHECKPOINT_HASH_SLOT), 0, "271");
        assertEq(_load(GENESIS_PACKED_SLOT), 0, "272");
        assertEq(IEtnaInbox(inboxProxy).landings(0).elHash, 0, "landings(0)");
        assertEq(IEtnaInbox(inboxProxy).origins(0).l1BlockNumber, 0, "origins(0)");
        assertEq(uint8(_load(0)), 1, "initializer version");

        // The owner can still initialize with a SignalService that authorizes the proxy.
        _upgradeAndInit(inboxImpl, _defaultInitParams());
        assertTrue(IEtnaInbox(inboxProxy).isInitialized(), "initialized after the fix");
    }

    /// @dev `init` is nonpayable, so ETH sent along the owner's `upgradeToAndCall` reverts the
    /// whole upgrade; only `saveForcedInclusion` accepts ETH (spec 7.1).
    function test_init_RevertWhen_EtherSent() external {
        address bootstrap = EssentialContract(inboxProxy).impl();
        bytes memory initCall = abi.encodeCall(EtnaInbox.init, (_defaultInitParams()));
        vm.deal(address(this), 2);

        vm.expectRevert("Address: low-level delegate call failed");
        EssentialContract(inboxProxy).upgradeToAndCall{ value: 1 }(address(inboxImpl), initCall);
        assertEq(EssentialContract(inboxProxy).impl(), bootstrap, "still on the bootstrap");

        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        (bool ok,) = inboxProxy.call{ value: 1 }(initCall);
        assertFalse(ok, "payable init");
        assertFalse(IEtnaInbox(inboxProxy).isInitialized(), "not initialized");
        assertEq(inboxProxy.balance, 0, "no ETH kept");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev 21,000 intrinsic gas plus the EIP-7623 floor of 40 gas per byte, counting every byte
    /// as non-zero, for the calldata of `land` with `_leafCount` leaves and a 4 KiB proof.
    function _landFloorGas(uint256 _leafCount) private pure returns (uint256) {
        IEtnaInbox.LandInput memory input;
        bytes memory data =
            abi.encodeCall(IEtnaInbox.land, (input, new bytes32[](_leafCount), new bytes(4096)));
        return 21_000 + 40 * data.length;
    }

    /// @dev Expects `init(_params)` through the owner's upgrade to `inboxImpl` to revert with
    /// `_selector`.
    function _assertInitRejects(
        IEtnaInbox.InitParams memory _params,
        bytes4 _selector
    )
        private
    {
        vm.expectRevert(_selector);
        _upgradeAndInit(inboxImpl, _params);
    }

    /// @dev Initializes through `inboxImpl` with `_params`, checks the stored parameters, then
    /// restores the uninitialized state.
    function _assertInitAccepts(IEtnaInbox.InitParams memory _params) private {
        uint256 fresh = vm.snapshotState();
        _upgradeAndInit(inboxImpl, _params);
        IEtnaInbox inbox = IEtnaInbox(inboxProxy);
        assertTrue(inbox.isInitialized(), "initialized");
        assertEq(inbox.configHash(), _DEFAULT_CONFIG_HASH, "config hash");
        assertEq(inbox.forcedInclusionDelay(), _params.forcedInclusionDelay, "delay");
        assertEq(inbox.maxAnchorAge(), _params.maxAnchorAge, "max anchor age");
        vm.revertToState(fresh);
    }

    function _load(uint256 _slot) private view returns (uint256) {
        return uint256(vm.load(inboxProxy, bytes32(_slot)));
    }
}
