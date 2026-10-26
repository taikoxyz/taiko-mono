// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
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
/// @notice Deploys the Etna contracts in the C2 order: the Inbox proxy on its bootstrap
/// implementation, the registry fixed to that proxy, and a SignalService authorizing it.
/// @dev The proxy stays on the bootstrap implementation; tests build `EtnaInbox` implementations
/// from `_defaultConfig()`.
abstract contract EtnaInboxTestBase is CommonTest {
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
    // Deployment parameters
    // ---------------------------------------------------------------

    uint64 internal constant L2_CHAIN_ID = 167_001;
    uint64 internal constant MAX_BATCH_BLOCKS = 1000;
    uint64 internal constant FORCED_INCLUSION_FEE_GWEI = 10_000_000;
    uint64 internal constant FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD = 50;
    address internal constant PROTOCOL_FEE_RECIPIENT = address(0xfee);

    uint256 internal constant MIN_STAKE = 1000 ether;
    uint256 internal constant ACTIVATION_DELAY = 10;
    uint256 internal constant EXIT_DELAY = 20;
    uint256 internal constant WITHDRAWAL_DELAY = 30;
    uint256 internal constant SLASH_BOUNTY_BPS = 1000;
    address internal constant SLASH_SINK = address(0x5151);
    address internal constant REMOTE_SIGNAL_SERVICE = address(0xdead);

    MockLandProofVerifier internal landVerifier;
    TestERC20 internal taikoToken;
    address internal inboxProxy;
    EtnaStakingRegistry internal registry;
    SignalService internal signalService;

    function setUp() public virtual override {
        super.setUp();
        landVerifier = new MockLandProofVerifier();
        taikoToken = new TestERC20("Taiko Token", "TAIKO");
        inboxProxy = _deployInboxProxy();
        registry = _deployRegistry(inboxProxy);
        signalService = _deploySignalService(inboxProxy);
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
        EtnaStakingRegistry impl = new EtnaStakingRegistry(
            IEtnaStakingRegistry.Config({
                token: address(taikoToken),
                minStake: MIN_STAKE,
                activationDelay: ACTIVATION_DELAY,
                exitDelay: EXIT_DELAY,
                withdrawalDelay: WITHDRAWAL_DELAY,
                slashBountyBps: SLASH_BOUNTY_BPS,
                slashSink: SLASH_SINK,
                l2ChainId: L2_CHAIN_ID,
                inbox: _inbox
            })
        );
        return EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
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
}
