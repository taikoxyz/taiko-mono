// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxOutOfOrderProving
/// @notice Tests for out-of-order proving and eventual chain advancement
/// @dev Verifies that proposals can be proven in any order but finalization respects sequence
contract InboxOutOfOrderProving is ShastaInboxTestBase {
    /// @notice Test proving proposals out of order with eventual finalization
    /// @dev Proves proposals in reverse order, then verifies correct finalization sequence
    function test_prove_out_of_order_then_finalize() public {
        uint48 numProposals = 5;
        bytes32 initialParentHash = createCoreState(1, 0).lastFinalizedClaimHash;

        // Phase 1: Create multiple proposals sequentially
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

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
            proposal.proposer = Alice; // This will be the actual proposer since we prank as Alice
            proposals[i - 1] = proposal;

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                encodeProposeProposeData(proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);

            // Verify proposal was stored (inbox stores with actual msg.sender)
            bytes32 storedHash = inbox.getProposalHash(i);
            assertTrue(storedHash != bytes32(0), "Proposal hash should be stored");
        }

        // Phase 2: Prove proposals in REVERSE order (5, 4, 3, 2, 1)
        bytes32[] memory claimHashes = new bytes32[](numProposals);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);

        // First, calculate all claim hashes in forward order (for parent relationships)
        bytes32 parentHash = initialParentHash;
        for (uint48 i = 0; i < numProposals; i++) {
            // Get the actual stored proposal hash
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            IInbox.Claim memory claim = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: parentHash,
                endBlockNumber: uint32(100 + i * 10),
                endBlockHash: keccak256(abi.encode(proposals[i].id, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(proposals[i].id, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });
            claim.endBlockNumber = uint32(100 + i * 10);
            claims[i] = claim;
            claimHashes[i] = keccak256(abi.encode(claim));
            parentHash = claimHashes[i];
        }

        // Now prove them in reverse order
        for (uint48 i = numProposals; i > 0; i--) {
            uint48 index = i - 1;
            IInbox.Proposal memory proposal = proposals[index];
            IInbox.Claim memory claim = claims[index];

            // Determine parent hash for this claim
            bytes32 claimParentHash = index == 0 ? initialParentHash : claimHashes[index - 1];

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claim;

            bytes memory proveData = encodeProveData(proveProposals, proveClaims);
            bytes memory proof = bytes(string.concat("proof_", vm.toString(i)));

            // Different prover for each proposal
            address prover = getProver(index);
            vm.prank(prover);
            inbox.prove(proveData, proof);

            // Verify claim record was stored with correct parent
            bytes32 storedClaimHash = inbox.getClaimRecordHash(proposal.id, claimParentHash);
            assertTrue(storedClaimHash != bytes32(0), "Claim record should be stored");
        }

        // Phase 3: Advance time past cooldown
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        // Phase 4: Attempt finalization - should finalize all in correct order
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);

        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                proposer: proposals[i].proposer,
                livenessBondGwei: 0,
                provabilityBondGwei: 0,
                nextProposalId: proposals[i].id + 1,
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

        mockProposerAllowed(Henry);
        mockHasSufficientBond(Henry, true);
        mockForcedInclusionDue(false);

        // Expect final block update
        IInbox.Claim memory lastClaim = claims[numProposals - 1];
        expectSyncedBlockSave(
            lastClaim.endBlockNumber, lastClaim.endBlockHash, lastClaim.endStateRoot
        );

        // Submit new proposal that triggers finalization
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, claimRecords);

        vm.prank(Henry);
        inbox.propose(bytes(""), proposeData);

        // Verify all proposals were finalized in correct order
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: numProposals + 2,
            lastFinalizedProposalId: numProposals,
            lastFinalizedClaimHash: claimHashes[numProposals - 1],
            bondOperationsHash: bytes32(0)
        });

        assertEq(inbox.getCoreStateHash(), keccak256(abi.encode(expectedCoreState)));
    }

    /// @notice Test scattered proving pattern with multiple gaps
    /// @dev Proves proposals in pattern: 3, 5, 1, 4, 2, then finalizes
    function test_prove_scattered_pattern_finalization() public {
        uint48 numProposals = 5;
        uint48[] memory proveOrder = new uint48[](5);
        proveOrder[0] = 3;
        proveOrder[1] = 5;
        proveOrder[2] = 1;
        proveOrder[3] = 4;
        proveOrder[4] = 2;

        bytes32 initialParentHash = createCoreState(1, 0).lastFinalizedClaimHash;

        // Create all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

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
            proposal.proposer = Alice; // Match what will be stored
            proposals[i - 1] = proposal;

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                encodeProposeProposeData(proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);

            // Update proposal to match what was stored
            proposal.proposer = Alice;
            proposals[i - 1] = proposal;
        }

        // Create claims with proper parent chain
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);
        bytes32 parentHash = initialParentHash;

        for (uint48 i = 0; i < numProposals; i++) {
            // Get the actual stored proposal hash
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            claims[i] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: parentHash,
                endBlockNumber: uint32(100 + i * 10),
                endBlockHash: keccak256(abi.encode(proposals[i].id, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(proposals[i].id, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });
            claims[i].endBlockNumber = uint32(100 + i * 10);
            parentHash = keccak256(abi.encode(claims[i]));
        }

        // Prove in scattered order
        for (uint48 i = 0; i < proveOrder.length; i++) {
            uint48 proposalIndex = proveOrder[i] - 1;
            IInbox.Proposal memory proposal = proposals[proposalIndex];
            IInbox.Claim memory claim = claims[proposalIndex];

            // Calculate correct parent hash
            bytes32 claimParentHash = proposalIndex == 0
                ? initialParentHash
                : keccak256(abi.encode(claims[proposalIndex - 1]));

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claim;

            vm.prank(getProver(i));
            inbox.prove(encodeProveData(proveProposals, proveClaims), bytes("proof"));

            // Verify storage
            assertTrue(
                inbox.getClaimRecordHash(proposal.id, claimParentHash) != bytes32(0),
                string.concat("Claim ", vm.toString(proposal.id), " not stored")
            );
        }

        // Wait for cooldown
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        // Finalize all proposals
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);
        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                proposer: proposals[i].proposer,
                livenessBondGwei: 0,
                provabilityBondGwei: 0,
                nextProposalId: i + 2,
                bondDecision: IInbox.BondDecision.NoOp
            });
        }

        finalizeProposals(numProposals, initialParentHash, claimRecords, claims[numProposals - 1]);

        // Verify correct finalization
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: numProposals + 2,
            lastFinalizedProposalId: numProposals,
            lastFinalizedClaimHash: keccak256(abi.encode(claims[numProposals - 1])),
            bondOperationsHash: bytes32(0)
        });

        assertEq(inbox.getCoreStateHash(), keccak256(abi.encode(expectedCoreState)));
    }

    /// @notice Test partial proving with gradual chain advancement
    /// @dev Simulates realistic scenario where proofs arrive gradually
    function test_gradual_proving_and_advancement() public {
        uint48 totalProposals = 10;
        bytes32 initialParentHash = createCoreState(1, 0).lastFinalizedClaimHash;

        // Create all proposals upfront
        IInbox.Proposal[] memory allProposals = new IInbox.Proposal[](totalProposals);
        for (uint48 i = 1; i <= totalProposals; i++) {
            allProposals[i - 1] = createAndSubmitProposal(i, 0, initialParentHash);
        }

        // Create all claims with proper chaining
        IInbox.Claim[] memory allClaims = new IInbox.Claim[](totalProposals);
        bytes32 parentHash = initialParentHash;
        for (uint48 i = 0; i < totalProposals; i++) {
            // Get the actual stored proposal hash
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            allClaims[i] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: parentHash,
                endBlockNumber: uint32(100 + i * 10),
                endBlockHash: keccak256(abi.encode(allProposals[i].id, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(allProposals[i].id, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });
            allClaims[i].endBlockNumber = uint32(100 + i * 10);
            parentHash = keccak256(abi.encode(allClaims[i]));
        }

        // Round 1: Prove proposals 1-3 out of order (2, 1, 3)
        proveProposal(allProposals[1], allClaims[1], keccak256(abi.encode(allClaims[0])), Bob);
        proveProposal(allProposals[0], allClaims[0], initialParentHash, Alice);
        proveProposal(allProposals[2], allClaims[2], keccak256(abi.encode(allClaims[1])), Carol);

        // Try to finalize - should finalize 1-3
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        IInbox.ClaimRecord[] memory claimRecords1 = new IInbox.ClaimRecord[](3);
        for (uint48 i = 0; i < 3; i++) {
            claimRecords1[i] = createClaimRecord(allProposals[i], allClaims[i]);
        }

        finalizeProposals(totalProposals, initialParentHash, claimRecords1, allClaims[2]);

        // Verify finalization of 1-3
        IInbox.CoreState memory state1 = decodeCurrentCoreState();
        assertEq(state1.lastFinalizedProposalId, 3, "Should finalize up to proposal 3");
        assertEq(state1.lastFinalizedClaimHash, keccak256(abi.encode(allClaims[2])));

        // Round 2: Prove proposals 6, 4, 7, 5 (with gap at 4-5)
        proveProposal(allProposals[5], allClaims[5], keccak256(abi.encode(allClaims[4])), David);
        proveProposal(allProposals[3], allClaims[3], keccak256(abi.encode(allClaims[2])), Emma);
        proveProposal(allProposals[6], allClaims[6], keccak256(abi.encode(allClaims[5])), Frank);
        proveProposal(allProposals[4], allClaims[4], keccak256(abi.encode(allClaims[3])), Grace);

        // Try to finalize - should finalize 4-7
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        IInbox.ClaimRecord[] memory claimRecords2 = new IInbox.ClaimRecord[](4);
        for (uint48 i = 0; i < 4; i++) {
            claimRecords2[i] = createClaimRecord(allProposals[i + 3], allClaims[i + 3]);
        }

        // Need to update state for next proposal
        state1.nextProposalId = totalProposals + 2;
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(state1)));

        mockProposerAllowed(Henry);
        mockHasSufficientBond(Henry, true);
        mockForcedInclusionDue(false);
        expectSyncedBlockSave(
            allClaims[6].endBlockNumber, allClaims[6].endBlockHash, allClaims[6].endStateRoot
        );

        LibBlobs.BlobReference memory blobRef2 = createValidBlobReference(totalProposals + 2);
        bytes memory proposeData2 = encodeProposeProposeData(state1, blobRef2, claimRecords2);

        vm.prank(Henry);
        inbox.propose(bytes(""), proposeData2);

        // Verify finalization advanced to 7
        IInbox.CoreState memory state2 = decodeCurrentCoreState();
        assertEq(state2.lastFinalizedProposalId, 7, "Should finalize up to proposal 7");
        assertEq(state2.lastFinalizedClaimHash, keccak256(abi.encode(allClaims[6])));

        // Round 3: Prove remaining proposals 8-10 in random order (9, 10, 8)
        proveProposal(allProposals[8], allClaims[8], keccak256(abi.encode(allClaims[7])), Isabella);
        proveProposal(allProposals[9], allClaims[9], keccak256(abi.encode(allClaims[8])), James);
        proveProposal(allProposals[7], allClaims[7], keccak256(abi.encode(allClaims[6])), Katherine);

        // Final finalization - should complete chain
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        IInbox.ClaimRecord[] memory claimRecords3 = new IInbox.ClaimRecord[](3);
        for (uint48 i = 0; i < 3; i++) {
            claimRecords3[i] = createClaimRecord(allProposals[i + 7], allClaims[i + 7]);
        }

        state2.nextProposalId = totalProposals + 3;
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(state2)));

        mockProposerAllowed(Liam);
        mockHasSufficientBond(Liam, true);
        mockForcedInclusionDue(false);
        expectSyncedBlockSave(
            allClaims[9].endBlockNumber, allClaims[9].endBlockHash, allClaims[9].endStateRoot
        );

        LibBlobs.BlobReference memory blobRef3 = createValidBlobReference(totalProposals + 3);
        bytes memory proposeData3 = encodeProposeProposeData(state2, blobRef3, claimRecords3);

        vm.prank(Liam);
        inbox.propose(bytes(""), proposeData3);

        // Verify complete finalization
        IInbox.CoreState memory finalState = decodeCurrentCoreState();
        assertEq(finalState.lastFinalizedProposalId, 10, "Should finalize all proposals");
        assertEq(finalState.lastFinalizedClaimHash, keccak256(abi.encode(allClaims[9])));
        assertEq(finalState.nextProposalId, 14, "Next proposal ID should be correct");
    }

    /// @notice Test multiple provers submitting proofs for same proposal
    /// @dev Verifies that multiple valid proofs can coexist and be finalized
    function test_multiple_proofs_same_proposal() public {
        uint48 numProposals = 3;
        bytes32 initialParentHash = createCoreState(1, 0).lastFinalizedClaimHash;

        // Create proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = createAndSubmitProposal(i, 0, initialParentHash);
        }

        // For proposal 2, submit multiple different proofs
        IInbox.Proposal memory proposal2 = proposals[1];
        IInbox.Claim memory tempClaim1 = createValidClaim(proposals[0], initialParentHash);
        bytes32 parentHashForProposal2 = keccak256(abi.encode(tempClaim1));

        // Three different provers submit different claims for proposal 2
        IInbox.Claim[] memory claims2 = new IInbox.Claim[](3);
        for (uint48 i = 0; i < 3; i++) {
            claims2[i] = createValidClaim(proposal2, parentHashForProposal2);
            claims2[i].endStateRoot = bytes32(uint256(1000 + i)); // Different state roots
            claims2[i].endStateRoot = bytes32(uint256(1000 + i)); // Different state roots

            mockProofVerification(true);
            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal2;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claims2[i];

            address prover = getProver(i);
            vm.prank(prover);
            inbox.prove(encodeProveData(proveProposals, proveClaims), bytes("proof"));

            // Verify each claim was stored
            bytes32 claimHash = inbox.getClaimRecordHash(proposal2.id, parentHashForProposal2);
            assertTrue(claimHash != bytes32(0), "Claim should be stored");
        }

        // Prove proposals 1 and 3 normally
        IInbox.Claim memory claim1 = createValidClaim(proposals[0], initialParentHash);
        proveProposal(proposals[0], claim1, initialParentHash, Alice);

        // For finalization, we'll use the first claim for proposal 2
        bytes32 claim2Hash = keccak256(abi.encode(claims2[0]));
        IInbox.Claim memory claim3 = createValidClaim(proposals[2], claim2Hash);
        proveProposal(proposals[2], claim3, claim2Hash, Bob);

        // Wait and finalize
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](3);
        claimRecords[0] = createClaimRecord(proposals[0], claim1);
        claimRecords[1] = createClaimRecord(proposals[1], claims2[0]); // Use first claim for
            // proposal 2
        claimRecords[2] = createClaimRecord(proposals[2], claim3);

        finalizeProposals(numProposals, initialParentHash, claimRecords, claim3);

        // Verify finalization used the specified claim chain
        IInbox.CoreState memory finalState = decodeCurrentCoreState();
        assertEq(finalState.lastFinalizedProposalId, 3);
        assertEq(finalState.lastFinalizedClaimHash, keccak256(abi.encode(claim3)));
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    function createAndSubmitProposal(
        uint48 proposalId,
        uint48 lastFinalizedId,
        bytes32 lastFinalizedHash
    )
        private
        returns (IInbox.Proposal memory)
    {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: proposalId,
            lastFinalizedProposalId: lastFinalizedId,
            lastFinalizedClaimHash: lastFinalizedHash,
            bondOperationsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        IInbox.Proposal memory proposal = createValidProposal(proposalId);
        proposal.proposer = Alice;

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(proposalId);
        IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, emptyClaimRecords);

        vm.prank(Alice);
        inbox.propose(bytes(""), proposeData);

        return proposal;
    }

    function proveProposal(
        IInbox.Proposal memory proposal,
        IInbox.Claim memory claim,
        bytes32 parentClaimHash,
        address prover
    )
        private
    {
        mockProofVerification(true);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        bytes memory proveData = encodeProveData(proposals, claims);
        vm.prank(prover);
        inbox.prove(proveData, bytes("proof"));
    }

    function createClaimRecord(
        IInbox.Proposal memory proposal,
        IInbox.Claim memory claim
    )
        private
        pure
        returns (IInbox.ClaimRecord memory)
    {
        return IInbox.ClaimRecord({
            claim: claim,
            proposer: proposal.proposer,
            livenessBondGwei: 0,
            provabilityBondGwei: 0,
            nextProposalId: proposal.id + 1,
            bondDecision: IInbox.BondDecision.NoOp
        });
    }

    function finalizeProposals(
        uint48 nextProposalId,
        bytes32 lastFinalizedHash,
        IInbox.ClaimRecord[] memory claimRecords,
        IInbox.Claim memory expectedLastClaim
    )
        private
    {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: nextProposalId + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: lastFinalizedHash,
            bondOperationsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Henry);
        mockHasSufficientBond(Henry, true);
        mockForcedInclusionDue(false);
        expectSyncedBlockSave(
            expectedLastClaim.endBlockNumber,
            expectedLastClaim.endBlockHash,
            expectedLastClaim.endStateRoot
        );

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(nextProposalId + 1);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, claimRecords);

        vm.prank(Henry);
        inbox.propose(bytes(""), proposeData);
    }

    function decodeCurrentCoreState() private view returns (IInbox.CoreState memory) {
        bytes32 stateHash = inbox.getCoreStateHash();
        // In real implementation, would need to track or reconstruct the state
        // For testing, we can infer from the hash or use exposed getters
        return IInbox.CoreState({
            nextProposalId: 0, // Would need getter
            lastFinalizedProposalId: 0, // Would need getter
            lastFinalizedClaimHash: bytes32(0), // Would need getter
            bondOperationsHash: bytes32(0)
        });
    }

    function getProver(uint256 index) private view returns (address) {
        address[10] memory provers =
            [Alice, Bob, Carol, David, Emma, Frank, Grace, Henry, Isabella, James];
        return provers[index % 10];
    }
}
