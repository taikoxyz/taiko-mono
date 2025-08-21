// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

/// @title InboxTest
/// @notice All common tests for Inbox implementations
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTest is InboxTestBase {
    
    function setUp() public virtual override {
        // Setup mocks
        setupMocks();
        
        // Deploy inbox through implementation-specific method
        inbox = deployInbox();
        
        // Setup blob hashes for testing
        setupBlobHashes();
        
        // Advance block to ensure we have block history
        vm.roll(100);
        vm.warp(1000);
    }
    
    // ---------------------------------------------------------------
    // Propose Tests
    // ---------------------------------------------------------------
    
    function test_propose_single() public {
        // Arrange: Create the first proposal input after genesis
        bytes memory proposeData = createFirstProposeInput();
        
        // Build expected event data
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);
        
        // Expect the Proposed event with the correct data
        vm.expectEmit();
        emit IInbox.Proposed(abi.encode(expectedPayload));
        
        // Act: Submit the proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), proposeData);
        
        // Assert: Verify proposal hash is stored
        bytes32 storedHash = inbox.getProposalHash(1);
        assertTrue(storedHash != bytes32(0), "Proposal hash should be stored");
    }
    
    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------
    
    function createFirstProposeInput() internal view returns (bytes memory) {
        // For the first proposal after genesis, we need specific state
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: getGenesisClaimHash(),
            bondInstructionsHash: bytes32(0)
        });
        
        // Parent proposal is genesis (id=0)
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = createGenesisProposal();
        
        // Create blob reference
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 0,
            numBlobs: 1,
            offset: 0
        });
        
        // Create the propose input
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: blobRef,
            endBlockMiniHeader: IInbox.BlockMiniHeader({
                number: uint48(block.number),
                hash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            claimRecords: new IInbox.ClaimRecord[](0)
        });
        
        return abi.encode(input);
    }
    
    function _buildExpectedProposedPayload(uint48 _proposalId) 
        internal 
        view 
        returns (IInbox.ProposedEventPayload memory) 
    {
        // Build the expected core state after proposal
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: getGenesisClaimHash(),
            bondInstructionsHash: bytes32(0)
        });
        
        // Build the expected derivation
        IInbox.Derivation memory expectedDerivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _getBlobHashesForTest(1),
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
        
        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: _proposalId,
            proposer: Alice,
            timestamp: uint48(block.timestamp),
            coreStateHash: keccak256(abi.encode(expectedCoreState)),
            derivationHash: keccak256(abi.encode(expectedDerivation))
        });
        
        return IInbox.ProposedEventPayload({
            proposal: expectedProposal,
            derivation: expectedDerivation,
            coreState: expectedCoreState
        });
    }
    
    function _getBlobHashesForTest(uint256 _numBlobs) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        return hashes;
    }
}