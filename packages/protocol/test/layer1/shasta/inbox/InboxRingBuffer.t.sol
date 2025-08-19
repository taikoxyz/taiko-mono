// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { ExceedsUnfinalizedProposalCapacity } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxRingBuffer
/// @notice Tests for ring buffer mechanics and capacity management
/// @dev This test suite covers ring buffer functionality for proposal storage:
///      - Basic read/write operations and data integrity
///      - Circular buffer wraparound behavior and slot reuse
///      - Capacity calculations and boundary conditions
///      - Modulo operations for indexing and overflow handling
///      - Protection of unfinalized proposals from overwrite
/// @custom:security-contact security@taiko.xyz
contract InboxRingBuffer is InboxTest {
    // Inherits setup from InboxTest base class

    /// @notice Test basic ring buffer write and read operations
    /// @dev Validates fundamental ring buffer data integrity
    function test_ring_buffer_write_read() public {
        uint48 numProposals = MANY_PROPOSALS;
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
            assertEq(storedHash, proposalHashes[i - 1], "Proposal hash should match");
        }
    }

    /// @notice Test ring buffer modulo arithmetic
    /// @dev Validates modulo-based slot indexing for circular buffer
    function test_ring_buffer_modulo() public {
        // Configure small ring buffer for testing
        inbox.setTestConfig(createTestConfigWithRingBufferSize(5));

        // Test proposals that should map to the same slot (1)
        uint48[3] memory proposalIds = [uint48(1), uint48(6), uint48(11)];
        bytes32[3] memory hashes = [keccak256("hash1"), keccak256("hash2"), keccak256("hash3")];

        // Store first proposal
        inbox.exposed_setProposalHash(proposalIds[0], hashes[0]);
        assertEq(inbox.getProposalHash(proposalIds[0]), hashes[0], "First hash should be stored");

        // Store second proposal (should overwrite slot)
        inbox.exposed_setProposalHash(proposalIds[1], hashes[1]);
        assertEq(inbox.getProposalHash(proposalIds[1]), hashes[1], "Second hash should overwrite");
        assertEq(
            inbox.getProposalHash(proposalIds[0]), hashes[1], "First slot should be overwritten"
        );

        // Store third proposal (should overwrite slot again)
        inbox.exposed_setProposalHash(proposalIds[2], hashes[2]);
        assertEq(inbox.getProposalHash(proposalIds[2]), hashes[2], "Third hash should overwrite");
    }

    /// @notice Test ring buffer wraparound behavior
    /// @dev Validates circular buffer wraparound and slot reuse
    function test_ring_buffer_wraparound() public {
        setupSmallRingBuffer(); // Uses SMALL_RING_BUFFER_SIZE (3)
        uint48 bufferSize = uint48(SMALL_RING_BUFFER_SIZE);

        // Fill the ring buffer completely (first round)
        bytes32[] memory firstRoundHashes = new bytes32[](bufferSize);
        for (uint48 i = 0; i < bufferSize; i++) {
            firstRoundHashes[i] = keccak256(abi.encode("first", i));
            inbox.exposed_setProposalHash(i, firstRoundHashes[i]);
        }

        // Verify first round storage
        for (uint48 i = 0; i < bufferSize; i++) {
            assertEq(inbox.getProposalHash(i), firstRoundHashes[i], "First round should be stored");
        }

        // Start second round (wraparound)
        bytes32[] memory secondRoundHashes = new bytes32[](bufferSize);
        for (uint48 i = 0; i < bufferSize; i++) {
            uint48 proposalId = i + bufferSize;
            secondRoundHashes[i] = keccak256(abi.encode("second", i));
            inbox.exposed_setProposalHash(proposalId, secondRoundHashes[i]);
        }

        // Verify wraparound overwrote first round
        for (uint48 i = 0; i < bufferSize; i++) {
            uint48 proposalId = i + bufferSize;
            assertEq(
                inbox.getProposalHash(proposalId),
                secondRoundHashes[i],
                "Second round should overwrite"
            );
            assertEq(
                inbox.getProposalHash(i), secondRoundHashes[i], "First round should be overwritten"
            );
        }
    }

    /// @notice Test ring buffer capacity calculation
    /// @dev Validates capacity calculation formula (bufferSize - 1)
    function test_ring_buffer_capacity_calculation() public {
        uint256[4] memory bufferSizes = [uint256(10), uint256(100), uint256(1000), uint256(5)];

        for (uint256 i = 0; i < bufferSizes.length; i++) {
            inbox.setTestConfig(createTestConfigWithRingBufferSize(bufferSizes[i]));

            uint256 capacity = inbox.getCapacity();
            uint256 expectedCapacity = bufferSizes[i] - 1;

            assertEq(
                capacity,
                expectedCapacity,
                string(
                    abi.encodePacked(
                        "Capacity should be bufferSize-1 for size ", vm.toString(bufferSizes[i])
                    )
                )
            );
        }
    }

    /// @notice Test protection of unfinalized proposals from overwrite
    /// @dev Validates capacity enforcement for data safety
    /// Ring buffer size 3 means slots 0, 1, 2:
    /// - Slot 0: Genesis proposal (can only be overwritten if proposal 1 is finalized)
    /// - Slot 1: Will hold proposal 1
    /// - Slot 2: Will hold proposal 2
    /// Capacity is 2, meaning max 2 unfinalized proposals
    function test_ring_buffer_protect_unfinalized() public {
        setupSmallRingBuffer(); // Ring buffer size 3, capacity = 2

        // Test scenario: Try to submit 3 proposals without finalization
        // Expected: 3rd proposal should fail because it would overwrite genesis
        // but proposal 1 is not finalized

        // Submit proposal 1
        IInbox.CoreState memory coreState1 = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: getGenesisClaimHash(),
            bondInstructionsHash: bytes32(0)
        });

        setupProposalMocks(Alice);
        bytes memory data1 = encodeProposalDataWithGenesis(
            coreState1, InboxTestLib.createBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        setupBlobHashes();
        vm.prank(Alice);
        inbox.propose(bytes(""), data1);

        // Get proposal 1 for use as parent
        (IInbox.Proposal memory proposal1,) =
            InboxTestLib.createProposal(1, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
        proposal1.coreStateHash = keccak256(
            abi.encode(
                IInbox.CoreState({
                    nextProposalId: 2,
                    lastFinalizedProposalId: 0,
                    lastFinalizedClaimHash: getGenesisClaimHash(),
                    bondInstructionsHash: bytes32(0)
                })
            )
        );

        // Submit proposal 2
        IInbox.CoreState memory coreState2 = IInbox.CoreState({
            nextProposalId: 2,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: getGenesisClaimHash(),
            bondInstructionsHash: bytes32(0)
        });

        setupProposalMocks(Alice);
        bytes memory data2 = encodeProposalDataForSubsequent(
            coreState2, proposal1, InboxTestLib.createBlobReference(2), new IInbox.ClaimRecord[](0)
        );

        setupBlobHashes();
        vm.prank(Alice);
        inbox.propose(bytes(""), data2);

        // Get proposal 2 for use as parent
        (IInbox.Proposal memory proposal2,) =
            InboxTestLib.createProposal(2, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
        proposal2.coreStateHash = keccak256(
            abi.encode(
                IInbox.CoreState({
                    nextProposalId: 3,
                    lastFinalizedProposalId: 0,
                    lastFinalizedClaimHash: getGenesisClaimHash(),
                    bondInstructionsHash: bytes32(0)
                })
            )
        );

        // Try to submit proposal 3 - should fail due to capacity
        // Proposal 3 would go to slot 0 (3 % 3 = 0), which has the genesis proposal
        // Genesis can only be overwritten if proposal 1 is finalized (which it's not)
        // So this will fail with ExceedsUnfinalizedProposalCapacity
        // We need to provide both proposal 2 (parent) and genesis (slot being overwritten)

        // Create the genesis proposal that was stored at initialization
        // Use the library function to correctly recreate the genesis proposal
        IInbox.CoreState memory dummyState; // Not used by createGenesisProposal
        IInbox.Proposal memory genesisProposal = InboxTestLib.createGenesisProposal(dummyState);

        IInbox.CoreState memory coreState3 = IInbox.CoreState({
            nextProposalId: 3,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: getGenesisClaimHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Create the proposal data with both parent proposals
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](2);
        parentProposals[0] = proposal2;
        parentProposals[1] = genesisProposal;

        setupProposalMocks(Alice);
        bytes memory data3 = encodeProposalDataWithProposals(
            uint48(0), // deadline
            coreState3,
            parentProposals,
            InboxTestLib.createBlobReference(3),
            new IInbox.ClaimRecord[](0)
        );

        setupBlobHashes();
        vm.expectRevert(ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data3);
    }

    // All helper functions are now inherited from InboxTest base class
}
