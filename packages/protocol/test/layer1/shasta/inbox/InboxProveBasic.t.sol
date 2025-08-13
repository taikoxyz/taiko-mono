// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "./InboxTestScenarios.sol";
import "./InboxTestUtils.sol";
import "./InboxTestBuilder.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxProveBasic
/// @notice Tests for basic proof submission functionality
/// @dev Tests cover single and multiple proof submissions, claim record storage, and events
/// @custom:security-contact security@taiko.xyz
contract InboxProveBasic is InboxTestScenarios {
    using InboxTestUtils for *;
    using InboxTestBuilder for *;


    function setUp() public virtual override {
        super.setUp();
    }

    /// @notice Test proving a single claim successfully
    function test_prove_single_claim() public {
        setupBlobHashes();
        
        // Setup and submit proposal
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = submitProposal(proposalId, Alice);
        
        // Prove the proposal
        bytes32 parentClaimHash = bytes32(uint256(999));
        IInbox.Claim memory claim = proveProposal(proposal, Bob, parentClaimHash);
        
        // Verify claim record is stored
        assertClaimRecordStored(proposalId, parentClaimHash);
    }

    /// @notice Test proving multiple claims in one transaction
    function test_prove_multiple_claims() public {
        setupBlobHashes();
        uint48 numClaims = 3;
        
        // Submit all proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numClaims);
        for (uint48 i = 0; i < numClaims; i++) {
            proposals[i] = submitProposal(i + 1, Alice);
        }
        
        // Create claims with different parent hashes
        IInbox.Claim[] memory claims = new IInbox.Claim[](numClaims);
        for (uint48 i = 0; i < numClaims; i++) {
            claims[i] = InboxTestUtils.createClaim(proposals[i], bytes32(uint256(i * 100)), Bob);
        }
        
        // Prove all claims at once
        setupStandardProofMocks(true);
        vm.prank(Bob);
        inbox.prove(InboxTestUtils.encodeProveData(proposals, claims), bytes("valid_proof"));
        
        // Verify all claim records are stored
        for (uint48 i = 0; i < numClaims; i++) {
            assertClaimRecordStored(i + 1, bytes32(uint256(i * 100)));
        }
    }

    /// @notice Test proving claims for sequential proposals
    function test_prove_sequential_proposals() public {
        setupBlobHashes();
        uint48 startId = 5;
        uint48 count = 4;
        bytes32 initialParentHash = bytes32(uint256(1000));
        
        // Create and prove chain of proposals
        (IInbox.Proposal[] memory proposals, IInbox.Claim[] memory claims) = 
            createProvenChain(startId, count, initialParentHash);
        
        // Verify the chain is stored correctly
        bytes32 parentHash = initialParentHash;
        for (uint48 i = 0; i < count; i++) {
            assertClaimRecordStored(startId + i, parentHash);
            parentHash = InboxTestUtils.hashClaim(claims[i]);
        }
    }

    /// @notice Test that proof verification is called with correct parameters
    function test_prove_verification_called() public {
        setupBlobHashes();
        
        // Submit proposal
        IInbox.Proposal memory proposal = submitProposal(1, Alice);
        
        // Create claim
        IInbox.Claim memory claim = InboxTestUtils.createClaim(proposal, bytes32(0), Bob);
        
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;
        
        // Calculate expected claims hash
        bytes32 expectedClaimsHash = keccak256(abi.encode(claims));
        bytes memory proof = bytes("test_proof_data");
        
        // Expect verifyProof to be called with correct parameters
        vm.expectCall(
            proofVerifier,
            abi.encodeWithSelector(IProofVerifier.verifyProof.selector, expectedClaimsHash, proof)
        );
        
        // Submit proof
        setupStandardProofMocks(true);
        vm.prank(Bob);
        inbox.prove(InboxTestUtils.encodeProveData(proposals, claims), proof);
    }

    /// @notice Test claim record storage and retrieval
    function test_prove_claim_record_storage() public {
        setupBlobHashes();
        uint48 numProposals = 3;
        
        // Submit and prove multiple proposals with different parent hashes
        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.Proposal memory proposal = submitProposal(i, Alice);
            
            // Create multiple claims per proposal
            for (uint256 j = 0; j < 2; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j));
                proveProposal(proposal, Bob, parentClaimHash);
                
                // Verify storage immediately
                assertClaimRecordStored(i, parentClaimHash);
            }
        }
        
        // Verify all records are still accessible
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < 2; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j));
                assertClaimRecordStored(i, parentClaimHash);
            }
        }
    }

    /// @notice Test proving with invalid proof reverts
    function test_prove_invalid_proof_reverts() public {
        setupBlobHashes();
        
        // Submit proposal
        IInbox.Proposal memory proposal = submitProposal(1, Alice);
        
        // Create claim
        IInbox.Claim memory claim = InboxTestUtils.createClaim(proposal, bytes32(0), Bob);
        
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;
        
        // Mock proof verification to fail
        setupStandardProofMocks(false);
        
        // Submit proof - should revert
        vm.expectRevert("Invalid proof");
        vm.prank(Bob);
        inbox.prove(InboxTestUtils.encodeProveData(proposals, claims), bytes("invalid_proof"));
    }

}

