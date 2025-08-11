// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxProposeValidation  
/// @notice Tests for proposal validation and error conditions
/// @dev Tests cover all validation checks and error scenarios in the propose function
contract InboxProposeValidation is ShastaInboxTestBase {
    
    /// @notice Test proposal rejection when fork is not active
    /// @dev Verifies that proposals are rejected when fork activation height is not reached
    /// Expected behavior: Transaction reverts with ForkNotActive error
    function test_propose_fork_not_active() public {
        // Set fork activation height to future
        IInbox.Config memory config = defaultConfig;
        config.forkActivationHeight = 1000;
        inbox.setConfig(config);
        
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Expect revert
        vm.expectRevert(Inbox.ForkNotActive.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }
    
    /// @notice Test proposal rejection for unauthorized proposer
    /// @dev Verifies that only authorized proposers can submit proposals
    /// Expected behavior: Transaction reverts when proposer check fails
    function test_propose_invalid_proposer() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Mock proposer not allowed
        mockProposerNotAllowed(Alice);
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Expect revert from proposer checker
        vm.expectRevert("Proposer not allowed");
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }
    
    /// @notice Test proposal rejection for insufficient bond
    /// @dev Verifies that proposers must have sufficient bond to submit proposals
    /// Expected behavior: Transaction reverts with ProposerBondInsufficient error
    function test_propose_insufficient_bond() public {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, false); // Insufficient bond
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Expect revert
        vm.expectRevert(Inbox.ProposerBondInsufficient.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }
    
    /// @notice Test proposal rejection with invalid core state hash
    /// @dev Verifies that the provided core state must match the stored hash
    /// Expected behavior: Transaction reverts with InvalidState error
    function test_propose_invalid_core_state() public {
        // Setup actual core state
        IInbox.CoreState memory actualCoreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(actualCoreState)));
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);
        
        // Create proposal data with mismatched core state
        IInbox.CoreState memory wrongCoreState = createCoreState(2, 0); // Wrong nextProposalId
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(wrongCoreState, blobRef, claimRecords);
        
        // Expect revert
        vm.expectRevert(Inbox.InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }
    
    /// @notice Test proposal rejection when exceeding unfinalized proposal capacity
    /// @dev Verifies that the number of unfinalized proposals cannot exceed ring buffer capacity - 1
    /// Expected behavior: Transaction reverts with ExceedsUnfinalizedProposalCapacity error
    function test_propose_exceeds_capacity() public {
        // Set small ring buffer for easier testing
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 5; // Capacity is 4 (size - 1)
        inbox.setConfig(config);
        
        // Setup core state with too many unfinalized proposals
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 5,
            lastFinalizedProposalId: 0, // 5 - 0 = 5 unfinalized, exceeds capacity of 4
            lastFinalizedClaimHash: bytes32(0),
            bondOperationsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);
        
        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);
        
        // Expect revert
        vm.expectRevert(Inbox.ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }
    
    /// @notice Test reentrancy protection on propose function
    /// @dev Verifies that the nonReentrant modifier prevents reentrancy attacks
    /// Expected behavior: Reentrancy attempt should fail
    function test_propose_reentrancy_protection() public {
        // Deploy a malicious contract that attempts reentrancy
        ReentrantProposer attacker = new ReentrantProposer(address(inbox));
        
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup mocks for attacker
        mockProposerAllowed(address(attacker));
        mockHasSufficientBond(address(attacker), true);
        mockForcedInclusionDue(false);
        
        // Expect reentrancy to fail
        vm.expectRevert("ReentrancyGuard: reentrant call");
        attacker.attack();
    }
}

/// @title ReentrantProposer
/// @notice Helper contract to test reentrancy protection
contract ReentrantProposer {
    TestInbox private inbox;
    bool private attacking;
    
    constructor(address _inbox) {
        inbox = TestInbox(_inbox);
    }
    
    function attack() external {
        attacking = true;
        
        // Create valid proposal data
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: bytes32(0),
            bondOperationsHash: bytes32(0)
        });
        
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 1,
            numBlobs: 1,
            offset: 0
        });
        
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(coreState, blobRef, claimRecords);
        
        // First call to propose (will trigger callback)
        inbox.propose(bytes(""), data);
    }
    
    // Receive function to handle plain ether transfers
    receive() external payable { }
    
    // Callback function that would be called if reentrancy were possible
    fallback() external payable {
        if (attacking) {
            attacking = false;
            
            // Try to reenter propose
            IInbox.CoreState memory coreState = IInbox.CoreState({
                nextProposalId: 2,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: bytes32(0),
                bondOperationsHash: bytes32(0)
            });
            
            LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
                blobStartIndex: 2,
                numBlobs: 1,
                offset: 0
            });
            
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = abi.encode(coreState, blobRef, claimRecords);
            
            inbox.propose(bytes(""), data);
        }
    }
}