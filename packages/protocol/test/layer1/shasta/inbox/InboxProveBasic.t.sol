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
    /// @dev Validates the complete proof submission flow
    function test_prove_single_claim() public {
        // Arrange: Submit a proposal that can be proven
        IInbox.Proposal memory proposal = submitProposal(SINGLE_PROPOSAL, Alice);
        bytes32 parentClaimHash = bytes32(uint256(999));

        // Act: Submit proof with parent claim hash
        proveProposal(proposal, Bob, parentClaimHash);

        // Assert: Verify claim record was stored with correct parent relationship
        assertClaimRecordStored(SINGLE_PROPOSAL, parentClaimHash);
    }

    /// @notice Test proving multiple claims in one transaction
    /// @dev Validates batch proof submission capabilities
    function test_prove_multiple_claims() public {
        // Arrange: Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](FEW_PROPOSALS);
        for (uint48 i = 1; i <= FEW_PROPOSALS; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Act & Assert: Prove each proposal with different parent hashes
        for (uint48 i = 1; i <= FEW_PROPOSALS; i++) {
            bytes32 parentClaimHash = bytes32(uint256(i * 100)); // 100, 200, 300
            proveProposal(proposals[i - 1], Bob, parentClaimHash);
            assertClaimRecordStored(i, parentClaimHash);
        }
    }

    /// @notice Test proving claims for sequential proposals
    /// @dev Validates linked proof chain construction
    function test_prove_sequential_proposals() public {
        uint48 count = 4;
        bytes32 parentHash = getGenesisClaimHash();

        // Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        for (uint48 i = 0; i < count; i++) {
            proposals[i] = submitProposal(i + 1, Alice);
        }

        // Prove sequentially with linked parent relationships
        for (uint48 i = 0; i < count; i++) {
            uint48 proposalId = i + 1;
            
            // Prove with current parent hash
            proveProposal(proposals[i], Bob, parentHash);
            assertClaimRecordStored(proposalId, parentHash);

            // Update parent hash for chain progression
            IInbox.Claim memory claim = InboxTestLib.createClaim(proposals[i], parentHash, Bob);
            parentHash = InboxTestLib.hashClaim(claim);
        }
    }

    /// @notice Test that proof verification is called with correct parameters
    /// @dev Validates proof verifier integration and parameter passing
    function test_prove_verification_called() public {
        // Arrange: Create proposal and claim data
        IInbox.Proposal memory proposal = submitProposal(SINGLE_PROPOSAL, Alice);
        IInbox.Claim memory claim = InboxTestLib.createClaim(proposal, bytes32(0), Bob);
        
        bytes memory proof = bytes("test_proof_data");
        bytes32 expectedClaimsHash = keccak256(abi.encode(_toArray(claim)));

        // Expect: Verifier should be called with exact parameters
        vm.expectCall(
            proofVerifier,
            abi.encodeWithSelector(IProofVerifier.verifyProof.selector, expectedClaimsHash, proof)
        );

        // Act: Submit proof and trigger verifier call
        setupProofMocks(true);
        vm.prank(Bob);
        inbox.prove(
            InboxTestLib.encodeProveData(_toArray(proposal), _toArray(claim)), 
            proof
        );
    }
    
    /// @dev Helper to convert single item to array
    function _toArray(IInbox.Proposal memory _item) private pure returns (IInbox.Proposal[] memory arr) {
        arr = new IInbox.Proposal[](1);
        arr[0] = _item;
    }
    
    /// @dev Helper to convert single item to array
    function _toArray(IInbox.Claim memory _item) private pure returns (IInbox.Claim[] memory arr) {
        arr = new IInbox.Claim[](1);
        arr[0] = _item;
    }

    /// @notice Test claim record storage and retrieval
    /// @dev Validates persistent claim record storage with multiple proofs per proposal
    function test_prove_claim_record_storage() public {
        uint48 numProposals = FEW_PROPOSALS;
        uint256 proofsPerProposal = 2;

        // Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Prove each proposal multiple times with different parent hashes
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < proofsPerProposal; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j));
                proveProposal(proposals[i - 1], Bob, parentClaimHash);
                assertClaimRecordStored(i, parentClaimHash);
            }
        }

        // Verify persistent storage of all records
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < proofsPerProposal; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j));
                assertClaimRecordStored(i, parentClaimHash);
            }
        }
    }

    /// @notice Test proving with invalid proof reverts
    /// @dev Validates error handling for proof verification failures
    function test_prove_invalid_proof_reverts() public {
        // Arrange: Create valid proposal and claim data
        IInbox.Proposal memory proposal = submitProposal(SINGLE_PROPOSAL, Alice);
        IInbox.Claim memory claim = InboxTestLib.createClaim(proposal, bytes32(0), Bob);

        // Configure: Mock proof verification to fail
        setupProofMocks(false);

        // Act & Assert: Invalid proof should be rejected
        expectRevertWithMessage("Invalid proof", "Invalid proof should be rejected");
        vm.prank(Bob);
        inbox.prove(
            InboxTestLib.encodeProveData(_toArray(proposal), _toArray(claim)), 
            bytes("invalid_proof")
        );
    }
}
