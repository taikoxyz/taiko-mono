// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import "./InboxMockContracts.sol";
import {
    Inbox,
    InvalidState,
    DeadlineExceeded,
    ExceedsUnfinalizedProposalCapacity
} from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxProposeValidation
/// @notice Tests for proposal validation logic including deadlines, state checks, and constraints
/// @dev Tests cover all validation aspects of the propose function
/// @custom:security-contact security@taiko.xyz
contract InboxProposeValidation is InboxTest {
    using InboxTestLib for *;

    // Override setupMockAddresses to use actual mock contracts
    function setupMockAddresses() internal override {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
    }

    /// @notice Test proposal with valid deadline
    function test_propose_with_valid_deadline() public {
        setupBlobHashes();

        // Setup core state with genesis
        bytes32 genesisHash = getGenesisClaimHash();
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));
        inbox.exposed_setCoreStateHash(InboxTestLib.hashCoreState(coreState));

        // Setup mocks and create proposal with future deadline
        setupProposalMocks(Alice);
        uint64 deadline = uint64(block.timestamp + 1 hours);

        bytes memory data = InboxTestLib.encodeProposalData(
            deadline, coreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify proposal was created
        assertProposalStored(1);
    }

    /// @notice Test proposal with expired deadline
    function test_propose_with_expired_deadline() public {
        setupBlobHashes();
        vm.warp(1000);

        // Setup core state
        bytes32 genesisHash = getGenesisClaimHash();
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));
        inbox.exposed_setCoreStateHash(InboxTestLib.hashCoreState(coreState));

        // Create proposal with expired deadline
        setupProposalMocks(Alice);
        uint64 deadline = uint64(block.timestamp - 1);

        bytes memory data = InboxTestLib.encodeProposalData(
            deadline, coreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with zero deadline (no deadline)
    function test_propose_with_no_deadline() public {
        setupBlobHashes();

        // Setup core state
        bytes32 genesisHash = getGenesisClaimHash();
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));
        inbox.exposed_setCoreStateHash(InboxTestLib.hashCoreState(coreState));

        // Create proposal with no deadline (deadline = 0)
        setupProposalMocks(Alice);

        bytes memory data = InboxTestLib.encodeProposalData(
            coreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Should succeed with no deadline
        assertProposalStored(1);
    }

    /// @notice Test proposal with invalid core state hash
    function test_propose_with_invalid_state_hash() public {
        bytes32 genesisHash = getGenesisClaimHash();

        // Set correct core state in storage
        IInbox.CoreState memory actualCoreState =
            InboxTestLib.createCoreState(1, 0, genesisHash, bytes32(0));
        inbox.exposed_setCoreStateHash(InboxTestLib.hashCoreState(actualCoreState));

        // But provide different core state in proposal
        IInbox.CoreState memory wrongCoreState =
            InboxTestLib.createCoreState(2, 0, genesisHash, bytes32(0)); // Wrong nextProposalId

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

        vm.expectRevert(LibBlobs.InvalidBlobReference.selector);
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

        vm.expectRevert(LibBlobs.BlobNotFound.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    // Override setupBlobHashes to support custom test cases
    function setupBlobHashes() internal override {
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
