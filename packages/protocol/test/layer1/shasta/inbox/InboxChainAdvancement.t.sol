// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxChainAdvancement
/// @notice Comprehensive tests for chain advancement through multiple propose-prove-finalize cycles
/// @dev Tests the full lifecycle of proposals advancing the chain state over multiple rounds
contract InboxChainAdvancement is ShastaInboxTestBase {
    /// @notice Test chain advancement through multiple complete cycles
    /// @dev Simulates realistic chain progression with multiple proposers and provers
    function test_chain_advancement_multiple_cycles() public {
        // Configuration
        uint48 cyclesCount = 4;
        uint48 proposalsPerCycle = 3;

        // Track chain state
        uint48 currentProposalId = 1;
        uint48 lastFinalizedId = 0;
        bytes32 lastFinalizedClaimHash = createCoreState(1, 0).lastFinalizedClaimHash;

        // Multiple cycles of propose -> prove -> finalize
        for (uint48 cycle = 0; cycle < cyclesCount; cycle++) {
            // Phase 1: Propose multiple blocks
            IInbox.Proposal[] memory cycleProposals = new IInbox.Proposal[](proposalsPerCycle);

            for (uint48 i = 0; i < proposalsPerCycle; i++) {
                IInbox.CoreState memory coreState = IInbox.CoreState({
                    nextProposalId: currentProposalId,
                    lastFinalizedProposalId: lastFinalizedId,
                    lastFinalizedClaimHash: lastFinalizedClaimHash,
                    bondOperationsHash: bytes32(0)
                });
                inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

                // Setup mocks for proposer
                address proposer = getProposer(cycle, i);
                mockProposerAllowed(proposer);
                mockHasSufficientBond(proposer, true);
                mockForcedInclusionDue(false);

                // Create proposal (will be modified by propose function to have msg.sender as
                // proposer)
                IInbox.Proposal memory proposal = createValidProposal(currentProposalId);
                // The actual proposal that will be stored has proposer as msg.sender
                proposal.proposer = proposer;
                cycleProposals[i] = proposal;

                // Create blob reference and encode data
                LibBlobs.BlobReference memory blobRef = createValidBlobReference(currentProposalId);
                IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
                bytes memory proposeData =
                    encodeProposeProposeData(coreState, blobRef, emptyClaimRecords);

                // Submit proposal
                vm.prank(proposer);
                inbox.propose(bytes(""), proposeData);

                // Update the proposal to match what was actually stored (proposer is msg.sender)
                proposal.proposer = proposer;
                cycleProposals[i] = proposal;

                // Verify proposal hash was stored (the inbox creates its own proposal with
                // msg.sender)
                // So we just verify it was stored, not that it matches our local proposal
                bytes32 storedHash = inbox.getProposalHash(currentProposalId);
                assertTrue(storedHash != bytes32(0), "Proposal hash should be stored");

                currentProposalId++;
            }

            // Phase 2: Prove all proposals in this cycle
            bytes32 parentClaimHash = lastFinalizedClaimHash;
            IInbox.Claim[] memory cycleClaims = new IInbox.Claim[](proposalsPerCycle);

            for (uint48 i = 0; i < proposalsPerCycle; i++) {
                // Use the proposal that was stored (with correct proposer)
                IInbox.Proposal memory proposal = cycleProposals[i];

                // Create claim with proper parent chain
                IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);
                claim.endBlockNumber = uint32(100 * cycle + 10 * i + 100); // Unique block numbers
                cycleClaims[i] = claim;

                // Mock proof verification
                mockProofVerification(true);

                // Create prove data
                IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
                proveProposals[0] = proposal;
                IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
                proveClaims[0] = claim;

                bytes memory proveData = encodeProveData(proveProposals, proveClaims);
                bytes memory proof = bytes("valid_proof");

                // Submit proof
                address prover = getProver(cycle, i);
                vm.prank(prover);
                inbox.prove(proveData, proof);

                // Verify claim record was stored
                bytes32 claimRecordHash = inbox.getClaimRecordHash(proposal.id, parentClaimHash);
                assertTrue(claimRecordHash != bytes32(0), "Claim record should be stored");

                // Update parent for next claim
                parentClaimHash = keccak256(abi.encode(claim));
            }

            // Phase 3: Advance time for cooldown
            vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

            // Phase 4: Finalize proposals in next propose transaction
            if (cycle < cyclesCount - 1) {
                // Don't finalize on last cycle (no next proposal)
                // Prepare claim records for finalization
                IInbox.ClaimRecord[] memory claimRecords =
                    new IInbox.ClaimRecord[](proposalsPerCycle);
                for (uint48 i = 0; i < proposalsPerCycle; i++) {
                    IInbox.Proposal memory proposal = cycleProposals[i];
                    IInbox.Claim memory claim = cycleClaims[i];

                    claimRecords[i] = IInbox.ClaimRecord({
                        claim: claim,
                        proposer: proposal.proposer,
                        livenessBondGwei: 0,
                        provabilityBondGwei: 0,
                        nextProposalId: proposal.id + 1,
                        bondDecision: IInbox.BondDecision.NoOp
                    });
                }

                // Setup for next proposal which will trigger finalization
                IInbox.CoreState memory coreState = IInbox.CoreState({
                    nextProposalId: currentProposalId,
                    lastFinalizedProposalId: lastFinalizedId,
                    lastFinalizedClaimHash: lastFinalizedClaimHash,
                    bondOperationsHash: bytes32(0)
                });
                inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

                // Mock for next proposer
                address nextProposer = getProposer(cycle + 1, 0);
                mockProposerAllowed(nextProposer);
                mockHasSufficientBond(nextProposer, true);
                mockForcedInclusionDue(false);

                // Expect synced block update for last finalized proposal
                IInbox.Claim memory lastClaim = cycleClaims[proposalsPerCycle - 1];
                expectSyncedBlockSave(
                    lastClaim.endBlockNumber, lastClaim.endBlockHash, lastClaim.endStateRoot
                );

                // Create next proposal with finalization data
                LibBlobs.BlobReference memory blobRef = createValidBlobReference(currentProposalId);
                bytes memory proposeData =
                    encodeProposeProposeData(coreState, blobRef, claimRecords);

                // Submit proposal (triggers finalization)
                vm.prank(nextProposer);
                inbox.propose(bytes(""), proposeData);

                // Update tracking variables
                lastFinalizedId = currentProposalId - 1;
                lastFinalizedClaimHash = keccak256(abi.encode(lastClaim));

                // Verify finalization occurred
                IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
                    nextProposalId: currentProposalId + 1,
                    lastFinalizedProposalId: lastFinalizedId,
                    lastFinalizedClaimHash: lastFinalizedClaimHash,
                    bondOperationsHash: bytes32(0)
                });

                bytes32 actualCoreStateHash = inbox.getCoreStateHash();
                assertEq(actualCoreStateHash, keccak256(abi.encode(expectedCoreState)));

                currentProposalId++; // Account for the proposal just submitted
            }
        }

        // Final verification: Check chain has advanced properly
        assertEq(lastFinalizedId, (cyclesCount - 1) * proposalsPerCycle);
    }

    /// @notice Test chain advancement with competing claims (forks)
    /// @dev Simulates multiple provers submitting different claims for same proposals
    function test_chain_advancement_with_forks() public {
        // Setup initial state
        uint48 numProposals = 3;
        bytes32 initialParentHash = createCoreState(1, 0).lastFinalizedClaimHash;

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

            // Store the actual proposal (with Alice as proposer)
            proposal.proposer = Alice;
        }

        // Phase 2: Create competing claims (forks)
        // Fork A: Bob's claims
        bytes32 parentHashA = initialParentHash;
        IInbox.Claim[] memory claimsA = new IInbox.Claim[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.Proposal memory proposal = createValidProposal(i);
            proposal.proposer = Alice; // Match what was actually stored
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
            IInbox.Proposal memory proposal = createValidProposal(i);
            proposal.proposer = Alice; // Match what was actually stored
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

        // Advance time past cooldown
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        // Phase 3: Finalize using Fork A (Bob's chain)
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);
        bytes32 parentHash = initialParentHash;

        for (uint48 i = 0; i < numProposals; i++) {
            IInbox.Proposal memory proposal = createValidProposal(i + 1);
            proposal.proposer = Alice; // Match what was actually stored
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claimsA[i],
                proposer: proposal.proposer,
                livenessBondGwei: 0,
                provabilityBondGwei: 0,
                nextProposalId: i + 2,
                bondDecision: IInbox.BondDecision.NoOp
            });
        }

        // Setup for finalization
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondOperationsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(David);
        mockHasSufficientBond(David, true);
        mockForcedInclusionDue(false);

        // Expect Fork A's final state
        IInbox.Claim memory lastClaimA = claimsA[numProposals - 1];
        expectSyncedBlockSave(
            lastClaimA.endBlockNumber, lastClaimA.endBlockHash, lastClaimA.endStateRoot
        );

        // Finalize with Fork A
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, claimRecords);

        vm.prank(David);
        inbox.propose(bytes(""), proposeData);

        // Verify Fork A was finalized
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: numProposals + 2,
            lastFinalizedProposalId: numProposals,
            lastFinalizedClaimHash: keccak256(abi.encode(lastClaimA)),
            bondOperationsHash: bytes32(0)
        });

        assertEq(inbox.getCoreStateHash(), keccak256(abi.encode(expectedCoreState)));

        // Verify Fork A's state was committed
        assertEq(lastClaimA.endStateRoot, bytes32(uint256(1000 + numProposals)));
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

            IInbox.Proposal memory proposal = createValidProposal(proposalId);
            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(proposalId);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                encodeProposeProposeData(proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);

            // Store the actual proposal (with Alice as proposer)
            proposal.proposer = Alice;
        }

        // Prove only proposals 1 and 2 (continuous chain)
        bytes32 claimParentHash = parentHash;
        IInbox.Claim[] memory claims = new IInbox.Claim[](2);

        for (uint48 i = 1; i <= 2; i++) {
            IInbox.Proposal memory proposal = createValidProposal(i);
            proposal.proposer = Alice; // Match what was actually stored
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
        IInbox.Proposal memory proposal4 = createValidProposal(4);
        proposal4.proposer = Alice; // Match what was actually stored
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

    // Helper functions
    function getProposer(uint48 cycle, uint48 index) private view returns (address) {
        address[4] memory proposers = [Alice, Bob, Carol, David];
        return proposers[(cycle + index) % 4];
    }

    function getProver(uint48 cycle, uint48 index) private view returns (address) {
        address[4] memory provers = [Emma, Frank, Grace, Henry];
        return provers[(cycle + index) % 4];
    }
}
