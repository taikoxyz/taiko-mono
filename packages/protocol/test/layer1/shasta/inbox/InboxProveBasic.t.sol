// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxProveBasic
/// @notice Tests for basic proof submission functionality
/// @dev This test suite covers proof submission and verification:
///      - Single and multiple proof submissions
///      - Claim record storage and retrieval
///      - Proof verification integration with mock verifier
///      - Sequential proof chaining with parent relationships
///      - Error handling for invalid proofs
/// @custom:security-contact security@taiko.xyz
contract InboxProveBasic is InboxTest {
    using InboxTestLib for *;

    function setUp() public virtual override {
        super.setUp();
    }

    /// @notice Test proving a single claim successfully
    /// @dev Validates the complete proof submission flow:
    ///      1. Submits a proposal to create provable content
    ///      2. Generates proof with specific parent claim hash
    ///      3. Verifies claim record storage for finalization
    function test_prove_single_claim() public {
        // Setup: Prepare environment for proof operations
        setupBlobHashes();

        // Arrange: Submit a proposal that can be proven
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = submitProposal(proposalId, Alice);

        // Act: Submit proof with arbitrary parent claim hash (simulating chain state)
        bytes32 parentClaimHash = bytes32(uint256(999));
        proveProposal(proposal, Bob, parentClaimHash);

        // Assert: Verify claim record was stored with correct parent relationship
        assertClaimRecordStored(proposalId, parentClaimHash);
    }

    /// @notice Test proving multiple claims in one transaction
    /// @dev Validates batch proof submission capabilities:
    ///      1. Creates multiple proposals with sequential IDs
    ///      2. Proves each with different parent claim hashes
    ///      3. Verifies independent storage of claim records
    function test_prove_multiple_claims() public {
        // Setup: Prepare environment for multiple proofs
        setupBlobHashes();
        uint48 numClaims = 3;

        // Arrange: Submit all proposals first to create provable content
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numClaims);
        for (uint48 i = 1; i <= numClaims; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Act: Prove each proposal with different parent hashes (simulating different chain states)
        for (uint48 i = 1; i <= numClaims; i++) {
            bytes32 parentClaimHash = bytes32(uint256(i * 100)); // 100, 200, 300
            proveProposal(proposals[i - 1], Bob, parentClaimHash);

            // Assert: Verify each claim record is stored independently
            assertClaimRecordStored(i, parentClaimHash);
        }
    }

    /// @notice Test proving claims for sequential proposals
    /// @dev Validates linked proof chain construction:
    ///      1. Creates proposals with non-sequential starting ID
    ///      2. Links each proof to previous claim (parent chaining)
    ///      3. Verifies proper claim hash progression for chain integrity
    function test_prove_sequential_proposals() public {
        // Setup: Prepare environment for sequential proof chain
        setupBlobHashes();
        uint48 startId = 5; // Start with ID 5 to test non-zero starting
        uint48 count = 4; // Create 4 proposals: IDs 5,6,7,8
        bytes32 parentHash = bytes32(uint256(1000)); // Initial parent (simulating existing chain)

        // Act & Assert: Create and prove proposals with linked parent relationships
        for (uint48 i = 0; i < count; i++) {
            // Submit proposal with current ID
            IInbox.Proposal memory proposal = submitProposal(startId + i, Alice);

            // Prove with current parent hash
            proveProposal(proposal, Bob, parentHash);

            // Verify claim record storage
            assertClaimRecordStored(startId + i, parentHash);

            // Calculate next parent hash from current claim (chain progression)
            IInbox.Claim memory claim = InboxTestLib.createClaim(proposal, parentHash, Bob);
            parentHash = InboxTestLib.hashClaim(claim);
        }
    }

    /// @notice Test that proof verification is called with correct parameters
    /// @dev Validates proof verifier integration and parameter passing:
    ///      1. Creates verifiable proposal and claim data
    ///      2. Calculates expected hash from claims array
    ///      3. Expects exact mock call to verifier with correct parameters
    ///      4. Verifies proper integration between Inbox and ProofVerifier
    function test_prove_verification_called() public {
        // Setup: Prepare environment for proof verification testing
        setupBlobHashes();

        // Arrange: Create proposal and corresponding claim for verification
        IInbox.Proposal memory proposal = submitProposal(1, Alice);
        IInbox.Claim memory claim = InboxTestLib.createClaim(proposal, bytes32(0), Bob);

        // Package data for proof submission
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        // Calculate expected parameters for verifier call
        bytes32 expectedClaimsHash = keccak256(abi.encode(claims));
        bytes memory proof = bytes("test_proof_data");

        // Expect: Verifier should be called with exact parameters
        vm.expectCall(
            proofVerifier,
            abi.encodeWithSelector(IProofVerifier.verifyProof.selector, expectedClaimsHash, proof)
        );

        // Act: Submit proof and trigger verifier call
        setupProofMocks(true);
        vm.prank(Bob);
        inbox.prove(InboxTestLib.encodeProveData(proposals, claims), proof);
    }

    /// @notice Test claim record storage and retrieval
    /// @dev Validates persistent claim record storage with multiple proofs per proposal:
    ///      1. Creates multiple proposals as base for proofs
    ///      2. Submits multiple proofs per proposal with different parent hashes
    ///      3. Verifies immediate storage after each proof submission
    ///      4. Validates persistent retrieval of all stored records
    function test_prove_claim_record_storage() public {
        // Setup: Prepare environment for complex storage testing
        setupBlobHashes();
        uint48 numProposals = 3;

        // Arrange: Submit all proposals first to create provable content
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Act: Prove each proposal multiple times with different parent hashes
        // This tests the ability to store multiple claim records per proposal
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < 2; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j)); // 1000,1001 2000,2001
                    // 3000,3001
                proveProposal(proposals[i - 1], Bob, parentClaimHash);

                // Assert: Verify immediate storage after each proof
                assertClaimRecordStored(i, parentClaimHash);
            }
        }

        // Assert: Verify all records remain accessible (persistent storage test)
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < 2; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j));
                assertClaimRecordStored(i, parentClaimHash);
            }
        }
    }

    /// @notice Test proving with invalid proof reverts
    /// @dev Validates error handling for proof verification failures:
    ///      1. Creates valid proposal and claim data
    ///      2. Configures mock verifier to reject proof
    ///      3. Expects revert with appropriate error message
    ///      4. Ensures security by preventing invalid proof acceptance
    function test_prove_invalid_proof_reverts() public {
        // Setup: Prepare environment for error condition testing
        setupBlobHashes();

        // Arrange: Create valid proposal and claim (data is valid, proof will be invalid)
        IInbox.Proposal memory proposal = submitProposal(1, Alice);
        IInbox.Claim memory claim = InboxTestLib.createClaim(proposal, bytes32(0), Bob);

        // Package data for proof submission
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        // Configure: Mock proof verification to fail (simulating invalid cryptographic proof)
        setupProofMocks(false);

        // Act & Assert: Invalid proof should be rejected with appropriate error
        vm.expectRevert("Invalid proof");
        vm.prank(Bob);
        inbox.prove(InboxTestLib.encodeProveData(proposals, claims), bytes("invalid_proof"));
    }
}
