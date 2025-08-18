// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import "./InboxMockContracts.sol";
import {
    Inbox,
    InvalidState,
    DeadlineExceeded,
    ExceedsUnfinalizedProposalCapacity
} from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxProposeValidation
/// @notice Tests for proposal validation logic including deadlines, state checks, and constraints
/// @dev This test suite covers comprehensive proposal validation:
///      - Deadline validation (valid, expired, none)
///      - Core state hash validation and security
///      - Proposer authorization and access control
///      - Blob reference validation and bounds checking
///      - Forced inclusion processing and special cases
///      - Ring buffer capacity limits and enforcement
///      - Error handling for all validation failures
/// @custom:security-contact security@taiko.xyz
contract InboxProposeValidation is InboxTest {
    using InboxTestLib for *;

    // Override setupMockAddresses to use actual mock contracts
    function setupMockAddresses() internal override {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
    }

    /// @notice Test proposal with valid deadline
    /// @dev Validates successful proposal submission with future deadline:
    ///      1. Sets up EIP-4844 blob environment
    ///      2. Creates core state with genesis claim hash
    ///      3. Submits proposal with deadline 1 hour in the future
    ///      4. Verifies successful storage without time-based rejection
    function test_propose_with_valid_deadline() public {
        // Setup: Prepare EIP-4844 blob environment for proposal submission
        setupBlobHashes();

        // Arrange: Setup core state with genesis claim hash for chain continuity
        bytes32 genesisHash = getGenesisClaimHash();
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));
        // Core state will be validated by the contract during propose()

        // Arrange: Configure mocks and create proposal with valid future deadline
        setupProposalMocks(Alice);
        uint64 deadline = uint64(block.timestamp + 1 hours); // Valid deadline (1 hour future)

        bytes memory data = encodeProposalDataWithGenesis(
            deadline, coreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        // Act: Submit proposal with valid deadline
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Assert: Verify proposal was accepted and stored successfully
        assertProposalStored(1);
    }

    /// @notice Test proposal with expired deadline
    /// @dev Validates deadline enforcement mechanism for security:
    ///      1. Advances blockchain time to create temporal context
    ///      2. Creates proposal with past deadline (timestamp - 1)
    ///      3. Expects DeadlineExceeded error for time-based protection
    ///      4. Ensures stale proposals cannot be submitted maliciously
    function test_propose_with_expired_deadline() public {
        // Setup: Prepare environment and advance time to create context
        setupBlobHashes();
        vm.warp(1000); // Set block.timestamp = 1000

        // Arrange: Setup core state for proposal submission
        bytes32 genesisHash = getGenesisClaimHash();
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));
        // Core state will be validated by the contract during propose()

        // Arrange: Create proposal with expired deadline (security test)
        setupProposalMocks(Alice);
        uint64 deadline = uint64(block.timestamp - 1); // Expired by 1 second

        bytes memory data = encodeProposalDataWithGenesis(
            deadline, coreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        // Act & Assert: Submission should fail with DeadlineExceeded error
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with zero deadline (no deadline)
    /// @dev Validates optional deadline handling for flexibility:
    ///      1. Creates proposal with deadline = 0 (no time constraint)
    ///      2. Verifies that zero deadline bypasses time validation
    ///      3. Ensures successful submission without temporal restrictions
    ///      4. Tests the optional nature of deadline enforcement
    function test_propose_with_no_deadline() public {
        // Setup: Prepare EIP-4844 blob environment
        setupBlobHashes();

        // Arrange: Setup core state for proposal submission
        bytes32 genesisHash = getGenesisClaimHash();
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));
        // Core state will be validated by the contract during propose()

        // Arrange: Create proposal with no deadline (deadline = 0)
        setupProposalMocks(Alice);

        bytes memory data = encodeProposalDataWithGenesis(
            coreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        // Act: Submit proposal without deadline constraint
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Assert: Should succeed with no deadline validation
        assertProposalStored(1);
    }

    /// @notice Test proposal with invalid core state hash
    /// @dev Validates core state integrity protection against attacks:
    ///      1. Sets correct core state in contract storage
    ///      2. Attempts submission with mismatched core state
    ///      3. Expects InvalidState error for security protection
    ///      4. Prevents state desynchronization and replay attacks
    function test_propose_with_invalid_state_hash() public {
        // Setup: Establish baseline for state integrity testing
        setupBlobHashes();
        bytes32 genesisHash = getGenesisClaimHash();

        // Arrange: Set correct core state in contract storage (nextProposalId=1)
        InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));

        // Arrange: Create proposal with mismatched core state (attack simulation)
        IInbox.CoreState memory wrongCoreState =
            InboxTestLib.createCoreState(2, 0, genesisHash, bytes32(0)); // Wrong nextProposalId

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);

        // Use proper encoding - but with wrong core state
        bytes memory data =
            encodeProposalDataWithGenesis(uint64(0), wrongCoreState, blobRef, claimRecords);

        // Act & Assert: Invalid state should be rejected with InvalidState error
        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal from unauthorized proposer
    /// @dev Validates access control and authorization mechanism:
    ///      1. Sets up valid proposal data and core state
    ///      2. Configures mock to reject proposer (Bob) authorization
    ///      3. Expects revert when unauthorized proposer attempts submission
    ///      4. Ensures only authorized proposers can submit proposals
    function test_propose_unauthorized_proposer() public {
        // Setup: Create valid genesis claim and core state structure
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTimestamp: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        // Core state will be validated by the contract during propose()

        // Arrange: Mock proposer checker to reject Bob's authorization
        vm.mockCallRevert(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, Bob),
            abi.encode("Not authorized")
        );
        mockForcedInclusionDue(false);

        // Arrange: Create valid proposal data (everything valid except authorization)
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        // Act & Assert: Unauthorized proposer should be rejected
        vm.expectRevert();
        vm.prank(Bob);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with forced inclusion
    /// @dev Validates forced inclusion mechanism for censorship resistance:
    ///      1. Configures forced inclusion as due/required
    ///      2. Mocks consumption of oldest forced inclusion with fee data
    ///      3. Submits regular proposal triggering forced inclusion processing
    ///      4. Verifies both forced and regular proposals are created correctly
    function test_propose_with_forced_inclusion() public {
        // Setup: Prepare EIP-4844 blob environment for forced inclusion testing
        setupBlobHashes();
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTimestamp: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        // Core state will be validated by the contract during propose()

        // Arrange: Configure Alice as authorized proposer
        mockProposerAllowed(Alice);

        // Arrange: Mock that forced inclusion is due (censorship resistance trigger)
        mockForcedInclusionDue(true);

        // Arrange: Mock consumption of oldest forced inclusion (fee-paying transaction)
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("forced_blob", 0));

        IForcedInclusionStore.ForcedInclusion memory forcedInclusion = IForcedInclusionStore
            .ForcedInclusion({
            feeInGwei: 10, // Fee paid for forced inclusion
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(
                IForcedInclusionStore.consumeOldestForcedInclusion.selector, Alice
            ),
            abi.encode(forcedInclusion)
        );

        // Arrange: Create regular proposal data (will trigger forced inclusion processing)
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(2);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);

        // Use proper encoding with proposals array
        bytes memory data =
            encodeProposalDataWithGenesis(uint64(0), coreState, blobRef, claimRecords);

        // Note: When forced inclusion is due, both forced inclusion and regular proposals are
        // created

        // Act: Submit proposal triggering forced inclusion processing
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Assert: Verify forced inclusion proposal was created
        bytes32 storedHash1 = inbox.getProposalHash(1); // Forced inclusion proposal
        assertTrue(storedHash1 != bytes32(0), "Forced inclusion proposal should be created");

        // Assert: Verify regular proposal was also created
        bytes32 storedHash2 = inbox.getProposalHash(2); // Regular proposal
        assertTrue(storedHash2 != bytes32(0), "Regular proposal should also be created");
    }

    /// @notice Test proposal exceeding unfinalized capacity
    /// @dev Validates ring buffer capacity enforcement for DoS protection:
    ///      1. Configures small ring buffer size (capacity = 2)
    ///      2. Fills capacity with valid proposals
    ///      3. Attempts to exceed capacity with third proposal
    ///      4. Expects ExceedsUnfinalizedProposalCapacity error for protection
    function test_propose_exceeds_capacity() public {
        // Setup: Prepare environment with limited ring buffer capacity
        setupBlobHashes();
        // Configure small ring buffer size for capacity testing
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 3; // Capacity = ringBufferSize - 1 = 2
        inbox.setTestConfig(config);

        // Submit 2 proposals to fill available capacity
        for (uint48 i = 1; i <= 2; i++) {
            submitProposal(i, Alice);
        }

        // Act & Assert: Attempt to add 3rd proposal (exceeds capacity)
        // Setup for proposal 3
        IInbox.CoreState memory coreState3 = _getGenesisCoreState();
        coreState3.nextProposalId = 3;

        setupProposalMocks(Alice);

        // When ring buffer wraps around to slot 0 (which has genesis), need 2 proposals
        // Create the last proposal (id=2) that was just stored
        IInbox.Proposal memory lastProposal = _recreateStoredProposal(2);

        // Get the genesis proposal that's in slot 0
        IInbox.Proposal memory genesisProposal = _recreateGenesisProposal();

        // Include both proposals for ring buffer wraparound validation
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = lastProposal;
        proposals[1] = genesisProposal;

        bytes memory data3 = encodeProposalDataWithProposals(
            uint64(0),
            coreState3,
            proposals,
            InboxTestLib.createBlobReference(3),
            new IInbox.ClaimRecord[](0)
        );

        // Expect capacity exceeded error for DoS protection
        vm.expectRevert(ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data3);
    }

    /// @notice Test proposal with invalid blob reference
    /// @dev Validates blob reference validation for data integrity:
    ///      1. Creates proposal with invalid blob reference (numBlobs = 0)
    ///      2. Expects InvalidBlobReference error for malformed data
    ///      3. Ensures only valid blob references are accepted
    ///      4. Protects against invalid EIP-4844 blob data
    function test_propose_invalid_blob_reference() public {
        // Setup: Create baseline state for blob reference validation
        setupBlobHashes();

        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTimestamp: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });

        // Arrange: Configure valid authorization and forced inclusion state
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Arrange: Create invalid blob reference (numBlobs = 0 violates EIP-4844)
        LibBlobs.BlobReference memory invalidBlobRef = LibBlobs.BlobReference({
            blobStartIndex: 0,
            numBlobs: 0, // Invalid! Must be > 0 for valid blob reference
            offset: 0
        });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);

        // Use proper encoding with proposals array
        bytes memory data =
            encodeProposalDataWithGenesis(uint64(0), coreState, invalidBlobRef, claimRecords);

        // Act & Assert: Invalid blob reference should be rejected
        vm.expectRevert(LibBlobs.InvalidBlobReference.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with blob not found
    /// @dev Validates blob existence checking for data availability:
    ///      1. Creates proposal referencing non-existent blob (index 100)
    ///      2. Expects BlobNotFound error for missing blob data
    ///      3. Ensures blob data availability before proposal acceptance
    ///      4. Protects against references to unavailable EIP-4844 blobs
    function test_propose_blob_not_found() public {
        // Setup: Create baseline state for blob availability testing
        setupBlobHashes(); // Setup valid blob hashes first

        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTimestamp: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });

        // Arrange: Configure valid authorization (everything valid except blob availability)
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Arrange: Reference a blob that doesn't exist (index 100 is empty in our setup)
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 100, // Intentionally empty in setupBlobHashes()
            numBlobs: 1,
            offset: 0
        });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);

        // Use the proper encoding function that includes the proposals array
        bytes memory data =
            encodeProposalDataWithGenesis(uint64(0), coreState, blobRef, claimRecords);

        // Act & Assert: Missing blob should be rejected for data availability
        vm.expectRevert(LibBlobs.BlobNotFound.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @dev Override setupBlobHashes to support custom test scenarios
    /// @notice Configures EIP-4844 blob hashes for validation testing:
    ///         - Indices 0-9: Valid blob hashes for normal testing
    ///         - Index 100: Empty (bytes32(0)) for testing blob not found
    ///         - Other indices: Uninitialized for boundary testing
    function setupBlobHashes() internal override {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                hashes[i] = keccak256(abi.encode("blob", i)); // Valid blob hashes for testing
            } else if (i == 100) {
                // Intentionally leave index 100 empty for testing blob not found
                hashes[i] = bytes32(0);
            }
            // Other indices remain uninitialized (bytes32(0)) for boundary testing
        }
        vm.blobhashes(hashes);
    }
}
