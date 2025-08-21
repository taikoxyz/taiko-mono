// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./MockContracts.sol";

/// @title InboxTestBase
/// @notice Base setup and helpers for Inbox tests
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTestBase is CommonTest {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------
    
    IInbox internal inbox;
    
    // Mock contracts
    MockERC20 internal bondToken;
    MockSyncedBlockManager internal syncedBlockManager;
    MockProofVerifier internal proofVerifier;
    MockProposerChecker internal proposerChecker;
    MockForcedInclusionStore internal forcedInclusionStore;
    
    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));
    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint48 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint48 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    
    // Test blob hashes
    bytes32[] internal testBlobHashes;
    
    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------
    
    function setupMocks() internal {
        bondToken = new MockERC20();
        syncedBlockManager = new MockSyncedBlockManager();
        proofVerifier = new MockProofVerifier();
        proposerChecker = new MockProposerChecker();
        forcedInclusionStore = new MockForcedInclusionStore();
        
        // Setup test blob hashes for EIP-4844
        testBlobHashes = new bytes32[](3);
        testBlobHashes[0] = keccak256("blob1");
        testBlobHashes[1] = keccak256("blob2");
        testBlobHashes[2] = keccak256("blob3");
    }
    
    function getDefaultConfig() internal view returns (IInbox.Config memory) {
        return IInbox.Config({
            ringBufferSize: DEFAULT_RING_BUFFER_SIZE,
            provingWindow: DEFAULT_PROVING_WINDOW,
            extendedProvingWindow: DEFAULT_EXTENDED_PROVING_WINDOW,
            maxFinalizationCount: DEFAULT_MAX_FINALIZATION_COUNT,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            bondToken: address(bondToken),
            syncedBlockManager: address(syncedBlockManager),
            proofVerifier: address(proofVerifier),
            proposerChecker: address(proposerChecker),
            forcedInclusionStore: address(forcedInclusionStore)
        });
    }
    
    // ---------------------------------------------------------------
    // Data Builders
    // ---------------------------------------------------------------
    
    function createProposeInput(
        uint48 _proposalId
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: getGenesisClaimHash(),
            bondInstructionsHash: bytes32(0)
        });
        
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = createProposal(_proposalId - 1, coreState);
        
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 0,
            numBlobs: 1,
            offset: 0
        });
        
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
    
    function createProposal(
        uint48 _id,
        IInbox.CoreState memory _coreState
    )
        internal
        view
        returns (IInbox.Proposal memory)
    {
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: testBlobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
        
        return IInbox.Proposal({
            id: _id,
            proposer: Alice,
            timestamp: uint48(block.timestamp),
            coreStateHash: keccak256(abi.encode(_coreState)),
            derivationHash: keccak256(abi.encode(derivation))
        });
    }
    
    function getGenesisClaimHash() internal pure returns (bytes32) {
        IInbox.Claim memory claim;
        claim.endBlockMiniHeader.hash = GENESIS_BLOCK_HASH;
        return keccak256(abi.encode(claim));
    }
    
    function createGenesisProposal() internal view returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: getGenesisClaimHash(),
            bondInstructionsHash: bytes32(0)
        });
        
        IInbox.Derivation memory derivation;
        
        return IInbox.Proposal({
            id: 0,
            proposer: address(0),
            timestamp: 0,
            coreStateHash: keccak256(abi.encode(coreState)),
            derivationHash: keccak256(abi.encode(derivation))
        });
    }
    
    // ---------------------------------------------------------------
    // Mock Blob Hash Function
    // ---------------------------------------------------------------
    
    function setupBlobHashes() internal {
        // Mock the blobhash function for testing
        vm.blobhashes(testBlobHashes);
    }
    
    // ---------------------------------------------------------------
    // Abstract Functions
    // ---------------------------------------------------------------
    
    function deployInbox() internal virtual returns (IInbox);
}