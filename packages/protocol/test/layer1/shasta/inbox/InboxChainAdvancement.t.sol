// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestScenarios.sol";
import "./InboxTestUtils.sol";
import "./InboxMockContracts.sol";

/// @title InboxChainAdvancement
/// @notice Tests for chain advancement through finalization and state transitions
/// @dev Tests cover finalization flow, chain continuity, and state progression
contract InboxChainAdvancement is InboxTestScenarios {
    using InboxTestUtils for *;
    function setUp() public virtual override {
        super.setUp();
    }

    // Override setupMockAddresses to use actual mock contracts
    function setupMockAddresses() internal override {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
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
            blobHashes[0] = keccak256(abi.encode("blob", i % 10));

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
                actualProver: Bob
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
            blobHashes[0] = keccak256(abi.encode("blob", i % 10));

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
                actualProver: Bob
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
            blobHashes[0] = keccak256(abi.encode("blob", i % 10));

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
                actualProver: Bob
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

    /// @notice Test that max finalization count is enforced
    function test_max_finalization_count_limit() public {
        setupBlobHashes();
        uint48 numProposals = 15; // More than maxFinalizationCount (10)

        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentHash = keccak256(abi.encode(genesisClaim));

        // Create and prove all proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            (proposals[i - 1], claims[i - 1]) = createAndProveProposal(i, parentHash);
            parentHash = keccak256(abi.encode(claims[i - 1]));
        }

        // Try to finalize all at once (should only finalize up to maxFinalizationCount)
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
            lastFinalizedClaimHash: keccak256(abi.encode(genesisClaim)),
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);

        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Verify that only maxFinalizationCount proposals were finalized
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: numProposals + 2,
            lastFinalizedProposalId: uint48(defaultConfig.maxFinalizationCount),
            lastFinalizedClaimHash: keccak256(
                abi.encode(claims[defaultConfig.maxFinalizationCount - 1])
            ),
            bondInstructionsHash: bytes32(0)
        });

        bytes32 actualCoreStateHash = inbox.getCoreStateHash();
        assertEq(actualCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }

    // Additional helper functions specific to chain advancement tests

    function createAndProveProposal(
        uint48 proposalId,
        bytes32 parentHash
    )
        internal
        returns (IInbox.Proposal memory proposal, IInbox.Claim memory claim)
    {
        // Use scenario builder
        (proposal, claim) = submitAndProveProposal(proposalId, Alice, Alice, parentHash);
    }

    /// @notice Test proving 3 consecutive proposals together with bond instruction aggregation
    /// @dev This test demonstrates the bug but also shows how bond instructions should be
    /// aggregated
    function test_prove_three_consecutive_and_finalize_all() public {
        setupBlobHashes();

        // Setup genesis claim
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentHash = keccak256(abi.encode(genesisClaim));

        // Step 1: Create 3 consecutive proposals with different timestamps to trigger bond
        // instructions
        uint48 numProposals = 3;
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

        // Create proposals at different timestamps to trigger different bond instructions
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

            vm.prank(Alice);
            setupBlobHashes();
            inbox.propose(bytes(""), proposalData);

            // Store proposal for proving
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", i % 10));

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

        // Step 2: Advance time to make proofs late (triggers liveness bond instructions)
        // This ensures each claim will have bond instructions that should be aggregated
        vm.warp(block.timestamp + defaultConfig.provingWindow + 1);

        // Prove all 3 proposals together in one transaction
        // Each will have different designated provers to create different bond instructions
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);
        bytes32 currentParent = parentHash;
        address[3] memory designatedProvers = [Alice, Bob, Carol];

        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            claims[i] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: currentParent,
                endBlockNumber: uint48(100 + (i + 1) * 10),
                endBlockHash: keccak256(abi.encode(i + 1, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(i + 1, "stateRoot")),
                designatedProver: designatedProvers[i], // Different designated prover for each
                actualProver: David // Same actual prover for all (late proof)
             });

            currentParent = keccak256(abi.encode(claims[i]));
        }

        // Prove all 3 proposals together - they will be aggregated
        mockProofVerification(true);
        bytes memory proveData = abi.encode(proposals, claims);

        // Expect the Proved event to be emitted with the aggregated claim record
        // We need to capture this to verify bond instructions are aggregated correctly
        vm.expectEmit(true, true, true, true);

        // Create expected aggregated bond instructions for verification
        LibBonds.BondInstruction[] memory expectedBondInstructions =
            new LibBonds.BondInstruction[](3);
        expectedBondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: Alice,
            receiver: David
        });
        expectedBondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: Bob,
            receiver: David
        });
        expectedBondInstructions[2] = LibBonds.BondInstruction({
            proposalId: 3,
            bondType: LibBonds.BondType.LIVENESS,
            payer: Carol,
            receiver: David
        });

        // The aggregated claim record that should be emitted
        IInbox.ClaimRecord memory expectedAggregatedRecord = IInbox.ClaimRecord({
            claim: claims[0],
            span: 3,
            bondInstructions: expectedBondInstructions
        });

        emit Proved(proposals[0], expectedAggregatedRecord);

        // Now prove - this should aggregate all 3 proposals with their bond instructions
        vm.prank(David);
        inbox.prove(proveData, bytes("proof"));

        // Step 3: Verify the aggregated claim record is stored correctly
        // For proposal 1, the parent should be the genesis claim hash
        bytes32 claimRecordHash1 = inbox.getClaimRecordHash(1, parentHash);
        assertTrue(claimRecordHash1 != bytes32(0), "Claim record for proposal 1 should exist");

        // Verify the stored claim record hash matches what we expect
        bytes32 expectedClaimRecordHash = keccak256(abi.encode(expectedAggregatedRecord));
        assertEq(
            claimRecordHash1,
            expectedClaimRecordHash,
            "Stored claim record should match expected aggregated record"
        );

        // For proposals 2 and 3, they won't have separate claim records since they're aggregated
        // The finalization will use the aggregated record from proposal 1

        // Step 4: Finalize all 3 proposals with the single aggregated claim record
        // Use the same bond instructions we verified above for finalization
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = expectedAggregatedRecord; // Use the verified aggregated record

        // Double-check that all 3 bond instructions are present and correct
        assertEq(
            claimRecords[0].bondInstructions.length, 3, "Should have exactly 3 bond instructions"
        );

        // Verify each bond instruction individually
        assertEq(
            claimRecords[0].bondInstructions[0].proposalId,
            1,
            "First bond instruction should be for proposal 1"
        );
        assertEq(
            claimRecords[0].bondInstructions[0].payer,
            Alice,
            "First bond instruction payer should be Alice"
        );
        assertEq(
            claimRecords[0].bondInstructions[0].receiver,
            David,
            "First bond instruction receiver should be David"
        );
        assertTrue(
            claimRecords[0].bondInstructions[0].bondType == LibBonds.BondType.LIVENESS,
            "First should be liveness bond"
        );

        assertEq(
            claimRecords[0].bondInstructions[1].proposalId,
            2,
            "Second bond instruction should be for proposal 2"
        );
        assertEq(
            claimRecords[0].bondInstructions[1].payer,
            Bob,
            "Second bond instruction payer should be Bob"
        );
        assertEq(
            claimRecords[0].bondInstructions[1].receiver,
            David,
            "Second bond instruction receiver should be David"
        );
        assertTrue(
            claimRecords[0].bondInstructions[1].bondType == LibBonds.BondType.LIVENESS,
            "Second should be liveness bond"
        );

        assertEq(
            claimRecords[0].bondInstructions[2].proposalId,
            3,
            "Third bond instruction should be for proposal 3"
        );
        assertEq(
            claimRecords[0].bondInstructions[2].payer,
            Carol,
            "Third bond instruction payer should be Carol"
        );
        assertEq(
            claimRecords[0].bondInstructions[2].receiver,
            David,
            "Third bond instruction receiver should be David"
        );
        assertTrue(
            claimRecords[0].bondInstructions[2].bondType == LibBonds.BondType.LIVENESS,
            "Third should be liveness bond"
        );

        // Setup core state for finalization
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: parentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Expect synced block save for the last finalized proposal
        expectSyncedBlockSave(
            claims[0].endBlockNumber, // Using first claim since it's aggregated
            claims[0].endBlockHash,
            claims[0].endStateRoot
        );

        // Create next proposal with finalization
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);
        setupBlobHashes();
        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // All 3 proposals are now finalized with just 1 aggregated claim record!
    }

    /// @notice Test proving 3 consecutive proposals separately and finalizing all of them
    /// @dev This test shows the working path - prove each separately, then finalize all 3
    function test_prove_three_separately_finalize_together() public {
        setupBlobHashes();

        // Setup genesis claim
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentHash = keccak256(abi.encode(genesisClaim));

        // Step 1: Create 3 consecutive proposals
        uint48 numProposals = 3;
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

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

            vm.prank(Alice);
            setupBlobHashes();
            inbox.propose(bytes(""), proposalData);

            // Store proposal for proving
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", i % 10));

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

        // Step 2: Prove each proposal separately
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);
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
                actualProver: Bob
            });

            // Prove each proposal individually
            mockProofVerification(true);
            IInbox.Proposal[] memory singleProposal = new IInbox.Proposal[](1);
            singleProposal[0] = proposals[i];
            IInbox.Claim[] memory singleClaim = new IInbox.Claim[](1);
            singleClaim[0] = claims[i];

            bytes memory proveData = abi.encode(singleProposal, singleClaim);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof"));

            currentParent = keccak256(abi.encode(claims[i]));
        }

        // Verify all claim records are stored
        bytes32 expectedParent = parentHash;
        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 claimRecordHash = inbox.getClaimRecordHash(i + 1, expectedParent);
            assertTrue(claimRecordHash != bytes32(0), "Claim record should exist");
            expectedParent = keccak256(abi.encode(claims[i]));
        }

        // Step 3: Finalize all 3 proposals in one transaction
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);
        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0)
            });
        }

        // Setup core state for finalization
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: parentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Expect synced block save for the last finalized proposal
        expectSyncedBlockSave(
            claims[numProposals - 1].endBlockNumber,
            claims[numProposals - 1].endBlockHash,
            claims[numProposals - 1].endStateRoot
        );

        // Create next proposal with finalization of all 3
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);
        setupBlobHashes();
        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // All 3 proposals are finalized successfully
    }
}
