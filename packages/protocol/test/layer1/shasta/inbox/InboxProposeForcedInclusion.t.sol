// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxProposeForcedInclusion
/// @notice Tests for forced inclusion mechanism in proposals
/// @dev Tests cover forced inclusion triggering, processing, and priority handling
contract InboxProposeForcedInclusion is ShastaInboxTestBase {
    
    /// @notice Test that forced inclusion is processed when due
    /// @dev Verifies that when a forced inclusion is due, it gets processed before regular proposal
    /// Expected behavior: Forced inclusion proposal created with isForcedInclusion=true
    function test_propose_with_forced_inclusion_due() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(true); // Forced inclusion is due
        mockConsumeForcedInclusion(Alice);
        
        // Create regular proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Record logs to verify both events
        vm.recordLogs();
        
        // Submit proposal (should process forced inclusion first)
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
        
        // Check logs for both Proposed events
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint proposedEventCount = 0;
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proposed(IInbox.Proposal,IInbox.CoreState)")) {
                proposedEventCount++;
                (IInbox.Proposal memory emittedProposal,) = 
                    abi.decode(logs[i].data, (IInbox.Proposal, IInbox.CoreState));
                
                if (proposedEventCount == 1) {
                    // First event should be forced inclusion
                    assertEq(emittedProposal.id, 1);
                    assertTrue(emittedProposal.isForcedInclusion);
                } else if (proposedEventCount == 2) {
                    // Second event should be regular proposal
                    assertEq(emittedProposal.id, 2);
                    assertFalse(emittedProposal.isForcedInclusion);
                }
            }
        }
        
        assertEq(proposedEventCount, 2, "Should emit two Proposed events");
        
        // Verify both proposals are stored
        bytes32 forcedProposalHash = inbox.getProposalHash(1);
        bytes32 regularProposalHash = inbox.getProposalHash(2);
        assertTrue(forcedProposalHash != bytes32(0));
        assertTrue(regularProposalHash != bytes32(0));
    }
    
    /// @notice Test that forced inclusion is consumed from store
    /// @dev Verifies that consumeOldestForcedInclusion is called with correct proposer
    /// Expected behavior: ForcedInclusionStore.consumeOldestForcedInclusion called with msg.sender
    function test_propose_forced_inclusion_consumed() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Bob);
        mockHasSufficientBond(Bob, true);
        mockForcedInclusionDue(true);
        
        // Expect consumeOldestForcedInclusion to be called with Bob
        vm.expectCall(
            forcedInclusionStore,
            abi.encodeWithSelector(
                IForcedInclusionStore.consumeOldestForcedInclusion.selector,
                Bob
            )
        );
        
        // Mock the response
        mockConsumeForcedInclusion(Bob);
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Submit proposal
        vm.prank(Bob);
        inbox.propose(bytes(""), data);
    }
    
    /// @notice Test that forced inclusion takes priority over regular proposal
    /// @dev Verifies that forced inclusion is always processed first when due
    /// Expected behavior: Forced inclusion gets ID 1, regular proposal gets ID 2
    function test_propose_forced_inclusion_priority() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Carol);
        mockHasSufficientBond(Carol, true);
        mockForcedInclusionDue(true);
        mockConsumeForcedInclusion(Carol);
        
        // Create a large regular proposal
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 1,
            numBlobs: 2, // Large blob spanning 2 blobs
            offset: 0
        });
        
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Submit proposal
        vm.prank(Carol);
        inbox.propose(bytes(""), data);
        
        // Verify forced inclusion got processed first (ID 1)
        bytes32 proposalHash1 = inbox.getProposalHash(1);
        assertTrue(proposalHash1 != bytes32(0));
        
        // Verify regular proposal got processed second (ID 2)
        bytes32 proposalHash2 = inbox.getProposalHash(2);
        assertTrue(proposalHash2 != bytes32(0));
        
        // Verify core state was updated to reflect both proposals
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = 3; // Should be incremented by 2
        
        bytes32 actualCoreStateHash = inbox.getCoreStateHash();
        assertEq(actualCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }
    
    /// @notice Test proposal when forced inclusion is not due
    /// @dev Verifies normal proposal processing when no forced inclusion is pending
    /// Expected behavior: Only regular proposal is created
    function test_propose_forced_inclusion_not_due() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false); // Not due
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Record logs
        vm.recordLogs();
        
        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
        
        // Check that only one Proposed event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint proposedEventCount = 0;
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proposed(IInbox.Proposal,IInbox.CoreState)")) {
                proposedEventCount++;
                (IInbox.Proposal memory emittedProposal,) = 
                    abi.decode(logs[i].data, (IInbox.Proposal, IInbox.CoreState));
                
                // Should be regular proposal
                assertEq(emittedProposal.id, 1);
                assertFalse(emittedProposal.isForcedInclusion);
            }
        }
        
        assertEq(proposedEventCount, 1, "Should emit only one Proposed event");
    }
    
    /// @notice Test forced inclusion with different blob parameters
    /// @dev Verifies that forced inclusion blob parameters are correctly used
    /// Expected behavior: Forced inclusion proposal uses blob from ForcedInclusionStore
    function test_propose_forced_inclusion_blob_parameters() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(true);
        
        // Mock forced inclusion with specific blob parameters
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256("forced_blob");
        
        IForcedInclusionStore.ForcedInclusion memory forcedInclusion = 
            IForcedInclusionStore.ForcedInclusion({
                feeInGwei: 1000,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: 100,
                    timestamp: uint48(block.timestamp - 1 hours)
                })
            });
        
        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(
                IForcedInclusionStore.consumeOldestForcedInclusion.selector,
                Alice
            ),
            abi.encode(forcedInclusion)
        );
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Record logs
        vm.recordLogs();
        
        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
        
        // Verify forced inclusion proposal has correct blob parameters
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proposed(IInbox.Proposal,IInbox.CoreState)")) {
                (IInbox.Proposal memory emittedProposal,) = 
                    abi.decode(logs[i].data, (IInbox.Proposal, IInbox.CoreState));
                
                if (emittedProposal.isForcedInclusion) {
                    assertEq(emittedProposal.blobSlice.blobHashes[0], keccak256("forced_blob"));
                    assertEq(emittedProposal.blobSlice.offset, 100);
                    assertEq(emittedProposal.blobSlice.timestamp, uint48(block.timestamp - 1 hours));
                    break;
                }
            }
        }
    }
}