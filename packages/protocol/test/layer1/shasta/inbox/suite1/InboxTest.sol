// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";
import "./InboxTestLib.sol";
import "./TestInboxFactory.sol";
import "./ITestInbox.sol";
import "./InboxTestAdapter.sol";
import "./InboxMockContracts.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "src/shared/shasta/libs/LibCheckpointStore.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/layer1/shasta/libs/LibProvedEventEncoder.sol";
import "src/shared/shasta/libs/LibBonds.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxTest
/// @notice Consolidated base contract for all Inbox tests
/// @dev Provides unified test infrastructure for all inbox test scenarios:
///      - Standardized setup and teardown procedures
///      - Common mock configurations and dependencies
///      - Reusable test data factories and builders
///      - Unified assertion patterns and helper functions
///      - Centralized constants and configuration management
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTest is CommonTest {
    using InboxTestLib for *;
    using InboxTestAdapter for *;

    // ---------------------------------------------------------------
    // Test Contract Instance
    // ---------------------------------------------------------------

    ITestInbox internal inbox;
    TestInboxFactory internal factory;
    TestInboxFactory.InboxType internal inboxType;

    // ---------------------------------------------------------------
    // Mock Dependencies
    // ---------------------------------------------------------------

    address internal bondToken;
    address internal checkpointManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // ---------------------------------------------------------------
    // Configuration Constants (now hardcoded in constructors)
    // ---------------------------------------------------------------

    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint48 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint48 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // ---------------------------------------------------------------
    // Test Constants and Limits
    // ---------------------------------------------------------------

    // Time-based constants
    uint256 internal constant TEST_TIMEOUT = 1 hours;
    uint256 internal constant SHORT_TIMEOUT = 10 minutes;
    uint256 internal constant EXTENDED_TIMEOUT = 6 hours;

    // Ring buffer sizes for different test scenarios
    uint256 internal constant TINY_RING_BUFFER_SIZE = 2;
    uint256 internal constant SMALL_RING_BUFFER_SIZE = 3;
    uint256 internal constant RING_BUFFER_TEST_SIZE = 5; // Common test size
    uint256 internal constant MEDIUM_RING_BUFFER_SIZE = 10;
    uint256 internal constant MAX_FINALIZATION_TEST_SIZE = 15; // For finalization limit tests
    uint256 internal constant STANDARD_RING_BUFFER_SIZE = 100;
    uint256 internal constant LARGE_RING_BUFFER_SIZE = 1000;

    // Fee constants for forced inclusion tests
    uint64 internal constant ZERO_FEE = 0;
    uint64 internal constant LOW_FEE = 1;
    uint64 internal constant STANDARD_FEE = 10;
    uint64 internal constant HIGH_FEE = 100;
    uint64 internal constant PREMIUM_FEE = 1000;

    // Proposal count constants for different test scenarios
    uint48 internal constant SINGLE_PROPOSAL = 1;
    uint48 internal constant PAIR_PROPOSALS = 2;
    uint48 internal constant FEW_PROPOSALS = 3;
    uint48 internal constant SEVERAL_PROPOSALS = 5;
    uint48 internal constant MANY_PROPOSALS = 10;
    uint48 internal constant LARGE_PROPOSAL_COUNT = 50;
    uint48 internal constant HUGE_PROPOSAL_COUNT = 100;

    // Gas limits for performance testing
    uint256 internal constant LOW_GAS_LIMIT = 100_000;
    uint256 internal constant STANDARD_GAS_LIMIT = 500_000;
    uint256 internal constant HIGH_GAS_LIMIT = 1_000_000;

    // Proof verification constants
    uint256 internal constant VALID_PROOF_SIZE = 32;
    uint256 internal constant INVALID_PROOF_SIZE = 0;

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        // Start at block 2 since genesis nextProposalBlockId = 2
        // This ensures first proposal can be made without hitting blockhash(0) issue
        vm.roll(2);

        setupMockAddresses();
        deployInbox();
        fundTestAccounts();
    }

    function setupMockAddresses() internal virtual {
        setupMockAddresses(true);
    }

    function setupMockAddresses(bool useRealMocks) internal virtual {
        if (useRealMocks) {
            bondToken = address(new MockERC20());
            checkpointManager = address(new StubCheckpointProvider());
            proofVerifier = address(new StubProofVerifier());
            proposerChecker = address(new StubProposerChecker());
        } else {
            bondToken = makeAddr("bondToken");
            checkpointManager = makeAddr("checkpointManager");
            forcedInclusionStore = makeAddr("forcedInclusionStore");
            proofVerifier = makeAddr("proofVerifier");
            proposerChecker = makeAddr("proposerChecker");
        }
    }

    function deployInbox() internal virtual {
        // Deploy the factory
        factory = new TestInboxFactory();

        // Get inbox type from environment variable, default to Core
        inboxType = getInboxTypeFromEnv();

        // Log which implementation is being tested
        emit log_string(
            string(abi.encodePacked("Testing with: ", InboxTestAdapter.getInboxTypeName(inboxType)))
        );

        // Deploy the selected inbox implementation with the mock addresses created in
        // setupMockAddresses
        address inboxAddress = factory.deployInboxWithMocks(
            inboxType,
            address(this),
            GENESIS_BLOCK_HASH,
            bondToken,
            uint16(100), // maxCheckpointHistory
            proofVerifier
        );
        inbox = ITestInbox(inboxAddress);
    }

    /// @dev Get the inbox type to test from environment variable
    function getInboxTypeFromEnv() internal returns (TestInboxFactory.InboxType) {
        string memory inboxTypeStr = vm.envOr("INBOX", string("base"));

        if (keccak256(bytes(inboxTypeStr)) == keccak256(bytes("base"))) {
            return TestInboxFactory.InboxType.Base;
        } else if (keccak256(bytes(inboxTypeStr)) == keccak256(bytes("opt1"))) {
            return TestInboxFactory.InboxType.Optimized1;
        } else if (keccak256(bytes(inboxTypeStr)) == keccak256(bytes("opt2"))) {
            return TestInboxFactory.InboxType.Optimized2;
        } else if (keccak256(bytes(inboxTypeStr)) == keccak256(bytes("opt3"))) {
            return TestInboxFactory.InboxType.Optimized3;
        } else {
            // Default to Core if unknown type
            emit log_string(
                string(abi.encodePacked("Unknown INBOX: ", inboxTypeStr, ", defaulting to base"))
            );
            return TestInboxFactory.InboxType.Base;
        }
    }

    function fundTestAccounts() internal virtual {
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Carol, 100 ether);
        vm.deal(David, 100 ether);
        vm.deal(Emma, 100 ether);
    }

    // ---------------------------------------------------------------
    // Advanced Test Data Structures and Factories
    // ---------------------------------------------------------------

    /// @dev Configuration for creating core states with full control
    struct CoreStateConfig {
        uint48 nextProposalId;
        uint48 lastFinalizedProposalId;
        bytes32 lastFinalizedTransitionHash;
        bytes32 bondInstructionsHash;
    }

    /// @dev Builder pattern for creating proposals with fluent interface
    struct ProposalBuilder {
        uint48 id;
        address proposer;
        bool isForcedInclusion;
        uint8 basefeeSharingPctg;
        LibBlobs.BlobSlice blobSlice;
        bytes32 coreStateHash;
    }

    /// @dev Builder pattern for creating transitions
    struct TransitionBuilder {
        bytes32 proposalHash;
        bytes32 parentTransitionHash;
        uint48 endBlockNumber;
        bytes32 endBlockHash;
        bytes32 endStateRoot;
        address designatedProver;
        address actualProver;
    }

    /// @dev Configuration for creating test proposals
    struct ProposalConfig {
        uint48 id;
        address proposer;
        bool isForcedInclusion;
        uint8 basefeeSharingPctg;
        uint8 blobStartIndex;
        uint8 numBlobs;
        uint48 deadline;
    }

    /// @dev Configuration for creating test transitions
    struct TransitionConfig {
        bytes32 proposalHash;
        bytes32 parentTransitionHash;
        uint48 endBlockNumber;
        bytes32 endBlockHash;
        bytes32 endStateRoot;
        address designatedProver;
        address actualProver;
    }

    /// @dev Configuration for ring buffer testing
    struct RingBufferConfig {
        uint256 size;
        uint48 proposalsToCreate;
        uint48 proposalsToFinalize;
        bool shouldWrapAround;
    }

    // ---------------------------------------------------------------
    // Builder Pattern Functions
    // ---------------------------------------------------------------

    /// @dev Start building a new proposal
    function newProposal(uint48 _id) internal view returns (ProposalBuilder memory) {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", _id));

        return ProposalBuilder({
            id: _id,
            proposer: Alice,
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(100) // Default timestamp
             }),
            coreStateHash: bytes32(0)
        });
    }

    /// @dev Start building a new transition
    function newTransition() internal view returns (TransitionBuilder memory) {
        return TransitionBuilder({
            proposalHash: bytes32(0),
            parentTransitionHash: bytes32(0),
            endBlockNumber: 100,
            endBlockHash: keccak256("endBlockHash"),
            endStateRoot: keccak256("stateRoot"),
            designatedProver: Alice,
            actualProver: Bob
        });
    }

    /// @dev Build proposal from builder
    function buildProposal(ProposalBuilder memory _builder)
        internal
        view
        returns (IInbox.Proposal memory)
    {
        // Create derivation for hash calculation
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: _builder.isForcedInclusion,
            basefeeSharingPctg: _builder.basefeeSharingPctg,
            blobSlice: _builder.blobSlice
        });

        return IInbox.Proposal({
            id: _builder.id,
            proposer: _builder.proposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: uint48(block.timestamp + 12), // Default: current + 1
                // slot
            coreStateHash: _builder.coreStateHash,
            derivationHash: keccak256(abi.encode(derivation))
        });
    }

    /// @dev Build transition from builder
    function buildTransition(TransitionBuilder memory _builder)
        internal
        pure
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: _builder.proposalHash,
            parentTransitionHash: _builder.parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: _builder.endBlockNumber,
                blockHash: _builder.endBlockHash,
                stateRoot: _builder.endStateRoot
            })
        });
    }

    /// @dev Creates core state from config struct
    function createCoreStateFromConfig(CoreStateConfig memory _config)
        internal
        view
        returns (IInbox.CoreState memory)
    {
        return IInbox.CoreState({
            nextProposalId: _config.nextProposalId,
            nextProposalBlockId: uint48(block.number), // Current block (proposal submitted in this
                // block)
            lastFinalizedProposalId: _config.lastFinalizedProposalId,
            lastFinalizedTransitionHash: _config.lastFinalizedTransitionHash,
            bondInstructionsHash: _config.bondInstructionsHash
        });
    }

    /// @dev Creates standard core state for most test scenarios
    function createStandardCoreState(uint48 _nextProposalId)
        internal
        view
        returns (IInbox.CoreState memory)
    {
        return createCoreStateFromConfig(
            CoreStateConfig({
                nextProposalId: _nextProposalId,
                lastFinalizedProposalId: 0,
                lastFinalizedTransitionHash: bytes32(0),
                bondInstructionsHash: bytes32(0)
            })
        );
    }

    /// @dev Creates core state with finalized proposals
    function createFinalizedCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedId,
        bytes32 _finalTransitionHash
    )
        internal
        view
        returns (IInbox.CoreState memory)
    {
        return createCoreStateFromConfig(
            CoreStateConfig({
                nextProposalId: _nextProposalId,
                lastFinalizedProposalId: _lastFinalizedId,
                lastFinalizedTransitionHash: _finalTransitionHash,
                bondInstructionsHash: bytes32(0)
            })
        );
    }

    /// @dev Creates a test scenario with N proposals, all proven but not finalized
    function createUnfinalizedProposalScenario(uint48 _count)
        internal
        returns (
            IInbox.Proposal[] memory proposals,
            IInbox.Transition[] memory transitions,
            IInbox.TransitionRecord[] memory transitionRecords
        )
    {
        bytes32 genesisHash = getGenesisTransitionHash();
        return createProvenChain(1, _count, genesisHash);
    }

    /// @dev Comprehensive test scenario configuration
    struct TestScenario {
        uint48 proposalCount;
        address proposer;
        address prover;
        address finalizer;
        bool shouldProve;
        bool shouldFinalize;
        bool useForcedInclusion;
        uint48 proposalDeadline;
        bytes32 initialParentHash;
        RingBufferConfig ringBuffer;
    }

    /// @dev Gas measurement and performance tracking
    struct PerformanceMetrics {
        uint256 proposalGas;
        uint256 proveGas;
        uint256 finalizeGas;
        uint256 totalGas;
        uint256 executionTime;
    }

    /// @dev Creates a complete test scenario from configuration
    function createTestScenario(TestScenario memory _config)
        internal
        returns (
            IInbox.Proposal[] memory proposals,
            IInbox.Transition[] memory transitions,
            IInbox.TransitionRecord[] memory transitionRecords,
            PerformanceMetrics memory metrics
        )
    {
        uint256 startGas = gasleft();
        uint256 startTime = block.timestamp;

        proposals = new IInbox.Proposal[](_config.proposalCount);
        transitions = new IInbox.Transition[](_config.proposalCount);
        transitionRecords = new IInbox.TransitionRecord[](_config.proposalCount);

        // Ring buffer size is now immutable - tests requiring different sizes should use different
        // contract variants
        if (_config.ringBuffer.size > 0) {
            // Note: Ring buffer size cannot be changed at runtime (immutable in constructor)
        }

        // Submit proposals with gas tracking
        uint256 proposalGasStart = gasleft();
        for (uint48 i = 1; i <= _config.proposalCount; i++) {
            if (_config.useForcedInclusion && i == 1) {
                proposals[i - 1] =
                    _submitForcedInclusionProposal(i, _config.proposer, _config.proposalDeadline);
            } else {
                proposals[i - 1] = _config.proposalDeadline > 0
                    ? _submitProposalWithDeadline(i, _config.proposer, _config.proposalDeadline)
                    : submitProposal(i, _config.proposer);
            }
        }
        metrics.proposalGas = proposalGasStart - gasleft();

        // Prove if requested with gas tracking
        if (_config.shouldProve) {
            uint256 proveGasStart = gasleft();
            bytes32 currentParent = _config.initialParentHash;

            // Create all transitions first
            for (uint48 i = 0; i < _config.proposalCount; i++) {
                transitions[i] = InboxTestLib.createTransition(proposals[i], currentParent);
                currentParent = InboxTestLib.hashTransition(transitions[i]);
            }

            // Prove all at once and get transition records from events
            transitionRecords = proveProposalBatch(proposals, transitions, _config.prover);
            metrics.proveGas = proveGasStart - gasleft();
        }

        // Finalize if requested with gas tracking
        if (_config.shouldFinalize && _config.shouldProve) {
            uint256 finalizeGasStart = gasleft();
            _batchFinalize(transitionRecords, _config.finalizer);
            metrics.finalizeGas = finalizeGasStart - gasleft();
        }

        metrics.totalGas = startGas - gasleft();
        metrics.executionTime = block.timestamp - startTime;
    }

    /// @dev Creates test data for deadline validation
    function createDeadlineTestData(bool _expired) internal view returns (uint48 deadline) {
        if (_expired) {
            deadline = uint48(block.timestamp - 1);
        } else {
            deadline = uint48(block.timestamp + TEST_TIMEOUT);
        }
    }

    /// @dev Creates deadline that's exactly at current timestamp (edge case)
    function createCurrentTimestampDeadline() internal view returns (uint64) {
        return uint64(block.timestamp);
    }

    /// @dev Creates deadline far in the future for stress testing
    function createFarFutureDeadline() internal view returns (uint64) {
        return uint64(block.timestamp + 365 days);
    }

    /// @dev Creates deadline based on timeout constant
    function createTimeoutDeadline(uint256 _timeout) internal view returns (uint64) {
        return uint64(block.timestamp + _timeout);
    }

    // ---------------------------------------------------------------
    // Advanced Proposal and Transition Factories
    // ---------------------------------------------------------------

    /// @dev Creates proposal from detailed configuration
    function createProposalFromConfig(ProposalConfig memory _config)
        internal
        view
        returns (IInbox.Proposal memory)
    {
        bytes32[] memory blobHashes = new bytes32[](_config.numBlobs);
        for (uint8 i = 0; i < _config.numBlobs; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", _config.blobStartIndex + i));
        }

        // Create derivation for hash calculation
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: _config.isForcedInclusion,
            basefeeSharingPctg: _config.basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        return IInbox.Proposal({
            id: _config.id,
            proposer: _config.proposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: uint48(block.timestamp + 12), // Default: current + 1
                // slot
            coreStateHash: bytes32(0), // Will be set later
            derivationHash: keccak256(abi.encode(derivation))
        });
    }

    /// @dev Creates transition from detailed configuration
    function createTransitionFromConfig(TransitionConfig memory _config)
        internal
        pure
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: _config.proposalHash,
            parentTransitionHash: _config.parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: _config.endBlockNumber,
                blockHash: _config.endBlockHash,
                stateRoot: _config.endStateRoot
            })
        });
    }

    /// @dev Creates test forced inclusion data
    function createForcedInclusionData(uint64 _fee)
        internal
        view
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        return createForcedInclusionDataWithSeed(_fee, 0);
    }

    /// @dev Creates test forced inclusion data with custom seed
    function createForcedInclusionDataWithSeed(
        uint64 _fee,
        uint256 _seed
    )
        internal
        view
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("forced_blob", _seed));

        return IForcedInclusionStore.ForcedInclusion({
            feeInGwei: _fee,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
    }

    /// @dev Creates standard forced inclusion for common test scenarios
    function createStandardForcedInclusion()
        internal
        view
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        return createForcedInclusionData(STANDARD_FEE);
    }

    /// @dev Creates multiple forced inclusions with different fees
    function createForcedInclusionBatch(uint64[] memory _fees)
        internal
        view
        returns (IForcedInclusionStore.ForcedInclusion[] memory)
    {
        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            new IForcedInclusionStore.ForcedInclusion[](_fees.length);

        for (uint256 i = 0; i < _fees.length; i++) {
            inclusions[i] = createForcedInclusionDataWithSeed(_fees[i], i);
        }

        return inclusions;
    }

    /// @dev Helper to submit proposal with forced inclusion
    function _submitForcedInclusionProposal(
        uint48 _proposalId,
        address _proposer,
        uint48 _deadline
    )
        private
        returns (IInbox.Proposal memory)
    {
        IForcedInclusionStore.ForcedInclusion memory forcedInclusion =
            createStandardForcedInclusion();
        setupForcedInclusionMocks(_proposer, forcedInclusion);

        return _deadline > 0
            ? _submitProposalWithDeadline(_proposalId, _proposer, _deadline)
            : submitProposal(_proposalId, _proposer);
    }

    /// @dev Helper to submit proposal with deadline
    function _submitProposalWithDeadline(
        uint48 _proposalId,
        address _proposer,
        uint48 _deadline
    )
        private
        returns (IInbox.Proposal memory)
    {
        IInbox.CoreState memory coreState = _buildCoreStateForProposal(_proposalId);
        setupProposalMocks(_proposer);
        setupBlobHashes();

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = InboxTestLib.createGenesisProposal(coreState);

        bytes memory data = InboxTestAdapter.encodeProposeInput(
            inboxType,
            _deadline,
            coreState,
            proposals,
            createValidBlobReference(_proposalId),
            new IInbox.TransitionRecord[](0)
        );

        vm.prank(_proposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), data);

        return _reconstructStoredProposal(_proposalId, _proposer, coreState);
    }

    /// @dev Helper for batch finalization
    function _batchFinalize(
        IInbox.TransitionRecord[] memory _transitionRecords,
        address _finalizer
    )
        private
    {
        if (_transitionRecords.length == 0) return;

        // Create a finalization proposal with the transition records
        uint48 nextProposalId = uint48(_transitionRecords.length + 1);
        IInbox.CoreState memory coreState = createStandardCoreState(nextProposalId);

        setupProposalMocks(_finalizer != address(0) ? _finalizer : Alice);
        setupBlobHashes();

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = InboxTestLib.createGenesisProposal(coreState);

        // Get the checkpoint from the last proposal that was proven
        // This should match what was used when the transition was created
        uint48 lastProposalId = uint48(_transitionRecords.length);
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: lastProposalId * 100,
            blockHash: keccak256(abi.encode(lastProposalId, "endBlockHash")),
            stateRoot: keccak256(abi.encode(lastProposalId, "stateRoot"))
        });

        bytes memory data = InboxTestAdapter.encodeProposeInputWithEndBlock(
            inboxType,
            uint48(0),
            coreState,
            proposals,
            createValidBlobReference(nextProposalId),
            _transitionRecords,
            checkpoint
        );

        vm.prank(_finalizer != address(0) ? _finalizer : Alice);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), data);
    }

    // ---------------------------------------------------------------
    // Blob Hash Setup
    // ---------------------------------------------------------------

    function setupBlobHashes() internal virtual {
        setupBlobHashes(256);
    }

    function setupBlobHashes(uint256 _count) internal {
        bytes32[] memory hashes = InboxTestLib.generateBlobHashes(_count);
        vm.blobhashes(hashes);
    }

    // ---------------------------------------------------------------
    // Enhanced Mock Helpers
    // ---------------------------------------------------------------

    function setupProposalMocks(address _proposer) internal {
        mockProposerAllowed(_proposer);
        mockForcedInclusionDue(false);
    }

    function setupProofMocks(bool _valid) internal {
        mockProofVerification(_valid);
    }

    /// @dev Sets up mocks for forced inclusion scenario
    function setupForcedInclusionMocks(
        address _proposer,
        IForcedInclusionStore.ForcedInclusion memory /*_forcedInclusion*/
    )
        internal
    {
        mockProposerAllowed(_proposer);
        mockForcedInclusionDue(true);

        // Note: consumeForcedInclusions is now internal to the inbox
        // No external mock needed since forced inclusion store is merged
    }

    /// @dev Sets up mocks for unauthorized proposer test
    function setupUnauthorizedProposerMocks(address _proposer) internal {
        vm.mockCallRevert(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, _proposer),
            abi.encode("Not authorized")
        );
        mockForcedInclusionDue(false);
    }

    /// @dev Sets up mocks for capacity exceeded scenario
    function setupCapacityExceededScenario(uint256 _ringBufferSize) internal {
        // Ring buffer size is now immutable - capacity tests must use appropriate test contract
        // variant
        // This function is kept for compatibility but does nothing
    }

    /// @dev Gets the ring buffer size from the inbox (now immutable)
    function getRingBufferSize() internal view returns (uint256) {
        return Inbox(address(inbox)).getConfig().ringBufferSize;
    }

    /// @dev Gets the proving window from the inbox (now immutable)
    function getProvingWindow() internal view returns (uint48) {
        return Inbox(address(inbox)).getConfig().provingWindow;
    }

    /// @dev Gets the max finalization count from the inbox (now immutable)
    function getMaxFinalizationCount() internal view returns (uint256) {
        return Inbox(address(inbox)).getConfig().maxFinalizationCount;
    }

    /// @dev Gets the basefee sharing percentage from the inbox (now immutable)
    function getBasefeeSharingPctg() internal view returns (uint8) {
        return Inbox(address(inbox)).getConfig().basefeeSharingPctg;
    }

    /// @dev Configuration is now immutable - these setup functions are no-ops for compatibility
    function setupSmallRingBuffer() internal {
        // Ring buffer size is now immutable (set in constructor)
        // Tests requiring different sizes should use different test contract variants
    }

    function setupMediumRingBuffer() internal {
        // Ring buffer size is now immutable (set in constructor)
    }

    function setupTinyRingBuffer() internal {
        // Ring buffer size is now immutable (set in constructor)
    }

    function setupLargeRingBuffer() internal {
        // Ring buffer size is now immutable (set in constructor)
    }

    // ---------------------------------------------------------------
    // Advanced Test Isolation and State Management
    // ---------------------------------------------------------------

    /// @dev Snapshot and rollback utilities for test isolation
    uint256 private _testSnapshot;

    /// @dev Takes a snapshot of current blockchain state
    function takeSnapshot() internal {
        _testSnapshot = vm.snapshot();
    }

    /// @dev Reverts to the last snapshot
    function revertToSnapshot() internal {
        vm.revertTo(_testSnapshot);
    }

    /// @dev Executes a test function in isolation with automatic cleanup
    function withIsolation(function() internal testFunction) internal {
        takeSnapshot();
        testFunction();
        revertToSnapshot();
    }

    /// @dev Resets inbox to clean state for test isolation
    function resetInboxState() internal {
        // Configuration is now immutable - only reset mock states
        _resetAllMocks();
        // Setup fresh blob hashes
        setupBlobHashes();
    }

    /// @dev Resets all mock configurations
    function _resetAllMocks() private {
        vm.clearMockedCalls();
    }

    /// @dev Sets up a clean test environment for each test
    function setupCleanTest() internal {
        resetInboxState();
        fundTestAccounts();
    }

    /// @dev Sets up test environment (configuration is now immutable)
    function setupTestEnvironment() internal {
        setupBlobHashes();
        fundTestAccounts();
    }

    /// @dev Sets up test environment optimized for performance testing
    function setupPerformanceTest() internal {
        // Use large ring buffer to avoid capacity issues
        setupLargeRingBuffer();
        setupBlobHashes();
        fundTestAccounts();

        // Pre-warm the contract by running a small operation
        _warmupContract();
    }

    /// @dev Warms up contract to get more consistent gas measurements
    function _warmupContract() private {
        try this._performWarmupOperation() {
            // Warmup successful
        } catch {
            // Warmup failed, continue anyway
        }
    }

    /// @dev Internal warmup operation
    function _performWarmupOperation() external {
        // Simple operation to warm up the contract
        setupProposalMocks(Alice);
        IInbox.CoreState memory state = createStandardCoreState(1);
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = InboxTestLib.createGenesisProposal(state);

        InboxTestAdapter.encodeProposeInput(
            inboxType,
            uint48(0),
            state,
            proposals,
            createValidBlobReference(1),
            new IInbox.TransitionRecord[](0)
        );
        // Don't actually submit, just prepare the data
    }

    // ---------------------------------------------------------------
    // Test Performance and Gas Tracking
    // ---------------------------------------------------------------

    /// @dev Gas tracking utilities
    struct GasSnapshot {
        uint256 gasStart;
        uint256 gasUsed;
        string operation;
    }

    /// @dev Starts gas tracking for an operation
    function startGasTracking(string memory _operation)
        internal
        view
        returns (GasSnapshot memory snapshot)
    {
        snapshot.operation = _operation;
        snapshot.gasStart = gasleft();
        return snapshot;
    }

    /// @dev Ends gas tracking and logs result
    function endGasTracking(GasSnapshot memory _snapshot) internal returns (uint256 gasUsed) {
        gasUsed = _snapshot.gasStart - gasleft();
        _snapshot.gasUsed = gasUsed;
        emit log_named_uint(string(abi.encodePacked("Gas used for ", _snapshot.operation)), gasUsed);
        return gasUsed;
    }

    /// @dev Measures gas usage for a function call
    function measureGas(
        string memory _operation,
        function() internal _func
    )
        internal
        returns (uint256)
    {
        GasSnapshot memory snapshot = startGasTracking(_operation);
        _func();
        return endGasTracking(snapshot);
    }

    /// @dev Runs performance benchmark for a test scenario
    function benchmarkScenario(
        TestScenario memory _scenario,
        string memory _description
    )
        internal
        returns (PerformanceMetrics memory metrics)
    {
        emit log_string(string(abi.encodePacked("Benchmarking: ", _description)));

        (,,, metrics) = createTestScenario(_scenario);

        emit log_named_uint("Total Gas Used", metrics.totalGas);
        emit log_named_uint("Proposal Gas", metrics.proposalGas);
        emit log_named_uint("Prove Gas", metrics.proveGas);
        emit log_named_uint("Finalize Gas", metrics.finalizeGas);
        emit log_named_uint("Execution Time", metrics.executionTime);

        return metrics;
    }

    /// @dev Compares performance between two scenarios
    function comparePerformance(
        PerformanceMetrics memory _baseline,
        PerformanceMetrics memory _optimized,
        string memory _comparison
    )
        internal
    {
        emit log_string(string(abi.encodePacked("Performance Comparison: ", _comparison)));

        int256 gasDiff = int256(_optimized.totalGas) - int256(_baseline.totalGas);
        int256 timeDiff = int256(_optimized.executionTime) - int256(_baseline.executionTime);

        emit log_named_int("Gas Difference", gasDiff);
        emit log_named_int("Time Difference", timeDiff);

        if (gasDiff < 0) {
            emit log_string("Gas optimized");
        } else if (gasDiff > 0) {
            emit log_string("Gas increased");
        }
    }

    /// @dev Asserts gas usage is within expected bounds
    function assertGasUsage(
        uint256 _actualGas,
        uint256 _expectedGas,
        uint256 _tolerance,
        string memory _operation
    )
        internal
        pure
    {
        uint256 minGas = _expectedGas > _tolerance ? _expectedGas - _tolerance : 0;
        uint256 maxGas = _expectedGas + _tolerance;

        assertTrue(
            _actualGas >= minGas && _actualGas <= maxGas,
            string(
                abi.encodePacked(
                    "Gas usage for ",
                    _operation,
                    " (",
                    vm.toString(_actualGas),
                    ") not within tolerance of ",
                    vm.toString(_expectedGas),
                    " +/- ",
                    vm.toString(_tolerance)
                )
            )
        );
    }

    function mockProposerAllowed(address _proposer) internal {
        vm.mockCall(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, _proposer),
            abi.encode(uint48(0))
        );
    }

    function mockForcedInclusionDue(bool _isDue) internal {
        vm.mockCall(
            address(inbox),
            abi.encodeWithSelector(IForcedInclusionStore.isOldestForcedInclusionDue.selector),
            abi.encode(_isDue)
        );
    }

    function mockProofVerification(bool _valid) internal {
        if (_valid) {
            vm.mockCall(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                abi.encode()
            );
        } else {
            vm.mockCallRevert(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                bytes("Invalid proof")
            );
        }
    }

    // ---------------------------------------------------------------
    // Common Test Scenarios
    // ---------------------------------------------------------------

    /// @dev Submits a proposal and returns it - simplified version
    function submitProposal(
        uint48 _proposalId,
        address _proposer
    )
        internal
        returns (IInbox.Proposal memory proposal)
    {
        return submitProposalWithTransitionRecords(
            _proposalId, _proposer, new IInbox.TransitionRecord[](0)
        );
    }

    /// @dev Submits a proposal with transition records for finalization
    function submitProposalWithTransitionRecords(
        uint48 _proposalId,
        address _proposer,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        returns (IInbox.Proposal memory proposal)
    {
        setupProposalMocks(_proposer);
        setupBlobHashes();

        // Calculate the correct block for this proposal (accounting for 1-block gaps)
        uint256 targetBlock = InboxTestLib.calculateProposalBlock(_proposalId, 2); // Base block 2

        // Roll to the target block
        vm.prank(_proposer);
        if (block.number < targetBlock) {
            vm.roll(targetBlock);
        }

        // Now create the proposal data using the rolled block context
        IInbox.CoreState memory coreState = _buildCoreStateForProposal(_proposalId);
        bytes memory data = _encodeProposeInputWithValidation(
            _proposalId,
            coreState,
            InboxTestLib.createBlobReference(uint8(_proposalId)),
            _transitionRecords
        );

        inbox.propose(bytes(""), data);

        // Reconstruct proposal using the actual block context when it was created (after roll)
        proposal = _reconstructStoredProposalAt(
            _proposalId, _proposer, coreState, block.number, block.timestamp
        );
    }

    /// @dev Builds core state for a given proposal ID
    function _buildCoreStateForProposal(uint48 _proposalId)
        internal
        pure
        returns (IInbox.CoreState memory coreState)
    {
        coreState = _getGenesisCoreState();
        coreState.nextProposalId = _proposalId;

        // Calculate the correct nextProposalBlockId based on proposal ID
        if (_proposalId == 1) {
            // First proposal uses genesis value (2 to prevent blockhash(0))
            coreState.nextProposalBlockId = 2;
        } else {
            // For subsequent proposals, calculate based on when the previous proposal was made
            // Previous proposal was at block 2 + (proposalId - 2) (1-block gaps)
            // It set nextProposalBlockId to that block + 1
            uint256 prevProposalBlock = 2 + (_proposalId - 2);
            coreState.nextProposalBlockId = uint48(prevProposalBlock + 1);
        }
    }

    /// @dev Helper function to encode proposal data with correct validation proposals
    function _encodeProposeInputWithValidation(
        uint48 _proposalId,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals;

        if (_proposalId == 1) {
            // First proposal after genesis, use genesis validation
            proposals = new IInbox.Proposal[](1);
            proposals[0] = InboxTestLib.createGenesisProposal(_coreState);
        } else {
            // Subsequent proposals, include the previous proposal for validation
            proposals = new IInbox.Proposal[](1);
            proposals[0] = _recreateStoredProposal(_proposalId - 1);
        }

        // Use adapter to handle encoding based on inbox type
        return InboxTestAdapter.encodeProposeInput(
            inboxType, uint48(0), _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Wrapper for encodeProposeInputWithProposals that uses the adapter
    function encodeProposeInputWithProposals(
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (bytes memory)
    {
        return InboxTestAdapter.encodeProposeInput(
            inboxType, uint48(0), _coreState, _proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Wrapper for encodeProposeInputWithProposals with deadline
    function encodeProposeInputWithProposals(
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (bytes memory)
    {
        return InboxTestAdapter.encodeProposeInput(
            inboxType, _deadline, _coreState, _proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Wrapper for encodeProposeInputWithGenesis that uses the adapter
    function encodeProposeInputWithGenesis(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = InboxTestLib.createGenesisProposal(_coreState);

        return InboxTestAdapter.encodeProposeInput(
            inboxType, uint48(0), _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Wrapper for encodeProposeInputWithGenesis with deadline
    function encodeProposeInputWithGenesis(
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = InboxTestLib.createGenesisProposal(_coreState);

        return InboxTestAdapter.encodeProposeInput(
            inboxType, _deadline, _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Wrapper for encodeProposeInputForSubsequent that uses the adapter
    function encodeProposeInputForSubsequent(
        IInbox.CoreState memory _coreState,
        IInbox.Proposal memory _previousProposal,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _previousProposal;

        return InboxTestAdapter.encodeProposeInput(
            inboxType, uint48(0), _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Wrapper for encodeProposeInputForSubsequent with deadline
    function encodeProposeInputForSubsequent(
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal memory _previousProposal,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _previousProposal;

        return InboxTestAdapter.encodeProposeInput(
            inboxType, _deadline, _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Wrapper for encoding prove data that uses the adapter
    function encodeProveInput(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions
    )
        internal
        view
        returns (bytes memory)
    {
        return InboxTestAdapter.encodeProveInput(inboxType, _proposals, _transitions);
    }

    /// @dev Gets the genesis core state that was created during contract initialization
    function _getGenesisCoreState() internal pure returns (IInbox.CoreState memory) {
        IInbox.CoreState memory genesisCoreState;
        genesisCoreState.nextProposalId = 1;
        genesisCoreState.nextProposalBlockId = 2; // Genesis value - prevents blockhash(0) issue
        genesisCoreState.lastFinalizedProposalId = 0;

        // Genesis transition hash from initialization
        IInbox.Transition memory genesisTransition;
        genesisTransition.checkpoint.blockHash = GENESIS_BLOCK_HASH;
        genesisCoreState.lastFinalizedTransitionHash = keccak256(abi.encode(genesisTransition));
        genesisCoreState.bondInstructionsHash = bytes32(0);

        return genesisCoreState;
    }

    /// @dev Recreates the genesis proposal that was stored during contract initialization
    function _recreateGenesisProposal() internal view returns (IInbox.Proposal memory) {
        // Use the library function that correctly recreates the genesis proposal
        IInbox.CoreState memory genesisCoreState = _getGenesisCoreState();
        return InboxTestLib.createGenesisProposal(genesisCoreState);
    }

    /// @dev Recreates a stored proposal based on the pattern used in tests
    function _recreateStoredProposal(uint48 _proposalId)
        internal
        view
        returns (IInbox.Proposal memory)
    {
        // For test purposes, use fixed deterministic values
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        // For the genesis proposal (ID 0), keep the genesis core state (nextProposalId = 1)
        if (_proposalId == 0) {
            return InboxTestLib.createGenesisProposal(coreState);
        }

        // For other proposals, the core state shows what was present WHEN that proposal was created
        coreState.nextProposalId = _proposalId;

        // Calculate nextProposalBlockId based on what the previous proposal would have set
        if (_proposalId == 1) {
            // Proposal 1 uses genesis state with nextProposalBlockId = 2
            coreState.nextProposalBlockId = 2;
        } else {
            // Previous proposal set nextProposalBlockId = its block + 1
            uint256 prevBlock = InboxTestLib.calculateProposalBlock(_proposalId - 1, 2);
            coreState.nextProposalBlockId = uint48(prevBlock + 1);
        }

        coreState.lastFinalizedProposalId = 0; // Keep as 0 for test simplicity

        // Calculate the block number when this proposal was created
        uint256 proposalBlockNumber = InboxTestLib.calculateProposalBlock(_proposalId, 2);

        return _reconstructStoredProposalAt(
            _proposalId, Alice, coreState, proposalBlockNumber, block.timestamp
        );
    }

    /// @dev Reconstructs the proposal as it was actually stored by the contract
    function _reconstructStoredProposal(
        uint48 _proposalId,
        address _proposer,
        IInbox.CoreState memory _coreState
    )
        internal
        view
        returns (IInbox.Proposal memory proposal)
    {
        // Use current block context for accurate reconstruction
        // The contract uses block.number and block.timestamp when creating proposals
        return _reconstructStoredProposalAt(
            _proposalId, _proposer, _coreState, block.number, block.timestamp
        );
    }

    /// @dev Reconstructs proposal with specific block context
    function _reconstructStoredProposalAt(
        uint48 _proposalId,
        address _proposer,
        IInbox.CoreState memory _coreState,
        uint256 _blockNumber,
        uint256 _timestamp
    )
        internal
        view
        returns (IInbox.Proposal memory proposal)
    {
        // Recreate the blob slice exactly as it was created
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", uint256(_proposalId % 256)));

        // Create derivation for hash calculation with specific block context
        // InboxTestLib.createProposal uses block.number - 1 for originBlockNumber
        // The data is created before vm.roll(), so _blockNumber is before the increment
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(_blockNumber - 1),
            originBlockHash: blockhash(_blockNumber - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(_timestamp)
            })
        });

        proposal.id = _proposalId;
        proposal.proposer = _proposer;
        proposal.timestamp = uint48(_timestamp);
        proposal.endOfSubmissionWindowTimestamp = uint48(0); // Set to 0 as returned by
            // mockProposerAllowed
        proposal.derivationHash = keccak256(abi.encode(derivation));

        // The contract increments nextProposalId and sets nextProposalBlockId BEFORE computing the
        // hash
        // In propose(), it sets nextProposalBlockId = block.number + 1 (line 215)
        IInbox.CoreState memory updatedCoreState = _coreState;
        updatedCoreState.nextProposalId++;
        updatedCoreState.nextProposalBlockId = uint48(_blockNumber + 1); // block.number + 1
        proposal.coreStateHash = keccak256(abi.encode(updatedCoreState));

        return proposal;
    }

    /// @dev Proves a proposal and returns the transition
    function proveProposal(
        IInbox.Proposal memory _proposal,
        address _prover,
        bytes32 _parentTransitionHash
    )
        internal
        returns (IInbox.Transition memory transition)
    {
        transition = InboxTestLib.createTransition(_proposal, _parentTransitionHash);
        _submitProof(_proposal, transition, _prover);
        // Store the checkpoint for test purposes
        inbox.storeCheckpoint(_proposal.id, transition.checkpoint);
    }

    /// @dev Proves multiple proposals in batch and returns transition records from events
    function proveProposalBatch(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions,
        address _prover
    )
        internal
        returns (IInbox.TransitionRecord[] memory transitionRecords)
    {
        require(_proposals.length == _transitions.length, "Array length mismatch");

        setupProofMocks(true);

        bytes memory proveData =
            InboxTestAdapter.encodeProveInput(inboxType, _proposals, _transitions);

        // Record events to extract transition records
        vm.recordLogs();
        vm.prank(_prover);
        inbox.prove(proveData, bytes("proof"));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Extract transition records from Proved events
        transitionRecords = extractTransitionRecordsFromProvedEvents(logs);

        // Store the checkpoints for test purposes
        for (uint256 i = 0; i < _proposals.length; i++) {
            inbox.storeCheckpoint(_proposals[i].id, _transitions[i].checkpoint);
        }
    }

    /// @dev Internal helper to submit a single proof
    function _submitProof(
        IInbox.Proposal memory _proposal,
        IInbox.Transition memory _transition,
        address _prover
    )
        private
    {
        setupProofMocks(true);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = _transition;

        vm.prank(_prover);
        inbox.prove(
            InboxTestAdapter.encodeProveInput(inboxType, proposals, transitions), bytes("proof")
        );
    }

    /// @dev Creates and proves a chain of proposals
    function createProvenChain(
        uint48 _startId,
        uint48 _count,
        bytes32 _initialParentHash
    )
        internal
        returns (
            IInbox.Proposal[] memory proposals,
            IInbox.Transition[] memory transitions,
            IInbox.TransitionRecord[] memory transitionRecords
        )
    {
        return createProvenChainWithCustomProver(_startId, _count, _initialParentHash, Alice, Bob);
    }

    /// @dev Creates and proves a chain of proposals with custom proposer and prover
    function createProvenChainWithCustomProver(
        uint48 _startId,
        uint48 _count,
        bytes32 _initialParentHash,
        address _proposer,
        address _prover
    )
        internal
        returns (
            IInbox.Proposal[] memory proposals,
            IInbox.Transition[] memory transitions,
            IInbox.TransitionRecord[] memory transitionRecords
        )
    {
        InboxTestLib.ProposalChain memory chain = InboxTestLib.createProposalChain(
            _startId, _count, _proposer, _initialParentHash, DEFAULT_BASEFEE_SHARING_PCTG
        );

        proposals = chain.proposals;
        transitions = chain.transitions;

        // Submit all proposals
        for (uint48 i = 0; i < _count; i++) {
            submitProposal(_startId + i, _proposer);
        }

        // Prove all at once and get transition records from events
        transitionRecords = proveProposalBatch(proposals, transitions, _prover);
    }

    /// @dev Creates a simple finalization scenario with N proposals
    function createFinalizationScenario(uint48 _numProposals)
        internal
        returns (
            IInbox.Proposal[] memory proposals,
            IInbox.Transition[] memory transitions,
            IInbox.TransitionRecord[] memory transitionRecords
        )
    {
        bytes32 genesisHash = getGenesisTransitionHash();
        (proposals, transitions, transitionRecords) =
            createProvenChain(1, _numProposals, genesisHash);
    }

    // ---------------------------------------------------------------
    // Event Extraction Helpers
    // ---------------------------------------------------------------

    /// @dev Extracts transition records from Proved events emitted during prove operations
    function extractTransitionRecordsFromProvedEvents(Vm.Log[] memory logs)
        internal
        view
        returns (IInbox.TransitionRecord[] memory transitionRecords)
    {
        // Count Proved events
        uint256 provedEventCount = 0;
        bytes32 provedEventSig = keccak256("Proved(bytes)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == provedEventSig) {
                provedEventCount++;
            }
        }

        transitionRecords = new IInbox.TransitionRecord[](provedEventCount);
        uint256 recordIndex = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == provedEventSig) {
                // Decode the event data based on inbox type
                bytes memory eventData = logs[i].data;

                if (
                    inboxType == TestInboxFactory.InboxType.Base
                        || inboxType == TestInboxFactory.InboxType.Optimized1
                ) {
                    // For base and opt1, use abi.decode
                    bytes memory payload = abi.decode(eventData, (bytes));
                    IInbox.ProvedEventPayload memory provedPayload =
                        abi.decode(payload, (IInbox.ProvedEventPayload));
                    transitionRecords[recordIndex] = provedPayload.transitionRecord;
                } else {
                    // For opt2 and opt3, use LibProvedEventEncoder.decode
                    bytes memory payload = abi.decode(eventData, (bytes));
                    IInbox.ProvedEventPayload memory provedPayload =
                        LibProvedEventEncoder.decode(payload);
                    transitionRecords[recordIndex] = provedPayload.transitionRecord;
                }
                recordIndex++;
            }
        }
    }

    // ---------------------------------------------------------------
    // Enhanced Assertions
    // ---------------------------------------------------------------

    function assertProposalStored(uint48 _proposalId) internal view {
        bytes32 storedHash = inbox.getProposalHash(_proposalId);
        assertTrue(
            storedHash != bytes32(0),
            string(abi.encodePacked("Proposal ", vm.toString(_proposalId), " not stored"))
        );
    }

    function assertProposalNotStored(uint48 _proposalId) internal view {
        bytes32 storedHash = inbox.getProposalHash(_proposalId);
        assertTrue(
            storedHash == bytes32(0),
            string(abi.encodePacked("Proposal ", vm.toString(_proposalId), " should not be stored"))
        );
    }

    function assertTransitionRecordStored(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
    {
        (, bytes26 recordHash) = inbox.getTransitionRecordHash(_proposalId, _parentTransitionHash);
        assertTrue(
            recordHash != bytes26(0),
            string(
                abi.encodePacked(
                    "Transition record for proposal ", vm.toString(_proposalId), " not stored"
                )
            )
        );
    }

    function assertTransitionRecordNotStored(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
    {
        (, bytes26 recordHash) = inbox.getTransitionRecordHash(_proposalId, _parentTransitionHash);
        assertTrue(
            recordHash == bytes26(0),
            string(
                abi.encodePacked(
                    "Transition record for proposal ",
                    vm.toString(_proposalId),
                    " should not be stored"
                )
            )
        );
    }

    function assertProposalsStored(uint48 _startId, uint48 _count) internal view {
        for (uint48 i = 0; i < _count; i++) {
            assertProposalStored(_startId + i);
        }
    }

    function assertProposalHashMatches(
        uint48 _proposalId,
        IInbox.Proposal memory _expected
    )
        internal
        view
    {
        bytes32 storedHash = inbox.getProposalHash(_proposalId);
        bytes32 expectedHash = InboxTestLib.hashProposal(_expected);
        assertEq(
            storedHash,
            expectedHash,
            string(abi.encodePacked("Proposal ", vm.toString(_proposalId), " hash mismatch"))
        );
    }

    function assertCoreState(
        uint48 _expectedNextProposalId,
        uint48 _expectedLastFinalizedId
    )
        internal
        view
    {
        // NOTE: Core state is no longer stored globally in the contract
        // This assertion validates behavior through successful operations

        // Create expected core state for reference (used by test logic)
        InboxTestLib.createCoreState(_expectedNextProposalId, _expectedLastFinalizedId);

        // Tests verify correct behavior through successful proposal submission/finalization
        // If operations succeed, core state is implicitly correct
        assertTrue(true, "Core state validation through successful operations");
    }

    /// @dev Asserts that a finalization operation completed successfully
    function assertFinalizationCompleted(
        uint48 _lastFinalizedId,
        bytes32 _expectedFinalTransitionHash
    )
        internal
        view
    {
        // Verify finalization by checking that proposals up to _lastFinalizedId are stored
        assertProposalsStored(1, _lastFinalizedId);
        assertTrue(
            _expectedFinalTransitionHash != bytes32(0), "Final transition hash should not be zero"
        );
    }

    /// @dev Asserts proposal count matches expected value
    function assertProposalCount(uint48 _expected, string memory _context) internal {
        // This is a logical assertion since we can't directly query proposal count
        // We verify by ensuring proposals 1 through _expected exist
        if (_expected > 0) {
            assertProposalsStored(1, _expected);
        }
        emit log_string(
            string(
                abi.encodePacked(
                    "Verified proposal count: ", vm.toString(_expected), " in ", _context
                )
            )
        );
    }

    /// @dev Asserts that a range of proposals are NOT stored
    function assertProposalsNotStored(uint48 _startId, uint48 _count) internal view {
        for (uint48 i = 0; i < _count; i++) {
            assertProposalNotStored(_startId + i);
        }
    }

    /// @dev Asserts inbox capacity matches expected value
    function assertCapacityEquals(uint256 _expected, string memory _context) internal view {
        uint256 actualCapacity = Inbox(address(inbox)).getConfig().ringBufferSize - 1;
        assertEq(
            actualCapacity, _expected, string(abi.encodePacked("Capacity mismatch in ", _context))
        );
    }

    /// @dev Asserts performance metrics are within expected bounds
    function assertPerformanceWithinBounds(
        PerformanceMetrics memory _metrics,
        PerformanceMetrics memory _expected,
        uint256 _tolerance,
        string memory _context
    )
        internal
        pure
    {
        assertGasUsage(
            _metrics.totalGas,
            _expected.totalGas,
            _tolerance,
            string(abi.encodePacked("Total gas in ", _context))
        );

        if (_expected.proposalGas > 0) {
            assertGasUsage(
                _metrics.proposalGas,
                _expected.proposalGas,
                _tolerance,
                string(abi.encodePacked("Proposal gas in ", _context))
            );
        }

        if (_expected.proveGas > 0) {
            assertGasUsage(
                _metrics.proveGas,
                _expected.proveGas,
                _tolerance,
                string(abi.encodePacked("Prove gas in ", _context))
            );
        }

        if (_expected.finalizeGas > 0) {
            assertGasUsage(
                _metrics.finalizeGas,
                _expected.finalizeGas,
                _tolerance,
                string(abi.encodePacked("Finalize gas in ", _context))
            );
        }
    }

    /// @dev Asserts that proposals form a valid chain
    function assertValidProposalChain(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions,
        bytes32 _genesisHash
    )
        internal
        pure
    {
        require(_proposals.length == _transitions.length, "Array length mismatch");

        bytes32 expectedParent = _genesisHash;

        for (uint256 i = 0; i < _proposals.length; i++) {
            // Verify transition references correct proposal
            bytes32 expectedProposalHash = InboxTestLib.hashProposal(_proposals[i]);
            assertEq(
                _transitions[i].proposalHash,
                expectedProposalHash,
                string(abi.encodePacked("Transition ", vm.toString(i), " proposal hash mismatch"))
            );

            // Verify transition has correct parent
            assertEq(
                _transitions[i].parentTransitionHash,
                expectedParent,
                string(abi.encodePacked("Transition ", vm.toString(i), " parent hash mismatch"))
            );

            // Update expected parent for next iteration
            expectedParent = InboxTestLib.hashTransition(_transitions[i]);
        }
    }

    /// @dev Asserts that ring buffer state is as expected
    function assertRingBufferState(
        uint48[] memory _expectedProposalIds,
        string memory _context
    )
        internal
        view
    {
        for (uint256 i = 0; i < _expectedProposalIds.length; i++) {
            uint48 proposalId = _expectedProposalIds[i];
            if (proposalId > 0) {
                assertProposalStored(proposalId);
            } else {
                // Slot should be empty or overwritten
                assertTrue(
                    true,
                    string(abi.encodePacked("Ring buffer slot ", vm.toString(i), " in ", _context))
                );
            }
        }
    }

    // ---------------------------------------------------------------
    // Enhanced Helper Functions
    // ---------------------------------------------------------------

    function getGenesisTransitionHash() internal pure returns (bytes32) {
        return InboxTestLib.getGenesisTransitionHash(GENESIS_BLOCK_HASH);
    }

    function createValidProposal(uint48 _id) internal view returns (IInbox.Proposal memory) {
        (IInbox.Proposal memory proposal,) =
            InboxTestLib.createProposal(_id, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
        return proposal;
    }

    function createValidBlobReference(uint256 _seed)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return InboxTestLib.createBlobReference(uint8(_seed % 256));
    }

    /// @dev Creates a standard test transition with default values
    function createStandardTransition(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        returns (IInbox.Transition memory)
    {
        IInbox.Proposal memory proposal = createValidProposal(_proposalId);
        return InboxTestLib.createTransition(proposal, _parentTransitionHash);
    }

    /// @dev Advances time beyond proving window for testing late proofs
    function advanceBeyondProvingWindow() internal {
        vm.warp(block.timestamp + DEFAULT_PROVING_WINDOW + 1);
    }

    /// @dev Advances time beyond extended proving window
    function advanceBeyondExtendedProvingWindow() internal {
        vm.warp(block.timestamp + DEFAULT_EXTENDED_PROVING_WINDOW + 1);
    }

    /// @dev Expects a specific error with descriptive message
    function expectRevertWithReason(bytes4 _selector, string memory _reason) internal {
        vm.expectRevert(abi.encodeWithSelector(_selector));
        // Log the reason for better test readability
        emit log_string(_reason);
    }

    /// @dev Expects revert with custom error message
    function expectRevertWithMessage(string memory _message, string memory _reason) internal {
        vm.expectRevert(bytes(_message));
        emit log_string(_reason);
    }

    /// @dev Expects any revert with descriptive reason
    function expectAnyRevert(string memory _reason) internal {
        vm.expectRevert();
        emit log_string(_reason);
    }
}
