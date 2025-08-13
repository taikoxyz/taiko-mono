// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "./TestInboxWithMockBlobs.sol";
import "./InboxMockContracts.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxChainAdvancement
/// @notice Tests for chain advancement through finalization and state transitions
/// @dev Tests cover finalization flow, chain continuity, and state progression
contract InboxChainAdvancement is CommonTest {
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
    event Proved(IInbox.Proposal proposal, IInbox.ClaimRecord claimRecord);

    function setUp() public virtual override {
        super.setUp();

        // Deploy mock contracts
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());

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
        vm.deal(Carol, 100 ether);

        // Setup blob hashes
        setupBlobHashes();
    }

    /// @notice Test sequential chain advancement through finalization
    function test_sequential_chain_advancement() public {
        setupBlobHashes();
        uint48 numProposals = 5;

        // Get initial parent hash
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentHash = keccak256(abi.encode(genesisClaim));

        // Phase 1: Create and prove proposals sequentially
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            // Create and prove proposal
            (proposals[i - 1], claims[i - 1]) = createAndProveProposal(i, parentHash);

            // Update parent hash for next iteration
            parentHash = keccak256(abi.encode(claims[i - 1]));

            // Finalize immediately by proposing next with claim record
            if (i < numProposals) {
                finalizeProposal(i, claims, genesisClaim);
            }
        }

        // Verify all proposals were created and proven
        for (uint48 i = 1; i <= numProposals; i++) {
            bytes32 storedHash = inbox.getProposalHash(i);
            assertTrue(storedHash != bytes32(0));

            // Verify claim records exist
            bytes32 expectedParent =
                i == 1 ? keccak256(abi.encode(genesisClaim)) : keccak256(abi.encode(claims[i - 2]));
            bytes32 claimRecordHash = inbox.getClaimRecordHash(i, expectedParent);
            assertTrue(claimRecordHash != bytes32(0));
        }
    }

    function createAndProveProposal(
        uint48 proposalId,
        bytes32 parentHash
    )
        internal
        returns (IInbox.Proposal memory proposal, IInbox.Claim memory claim)
    {
        // Create proposal
        IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
            nextProposalId: proposalId,
            lastFinalizedProposalId: proposalId - 1,
            lastFinalizedClaimHash: parentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(proposalId);
        IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
        bytes memory proposalData =
            abi.encode(uint64(0), proposalCoreState, proposalBlobRef, emptyClaimRecords);

        vm.prank(Alice);
        inbox.propose(bytes(""), proposalData);

        // Store proposal
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", (proposalId - 1) % 10));

        proposal = IInbox.Proposal({
            id: proposalId,
            proposer: Alice,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: proposalBlobRef.offset,
                timestamp: uint48(block.timestamp)
            })
        });

        // Prove proposal immediately
        bytes32 storedProposalHash = inbox.getProposalHash(proposalId);

        claim = IInbox.Claim({
            proposalHash: storedProposalHash,
            parentClaimHash: parentHash,
            endBlockNumber: uint48(100 + proposalId * 10),
            endBlockHash: keccak256(abi.encode(proposalId, "endBlockHash")),
            endStateRoot: keccak256(abi.encode(proposalId, "stateRoot")),
            designatedProver: Alice,
            actualProver: Alice
        });

        mockProofVerification(true);

        IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
        proveProposals[0] = proposal;
        IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
        proveClaims[0] = claim;

        bytes memory proveData = abi.encode(proveProposals, proveClaims);
        bytes memory proof = bytes("valid_proof");

        vm.prank(Bob);
        inbox.prove(proveData, proof);
    }

    function finalizeProposal(
        uint48 proposalId,
        IInbox.Claim[] memory claims,
        IInbox.Claim memory genesisClaim
    )
        internal
    {
        bytes32 lastFinalizedHash;
        if (proposalId == 1) {
            lastFinalizedHash = keccak256(abi.encode(genesisClaim));
        } else {
            lastFinalizedHash = keccak256(abi.encode(claims[proposalId - 2]));
        }

        IInbox.CoreState memory finalizeCoreState = IInbox.CoreState({
            nextProposalId: proposalId + 1,
            lastFinalizedProposalId: proposalId - 1,
            lastFinalizedClaimHash: lastFinalizedHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(finalizeCoreState)));

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = IInbox.ClaimRecord({
            claim: claims[proposalId - 1],
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        // Expect synced block save
        expectSyncedBlockSave(
            claims[proposalId - 1].endBlockNumber,
            claims[proposalId - 1].endBlockHash,
            claims[proposalId - 1].endStateRoot
        );

        LibBlobs.BlobReference memory nextBlobRef = createValidBlobReference(proposalId + 1);
        bytes memory finalizeProposeData =
            abi.encode(uint64(0), finalizeCoreState, nextBlobRef, claimRecords);

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);
        setupBlobHashes();
        vm.prank(Carol);
        inbox.propose(bytes(""), finalizeProposeData);
    }

    /// @notice Test batch finalization of multiple proposals
    function test_batch_finalization() public {
        // Create and prove 5 proposals
        uint48 numProposals = 5;

        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentHash = keccak256(abi.encode(genesisClaim));

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);
        bytes32[] memory claimHashes = new bytes32[](numProposals);

        // Create all proposals first
        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: parentHash,
                bondInstructionsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                abi.encode(uint64(0), proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.startPrank(Alice);
            setupBlobHashes();
            inbox.propose(bytes(""), proposalData);
            vm.stopPrank();

            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", (i - 1) % 10));

            proposals[i - 1] = IInbox.Proposal({
                id: i,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: 0,
                    timestamp: uint48(block.timestamp)
                })
            });
        }

        // Prove all proposals with correct parent chain
        bytes32 currentParent = parentHash;
        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            claims[i] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: currentParent,
                endBlockNumber: uint48(100 + (i + 1) * 10),
                endBlockHash: keccak256(abi.encode(i + 1, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(i + 1, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });

            claimHashes[i] = keccak256(abi.encode(claims[i]));

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposals[i];
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claims[i];

            bytes memory proveData = abi.encode(proveProposals, proveClaims);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof"));

            currentParent = claimHashes[i];
        }

        // Batch finalize all proposals in one transaction
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);
        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0)
            });
        }

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: parentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Expect final block update
        expectSyncedBlockSave(
            claims[numProposals - 1].endBlockNumber,
            claims[numProposals - 1].endBlockHash,
            claims[numProposals - 1].endStateRoot
        );

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);
        setupBlobHashes();
        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);
    }

    /// @notice Test chain advancement with gaps (missing proofs)
    function test_chain_advancement_with_gaps() public {
        setupBlobHashes();
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentHash = keccak256(abi.encode(genesisClaim));

        // Create 5 proposals
        for (uint48 i = 1; i <= 5; i++) {
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: parentHash,
                bondInstructionsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                abi.encode(uint64(0), proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.startPrank(Alice);
            setupBlobHashes();
            inbox.propose(bytes(""), proposalData);
            vm.stopPrank();
        }

        // Prove only proposals 1, 2, 4, 5 (skip 3)
        bytes32 currentParent = parentHash;
        IInbox.Claim[] memory claims = new IInbox.Claim[](5);

        for (uint48 i = 1; i <= 5; i++) {
            if (i == 3) continue; // Skip proposal 3

            bytes32 storedProposalHash = inbox.getProposalHash(i);

            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", (i - 1) % 10));
            
            IInbox.Proposal memory proposal = IInbox.Proposal({
                id: i,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: 0,
                    timestamp: uint48(block.timestamp)
                })
            });

            claims[i - 1] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: currentParent,
                endBlockNumber: uint48(100 + i * 10),
                endBlockHash: keccak256(abi.encode(i, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(i, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claims[i - 1];

            bytes memory proveData = abi.encode(proveProposals, proveClaims);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof"));

            if (i <= 2) {
                currentParent = keccak256(abi.encode(claims[i - 1]));
            }
        }

        // Try to finalize - should only finalize 1 and 2 (3 is missing)
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](2);
        for (uint48 i = 0; i < 2; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0)
            });
        }

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 6,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: parentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Expect only proposal 2's block to be saved (last finalized)
        expectSyncedBlockSave(
            claims[1].endBlockNumber, claims[1].endBlockHash, claims[1].endStateRoot
        );

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(6);
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);
        setupBlobHashes();
        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Proposals 1 and 2 should be finalized, 3-5 remain unfinalized
    }

    /// @notice Test max finalization count limit
    /// @dev TODO: This test needs to be fixed - the claim records are not being encoded properly
    function disabled_test_max_finalization_count_limit() public {
        setupBlobHashes();
        // Set max finalization count to 3
        IInbox.Config memory config = defaultConfig;
        config.maxFinalizationCount = 3;
        inbox.setTestConfig(config);

        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentHash = keccak256(abi.encode(genesisClaim));

        // Create and prove 10 proposals
        uint48 numProposals = 10;
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            // Create proposal
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: parentHash,
                bondInstructionsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                abi.encode(uint64(0), proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.startPrank(Alice);
            setupBlobHashes();
            inbox.propose(bytes(""), proposalData);
            vm.stopPrank();

            // Prove proposal
            bytes32 storedProposalHash = inbox.getProposalHash(i);

            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", (i - 1) % 10));

            IInbox.Proposal memory proposal = IInbox.Proposal({
                id: i,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: config.basefeeSharingPctg,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: 0,
                    timestamp: uint48(block.timestamp)
                })
            });

            bytes32 currentParent = i == 1 ? parentHash : keccak256(abi.encode(claims[i - 2]));
            claims[i - 1] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: currentParent,
                endBlockNumber: uint48(100 + i * 10),
                endBlockHash: keccak256(abi.encode(i, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(i, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claims[i - 1];

            bytes memory proveData = abi.encode(proveProposals, proveClaims);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof"));
        }

        // Try to finalize - contract will only process first 3 due to maxFinalizationCount
        // We provide exactly 3 claim records (the max that can be finalized)
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](3);
        for (uint48 i = 0; i < 3; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0)
            });
        }

        // Core state should have nextProposalId as 11 since we created 10 proposals
        // But we're starting from lastFinalizedProposalId: 0
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: parentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Expect only proposal 3's block to be saved (due to max finalization count)
        expectSyncedBlockSave(
            claims[2].endBlockNumber, // Only first 3 will be finalized
            claims[2].endBlockHash,
            claims[2].endStateRoot
        );

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);
        setupBlobHashes();
        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Only first 3 proposals should be finalized
    }

    // Helper functions

    function createValidBlobReference(uint256 _seed)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return LibBlobs.BlobReference({
            blobStartIndex: uint48((_seed - 1) % 10), // Use _seed - 1 to match 0-based indexing
            numBlobs: 1,
            offset: 0
        });
    }

    function mockProposerAllowed(address) internal {
        // Stub contract always allows proposers, no need to mock
    }

    function mockForcedInclusionDue(bool _isDue) internal {
        // Stub contract always returns false, only mock if true is needed
        if (_isDue) {
            vm.mockCall(
                forcedInclusionStore,
                abi.encodeWithSelector(IForcedInclusionStore.isOldestForcedInclusionDue.selector),
                abi.encode(_isDue)
            );
        }
    }

    function mockProofVerification(bool _valid) internal {
        // Stub contract always passes verification, no need to mock
        if (!_valid) {
            vm.mockCallRevert(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                abi.encode("Invalid proof")
            );
        }
    }

    function expectSyncedBlockSave(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
    {
        vm.expectCall(
            syncedBlockManager,
            abi.encodeWithSelector(
                ISyncedBlockManager.saveSyncedBlock.selector, _blockNumber, _blockHash, _stateRoot
            )
        );
    }

    function setupBlobHashes() internal {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                hashes[i] = keccak256(abi.encode("blob", i));
            }
        }
        vm.blobhashes(hashes);
    }
}
