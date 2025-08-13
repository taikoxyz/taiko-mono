// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "./TestInboxWithMockBlobs.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxProposeValidation
/// @notice Tests for proposal validation logic including deadlines, state checks, and constraints
/// @dev Tests cover all validation aspects of the propose function
contract InboxProposeValidation is CommonTest {
    TestInboxWithMockBlobs internal inbox;
    IInbox.Config internal defaultConfig;

    // Mock dependencies
    address internal bondToken;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // Events
    event Proposed(IInbox.Proposal proposal, IInbox.CoreState coreState);

    function setUp() public virtual override {
        super.setUp();

        // Create mock addresses
        bondToken = makeAddr("bondToken");
        syncedBlockManager = makeAddr("syncedBlockManager");
        forcedInclusionStore = makeAddr("forcedInclusionStore");
        proofVerifier = makeAddr("proofVerifier");
        proposerChecker = makeAddr("proposerChecker");

        // Deploy and initialize inbox
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(this), GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        inbox = TestInboxWithMockBlobs(address(proxy));

        // Set default config
        defaultConfig = IInbox.Config({
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
        inbox.setTestConfig(defaultConfig);

        // Fund test accounts
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);

        // Setup blob hashes
        setupBlobHashes();
    }

    /// @notice Test proposal with valid deadline
    function test_propose_with_valid_deadline() public {
        setupBlobHashes();
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Set deadline 1 hour in the future
        uint64 deadline = uint64(block.timestamp + 1 hours);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(deadline, coreState, blobRef, claimRecords);

        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify proposal was created
        bytes32 storedHash = inbox.getProposalHash(1);
        assertTrue(storedHash != bytes32(0));
    }

    /// @notice Test proposal with expired deadline
    function test_propose_with_expired_deadline() public {
        setupBlobHashes();

        // Move time forward to ensure block.timestamp > 1
        vm.warp(1000);

        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Set deadline in the past
        uint64 deadline = uint64(block.timestamp - 1);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(deadline, coreState, blobRef, claimRecords);

        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with zero deadline (no deadline)
    function test_propose_with_no_deadline() public {
        setupBlobHashes();
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Zero deadline means no deadline
        uint64 deadline = 0;

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(deadline, coreState, blobRef, claimRecords);

        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Should succeed with no deadline
        bytes32 storedHash = inbox.getProposalHash(1);
        assertTrue(storedHash != bytes32(0));
    }

    /// @notice Test proposal with invalid core state hash
    function test_propose_with_invalid_state_hash() public {
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        // Set one core state in storage
        IInbox.CoreState memory actualCoreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(actualCoreState)));

        // But provide different core state in proposal
        IInbox.CoreState memory wrongCoreState = IInbox.CoreState({
            nextProposalId: 2, // Wrong!
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(uint64(0), wrongCoreState, blobRef, claimRecords);

        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal from unauthorized proposer
    function test_propose_unauthorized_proposer() public {
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Mock proposer not allowed
        vm.mockCallRevert(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, Bob),
            abi.encode("Not authorized")
        );
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        vm.expectRevert();
        vm.prank(Bob);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with forced inclusion
    function test_propose_with_forced_inclusion() public {
        setupBlobHashes();
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);

        // Mock forced inclusion is due
        mockForcedInclusionDue(true);

        // Mock consuming forced inclusion
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("forced_blob", 0));

        IForcedInclusionStore.ForcedInclusion memory forcedInclusion = IForcedInclusionStore
            .ForcedInclusion({
            feeInGwei: 10,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(
                IForcedInclusionStore.consumeOldestForcedInclusion.selector, Alice
            ),
            abi.encode(forcedInclusion)
        );

        // Regular proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(2);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        // Expect two Proposed events - one for forced, one for regular
        vm.expectEmit(false, false, false, false);
        emit Proposed(
            IInbox.Proposal({
                id: 1,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: true,
                basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
                blobSlice: forcedInclusion.blobSlice
            }),
            coreState
        );

        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify both proposals were created
        bytes32 storedHash1 = inbox.getProposalHash(1);
        bytes32 storedHash2 = inbox.getProposalHash(2);
        assertTrue(storedHash1 != bytes32(0));
        assertTrue(storedHash2 != bytes32(0));
    }

    /// @notice Test proposal exceeding unfinalized capacity
    function test_propose_exceeds_capacity() public {
        setupBlobHashes();
        // Set small ring buffer size
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 3; // Capacity = 2
        inbox.setTestConfig(config);

        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        // Create 2 proposals (fills capacity)
        for (uint48 i = 1; i <= 2; i++) {
            IInbox.CoreState memory coreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: initialParentHash,
                bondInstructionsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory blobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), data);
        }

        // Try to add 3rd proposal (exceeds capacity)
        IInbox.CoreState memory coreState3 = IInbox.CoreState({
            nextProposalId: 3,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState3)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef3 = createValidBlobReference(3);
        IInbox.ClaimRecord[] memory claimRecords3 = new IInbox.ClaimRecord[](0);
        bytes memory data3 = abi.encode(uint64(0), coreState3, blobRef3, claimRecords3);

        vm.expectRevert(ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data3);
    }

    /// @notice Test proposal with invalid blob reference
    function test_propose_invalid_blob_reference() public {
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Invalid blob reference with numBlobs = 0
        LibBlobs.BlobReference memory invalidBlobRef = LibBlobs.BlobReference({
            blobStartIndex: 0,
            numBlobs: 0, // Invalid!
            offset: 0
        });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(uint64(0), coreState, invalidBlobRef, claimRecords);

        vm.expectRevert(InvalidBlobReference.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with blob not found
    function test_propose_blob_not_found() public {
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Reference a blob that doesn't exist (index 100)
        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 100, // Doesn't exist in our setup
            numBlobs: 1,
            offset: 0
        });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        vm.expectRevert(BlobNotFound.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    // Helper functions

    function createValidBlobReference(uint256 _seed)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return
            LibBlobs.BlobReference({ blobStartIndex: uint48(_seed % 10), numBlobs: 1, offset: 0 });
    }

    function mockProposerAllowed(address _proposer) internal {
        vm.mockCall(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, _proposer),
            abi.encode()
        );
    }

    function mockForcedInclusionDue(bool _isDue) internal {
        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(IForcedInclusionStore.isOldestForcedInclusionDue.selector),
            abi.encode(_isDue)
        );
    }

    function setupBlobHashes() internal {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                hashes[i] = keccak256(abi.encode("blob", i));
            } else if (i == 100) {
                // Leave index 100 empty for testing blob not found
                hashes[i] = bytes32(0);
            }
        }
        vm.blobhashes(hashes);
    }
}

// Import errors
error InvalidBlobReference();
error BlobNotFound();
