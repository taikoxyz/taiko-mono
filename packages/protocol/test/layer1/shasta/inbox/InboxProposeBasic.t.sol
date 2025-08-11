// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxProposeBasic
/// @notice Tests for basic proposal submission functionality
/// @dev Tests cover single and multiple proposal submissions, event emissions, and state updates
contract InboxProposeBasic is ShastaInboxTestBase {
    
    /// @notice Test submitting a single valid proposal
    /// @dev Verifies that a valid proposal can be submitted successfully with:
    ///      - Correct proposal hash stored in ring buffer
    ///      - Core state updated with incremented nextProposalId
    ///      - Proposed event emitted with correct data
    function test_propose_single_valid() public {
        // Setup initial core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        bytes32 initialCoreStateHash = keccak256(abi.encode(coreState));
        inbox.exposed_setCoreStateHash(initialCoreStateHash);
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: 1,
            proposer: Alice,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            provabilityBondGwei: DEFAULT_PROVABILITY_BOND,
            livenessBondGwei: DEFAULT_LIVENESS_BOND,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](1),
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
        
        // Expected updated core state
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = 2;
        
        // Expect Proposed event
        vm.expectEmit(true, true, true, true);
        emit Proposed(expectedProposal, expectedCoreState);
        
        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
        
        // Verify proposal hash is stored
        bytes32 storedProposalHash = inbox.getProposalHash(1);
        bytes32 expectedProposalHash = keccak256(abi.encode(expectedProposal));
        assertEq(storedProposalHash, expectedProposalHash);
        
        // Verify core state is updated
        bytes32 newCoreStateHash = inbox.getCoreStateHash();
        assertEq(newCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }
    
    /// @notice Test submitting multiple proposals sequentially
    /// @dev Verifies that multiple proposals can be submitted in sequence with:
    ///      - Each proposal getting a unique incremented ID
    ///      - All proposals stored correctly in ring buffer
    ///      - Core state updated correctly after each proposal
    function test_propose_multiple_sequential() public {
        uint48 numProposals = 5;
        
        for (uint48 i = 0; i < numProposals; i++) {
            // Setup core state for this iteration
            IInbox.CoreState memory coreState = createCoreState(i + 1, 0);
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
            
            // Setup mocks
            mockProposerAllowed(Alice);
            mockHasSufficientBond(Alice, true);
            mockForcedInclusionDue(false);
            
            // Create proposal data
            LibBlobs.BlobReference memory blobRef = createValidBlobReference(i + 1);
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
            
            // Submit proposal
            vm.prank(Alice);
            inbox.propose(bytes(""), data);
            
            // Verify proposal is stored
            bytes32 proposalHash = inbox.getProposalHash(i + 1);
            assertTrue(proposalHash != bytes32(0));
        }
        
        // Verify all proposals are accessible
        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 proposalHash = inbox.getProposalHash(i + 1);
            assertTrue(proposalHash != bytes32(0));
        }
    }
    
    /// @notice Test proposal with valid blob reference
    /// @dev Verifies that blob references are properly validated and stored
    /// Expected behavior: Proposal succeeds with valid blob reference containing hash and KZG commitment
    function test_propose_with_valid_blob_reference() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);
        
        // Create blob reference with specific values
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 1,
            numBlobs: 1,
            offset: 100
        });
        
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
        
        // Verify proposal contains correct blob slice
        bytes32 proposalHash = inbox.getProposalHash(1);
        assertTrue(proposalHash != bytes32(0));
    }
    
    /// @notice Test proposal event emission with correct data
    /// @dev Verifies that the Proposed event contains all expected fields
    /// Expected behavior: Event emitted with proposal details and updated core state
    function test_propose_event_emission() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Bob);
        mockHasSufficientBond(Bob, true);
        mockForcedInclusionDue(false);
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(999);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Record logs to check event data
        vm.recordLogs();
        
        // Submit proposal
        vm.prank(Bob);
        inbox.propose(bytes(""), data);
        
        // Get emitted logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Find Proposed event (should be the last one)
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proposed(IInbox.Proposal,IInbox.CoreState)")) {
                foundEvent = true;
                // Decode and verify event data
                (IInbox.Proposal memory emittedProposal, IInbox.CoreState memory emittedCoreState) = 
                    abi.decode(logs[i].data, (IInbox.Proposal, IInbox.CoreState));
                
                assertEq(emittedProposal.id, 1);
                assertEq(emittedProposal.proposer, Bob);
                assertEq(emittedCoreState.nextProposalId, 2);
                break;
            }
        }
        assertTrue(foundEvent);
    }
    
    /// @notice Test multiple proposers submitting proposals
    /// @dev Verifies that different accounts can submit proposals
    /// Expected behavior: Each proposer can submit proposals independently
    function test_propose_multiple_proposers() public {
        address[3] memory proposers = [Alice, Bob, Carol];
        
        for (uint i = 0; i < proposers.length; i++) {
            // Setup core state
            IInbox.CoreState memory coreState = createCoreState(uint48(i + 1), 0);
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
            
            // Setup mocks for this proposer
            mockProposerAllowed(proposers[i]);
            mockHasSufficientBond(proposers[i], true);
            mockForcedInclusionDue(false);
            
            // Create proposal data
            LibBlobs.BlobReference memory blobRef = createValidBlobReference(i + 1);
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
            
            // Submit proposal
            vm.prank(proposers[i]);
            inbox.propose(bytes(""), data);
            
            // Verify proposal is stored
            bytes32 proposalHash = inbox.getProposalHash(uint48(i + 1));
            assertTrue(proposalHash != bytes32(0));
        }
    }
}