// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxRingBufferOverflow
/// @notice Tests handling of more proposals than ring buffer size with persistent claim storage
/// @dev Demonstrates proper finalization to handle ring buffer overflow scenarios
contract InboxRingBufferOverflow is ShastaInboxTestBase {
    // Storage for claims to persist across transactions
    mapping(uint48 => IInbox.Claim) private storedClaims;
    mapping(uint48 => bytes32) private storedParentHashes;
    mapping(uint48 => IInbox.ClaimRecord) private storedClaimRecords;
    
    /// @notice Test processing more proposals than ring buffer size
    /// @dev Creates and processes 150 proposals with a ring buffer size of 100
    ///      Each proposal is proposed and proved by different addresses
    ///      Demonstrates finalization to free up ring buffer slots
    /* function test_ring_buffer_overflow_with_finalization() public {
        // Configuration
        uint48 totalProposals = 150; // More than default ring buffer size (100)
        uint48 batchSize = 10; // Process in batches
        uint48 currentProposalId = 1;
        uint48 lastFinalizedId = 0;
        bytes32 lastFinalizedClaimHash = createCoreState(1, 0).lastFinalizedClaimHash;
        
        // Process proposals in batches
        for (uint48 batch = 0; batch < totalProposals / batchSize; batch++) {
            // Phase 1: Propose a batch
            IInbox.Proposal[] memory batchProposals = new IInbox.Proposal[](batchSize);
            
            for (uint48 i = 0; i < batchSize; i++) {
                // Check if we need to finalize to make room
                uint48 unfinalizedCount = currentProposalId - lastFinalizedId - 1;
                
                // Each proposal gets a unique proposer
                address proposer = getUniqueProposer(currentProposalId);
                
                // Setup core state for proposal
                IInbox.CoreState memory coreState = IInbox.CoreState({
                    nextProposalId: currentProposalId,
                    lastFinalizedProposalId: lastFinalizedId,
                    lastFinalizedClaimHash: lastFinalizedClaimHash,
                    bondOperationsHash: bytes32(0)
                });
                
                // If approaching capacity, include finalization data
                IInbox.ClaimRecord[] memory claimRecords;
                if (unfinalizedCount >= defaultConfig.ringBufferSize - 10 && lastFinalizedId > 0) {
                    // Determine how many we can finalize
                    uint48 numToFinalize = 0;
                    for (uint48 j = 0; j < batchSize; j++) {
                        uint48 proposalToCheck = lastFinalizedId + j + 1;
                        if (proposalToCheck >= currentProposalId) break;
                        if (storedClaims[proposalToCheck].proposalHash != bytes32(0)) {
                            numToFinalize++;
                        } else {
                            break; // Stop at first unproven proposal
                        }
                    }
                    
                    if (numToFinalize > 0) {
                        claimRecords = new IInbox.ClaimRecord[](numToFinalize);
                        
                        for (uint48 j = 0; j < numToFinalize; j++) {
                            uint48 proposalToFinalize = lastFinalizedId + j + 1;
                            // Use the stored claim record
                            claimRecords[j] = storedClaimRecords[proposalToFinalize];
                        }
                        
                        // Update finalization tracking
                        lastFinalizedId = lastFinalizedId + numToFinalize;
                        lastFinalizedClaimHash = keccak256(abi.encode(storedClaims[lastFinalizedId]));
                        coreState.lastFinalizedProposalId = lastFinalizedId;
                        coreState.lastFinalizedClaimHash = lastFinalizedClaimHash;
                    } else {
                        claimRecords = new IInbox.ClaimRecord[](0);
                    }
                } else {
                    claimRecords = new IInbox.ClaimRecord[](0);
                }
                
                // Submit proposal
                inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
                setupStandardProposerMocks(proposer);
                
                LibBlobs.BlobReference memory blobRef = createValidBlobReference(currentProposalId);
                bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, claimRecords);
                
                vm.prank(proposer);
                inbox.propose(bytes(""), proposeData);
                
                // Store the proposal
                batchProposals[i] = reconstructProposal(currentProposalId, proposer, blobRef);
                currentProposalId++;
            }
            
            // Phase 2: Prove the batch
            bytes32 parentClaimHash = batch == 0 ? 
                createCoreState(1, 0).lastFinalizedClaimHash : 
                storedParentHashes[currentProposalId - batchSize - 1];
            
            for (uint48 i = 0; i < batchSize; i++) {
                uint48 proposalId = currentProposalId - batchSize + i;
                IInbox.Proposal memory proposal = batchProposals[i];
                
                // Each proof gets a unique prover (different from proposer)
                address prover = getUniqueProver(proposalId);
                
                // Create and store claim
                IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);
                claim.proposalHash = inbox.getProposalHash(proposalId);
                claim.endBlockNumber = uint32(1000 + proposalId * 10);
                claim.actualProver = prover;
                claim.designatedProver = proposal.proposer;
                
                // Store in persistent storage
                storedClaims[proposalId] = claim;
                storedParentHashes[proposalId] = parentClaimHash;
                
                // Also store the claim record for finalization
                storedClaimRecords[proposalId] = IInbox.ClaimRecord({
                    claim: claim,
                    proposer: proposal.proposer,
                    livenessBondGwei: 0,
                    provabilityBondGwei: 0,
                    nextProposalId: proposalId + 1,
                    bondDecision: IInbox.BondDecision.NoOp
                });
                
                // Submit proof
                mockProofVerification(true);
                IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
                proposals[0] = proposal;
                IInbox.Claim[] memory claims = new IInbox.Claim[](1);
                claims[0] = claim;
                
                vm.prank(prover);
                inbox.prove(encodeProveData(proposals, claims), bytes("proof"));
                
                // Update parent for next
                parentClaimHash = keccak256(abi.encode(claim));
            }
            
            // Advance time for next batch
            vm.warp(block.timestamp + defaultConfig.provingWindow + 1);
        }
        
        // Verify we processed all proposals
        assertTrue(currentProposalId > totalProposals, "Should have processed all proposals");
        
        // Verify proposals are proven (spot check)
        for (uint48 i = 1; i <= 10; i++) {
            bytes32 claimRecordHash = inbox.getClaimRecordHash(i, storedParentHashes[i]);
            assertTrue(claimRecordHash != bytes32(0), string(abi.encodePacked("Proposal ", i, " should be proven")));
        }
    } */
    
    /// @notice Helper to reconstruct proposal after submission
    function reconstructProposal(
        uint48 _proposalId,
        address _proposer,
        LibBlobs.BlobReference memory _blobRef
    ) 
        private 
        view 
        returns (IInbox.Proposal memory) 
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", _blobRef.blobStartIndex));
        
        return IInbox.Proposal({
            id: _proposalId,
            proposer: _proposer,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
            provabilityBondGwei: defaultConfig.provabilityBondGwei,
            livenessBondGwei: defaultConfig.livenessBondGwei,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: _blobRef.offset,
                timestamp: uint48(block.timestamp)
            })
        });
    }
    
    /// @notice Test that demonstrates the ring buffer size limit without finalization
    function test_ring_buffer_capacity_limit() public {
        // Use smaller ring buffer for demonstration
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 10; // Capacity = 9 unfinalized proposals
        inbox.setConfig(config);
        
        // Successfully create 9 proposals (up to capacity)
        for (uint48 i = 1; i <= 9; i++) {
            // Each proposal gets a unique proposer
            address proposer = getUniqueProposer(i);
            IInbox.Proposal memory proposal = submitStandardProposal(
                proposer,
                i,
                0, // No finalization
                createCoreState(1, 0).lastFinalizedClaimHash
            );
            
            // Verify stored
            assertTrue(inbox.getProposalHash(i) != bytes32(0), "Proposal should be stored");
        }
        
        // Attempt to create 10th proposal without finalization should fail
        address proposer10 = getUniqueProposer(10);
        IInbox.CoreState memory coreState = createCoreState(10, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        setupStandardProposerMocks(proposer10);
        
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(10);
        IInbox.ClaimRecord[] memory emptyRecords = new IInbox.ClaimRecord[](0);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, emptyRecords);
        
        vm.expectRevert(InboxBase.ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(proposer10);
        inbox.propose(bytes(""), proposeData);
    }
    
    /// @notice Helper to get unique proposer address for each proposal
    function getUniqueProposer(uint48 proposalId) private pure returns (address) {
        // Generate unique addresses for proposers
        return address(uint160(0x10000 + proposalId));
    }
    
    /// @notice Helper to get unique prover address for each proposal
    function getUniqueProver(uint48 proposalId) private pure returns (address) {
        // Generate unique addresses for provers (different from proposers)
        return address(uint160(0x20000 + proposalId));
    }
}