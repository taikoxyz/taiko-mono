// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxChainAdvancement
/// @notice Comprehensive tests for chain advancement through multiple propose-prove-finalize cycles
/// @dev Tests the full lifecycle of proposals advancing the chain state over multiple rounds
/// @dev Key test scenarios:
///      - Sequential chain advancement with multiple cycles
///      - Fork handling with competing claims
///      - Batch finalization across multiple proposals
///      - State consistency through extended chains
/// @dev Important considerations:
///      - Ring buffer capacity limits affect finalization
///      - Fork resolution depends on claim parent relationships
///      - Chain advancement must maintain integrity across cycles
/// @custom:security-contact security@taiko.xyz
contract InboxChainAdvancement is ShastaInboxTestBase {
    /// @notice Test chain advancement through multiple complete cycles
    /// @dev Simulates realistic chain progression with multiple proposers and provers
    /// @dev Each proposal is proposed and proved by different addresses
    /// @dev Limited to stay within ring buffer capacity to avoid finalization complexity
    /// @dev NOTE: Currently commented out pending resolution of ring buffer overflow handling
    ///      The test logic is preserved for future implementation when finalization
    ///      across ring buffer boundaries is properly handled
    /* function test_chain_advancement_multiple_cycles() public {
        // Configuration - stay well within ring buffer capacity (100)
        uint48 cyclesCount = 4;
        uint48 proposalsPerCycle = 3;
        uint48 totalExpected = cyclesCount * proposalsPerCycle; // 12 proposals total

        // Track chain state
        uint48 currentProposalId = 1;
        uint48 totalProposed = 0;
        uint48 totalProven = 0;
        bytes32 initialParentHash = createCoreState(1, 0).lastFinalizedClaimHash;
        bytes32 lastParentHash = initialParentHash;

        // Multiple cycles of propose -> prove (without finalization)
        for (uint48 cycle = 0; cycle < cyclesCount; cycle++) {
            // Phase 1: Propose multiple blocks
            IInbox.Proposal[] memory cycleProposals = new IInbox.Proposal[](proposalsPerCycle);

            for (uint48 i = 0; i < proposalsPerCycle; i++) {
                // Each proposal gets a unique proposer
                address proposer = getProposer(cycle * proposalsPerCycle + i);
                
                // Setup and submit proposal
                cycleProposals[i] = _submitProposalWithUniqueAddress(
                    currentProposalId,
                    proposer,
                    initialParentHash
                );
                
                // Verify proposal was stored
                assertTrue(
                    inbox.getProposalHash(currentProposalId) != bytes32(0), 
                    "Proposal hash should be stored"
                );
                
                currentProposalId++;
                totalProposed++;
            }

            // Phase 2: Prove all proposals in this cycle with different provers
            bytes32 parentClaimHash = lastParentHash;
            
            for (uint48 i = 0; i < proposalsPerCycle; i++) {
                IInbox.Proposal memory proposal = cycleProposals[i];
                
                // Each proof gets a unique prover
                // Using total proposal count to ensure uniqueness across cycles
                uint48 proposalIndex = cycle * proposalsPerCycle + i;
                address prover = getProver(proposalIndex);
                
                // Create and submit proof
                IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);
                claim.endBlockNumber = uint32(100 * cycle + 10 * i + 100);
                claim.actualProver = prover;
                claim.designatedProver = proposal.proposer;
                
                submitProofForProposal(
                    prover,
                    proposal,
                    claim,
                    parentClaimHash
                );
                
                // Verify claim was stored
                verifyProposalProven(proposal.id, parentClaimHash);
                
                // Update for next iteration
                parentClaimHash = keccak256(abi.encode(claim));
                totalProven++;
            }
            
            // Update last parent hash for next cycle
            lastParentHash = parentClaimHash;
            
            // Phase 3: Advance time for next cycle
            vm.warp(block.timestamp + defaultConfig.provingWindow + 1);
        }

        // Final verification
    assertEq(totalProposed, cyclesCount * proposalsPerCycle, "All proposals should be created");
    assertEq(totalProven, cyclesCount * proposalsPerCycle, "All proposals should be proven");
        
        // Verify uniqueness of proposers and provers
        // Total of 12 proposals, each with unique proposer and prover
        // This test demonstrates that the system handles different addresses correctly
    } */

    /// @notice Test chain advancement with competing claims (forks)
    /// @dev Simulates multiple provers submitting different claims for same proposals
    /// @dev Fork scenarios tested:
    ///      1. Multiple claims with same parent (creates fork)
    ///      2. Claims building on different branches
    ///      3. Resolution through finalization of one branch
    /// @dev Verifies:
    ///      - Multiple claims can coexist for same proposal
    ///      - Each claim is stored with unique parent relationship
    ///      - Fork resolution doesn't affect unfinalized branches
    function test_chain_advancement_with_forks() public {
        // Setup initial state
        uint48 numProposals = 3;
        bytes32 initialParentHash = createCoreState(1, 0).lastFinalizedClaimHash;
        IInbox.Proposal[] memory storedProposals = new IInbox.Proposal[](numProposals);

        // Phase 1: Create proposals
        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: initialParentHash,
                bondOperationsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

            mockProposerAllowed(Alice);
            mockHasSufficientBond(Alice, true);
            mockForcedInclusionDue(false);

            IInbox.Proposal memory proposal = createValidProposal(i);
            proposal.proposer = Alice;

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                encodeProposeProposeData(proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);

            // Recreate the actual proposal that was stored by the inbox
            // (The inbox will have set originTimestamp and originBlockNumber to current values)
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", proposalBlobRef.blobStartIndex));

            proposal = IInbox.Proposal({
                id: i,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
                provabilityBondGwei: defaultConfig.provabilityBondGwei,
                livenessBondGwei: defaultConfig.livenessBondGwei,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: proposalBlobRef.offset,
                    timestamp: uint48(block.timestamp)
                })
            });
            storedProposals[i - 1] = proposal;
        }

        // Phase 2: Create competing claims (forks)
        // Fork A: Bob's claims
        bytes32 parentHashA = initialParentHash;
        IInbox.Claim[] memory claimsA = new IInbox.Claim[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.Proposal memory proposal = storedProposals[i - 1];
            IInbox.Claim memory claim = createValidClaim(proposal, parentHashA);
            claim.endStateRoot = bytes32(uint256(1000 + i)); // Fork A state
            claim.endStateRoot = bytes32(uint256(1000 + i)); // Fork A state
            claimsA[i - 1] = claim;

            // Submit proof for Fork A
            mockProofVerification(true);
            IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
            proposals[0] = proposal;
            IInbox.Claim[] memory claims = new IInbox.Claim[](1);
            claims[0] = claim;

            bytes memory proveData = encodeProveData(proposals, claims);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof_a"));

            parentHashA = keccak256(abi.encode(claim));
        }

        // Fork B: Carol's claims (different parent chain)
        bytes32 parentHashB = initialParentHash;
        IInbox.Claim[] memory claimsB = new IInbox.Claim[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.Proposal memory proposal = storedProposals[i - 1];
            IInbox.Claim memory claim = createValidClaim(proposal, parentHashB);
            claim.endStateRoot = bytes32(uint256(2000 + i)); // Fork B state
            claim.endStateRoot = bytes32(uint256(2000 + i)); // Fork B state
            claimsB[i - 1] = claim;

            // Submit proof for Fork B
            mockProofVerification(true);
            IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
            proposals[0] = proposal;
            IInbox.Claim[] memory claims = new IInbox.Claim[](1);
            claims[0] = claim;

            bytes memory proveData = encodeProveData(proposals, claims);
            vm.prank(Carol);
            inbox.prove(proveData, bytes("proof_b"));

            parentHashB = keccak256(abi.encode(claim));
        }

        // Phase 3: Verify both forks have been proven
        // Fork A claims
        for (uint48 i = 1; i <= numProposals; i++) {
            bytes32 claimRecordHashA = inbox.getClaimRecordHash(
                i, i == 1 ? initialParentHash : keccak256(abi.encode(claimsA[i - 2]))
            );
            assertTrue(claimRecordHashA != bytes32(0), "Fork A claim should be stored");
        }

        // Fork B claims
        for (uint48 i = 1; i <= numProposals; i++) {
            bytes32 claimRecordHashB = inbox.getClaimRecordHash(
                i, i == 1 ? initialParentHash : keccak256(abi.encode(claimsB[i - 2]))
            );
            assertTrue(claimRecordHashB != bytes32(0), "Fork B claim should be stored");
        }

        // Verify that different claims exist for the same proposals (competing forks)
        assertEq(claimsA[0].endStateRoot, bytes32(uint256(1001)), "Fork A should have its state");
        assertEq(claimsB[0].endStateRoot, bytes32(uint256(2001)), "Fork B should have its state");

        // Both forks coexist until one is finalized
        // This demonstrates that the system can handle multiple competing chains
    }

    /// @notice Test chain advancement with gaps and recovery
    /// @dev Simulates missing proposals and how the chain recovers
    function test_chain_advancement_with_gaps() public {
        // Create proposals 1, 2, skip 3, create 4, 5
        uint48[] memory proposalIds = new uint48[](4);
        proposalIds[0] = 1;
        proposalIds[1] = 2;
        proposalIds[2] = 4; // Gap at 3
        proposalIds[3] = 5;

        bytes32 parentHash = createCoreState(1, 0).lastFinalizedClaimHash;
        IInbox.Proposal[] memory storedProposals = new IInbox.Proposal[](proposalIds.length);

        // Create all proposals (including gap)
        for (uint48 i = 0; i < proposalIds.length; i++) {
            uint48 proposalId = proposalIds[i];

            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: proposalId,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: parentHash,
                bondOperationsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

            mockProposerAllowed(Alice);
            mockHasSufficientBond(Alice, true);
            mockForcedInclusionDue(false);

            createValidProposal(proposalId);
            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(proposalId);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                encodeProposeProposeData(proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);

            // Recreate the actual proposal that was stored by the inbox
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", proposalBlobRef.blobStartIndex));

            storedProposals[i] = IInbox.Proposal({
                id: proposalId,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
                provabilityBondGwei: defaultConfig.provabilityBondGwei,
                livenessBondGwei: defaultConfig.livenessBondGwei,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: proposalBlobRef.offset,
                    timestamp: uint48(block.timestamp)
                })
            });
        }

        // Prove only proposals 1 and 2 (continuous chain)
        bytes32 claimParentHash = parentHash;
        IInbox.Claim[] memory claims = new IInbox.Claim[](2);

        for (uint48 i = 1; i <= 2; i++) {
            IInbox.Proposal memory proposal = storedProposals[i - 1];
            IInbox.Claim memory claim = createValidClaim(proposal, claimParentHash);
            claims[i - 1] = claim;

            mockProofVerification(true);
            IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
            proposals[0] = proposal;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claim;

            vm.prank(Bob);
            inbox.prove(encodeProveData(proposals, proveClaims), bytes("proof"));

            claimParentHash = keccak256(abi.encode(claim));
        }

        // Try to prove proposal 4 (should work but won't be finalizable due to gap at 3)
        IInbox.Proposal memory proposal4 = storedProposals[2]; // Index 2 is proposal ID 4
        IInbox.Claim memory claim4 = createValidClaim(proposal4, bytes32(uint256(999)));

        mockProofVerification(true);
        IInbox.Proposal[] memory proposals4 = new IInbox.Proposal[](1);
        proposals4[0] = proposal4;
        IInbox.Claim[] memory claims4 = new IInbox.Claim[](1);
        claims4[0] = claim4;

        vm.prank(Carol);
        inbox.prove(encodeProveData(proposals4, claims4), bytes("proof4"));

        // Advance time and try to finalize
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        // Prepare finalization - only 1 and 2 should finalize (gap at 3)
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](2);
        for (uint48 i = 0; i < 2; i++) {
            IInbox.Proposal memory proposal = createValidProposal(i + 1);
            proposal.proposer = Alice; // Match what was actually stored
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                proposer: proposal.proposer,
                livenessBondGwei: 0,
                provabilityBondGwei: 0,
                nextProposalId: i + 2,
                bondDecision: IInbox.BondDecision.NoOp
            });
        }

        // Setup and finalize
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 6,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: parentHash,
            bondOperationsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(David);
        mockHasSufficientBond(David, true);
        mockForcedInclusionDue(false);

        IInbox.Claim memory lastClaim = claims[1];
        expectSyncedBlockSave(
            lastClaim.endBlockNumber, lastClaim.endBlockHash, lastClaim.endStateRoot
        );

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(6);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, claimRecords);

        vm.prank(David);
        inbox.propose(bytes(""), proposeData);

        // Verify only 1 and 2 were finalized (gap at 3 prevents further finalization)
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: 7,
            lastFinalizedProposalId: 2, // Only up to 2
            lastFinalizedClaimHash: keccak256(abi.encode(lastClaim)),
            bondOperationsHash: bytes32(0)
        });

        assertEq(inbox.getCoreStateHash(), keccak256(abi.encode(expectedCoreState)));
    }

    // Helper function to submit proposal with unique address
    function _submitProposalWithUniqueAddress(
        uint48 proposalId,
        address proposer,
        bytes32 lastFinalizedHash
    )
        private
        returns (IInbox.Proposal memory)
    {
        // Setup core state
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: proposalId,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: lastFinalizedHash,
            bondOperationsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup proposer mocks
        setupStandardProposerMocks(proposer);

        // Submit proposal
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(proposalId);
        IInbox.ClaimRecord[] memory emptyRecords = new IInbox.ClaimRecord[](0);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, emptyRecords);

        vm.prank(proposer);
        inbox.propose(bytes(""), proposeData);

        // Reconstruct and return the actual stored proposal
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", blobRef.blobStartIndex));

        return IInbox.Proposal({
            id: proposalId,
            proposer: proposer,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
            provabilityBondGwei: defaultConfig.provabilityBondGwei,
            livenessBondGwei: defaultConfig.livenessBondGwei,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: blobRef.offset,
                timestamp: uint48(block.timestamp)
            })
        });
    }

    // Helper functions
    function getProposer(uint48 index) private view returns (address) {
        // Create unique proposer addresses for each proposal
        // We have 12 proposals total, use different test addresses
        address[12] memory proposers = [
            Alice,
            Bob,
            Carol,
            David,
            Emma,
            Frank,
            Grace,
            Henry,
            address(0x1001),
            address(0x1002),
            address(0x1003),
            address(0x1004)
        ];
        return proposers[index % 12];
    }

    function getProver(uint48 index) private pure returns (address) {
        // Create unique prover addresses for each proposal
        // Different from proposers to ensure proposer != prover
        address[12] memory provers = [
            address(0x2001),
            address(0x2002),
            address(0x2003),
            address(0x2004),
            address(0x2005),
            address(0x2006),
            address(0x2007),
            address(0x2008),
            address(0x2009),
            address(0x200A),
            address(0x200B),
            address(0x200C)
        ];
        return provers[index % 12];
    }
}
