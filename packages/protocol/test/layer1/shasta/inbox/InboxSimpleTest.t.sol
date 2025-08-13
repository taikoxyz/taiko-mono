// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/libs/LibDecoder.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxSimpleTest  
/// @notice Simple tests for core Inbox functionality without blob validation
contract InboxSimpleTest is CommonTest {
    using LibDecoder for bytes;

    TestInboxSimple internal inbox;
    
    // Mock dependencies
    address internal bondToken;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // Events
    event CoreStateSet(IInbox.CoreState coreState);
    event Proposed(IInbox.Proposal proposal, IInbox.CoreState coreState);

    function setUp() public virtual override {
        super.setUp();

        // Create mock addresses
        bondToken = address(new MockERC20Simple());
        syncedBlockManager = makeAddr("syncedBlockManager");
        forcedInclusionStore = makeAddr("forcedInclusionStore");
        proofVerifier = makeAddr("proofVerifier");
        proposerChecker = makeAddr("proposerChecker");

        // Deploy and initialize inbox
        TestInboxSimple impl = new TestInboxSimple();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), 
            address(this), 
            GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        inbox = TestInboxSimple(address(proxy));

        // Set config on the inbox
        IInbox.Config memory config = IInbox.Config({
            bondToken: bondToken,
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 100,
            basefeeSharingPctg: 10,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });
        inbox.setTestConfig(config);

        // Fund test accounts
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
    }

    /// @notice Test that the genesis block is set correctly
    function test_genesis_block_initialization() public view {
        bytes32 storedHash = inbox.getCoreStateHash();
        
        IInbox.CoreState memory expectedCoreState;
        expectedCoreState.nextProposalId = 1;
        
        IInbox.Claim memory claim;
        claim.endBlockHash = GENESIS_BLOCK_HASH;
        expectedCoreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));

        bytes32 expectedHash = keccak256(abi.encode(expectedCoreState));
        assertEq(storedHash, expectedHash);
    }

    /// @notice Test core state updates
    function test_core_state_updates() public {
        IInbox.CoreState memory newState = IInbox.CoreState({
            nextProposalId: 5,
            lastFinalizedProposalId: 3,
            lastFinalizedClaimHash: bytes32(uint256(123)),
            bondInstructionsHash: bytes32(uint256(456))
        });

        inbox.exposed_setCoreStateHash(keccak256(abi.encode(newState)));
        
        bytes32 storedHash = inbox.getCoreStateHash();
        assertEq(storedHash, keccak256(abi.encode(newState)));
    }

    /// @notice Test proposal hash storage in ring buffer
    function test_proposal_hash_storage() public {
        uint48 proposalId = 42;
        bytes32 proposalHash = keccak256("test proposal");
        
        inbox.exposed_setProposalHash(proposalId, proposalHash);
        
        bytes32 retrievedHash = inbox.getProposalHash(proposalId);
        assertEq(retrievedHash, proposalHash);
    }

    /// @notice Test ring buffer wrapping
    function test_ring_buffer_wrapping() public {
        uint256 ringBufferSize = 100; // from config
        
        uint48 proposalId1 = 5;
        uint48 proposalId2 = 105; // Should wrap to same slot as proposalId1
        
        bytes32 hash1 = keccak256("proposal 1");
        bytes32 hash2 = keccak256("proposal 2");
        
        // Store first proposal
        inbox.exposed_setProposalHash(proposalId1, hash1);
        assertEq(inbox.getProposalHash(proposalId1), hash1);
        
        // Store second proposal in same slot (overwrites)
        inbox.exposed_setProposalHash(proposalId2, hash2);
        assertEq(inbox.getProposalHash(proposalId2), hash2);
        
        // First proposal hash should be overwritten
        assertEq(inbox.getProposalHash(proposalId1), hash2);
    }

    /// @notice Test claim record hash storage
    function test_claim_record_hash_storage() public {
        uint48 proposalId = 10;
        bytes32 parentClaimHash = keccak256("parent claim");
        bytes32 claimRecordHash = keccak256("claim record");
        
        inbox.exposed_setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash);
        
        bytes32 retrievedHash = inbox.getClaimRecordHash(proposalId, parentClaimHash);
        assertEq(retrievedHash, claimRecordHash);
    }

    /// @notice Test invalid state revert
    function test_propose_invalid_state_reverts() public {
        // Setup initial core state
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mock for proposer check
        vm.mockCall(
            proposerChecker,
            abi.encodeWithSelector(bytes4(keccak256("checkProposer(address)")), Alice),
            abi.encode()
        );

        // Mock forced inclusion check
        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(bytes4(keccak256("isOldestForcedInclusionDue()"))),
            abi.encode(false)
        );

        // Create proposal data with wrong core state
        IInbox.CoreState memory wrongCoreState = IInbox.CoreState({
            nextProposalId: 2, // Wrong!
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        // Use empty blob reference to avoid blob validation
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 0,
            numBlobs: 0, // Empty to bypass validation
            offset: 0
        });
        
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(uint64(0), wrongCoreState, blobRef, claimRecords);

        // Expect revert with InvalidState error
        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }
}

// Test contract that exposes internal functions and bypasses blob validation
contract TestInboxSimple is Inbox {
    IInbox.Config private testConfig;

    function setTestConfig(IInbox.Config memory _config) external {
        testConfig = _config;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return testConfig;
    }

    function exposed_setCoreStateHash(bytes32 _hash) external {
        coreStateHash = _hash;
    }

    function getCoreStateHash() external view returns (bytes32) {
        return coreStateHash;
    }

    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external {
        uint256 slot = _proposalId % testConfig.ringBufferSize;
        proposalRingBuffer[slot].proposalHash = _hash;
    }

    function exposed_setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    ) external {
        uint256 slot = _proposalId % testConfig.ringBufferSize;
        proposalRingBuffer[slot].claimHashLookup[_parentClaimHash].claimRecordHash = _claimRecordHash;
    }
}

// Simple mock ERC20
contract MockERC20Simple {
    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
}