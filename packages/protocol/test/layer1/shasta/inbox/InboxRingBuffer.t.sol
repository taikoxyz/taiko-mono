// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "./TestInboxWithMockBlobs.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import { Inbox, ExceedsUnfinalizedProposalCapacity } from "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxRingBuffer
/// @notice Tests for ring buffer mechanics and capacity management
/// @dev This test suite covers ring buffer functionality for proposal storage:
///      - Basic read/write operations and data integrity
///      - Circular buffer wraparound behavior and slot reuse
///      - Capacity calculations and boundary conditions
///      - Modulo operations for indexing and overflow handling
///      - Protection of unfinalized proposals from overwrite
/// @custom:security-contact security@taiko.xyz
contract InboxRingBuffer is CommonTest {
    TestInboxWithMockBlobs internal inbox;

    // Mock dependencies
    address internal bondToken;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    function setUp() public virtual override {
        super.setUp();

        // Create mock addresses
        bondToken = makeAddr("bondToken");
        syncedBlockManager = makeAddr("syncedBlockManager");
        forcedInclusionStore = makeAddr("forcedInclusionStore");
        proofVerifier = makeAddr("proofVerifier");
        proposerChecker = makeAddr("proposerChecker");

        // Deploy and initialize inbox
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(this), GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        inbox = TestInboxWithMockBlobs(address(proxy));

        // Set default config
        IInbox.Config memory config = IInbox.Config({
            bondToken: bondToken,
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 100,
            basefeeSharingPctg: 10,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });
        inbox.setTestConfig(config);

        // Fund test accounts
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
    }

    /// @notice Test basic ring buffer write and read operations
    /// @dev Validates fundamental ring buffer data integrity:
    ///      1. Writes multiple proposal hashes to sequential slots
    ///      2. Reads back all stored hashes for verification
    ///      3. Ensures data consistency and proper storage/retrieval
    function test_ring_buffer_write_read() public {
        uint48 numProposals = 10;
        bytes32[] memory proposalHashes = new bytes32[](numProposals);

        // Write proposal hashes to ring buffer
        for (uint48 i = 1; i <= numProposals; i++) {
            bytes32 proposalHash = keccak256(abi.encode("proposal", i));
            proposalHashes[i - 1] = proposalHash;
            inbox.exposed_setProposalHash(i, proposalHash);
        }

        // Read and verify all proposal hashes
        for (uint48 i = 1; i <= numProposals; i++) {
            bytes32 storedHash = inbox.getProposalHash(i);
            assertEq(storedHash, proposalHashes[i - 1]);
        }
    }

    /// @notice Test ring buffer modulo arithmetic
    /// @dev Validates modulo-based slot indexing for circular buffer:
    ///      1. Configures small ring buffer (size 5) for testing
    ///      2. Tests proposals mapping to same slot via modulo arithmetic
    ///      3. Verifies slot overwriting behavior for ID collisions
    function test_ring_buffer_modulo() public {
        // Set small ring buffer size for testing
        IInbox.Config memory config = IInbox.Config({
            bondToken: bondToken,
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 5,
            basefeeSharingPctg: 10,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });
        inbox.setTestConfig(config);

        // Test that proposals map to expected slots
        uint48[] memory proposalIds = new uint48[](3);
        proposalIds[0] = 1; // Should map to slot 1
        proposalIds[1] = 6; // Should map to slot 1 (6 % 5 = 1)
        proposalIds[2] = 11; // Should map to slot 1 (11 % 5 = 1)

        // Store first proposal
        bytes32 hash1 = keccak256("hash1");
        inbox.exposed_setProposalHash(proposalIds[0], hash1);
        assertEq(inbox.getProposalHash(proposalIds[0]), hash1);

        // Store second proposal (should overwrite slot)
        bytes32 hash2 = keccak256("hash2");
        inbox.exposed_setProposalHash(proposalIds[1], hash2);
        assertEq(inbox.getProposalHash(proposalIds[1]), hash2);

        // Verify first proposal's slot was overwritten
        assertEq(inbox.getProposalHash(proposalIds[0]), hash2);

        // Store third proposal (should overwrite slot again)
        bytes32 hash3 = keccak256("hash3");
        inbox.exposed_setProposalHash(proposalIds[2], hash3);
        assertEq(inbox.getProposalHash(proposalIds[2]), hash3);
    }

    /// @notice Test ring buffer wraparound behavior
    /// @dev Validates circular buffer wraparound and slot reuse:
    ///      1. Fills entire ring buffer with initial proposals
    ///      2. Adds new proposals causing wraparound to beginning
    ///      3. Verifies old data is properly overwritten by new data
    function test_ring_buffer_wraparound() public {
        // Set small ring buffer size
        IInbox.Config memory config = IInbox.Config({
            bondToken: bondToken,
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 3,
            basefeeSharingPctg: 10,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });
        inbox.setTestConfig(config);

        // Fill the ring buffer completely
        bytes32[] memory firstRoundHashes = new bytes32[](3);
        for (uint48 i = 0; i < 3; i++) {
            firstRoundHashes[i] = keccak256(abi.encode("first", i));
            inbox.exposed_setProposalHash(i, firstRoundHashes[i]);
        }

        // Verify first round
        for (uint48 i = 0; i < 3; i++) {
            assertEq(inbox.getProposalHash(i), firstRoundHashes[i]);
        }

        // Start second round (wraparound)
        bytes32[] memory secondRoundHashes = new bytes32[](3);
        for (uint48 i = 0; i < 3; i++) {
            uint48 proposalId = i + 3; // IDs 3, 4, 5
            secondRoundHashes[i] = keccak256(abi.encode("second", i));
            inbox.exposed_setProposalHash(proposalId, secondRoundHashes[i]);
        }

        // Verify second round overwrote first round
        for (uint48 i = 0; i < 3; i++) {
            uint48 proposalId = i + 3;
            assertEq(inbox.getProposalHash(proposalId), secondRoundHashes[i]);
            // First round hashes should be overwritten
            assertEq(inbox.getProposalHash(i), secondRoundHashes[i]);
        }
    }

    /// @notice Test ring buffer capacity calculation
    /// @dev Validates capacity calculation formula (bufferSize - 1):
    ///      1. Tests various buffer sizes (10, 100, 1000, 5)
    ///      2. Verifies capacity is always one less than buffer size
    ///      3. Ensures consistent calculation across different sizes
    function test_ring_buffer_capacity_calculation() public {
        uint256[] memory bufferSizes = new uint256[](4);
        bufferSizes[0] = 10;
        bufferSizes[1] = 100;
        bufferSizes[2] = 1000;
        bufferSizes[3] = 5;

        for (uint256 i = 0; i < bufferSizes.length; i++) {
            IInbox.Config memory config = IInbox.Config({
                bondToken: bondToken,
                provingWindow: 1 hours,
                extendedProvingWindow: 2 hours,
                maxFinalizationCount: 10,
                ringBufferSize: bufferSizes[i],
                basefeeSharingPctg: 10,
                syncedBlockManager: syncedBlockManager,
                proofVerifier: proofVerifier,
                proposerChecker: proposerChecker,
                forcedInclusionStore: forcedInclusionStore
            });
            inbox.setTestConfig(config);

            uint256 capacity = inbox.getCapacity();
            assertEq(capacity, bufferSizes[i] - 1);
        }
    }

    /// @notice Test protection of unfinalized proposals from overwrite
    /// @dev Validates capacity enforcement for data safety:
    ///      1. Fills ring buffer capacity with unfinalized proposals
    ///      2. Attempts to add beyond capacity limit
    ///      3. Expects ExceedsUnfinalizedProposalCapacity error for protection
    function test_ring_buffer_protect_unfinalized() public {
        // Set small buffer
        IInbox.Config memory config = IInbox.Config({
            bondToken: bondToken,
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 3, // Capacity = 2
            basefeeSharingPctg: 10,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });
        inbox.setTestConfig(config);

        // Setup blob hashes for testing
        setupBlobHashes();

        // Create 2 unfinalized proposals (fills capacity)
        for (uint48 i = 1; i <= 2; i++) {
            IInbox.CoreState memory coreState = createCoreState(i, 0);
            // Core state will be validated by the contract during propose()

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory blobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), data);
        }

        // Try to add proposal 3 (would need slot 0, but proposals 1 and 2 are unfinalized)
        IInbox.CoreState memory coreState3 = createCoreState(3, 0);
        // Core state will be validated by the contract during propose()

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef3 = createValidBlobReference(3);
        IInbox.ClaimRecord[] memory claimRecords3 = new IInbox.ClaimRecord[](0);
        bytes memory data3 = abi.encode(uint64(0), coreState3, blobRef3, claimRecords3);

        // Should fail - exceeds capacity
        vm.expectRevert(ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data3);
    }

    // Helper functions

    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });
    }

    function createValidBlobReference(uint256 _seed)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return LibBlobs.BlobReference({ blobStartIndex: uint8(_seed % 10), numBlobs: 1, offset: 0 });
    }

    function mockProposerAllowed(address _proposer) internal {
        vm.mockCall(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, _proposer),
            abi.encode()
        );
    }

    function mockForcedInclusionDue(bool _isDue) internal {
        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(IForcedInclusionStore.isOldestForcedInclusionDue.selector),
            abi.encode(_isDue)
        );
    }

    function setupBlobHashes() internal {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                hashes[i] = keccak256(abi.encode("blob", i));
            }
        }
        vm.blobhashes(hashes);
    }
}
