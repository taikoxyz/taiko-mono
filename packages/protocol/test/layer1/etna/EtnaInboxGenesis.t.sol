// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract EtnaInboxGenesisTest is EtnaInboxTestBase {
    /// @dev 2^48, the first value a 48-bit field cannot hold.
    uint256 private constant _TWO_POW_48 = 2 ** 48;

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
        assertEq(impl.stakingRegistry(), address(registry), "registry");
        assertEq(impl.l2ChainId(), L2_CHAIN_ID, "l2 chain id");
        assertEq(impl.maxBatchBlocks(), MAX_BATCH_BLOCKS, "max batch blocks");
        assertEq(impl.forcedInclusionFeeInGwei(), FORCED_INCLUSION_FEE_GWEI, "fee");
        assertEq(
            impl.forcedInclusionFeeDoubleThreshold(),
            FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            "fee threshold"
        );
        assertEq(impl.protocolFeeRecipient(), PROTOCOL_FEE_RECIPIENT, "protocol fee recipient");
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
        cfg.stakingRegistry = address(0);
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

    function test_constructor_RevertWhen_MaxBatchBlocksBelowSix() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.maxBatchBlocks = 0;
        vm.expectRevert(IEtnaInbox.InvalidMaxBatchBlocks.selector);
        _newInboxImpl(cfg);

        cfg.maxBatchBlocks = 5;
        vm.expectRevert(IEtnaInbox.InvalidMaxBatchBlocks.selector);
        _newInboxImpl(cfg);

        // One grid segment; no multiple-of-six rule (C15).
        cfg.maxBatchBlocks = 6;
        assertEq(_newInboxImpl(cfg).maxBatchBlocks(), 6);
        cfg.maxBatchBlocks = 7;
        assertEq(_newInboxImpl(cfg).maxBatchBlocks(), 7);
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
    // bootstrap (C2)
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

    function test_init_WritesAppendixBInitialValues() external {
        uint256 l1Block = block.number;
        uint256 cutoff = registryCheckpointBlock;
        bytes32 configHash = keccak256(
            abi.encode(
                bytes32("ETNA_PARENT_ANCHOR_V1"),
                uint256(L2_CHAIN_ID),
                address(registry),
                uint256(1e9),
                uint256(1000 ether),
                uint256(128),
                uint256(3600)
            )
        );

        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.EtnaInitialized(
            GENESIS_BLOCK_HASH,
            GENESIS_STATE_ROOT,
            l1Block,
            10,
            cutoff,
            COMMITTEE_RECORD_HASH,
            configHash
        );
        _upgradeAndInit(inboxImpl, _defaultInitParams());

        assertEq(_load(INITIALIZATION_STATUS_SLOT), 3, "258");
        assertEq(_load(RECOVERY_GENERATION_SLOT), 0, "268");
        assertEq(bytes32(_load(COMMITTEE_CONFIG_HASH_SLOT)), configHash, "269");
        assertEq(_load(LAST_CHECKPOINT_HEIGHT_SLOT), 0, "270");
        assertEq(bytes32(_load(LAST_CHECKPOINT_HASH_SLOT)), GENESIS_BLOCK_HASH, "271");
        assertEq(_load(GENESIS_PACKED_SLOT), 0 | l1Block << 48 | 10 << 96, "272");
        assertEq(bytes32(_load(GENESIS_BLOCK_HASH_SLOT)), GENESIS_BLOCK_HASH, "273");
        assertEq(bytes32(_load(GENESIS_STATE_ROOT_SLOT)), GENESIS_STATE_ROOT, "274");
        assertEq(bytes32(_load(GENESIS_COMMITTEE_RECORD_HASH_SLOT)), COMMITTEE_RECORD_HASH, "278");
        assertEq(_load(GENESIS_CUTOFF_SLOT), cutoff, "279");
        assertEq(_load(FORCED_INCLUSION_HEAD_TAIL_SLOT), 0, "281");
        assertEq(_load(FORCED_INCLUSION_CONFIG_SLOT), 3600 | 7200 << 48, "282");
        assertEq(_load(ACTIVE_COMMITTEE_SNAPSHOT_SLOT), cutoff, "284");
        // Every other slot from 251 on stays zero, the reserved ones included.
        for (uint256 slot = 251; slot < 301; ++slot) {
            if (slot == INITIALIZATION_STATUS_SLOT || slot == COMMITTEE_CONFIG_HASH_SLOT) continue;
            if (slot >= LAST_CHECKPOINT_HASH_SLOT && slot <= GENESIS_STATE_ROOT_SLOT) continue;
            if (slot >= GENESIS_COMMITTEE_RECORD_HASH_SLOT && slot <= GENESIS_CUTOFF_SLOT) {
                continue;
            }
            if (slot == FORCED_INCLUSION_CONFIG_SLOT || slot == ACTIVE_COMMITTEE_SNAPSHOT_SLOT) {
                continue;
            }
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
        IEtnaInbox.Origin memory origin = inbox.origins(0);
        assertEq(origin.startHeight, 0, "origins(0).startHeight");
        assertEq(origin.l1BlockNumber, l1Block, "origins(0).l1BlockNumber");
        assertEq(origin.l1Timestamp, block.timestamp, "origins(0).l1Timestamp");
        assertEq(inbox.generationStartHeight(), 0, "generationStartHeight");
        assertEq(inbox.recoverySnapshot(), l1Block, "recoverySnapshot");
        assertTrue(inbox.isInitialized(), "isInitialized");

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

    function test_init_RevertWhen_RegistryInboxMismatch() external {
        // A registry valid in every other way: same L2 chain id, a checkpoint at the cutoff.
        EtnaStakingRegistry other = _deployRegistry(_deployInboxProxy());
        _registerValidator(other, Alice, VALIDATOR_PK);
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisCutoff = block.number;
        vm.roll(block.number + 1);

        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.stakingRegistry = address(other);
        EtnaInbox impl = _newInboxImpl(cfg);
        vm.expectRevert(IEtnaInbox.RegistryMismatch.selector);
        _upgradeAndInit(impl, params);

        cfg.stakingRegistry = address(registry);
        _assertInitAccepts(_newInboxImpl(cfg), params);
    }

    function test_init_RevertWhen_RegistryL2ChainIdMismatch() external {
        // The implementation's chain id differs from the registry's.
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.l2ChainId = L2_CHAIN_ID + 1;
        EtnaInbox impl = _newInboxImpl(cfg);
        vm.expectRevert(IEtnaInbox.RegistryMismatch.selector);
        _upgradeAndInit(impl, _defaultInitParams());

        // The registry's chain id differs from the implementation's.
        IEtnaStakingRegistry.Config memory registryCfg =
            _registryConfig(address(taikoToken), inboxProxy);
        registryCfg.l2ChainId = L2_CHAIN_ID + 1;
        EtnaStakingRegistry other = _deployRegistry(registryCfg);
        _registerValidator(other, Alice, VALIDATOR_PK);
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisCutoff = block.number;
        vm.roll(block.number + 1);
        cfg = _defaultConfig();
        cfg.stakingRegistry = address(other);
        impl = _newInboxImpl(cfg);
        vm.expectRevert(IEtnaInbox.RegistryMismatch.selector);
        _upgradeAndInit(impl, params);
    }

    /// @dev Lean `config_u_range`: U is a multiple of 6 in [6, 65,532]. 9 and 3,603 are multiples
    /// of 3 only, 3,602 of 2 only.
    function test_init_RevertWhen_UnsettledLimitInvalid() external {
        uint256[8] memory rejected = [uint256(0), 5, 9, 3601, 3602, 3603, 65_536, 65_538];
        for (uint256 i; i < rejected.length; ++i) {
            IEtnaInbox.InitParams memory params = _defaultInitParams();
            params.committeeConfig.unsettledLimit = rejected[i];
            _assertInitRejects(params, IEtnaInbox.InvalidCommitteeConfig.selector);
        }
        uint256[3] memory accepted = [uint256(6), 3600, 65_532];
        for (uint256 i; i < accepted.length; ++i) {
            IEtnaInbox.InitParams memory params = _defaultInitParams();
            params.committeeConfig.unsettledLimit = accepted[i];
            _assertInitAccepts(params);
        }
    }

    function test_init_RevertWhen_VpUnitBelowBound() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.committeeConfig.vpUnit = 867_361_737;
        _assertInitRejects(params, IEtnaInbox.InvalidCommitteeConfig.selector);
        params.committeeConfig.vpUnit = 867_361_738;
        _assertInitAccepts(params);
    }

    function test_init_RevertWhen_SMinBelowVpUnit() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.committeeConfig.sMin = 0;
        _assertInitRejects(params, IEtnaInbox.InvalidCommitteeConfig.selector);
        params.committeeConfig.sMin = VP_UNIT - 1;
        _assertInitRejects(params, IEtnaInbox.InvalidCommitteeConfig.selector);
        params.committeeConfig.sMin = VP_UNIT;
        _assertInitAccepts(params);
    }

    function test_init_RevertWhen_NMaxOutOfRange() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.committeeConfig.nMax = 0;
        _assertInitRejects(params, IEtnaInbox.InvalidCommitteeConfig.selector);
        params.committeeConfig.nMax = 4097;
        _assertInitRejects(params, IEtnaInbox.InvalidCommitteeConfig.selector);
        params.committeeConfig.nMax = 1;
        _assertInitAccepts(params);
        params.committeeConfig.nMax = 4096;
        _assertInitAccepts(params);
    }

    /// @dev L >= 3 and L + 1 < 2^48.
    function test_init_RevertWhen_EpochLengthOutOfRange() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        uint256[4] memory rejected = [uint256(0), 2, _TWO_POW_48 - 1, type(uint256).max];
        for (uint256 i; i < rejected.length; ++i) {
            params.epochLenL2 = rejected[i];
            _assertInitRejects(params, IEtnaInbox.InvalidEpochLength.selector);
        }
        params.epochLenL2 = 3;
        _assertInitAccepts(params);
        params.epochLenL2 = _TWO_POW_48 - 2;
        _assertInitAccepts(params);
    }

    function test_init_RevertWhen_GenesisCutoffNotPastOrBeforeFirstCheckpoint() external {
        vm.roll(block.number + 5);
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        uint256[4] memory rejected = [
            block.number, // not in the past
            block.number + 1,
            registryCheckpointBlock - 1, // before the first checkpoint
            type(uint256).max
        ];
        for (uint256 i; i < rejected.length; ++i) {
            params.genesisCutoff = rejected[i];
            _assertInitRejects(params, IEtnaInbox.InvalidGenesisCutoff.selector);
        }
        params.genesisCutoff = registryCheckpointBlock;
        _assertInitAccepts(params);
        params.genesisCutoff = block.number - 1;
        _assertInitAccepts(params);

        // A registry fixed to this proxy without any checkpoint accepts no cutoff.
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.stakingRegistry = address(_deployRegistry(inboxProxy));
        EtnaInbox impl = _newInboxImpl(cfg);
        params.genesisCutoff = registryCheckpointBlock;
        vm.expectRevert(IEtnaInbox.InvalidGenesisCutoff.selector);
        _upgradeAndInit(impl, params);
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

    function test_init_RevertWhen_GenesisHashStateRootOrRecordZero() external {
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisBlockHash = 0;
        _assertInitRejects(params, IEtnaInbox.InvalidGenesis.selector);

        params = _defaultInitParams();
        params.genesisStateRoot = 0;
        _assertInitRejects(params, IEtnaInbox.InvalidGenesis.selector);

        params = _defaultInitParams();
        params.committeeRecordHash = 0;
        _assertInitRejects(params, IEtnaInbox.ZeroCommitteeRecord.selector);
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
        assertEq(_load(COMMITTEE_CONFIG_HASH_SLOT), 0, "269");
        assertEq(_load(LAST_CHECKPOINT_HASH_SLOT), 0, "271");
        assertEq(_load(GENESIS_PACKED_SLOT), 0, "272");
        assertEq(_load(ACTIVE_COMMITTEE_SNAPSHOT_SLOT), 0, "284");
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

    /// @dev Expects `init(_params)` through the owner's upgrade to `inboxImpl` to revert with
    /// `_selector`.
    function _assertInitRejects(IEtnaInbox.InitParams memory _params, bytes4 _selector) private {
        vm.expectRevert(_selector);
        _upgradeAndInit(inboxImpl, _params);
    }

    /// @dev `_assertInitAccepts` through `inboxImpl`.
    function _assertInitAccepts(IEtnaInbox.InitParams memory _params) private {
        _assertInitAccepts(inboxImpl, _params);
    }

    /// @dev Initializes through `_impl` with `_params`, checks the stored parameters, then
    /// restores the uninitialized state.
    function _assertInitAccepts(EtnaInbox _impl, IEtnaInbox.InitParams memory _params) private {
        uint256 fresh = vm.snapshotState();
        _upgradeAndInit(_impl, _params);
        IEtnaInbox inbox = IEtnaInbox(inboxProxy);
        assertTrue(inbox.isInitialized(), "initialized");
        IEtnaInbox.CommitteeConfig memory c = _params.committeeConfig;
        bytes32 configHash = keccak256(
            abi.encode(
                bytes32("ETNA_PARENT_ANCHOR_V1"),
                uint256(L2_CHAIN_ID),
                _impl.stakingRegistry(),
                c.vpUnit,
                c.sMin,
                c.nMax,
                c.unsettledLimit
            )
        );
        assertEq(inbox.committeeConfigHash(), configHash, "config hash");
        assertEq(inbox.genesis().epochLenL2, _params.epochLenL2, "L");
        assertEq(inbox.genesisCutoff(), _params.genesisCutoff, "cutoff");
        assertEq(inbox.activeCommitteeSnapshot(), _params.genesisCutoff, "snapshot");
        assertEq(inbox.forcedInclusionDelay(), _params.forcedInclusionDelay, "delay");
        assertEq(inbox.maxAnchorAge(), _params.maxAnchorAge, "max anchor age");
        vm.revertToState(fresh);
    }

    function _load(uint256 _slot) private view returns (uint256) {
        return uint256(vm.load(inboxProxy, bytes32(_slot)));
    }
}
