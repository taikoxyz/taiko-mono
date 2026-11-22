// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestConstants } from "./EtnaTestConstants.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
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
/// bootstrap implementation, the SignalService authorizing the proxy and the `EtnaInbox`
/// implementation, which the owner then upgrades to and initializes in one transaction.
/// @dev `setUp` initializes the Inbox unless a suite overrides `_initializeOnSetUp`. The test
/// contract owns both proxies.
abstract contract EtnaInboxTestBase is CommonTest, EtnaTestConstants {
    // ---------------------------------------------------------------
    // Inbox storage slots (spec appendix B)
    // ---------------------------------------------------------------

    uint256 internal constant INITIALIZATION_STATUS_SLOT = 258;
    uint256 internal constant RECOVERY_GENERATION_SLOT = 268;
    uint256 internal constant CONFIG_HASH_SLOT = 269;
    uint256 internal constant LAST_CHECKPOINT_HEIGHT_SLOT = 270;
    uint256 internal constant LAST_CHECKPOINT_HASH_SLOT = 271;
    uint256 internal constant GENESIS_PACKED_SLOT = 272;
    uint256 internal constant GENESIS_BLOCK_HASH_SLOT = 273;
    uint256 internal constant GENESIS_STATE_ROOT_SLOT = 274;
    uint256 internal constant FORCED_INCLUSION_QUEUE_SLOT = 280;
    uint256 internal constant FORCED_INCLUSION_HEAD_TAIL_SLOT = 281;
    uint256 internal constant FORCED_INCLUSION_CONFIG_SLOT = 282;
    uint256 internal constant RESERVED_SLOT_283 = 283;
    uint256 internal constant RESERVED_SLOT_284 = 284;
    uint256 internal constant LANDINGS_SLOT = 285;
    uint256 internal constant RESERVED_SLOT_286 = 286;
    uint256 internal constant RESERVED_SLOT_289 = 289;
    uint256 internal constant ORIGINS_SLOT = 290;
    uint256 internal constant RESERVED_SLOT_291 = 291;
    uint256 internal constant RECOVERY_NONCE_SLOT = 292;
    uint256 internal constant RULES_SCHEDULE_SLOT = 293;

    // ---------------------------------------------------------------
    // Deployment parameters (the shared ones are in `EtnaTestConstants`)
    // ---------------------------------------------------------------

    uint64 internal constant MAX_BATCH_BLOCKS = 1000;
    /// @dev The Inbox's upper bound on `maxBatchBlocks` (PARAM-11-6).
    uint64 internal constant MAX_BATCH_BLOCKS_CAP = 12_952;
    uint64 internal constant FORCED_INCLUSION_FEE_GWEI = 10_000_000;
    uint64 internal constant FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD = 50;
    address internal constant PROTOCOL_FEE_RECIPIENT = address(0xfee);
    address internal constant REMOTE_SIGNAL_SERVICE = address(0xdead);

    // ---------------------------------------------------------------
    // Genesis parameters (`_defaultInitParams`)
    // ---------------------------------------------------------------

    bytes32 internal constant GENESIS_BLOCK_HASH = keccak256("Etna L2 genesis block");
    bytes32 internal constant GENESIS_STATE_ROOT = keccak256("Etna L2 genesis state");
    uint256 internal constant FORCED_INCLUSION_DELAY = 1 hours;
    uint256 internal constant MAX_ANCHOR_AGE = 2 hours;

    MockLandProofVerifier internal landVerifier;
    address internal inboxProxy;
    SignalService internal signalService;
    /// @dev The `EtnaInbox` implementation of the latest `_deployFreshInbox`.
    EtnaInbox internal inboxImpl;

    function setUp() public virtual override {
        super.setUp();
        landVerifier = new MockLandProofVerifier();
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
    /// Inbox proxy on its bootstrap implementation, the SignalService authorizing the proxy and
    /// `inboxImpl` built from `_config`. With `_initialize`, the owner then upgrades the proxy to
    /// `inboxImpl` and calls `init(_params)` in the same transaction.
    /// `_config.signalService` is always set to this deployment's SignalService; every other field
    /// is used as given.
    function _deployFreshInbox(
        IEtnaInbox.Config memory _config,
        IEtnaInbox.InitParams memory _params,
        bool _initialize
    )
        internal
    {
        inboxProxy = _deployInboxProxy();
        signalService = _deploySignalService(inboxProxy);

        _config.signalService = address(signalService);
        inboxImpl = _newInboxImpl(_config);
        if (_initialize) _upgradeAndInit(inboxImpl, _params);
    }

    /// @dev The owner upgrades the Inbox proxy to `_impl` and calls `init(_params)` in the same
    /// transaction.
    function _upgradeAndInit(
        EtnaInbox _impl,
        IEtnaInbox.InitParams memory _params
    )
        internal
    {
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

    /// @dev Deploys a SignalService proxy that accepts checkpoints only from `_inbox`.
    function _deploySignalService(address _inbox) internal returns (SignalService) {
        SignalService impl = new SignalService(_inbox, REMOTE_SIGNAL_SERVICE, address(0), false);
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
            etnaStaking: ETNA_STAKING,
            l2ChainId: L2_CHAIN_ID,
            maxBatchBlocks: MAX_BATCH_BLOCKS,
            forcedInclusionFeeInGwei: FORCED_INCLUSION_FEE_GWEI,
            forcedInclusionFeeDoubleThreshold: FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            protocolFeeRecipient: PROTOCOL_FEE_RECIPIENT,
            unzenInbox: address(0),
            etnaForkTime: 0,
            unsettledLimit: UNSETTLED_LIMIT
        });
    }

    /// @dev The genesis inputs: the block-0 hash and state root, a one-hour forced inclusion delay
    /// and a two-hour maximum anchor age.
    function _defaultInitParams() internal pure returns (IEtnaInbox.InitParams memory) {
        return IEtnaInbox.InitParams({
            genesisBlockHash: GENESIS_BLOCK_HASH,
            genesisStateRoot: GENESIS_STATE_ROOT,
            forcedInclusionDelay: FORCED_INCLUSION_DELAY,
            maxAnchorAge: MAX_ANCHOR_AGE
        });
    }
}
