// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
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
/// @notice Deploys a fresh Etna Inbox and SignalService with an L2 block-zero checkpoint.
/// @dev The real registry has one validator checkpoint before Inbox initialization. No Shasta
/// contract or history is deployed. The SignalService authorizes the predicted Inbox proxy.
abstract contract EtnaInboxTestBase is CommonTest {
    uint256 internal constant STATUS_SLOT = 258;
    uint256 internal constant RECOVERY_GENERATION_SLOT = 268;
    uint256 internal constant LAST_CHECKPOINT_SLOT = 270;
    uint256 internal constant ACTIVATION_SLOT = 272;
    uint256 internal constant COMMITTEE_CONFIG_SLOT = 269;
    uint256 internal constant GENESIS_COMMITTEE_SLOT = 278;
    uint256 internal constant GENESIS_CUTOFF_SLOT = 279;
    uint256 internal constant FORCED_INCLUSION_QUEUE_SLOT = 280;
    uint256 internal constant FORCED_INCLUSION_HEAD_TAIL_SLOT = 281;
    uint256 internal constant FORCED_INCLUSION_CONFIG_SLOT = 282;

    uint64 internal constant L2_CHAIN_ID = 167_001;
    uint64 internal constant MAX_BATCH_BLOCKS = 1000;
    uint64 internal constant FORCED_INCLUSION_FEE_GWEI = 10_000_000;
    uint64 internal constant FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD = 50;
    uint64 internal constant FORCED_INCLUSION_DELAY = 1 hours;
    uint64 internal constant MAX_ANCHOR_AGE = 2 hours;
    uint64 internal constant FORCED_INCLUSION_EXPIRY = 14 days;
    uint64 internal constant EPOCH_LEN_L2 = 10;
    uint64 internal constant EPOCH_LEN_L1 = 32;
    bytes32 internal constant COMMITTEE_RECORD_0 = keccak256("committee record 0");
    bytes32 internal constant COMMITTEE_CONFIG_HASH = keccak256("committee config");
    uint256 internal constant MIN_STAKE = 1000 ether;
    bytes32 internal constant VALIDATOR_KEY = bytes32(uint256(0xa1));
    address internal constant REMOTE_SIGNAL_SERVICE = address(0xdead);

    uint64 internal constant genesisHeight = 0;
    bytes32 internal constant genesisBlockHash = keccak256("Etna L2 genesis block");
    bytes32 internal constant genesisStateRoot = keccak256("Etna L2 genesis state");

    MockLandProofVerifier internal landVerifier;
    TestERC20 internal taikoToken;
    EtnaStakingRegistry internal registry;
    SignalService internal signalService;
    IEtnaInbox.Config internal etnaConfig;
    EtnaInbox internal etnaInbox;
    EtnaInbox internal etnaImplementation;
    uint64 internal registryCheckpointBlock;
    uint64 internal initializedAtBlock;

    function setUp() public virtual override {
        super.setUp();
        vm.roll(100);
        vm.warp(1000);
        taikoToken = new TestERC20("Taiko Token", "TAIKO");
        registry = _deployRegistry();
        taikoToken.mint(Alice, MIN_STAKE);
        vm.startPrank(Alice);
        taikoToken.approve(address(registry), MIN_STAKE);
        registry.register(VALIDATOR_KEY, MIN_STAKE);
        vm.stopPrank();
        registryCheckpointBlock = uint64(block.number);
        _advanceBlock();
        landVerifier = new MockLandProofVerifier();
        _deployFreshInbox(_initializeOnDeploy());
    }

    function _initializeOnDeploy() internal pure virtual returns (bool) {
        return true;
    }

    /// @dev Deploys both proxies in CREATE order, authorizing the fourth address as the syncer.
    function _deployFreshInbox(bool _initialize) internal {
        address predictedInbox =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        SignalService serviceImpl =
            new SignalService(predictedInbox, REMOTE_SIGNAL_SERVICE, address(0));
        signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(serviceImpl), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        etnaConfig = IEtnaInbox.Config({
            proofVerifier: address(landVerifier),
            signalService: address(signalService),
            stakingRegistry: address(registry),
            l2ChainId: L2_CHAIN_ID,
            maxBatchBlocks: MAX_BATCH_BLOCKS,
            forcedInclusionFeeInGwei: FORCED_INCLUSION_FEE_GWEI,
            forcedInclusionFeeDoubleThreshold: FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD
        });
        etnaImplementation = new EtnaInbox(etnaConfig);
        bytes memory data = _initialize
            ? abi.encodeCall(EtnaInbox.init, (address(this), _defaultGenesisParams()))
            : bytes("");
        etnaInbox = EtnaInbox(address(new ERC1967Proxy(address(etnaImplementation), data)));
        assertEq(address(etnaInbox), predictedInbox, "predicted Inbox proxy");
        initializedAtBlock = uint64(block.number);
    }

    function _deployRegistry() internal returns (EtnaStakingRegistry) {
        EtnaStakingRegistry impl =
            new EtnaStakingRegistry(address(taikoToken), MIN_STAKE, 10, 20, 30, 50, 0, 0, 0);
        return EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
    }

    function _defaultGenesisParams() internal view returns (IEtnaInbox.GenesisParams memory) {
        return IEtnaInbox.GenesisParams({
            genesisBlockHash: genesisBlockHash,
            genesisStateRoot: genesisStateRoot,
            epochLenL2: EPOCH_LEN_L2,
            epochLenL1: EPOCH_LEN_L1,
            genesisCutoff: registryCheckpointBlock,
            committeeRecordHash: COMMITTEE_RECORD_0,
            committeeConfigHash: COMMITTEE_CONFIG_HASH,
            forcedInclusionDelay: FORCED_INCLUSION_DELAY,
            maxAnchorAge: MAX_ANCHOR_AGE
        });
    }

    function _advanceBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _getBlobHashes(uint256 _count) internal pure returns (bytes32[] memory hashes_) {
        hashes_ = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            hashes_[i] = keccak256(abi.encode("blob", i));
        }
    }

    function _loadSlot(uint256 _slot) internal view returns (uint256) {
        return uint256(vm.load(address(etnaInbox), bytes32(_slot)));
    }

    function _legacyCommitteeSlot(uint64 _epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(_epoch), GENESIS_COMMITTEE_SLOT));
    }
}
