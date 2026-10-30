// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestConstants } from "./EtnaTestConstants.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @notice A `land` proof verifier that accepts every proof until it is told to reject.
/// @dev `verifyProof` is a view; tests observe its statement hash with `vm.expectCall`.
contract MockLandProofVerifier is IProofVerifier {
    bool public rejects;
    bytes32 public expectedStatementHash;

    function setRejects(bool _rejects) external {
        rejects = _rejects;
    }

    /// @dev Models a proof accepted only for one public statement, without implementing a guest.
    function setExpectedStatementHash(bytes32 _statementHash) external {
        expectedStatementHash = _statementHash;
    }

    function verifyProof(
        uint256 _proposalAge,
        bytes32 _statementHash,
        bytes calldata
    )
        external
        view
    {
        require(!rejects && _proposalAge == 0, ProofRejected());
        require(
            expectedStatementHash == 0 || _statementHash == expectedStatementHash, ProofRejected()
        );
    }

    error ProofRejected();
}

/// @title EtnaInboxTestBase
/// @notice Deploys the Etna contracts in the owner-initialized order: the Inbox proxy on its
/// bootstrap implementation, the registry fixed to that proxy, a validator registration, the
/// SignalService authorizing the proxy and the `EtnaInbox` implementation, which the owner then
/// upgrades to and initializes in one transaction.
/// @dev `setUp` initializes the Inbox unless a suite overrides `_initializeOnSetUp`. The test
/// contract owns both proxies.
abstract contract EtnaInboxTestBase is CommonTest, EtnaTestConstants {
    // ---------------------------------------------------------------
    // Inbox storage slots (spec appendix B)
    // ---------------------------------------------------------------

    uint256 internal constant INITIALIZATION_STATUS_SLOT = 258;
    uint256 internal constant RECOVERY_GENERATION_SLOT = 268;
    uint256 internal constant COMMITTEE_CONFIG_HASH_SLOT = 269;
    uint256 internal constant LAST_CHECKPOINT_HEIGHT_SLOT = 270;
    uint256 internal constant LAST_CHECKPOINT_HASH_SLOT = 271;
    uint256 internal constant GENESIS_PACKED_SLOT = 272;
    uint256 internal constant GENESIS_BLOCK_HASH_SLOT = 273;
    uint256 internal constant GENESIS_STATE_ROOT_SLOT = 274;
    uint256 internal constant GENESIS_COMMITTEE_RECORD_HASH_SLOT = 278;
    uint256 internal constant GENESIS_CUTOFF_SLOT = 279;
    uint256 internal constant FORCED_INCLUSION_QUEUE_SLOT = 280;
    uint256 internal constant FORCED_INCLUSION_HEAD_TAIL_SLOT = 281;
    uint256 internal constant FORCED_INCLUSION_CONFIG_SLOT = 282;
    uint256 internal constant RESERVED_SLOT_283 = 283;
    uint256 internal constant ACTIVE_COMMITTEE_SNAPSHOT_SLOT = 284;
    uint256 internal constant LANDINGS_SLOT = 285;
    uint256 internal constant RESERVED_SLOT_286 = 286;
    uint256 internal constant RESERVED_SLOT_287 = 287;
    uint256 internal constant RESERVED_SLOT_288 = 288;
    uint256 internal constant RESERVED_SLOT_289 = 289;
    uint256 internal constant ORIGINS_SLOT = 290;
    uint256 internal constant RESERVED_SLOT_291 = 291;

    // ---------------------------------------------------------------
    // Deployment parameters (the shared ones are in `EtnaTestConstants`)
    // ---------------------------------------------------------------

    uint64 internal constant MAX_BATCH_BLOCKS = 1000;
    uint64 internal constant FORCED_INCLUSION_FEE_GWEI = 10_000_000;
    uint64 internal constant FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD = 50;
    address internal constant PROTOCOL_FEE_RECIPIENT = address(0xfee);
    address internal constant REMOTE_SIGNAL_SERVICE = address(0xdead);

    // ---------------------------------------------------------------
    // Genesis parameters (`_defaultInitParams`)
    // ---------------------------------------------------------------

    bytes32 internal constant GENESIS_BLOCK_HASH = keccak256("Etna L2 genesis block");
    bytes32 internal constant GENESIS_STATE_ROOT = keccak256("Etna L2 genesis state");
    bytes32 internal constant COMMITTEE_RECORD_HASH = keccak256("Etna committee 0 record");
    uint256 internal constant EPOCH_LEN_L2 = 10;
    uint256 internal constant VP_UNIT = 1e9;
    uint256 internal constant S_MIN = 1000 ether;
    uint256 internal constant N_MAX = 128;
    uint256 internal constant UNSETTLED_LIMIT = 3600;
    uint256 internal constant FORCED_INCLUSION_DELAY = 1 hours;
    uint256 internal constant MAX_ANCHOR_AGE = 2 hours;

    /// @dev The consensus private key Alice registers before the Inbox is initialized.
    uint256 internal constant VALIDATOR_PK = 0xA11CE;

    MockLandProofVerifier internal landVerifier;
    TestERC20 internal taikoToken;
    address internal inboxProxy;
    EtnaStakingRegistry internal registry;
    SignalService internal signalService;
    /// @dev The `EtnaInbox` implementation of the latest `_deployFreshInbox`.
    EtnaInbox internal inboxImpl;
    /// @dev The L1 block of the registry's first checkpoint, the default genesis cutoff.
    uint256 internal registryCheckpointBlock;

    function setUp() public virtual override {
        super.setUp();
        landVerifier = new MockLandProofVerifier();
        taikoToken = new TestERC20("Taiko Token", "TAIKO");
        _deployFreshInbox(_initializeOnSetUp());
    }

    /// @dev Whether `setUp` initializes the Inbox; if not, the proxy stays on its bootstrap
    /// implementation.
    function _initializeOnSetUp() internal pure virtual returns (bool) {
        return true;
    }

    /// @dev `_deployFreshInbox` with `_defaultConfig()` and `_defaultInitParams()`.
    function _deployFreshInbox(bool _initialize) internal {
        _deployFreshInbox(_defaultConfig(), _defaultInitParams(), _initialize);
    }

    /// @dev Deploys a fresh Etna stack in the owner-initialized order (spec 10 steps 1 and 5): the
    /// Inbox proxy on its bootstrap implementation, the registry fixed to it, Alice's registration
    /// of `VALIDATOR_PK` (the registry's first checkpoint, at `registryCheckpointBlock`), one more
    /// L1 block, the SignalService authorizing the proxy and `inboxImpl` built from `_config`. With
    /// `_initialize`, the owner then upgrades the proxy to `inboxImpl` and calls `init(_params)` in
    /// the same transaction.
    /// `_config.signalService`, `_config.stakingRegistry` and `_params.genesisCutoff` are always
    /// set to this deployment's SignalService, registry and `registryCheckpointBlock`, the only
    /// cutoff the fresh registry accepts in this block; every other field is used as given.
    function _deployFreshInbox(
        IEtnaInbox.Config memory _config,
        IEtnaInbox.InitParams memory _params,
        bool _initialize
    )
        internal
    {
        inboxProxy = _deployInboxProxy();
        registry = _deployRegistry(inboxProxy);
        _registerValidator(registry, Alice, VALIDATOR_PK);
        registryCheckpointBlock = block.number;
        vm.roll(block.number + 1);
        signalService = _deploySignalService(inboxProxy);

        _config.signalService = address(signalService);
        _config.stakingRegistry = address(registry);
        _params.genesisCutoff = registryCheckpointBlock;
        inboxImpl = _newInboxImpl(_config);
        if (_initialize) _upgradeAndInit(inboxImpl, _params);
    }

    /// @dev The owner upgrades the Inbox proxy to `_impl` and calls `init(_params)` in the same
    /// transaction.
    function _upgradeAndInit(EtnaInbox _impl, IEtnaInbox.InitParams memory _params) internal {
        EssentialContract(inboxProxy)
            .upgradeToAndCall(address(_impl), abi.encodeCall(EtnaInbox.init, (_params)));
    }

    /// @dev Deploys an Inbox proxy on the bootstrap implementation, owned by this test.
    function _deployInboxProxy() internal returns (address) {
        return address(
            new ERC1967Proxy(
                address(new EtnaInboxBootstrap()),
                abi.encodeCall(EtnaInboxBootstrap.init, (address(this)))
            )
        );
    }

    /// @dev Deploys a registry proxy, owned by this test, whose Inbox is fixed to `_inbox`.
    function _deployRegistry(address _inbox) internal returns (EtnaStakingRegistry) {
        return _deployRegistry(_registryConfig(address(taikoToken), _inbox));
    }

    /// @dev Deploys a registry proxy, owned by this test, with `_config`.
    function _deployRegistry(IEtnaStakingRegistry.Config memory _config)
        internal
        returns (EtnaStakingRegistry)
    {
        EtnaStakingRegistry impl = new EtnaStakingRegistry(_config);
        return EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
    }

    /// @dev Mints `MIN_STAKE` to `_staker`, who registers the consensus key of `_pk` with it at
    /// `_registry`.
    function _registerValidator(
        EtnaStakingRegistry _registry,
        address _staker,
        uint256 _pk
    )
        internal
        returns (uint256 bondId_)
    {
        taikoToken.mint(_staker, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_pk);
        bytes memory pop = EtnaTestKeys.popSig(_pk, _registry, _staker);
        vm.startPrank(_staker);
        taikoToken.approve(address(_registry), MIN_STAKE);
        bondId_ = _registry.register(publicKey, MIN_STAKE, pop);
        vm.stopPrank();
    }

    /// @dev Deploys a SignalService proxy that accepts checkpoints only from `_inbox`.
    function _deploySignalService(address _inbox) internal returns (SignalService) {
        SignalService impl = new SignalService(_inbox, REMOTE_SIGNAL_SERVICE, address(0));
        return SignalService(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(SignalService.init, (address(this))))
            )
        );
    }

    function _newInboxImpl(IEtnaInbox.Config memory _config) internal returns (EtnaInbox) {
        return new EtnaInbox(_config);
    }

    function _defaultConfig() internal view returns (IEtnaInbox.Config memory) {
        return IEtnaInbox.Config({
            proofVerifier: address(landVerifier),
            signalService: address(signalService),
            stakingRegistry: address(registry),
            l2ChainId: L2_CHAIN_ID,
            maxBatchBlocks: MAX_BATCH_BLOCKS,
            forcedInclusionFeeInGwei: FORCED_INCLUSION_FEE_GWEI,
            forcedInclusionFeeDoubleThreshold: FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            protocolFeeRecipient: PROTOCOL_FEE_RECIPIENT
        });
    }

    /// @dev The genesis inputs of the latest deployment: L = 10, the registry's first checkpoint
    /// as cutoff, committee configuration (1e9, 1000 TAIKO, 128, 3600), a one-hour forced
    /// inclusion delay and a two-hour maximum anchor age.
    function _defaultInitParams() internal view returns (IEtnaInbox.InitParams memory) {
        return IEtnaInbox.InitParams({
            genesisBlockHash: GENESIS_BLOCK_HASH,
            genesisStateRoot: GENESIS_STATE_ROOT,
            epochLenL2: EPOCH_LEN_L2,
            genesisCutoff: registryCheckpointBlock,
            committeeRecordHash: COMMITTEE_RECORD_HASH,
            committeeConfig: IEtnaInbox.CommitteeConfig({
                vpUnit: VP_UNIT, sMin: S_MIN, nMax: N_MAX, unsettledLimit: UNSETTLED_LIMIT
            }),
            forcedInclusionDelay: FORCED_INCLUSION_DELAY,
            maxAnchorAge: MAX_ANCHOR_AGE
        });
    }
}
