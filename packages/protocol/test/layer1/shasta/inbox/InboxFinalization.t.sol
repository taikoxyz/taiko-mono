// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxFinalization
/// @notice Tests for proposal finalization functionality including chain validation and state
/// updates
/// @dev Tests cover finalization scenarios:
///      - Single proposal finalization
///      - Batch finalization of multiple proposals
///      - Chain validation (parent-child relationships)
///      - Core state updates (lastFinalizedProposalId, lastFinalizedClaimHash)
///      - Bond operation processing during finalization
///      - Integration with SyncedBlockManager
/// @dev Key invariants tested:
///      - Proposals must be finalized in sequence
///      - Parent claim hashes must match for chain continuity
///      - Bond operations must be processed atomically
/// @custom:security-contact security@taiko.xyz
contract InboxFinalization is ShastaInboxTestBase {
    /// @notice Test finalizing a single proposal
    /// @dev Verifies that a proposal with a valid claim record can be finalized with:
    ///      - Core state updated (lastFinalizedProposalId, lastFinalizedClaimHash)
    ///      - SyncedBlockManager updated with final block data
    ///      - Bond operations processed
    function test_finalize_single_proposal() public {
        // Setup: Create and store a proposal
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = createValidProposal(proposalId);
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        inbox.exposed_setProposalHash(proposalId, proposalHash);

        // Create initial core state (proposal exists but not finalized)
        IInbox.CoreState memory coreState = createCoreState(2, 0); // nextId=2, lastFinalized=0

        // Create and store a claim record
        IInbox.Claim memory claim = createValidClaim(proposal, coreState.lastFinalizedClaimHash);
        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            claim: claim,
            proposer: proposal.proposer,
            livenessBondGwei: 0,
            provabilityBondGwei: 0,
            nextProposalId: proposalId + 1,
            bondDecision: IInbox.BondDecision.NoOp
        });

        // Store the claim record
        bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
        inbox.exposed_setClaimRecordHash(
            proposalId, coreState.lastFinalizedClaimHash, claimRecordHash
        );

        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        // Expect SyncedBlockManager to be updated
        expectSyncedBlockSave(claim.endBlockNumber, claim.endBlockHash, claim.endStateRoot);

        // Create proposal data with claim records for finalization
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord;

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(2);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        // Set initial core state
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Submit proposal (which triggers finalization)
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify core state was updated
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = 3; // Incremented for new proposal
        expectedCoreState.lastFinalizedProposalId = proposalId;
        expectedCoreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));

        bytes32 actualCoreStateHash = inbox.getCoreStateHash();
        assertEq(actualCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }

    /// @notice Test finalizing multiple proposals in sequence
    /// @dev Verifies that multiple proposals can be finalized in a single transaction
    /// Expected behavior: All proposals up to maxFinalizationCount are finalized
    function test_finalize_multiple_proposals() public {
        uint48 numProposals = 3;

        // Setup: Create and store multiple proposals with linked claims
        bytes32 parentClaimHash = createCoreState(1, 0).lastFinalizedClaimHash;
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            // Create and store proposal
            IInbox.Proposal memory proposal = createValidProposal(i);
            bytes32 proposalHash = keccak256(abi.encode(proposal));
            inbox.exposed_setProposalHash(i, proposalHash);

            // Create claim with chained parent
            IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);
            IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
                claim: claim,
                proposer: proposal.proposer,
                livenessBondGwei: 0,
                provabilityBondGwei: 0,
                nextProposalId: i + 1,
                bondDecision: IInbox.BondDecision.NoOp
            });

            // Store claim record
            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            inbox.exposed_setClaimRecordHash(i, parentClaimHash, claimRecordHash);

            claimRecords[i - 1] = claimRecord;
            parentClaimHash = keccak256(abi.encode(claim));
        }

        // Setup initial core state
        IInbox.CoreState memory coreState = createCoreState(numProposals + 1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        // Expect final synced block save
        IInbox.Claim memory lastClaim = claimRecords[numProposals - 1].claim;
        expectSyncedBlockSave(
            lastClaim.endBlockNumber, lastClaim.endBlockHash, lastClaim.endStateRoot
        );

        // Create proposal data with all claim records
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        // Submit proposal (triggers finalization)
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify all proposals were finalized
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = numProposals + 2;
        expectedCoreState.lastFinalizedProposalId = numProposals;
        expectedCoreState.lastFinalizedClaimHash = keccak256(abi.encode(lastClaim));

        bytes32 actualCoreStateHash = inbox.getCoreStateHash();
        assertEq(actualCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }

    /// @notice Test finalization stops at missing claim record
    /// @dev Verifies that finalization stops when encountering a gap in the claim chain
    /// Expected behavior: Only proposals with continuous claim chain are finalized
    function test_finalize_stops_at_missing_claim() public {
        // Setup: Create proposals 1, 2, 3 but only store claims for 1 and 3
        bytes32 parentClaimHash = createCoreState(1, 0).lastFinalizedClaimHash;

        // Store proposal 1 with claim
        IInbox.Proposal memory proposal1 = createValidProposal(1);
        inbox.exposed_setProposalHash(1, keccak256(abi.encode(proposal1)));

        IInbox.Claim memory claim1 = createValidClaim(proposal1, parentClaimHash);
        IInbox.ClaimRecord memory claimRecord1 = IInbox.ClaimRecord({
            claim: claim1,
            proposer: proposal1.proposer,
            livenessBondGwei: 0,
            provabilityBondGwei: 0,
            nextProposalId: 2,
            bondDecision: IInbox.BondDecision.NoOp
        });
        inbox.exposed_setClaimRecordHash(1, parentClaimHash, keccak256(abi.encode(claimRecord1)));

        // Store proposal 2 WITHOUT claim (gap in chain)
        IInbox.Proposal memory proposal2 = createValidProposal(2);
        inbox.exposed_setProposalHash(2, keccak256(abi.encode(proposal2)));
        // No claim record stored for proposal 2

        // Store proposal 3 with claim (but unreachable due to gap)
        IInbox.Proposal memory proposal3 = createValidProposal(3);
        inbox.exposed_setProposalHash(3, keccak256(abi.encode(proposal3)));

        bytes32 claim1Hash = keccak256(abi.encode(claim1));
        IInbox.Claim memory claim3 = createValidClaim(proposal3, bytes32(uint256(999))); // Different
            // parent
        IInbox.ClaimRecord memory claimRecord3 = IInbox.ClaimRecord({
            claim: claim3,
            proposer: proposal3.proposer,
            livenessBondGwei: 0,
            provabilityBondGwei: 0,
            nextProposalId: 4,
            bondDecision: IInbox.BondDecision.NoOp
        });
        inbox.exposed_setClaimRecordHash(
            3, bytes32(uint256(999)), keccak256(abi.encode(claimRecord3))
        );

        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(4, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        // Only expect first proposal to be finalized
        expectSyncedBlockSave(claim1.endBlockNumber, claim1.endBlockHash, claim1.endStateRoot);

        // Create proposal data with only claimRecord1 (gap prevents further finalization)
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord1;

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(4);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify only proposal 1 was finalized
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = 5;
        expectedCoreState.lastFinalizedProposalId = 1; // Only 1 finalized
        expectedCoreState.lastFinalizedClaimHash = claim1Hash;

        bytes32 actualCoreStateHash = inbox.getCoreStateHash();
        assertEq(actualCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }

    /// @notice Test finalization with invalid claim record hash
    /// @dev Verifies that finalization fails if provided claim record doesn't match stored hash
    /// Expected behavior: Transaction reverts with ClaimRecordHashMismatch error
    function test_finalize_invalid_claim_hash() public {
        // Setup: Create and store a proposal with claim
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = createValidProposal(proposalId);
        inbox.exposed_setProposalHash(proposalId, keccak256(abi.encode(proposal)));

        IInbox.CoreState memory coreState = createCoreState(2, 0);

        // Store correct claim record
        IInbox.Claim memory claim = createValidClaim(proposal, coreState.lastFinalizedClaimHash);
        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            claim: claim,
            proposer: proposal.proposer,
            livenessBondGwei: 0,
            provabilityBondGwei: 0,
            nextProposalId: 2,
            bondDecision: IInbox.BondDecision.NoOp
        });
        inbox.exposed_setClaimRecordHash(
            proposalId, coreState.lastFinalizedClaimHash, keccak256(abi.encode(claimRecord))
        );

        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        // Create proposal data with WRONG claim record
        IInbox.ClaimRecord memory wrongClaimRecord = claimRecord;
        wrongClaimRecord.provabilityBondGwei = 999; // Modified field

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = wrongClaimRecord;

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(2);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Expect revert
        vm.expectRevert(InboxBase.ClaimRecordHashMismatch.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test finalization respects maxFinalizationCount
    /// @dev Verifies that only maxFinalizationCount proposals are finalized per transaction
    /// Expected behavior: Finalization stops after reaching the limit
    function test_finalize_respects_max_count() public {
        // Set low max finalization count
        IInbox.Config memory config = defaultConfig;
        config.maxFinalizationCount = 2;
        inbox.setConfig(config);

        // Create 5 proposals with valid claim chain
        uint48 numProposals = 5;
        bytes32 parentClaimHash = createCoreState(1, 0).lastFinalizedClaimHash;
        IInbox.ClaimRecord[] memory allClaimRecords = new IInbox.ClaimRecord[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.Proposal memory proposal = createValidProposal(i);
            inbox.exposed_setProposalHash(i, keccak256(abi.encode(proposal)));

            IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);
            IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
                claim: claim,
                proposer: proposal.proposer,
                livenessBondGwei: 0,
                provabilityBondGwei: 0,
                nextProposalId: i + 1,
                bondDecision: IInbox.BondDecision.NoOp
            });

            inbox.exposed_setClaimRecordHash(i, parentClaimHash, keccak256(abi.encode(claimRecord)));
            allClaimRecords[i - 1] = claimRecord;
            parentClaimHash = keccak256(abi.encode(claim));
        }

        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(numProposals + 1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        // Only expect finalization of first 2 (maxFinalizationCount)
        IInbox.Claim memory secondClaim = allClaimRecords[1].claim;
        expectSyncedBlockSave(
            secondClaim.endBlockNumber, secondClaim.endBlockHash, secondClaim.endStateRoot
        );

        // Provide only first 2 claim records (matching maxFinalizationCount)
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](2);
        claimRecords[0] = allClaimRecords[0];
        claimRecords[1] = allClaimRecords[1];

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify only 2 proposals were finalized
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = numProposals + 2;
        expectedCoreState.lastFinalizedProposalId = 2; // Only 2 finalized
        expectedCoreState.lastFinalizedClaimHash = keccak256(abi.encode(secondClaim));

        bytes32 actualCoreStateHash = inbox.getCoreStateHash();
        assertEq(actualCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }
}
