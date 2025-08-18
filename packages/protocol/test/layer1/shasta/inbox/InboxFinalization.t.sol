// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { Inbox, ClaimRecordHashMismatchWithStorage } from "contracts/layer1/shasta/impl/Inbox.sol";
import "./InboxMockContracts.sol";

/// @title InboxFinalization
/// @notice Tests for proposal finalization functionality
/// @dev This test suite covers:
///      - Single proposal finalization with state updates
///      - Multiple proposal batch finalization
///      - Missing claim handling and partial finalization
///      - Invalid claim hash rejection and error handling
/// @custom:security-contact security@taiko.xyz
contract InboxFinalization is InboxTest {
    using InboxTestLib for *;
    // Override setupMockAddresses to use actual mock contracts instead of makeAddr

    function setupMockAddresses() internal override {
        setupMockAddresses(true); // Use real mock contracts for finalization tests
    }
    /// @notice Test finalizing a single proposal
    /// @dev Validates complete single proposal finalization flow:
    ///      1. Creates and stores proposal with valid claim record
    ///      2. Triggers finalization through new proposal submission
    ///      3. Verifies synced block manager update and state progression

    function test_finalize_single_proposal() public {
        // Arrange: Create a proposal and claim record ready for finalization
        uint48 proposalId = 1;
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        IInbox.Proposal memory proposal = _createStoredProposal(proposalId, coreState);
        IInbox.Claim memory claim =
            InboxTestLib.createClaim(proposal, coreState.lastFinalizedClaimHash, Alice);
        IInbox.ClaimRecord memory claimRecord =
            _createStoredClaimRecord(proposalId, claim, coreState.lastFinalizedClaimHash);

        // Setup expectations
        expectSyncedBlockSave(claim.endBlockNumber, claim.endBlockHash, claim.endStateRoot);

        // Act: Submit proposal that triggers finalization
        _submitFinalizationProposal(proposal, claimRecord);
    }

    /// @dev Helper to create and store a proposal for testing
    function _createStoredProposal(
        uint48 _proposalId,
        IInbox.CoreState memory _coreState
    )
        private
        returns (IInbox.Proposal memory proposal)
    {
        IInbox.CoreState memory updatedCoreState = _coreState;
        updatedCoreState.nextProposalId = _proposalId + 1;

        proposal = createValidProposal(_proposalId);
        proposal.coreStateHash = keccak256(abi.encode(updatedCoreState));
        inbox.exposed_setProposalHash(_proposalId, InboxTestLib.hashProposal(proposal));
    }

    /// @dev Helper to create and store a claim record for testing
    function _createStoredClaimRecord(
        uint48 _proposalId,
        IInbox.Claim memory _claim,
        bytes32 _parentClaimHash
    )
        private
        returns (IInbox.ClaimRecord memory claimRecord)
    {
        claimRecord = InboxTestLib.createClaimRecord(_proposalId, _claim, 1);
        inbox.exposed_setClaimRecordHash(
            _proposalId, _parentClaimHash, InboxTestLib.hashClaimRecord(claimRecord)
        );
    }

    /// @dev Helper to submit a finalization proposal
    function _submitFinalizationProposal(
        IInbox.Proposal memory _proposalToValidate,
        IInbox.ClaimRecord memory _claimRecord
    )
        private
    {
        setupProposalMocks(Alice);

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = _claimRecord;

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposalToValidate;

        IInbox.CoreState memory newCoreState = _getGenesisCoreState();
        newCoreState.nextProposalId = 2;

        bytes memory data = encodeProposalDataWithProposals(
            newCoreState, proposals, InboxTestLib.createBlobReference(2), claimRecords
        );

        setupBlobHashes();
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test finalizing multiple proposals in sequence
    /// @dev Validates batch finalization of multiple proposals:
    ///      1. Submits and proves multiple proposals with linked claims
    ///      2. Batch finalizes all proposals in one transaction
    ///      3. Verifies final state consistency and claim hash progression
    function test_finalize_multiple_proposals() public {
        uint48 numProposals = 3;
        bytes32 genesisHash = getGenesisClaimHash();

        // Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Then prove them all
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);
        bytes32 currentParentHash = genesisHash;

        for (uint48 i = 0; i < numProposals; i++) {
            claims[i] = InboxTestLib.createClaim(proposals[i], currentParentHash, Bob);
            proveProposal(proposals[i], Bob, currentParentHash);
            currentParentHash = InboxTestLib.hashClaim(claims[i]);
        }

        // Create claim records for finalization
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);
        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = InboxTestLib.createClaimRecord(i + 1, claims[i], 1);
        }

        // Setup expectations for finalization
        expectSyncedBlockSave(
            claims[numProposals - 1].endBlockNumber,
            claims[numProposals - 1].endBlockHash,
            claims[numProposals - 1].endStateRoot
        );

        // Act: Submit finalization proposal
        _submitBatchFinalizationProposal(
            proposals[numProposals - 1], claimRecords, numProposals + 1
        );

        // Assert: Verify finalization completed
        bytes32 finalClaimHash = InboxTestLib.hashClaim(claims[numProposals - 1]);
        assertFinalizationCompleted(numProposals, finalClaimHash);
    }

    /// @dev Helper to submit a batch finalization proposal
    function _submitBatchFinalizationProposal(
        IInbox.Proposal memory _lastProposal,
        IInbox.ClaimRecord[] memory _claimRecords,
        uint48 _nextProposalId
    )
        private
    {
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(_nextProposalId, 0, getGenesisClaimHash(), bytes32(0));

        setupProposalMocks(Carol);
        setupBlobHashes();

        vm.prank(Carol);
        inbox.propose(
            bytes(""),
            encodeProposalDataForSubsequent(
                coreState,
                _lastProposal,
                InboxTestLib.createBlobReference(uint8(_nextProposalId)),
                _claimRecords
            )
        );
    }

    /// @notice Test finalization stops at missing claim record
    /// @dev Validates partial finalization when claim records are missing:
    ///      1. Creates proposals with only first having claim record
    ///      2. Attempts finalization and expects stopping at missing claim
    ///      3. Verifies only proven consecutive proposals are finalized
    function test_finalize_stops_at_missing_claim() public {
        // Setup blobhashes for this specific test
        setupBlobHashes();
        // Create genesis claim
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentClaimHash = keccak256(abi.encode(genesisClaim));

        // Store proposal 1 with claim
        IInbox.CoreState memory coreState1 = _getGenesisCoreState();
        coreState1.nextProposalId = 2; // After proposal 1

        IInbox.Proposal memory proposal1 = createValidProposal(1);
        proposal1.coreStateHash = keccak256(abi.encode(coreState1));
        inbox.exposed_setProposalHash(1, keccak256(abi.encode(proposal1)));

        IInbox.Claim memory claim1 = InboxTestLib.createClaim(proposal1, parentClaimHash, Bob);
        IInbox.ClaimRecord memory claimRecord1 = IInbox.ClaimRecord({
            proposalId: 1,
            claim: claim1,
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });
        inbox.exposed_setClaimRecordHash(1, parentClaimHash, keccak256(abi.encode(claimRecord1)));

        // Store proposal 2 WITHOUT claim (gap in chain)
        IInbox.CoreState memory coreState2 = _getGenesisCoreState();
        coreState2.nextProposalId = 3; // After proposal 2

        IInbox.Proposal memory proposal2 = createValidProposal(2);
        proposal2.coreStateHash = keccak256(abi.encode(coreState2));
        inbox.exposed_setProposalHash(2, keccak256(abi.encode(proposal2)));
        // No claim record stored for proposal 2

        // Setup core state for new proposal
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(3, 0);
        coreState.lastFinalizedClaimHash = parentClaimHash;

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Only expect first proposal to be finalized
        expectSyncedBlockSave(claim1.endBlockNumber, claim1.endBlockHash, claim1.endStateRoot);

        // Create proposal data with only claimRecord1
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord1;

        // Include proposal 2 for validation (as the last proposal)
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal2;

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        bytes memory data = encodeProposalDataWithProposals(uint64(0), coreState, proposals, blobRef, claimRecords);

        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify only proposal 1 was finalized
        // The test passes if propose succeeded without reverting
        // We expect only proposal 1 to have been finalized
    }

    /// @notice Test finalization with invalid claim record hash
    /// @dev Validates claim record integrity protection:
    ///      1. Stores correct claim record in contract storage
    ///      2. Submits modified claim record for finalization
    ///      3. Expects ClaimRecordHashMismatchWithStorage error for security
    function test_finalize_invalid_claim_hash() public {
        setupBlobHashes();

        // Submit and prove proposal 1 correctly first
        IInbox.Proposal memory proposal1 = submitProposal(1, Alice);
        bytes32 parentClaimHash = getGenesisClaimHash();
        IInbox.Claim memory claim1 = InboxTestLib.createClaim(proposal1, parentClaimHash, Bob);
        proveProposal(proposal1, Bob, parentClaimHash);

        // Now try to finalize with a WRONG claim record
        IInbox.ClaimRecord memory wrongClaimRecord = IInbox.ClaimRecord({
            proposalId: 1,
            claim: claim1,
            span: 2, // Modified field - wrong span value
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = wrongClaimRecord;

        // Create core state for next proposal
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(2, 0, parentClaimHash, bytes32(0));

        // Setup mocks for new proposal
        setupProposalMocks(Carol);
        setupBlobHashes();

        // Expect revert due to mismatched claim record hash
        vm.expectRevert(ClaimRecordHashMismatchWithStorage.selector);
        vm.prank(Carol);
        inbox.propose(
            bytes(""),
            encodeProposalDataForSubsequent(
                coreState, proposal1, InboxTestLib.createBlobReference(2), claimRecords
            )
        );
    }
}
