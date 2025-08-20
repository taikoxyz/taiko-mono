// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import "./InboxMockContracts.sol";

/// @title InboxOutOfOrderProving
/// @notice Tests for out-of-order proving and eventual chain advancement
/// @dev This test suite covers out-of-order proving scenarios:
///      - Proving proposals in reverse order with eventual finalization
///      - Finalization dependency on proof completeness
///      - Chain continuity requirements and sequential validation
/// @custom:security-contact security@taiko.xyz
contract InboxOutOfOrderProving is InboxTest {
    using InboxTestLib for *;

    // Override setupMockAddresses to use actual mock contracts
    function setupMockAddresses() internal override {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
    }

    function setUp() public virtual override {
        super.setUp();
    }

    /// @notice Test proving proposals out of order with eventual finalization
    /// @dev Validates that proposals can be proven in any order but finalize sequentially:
    ///      1. Creates multiple proposals in forward order (1,2,3)
    ///      2. Proves proposals in reverse order (3,2,1)
    ///      3. Finalizes all proposals in correct sequential order
    ///      4. Verifies proper chain advancement despite out-of-order proving
    function test_prove_out_of_order_then_finalize() public {
        setupBlobHashes();
        uint48 numProposals = 3;

        // Get initial parent hash
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockMiniHeader.hash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        // Phase 1: Create multiple proposals sequentially
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: initialParentHash,
                bondInstructionsHash: bytes32(0)
            });
            // Core state will be validated by the contract during propose()

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);

            // Include proposals array for validation
            IInbox.Proposal[] memory validationProposals;
            if (i == 1) {
                // First proposal needs genesis for validation
                validationProposals = new IInbox.Proposal[](1);
                validationProposals[0] = InboxTestLib.createGenesisProposal(proposalCoreState);
            } else {
                // Subsequent proposals need the previous proposal for validation
                validationProposals = new IInbox.Proposal[](1);
                validationProposals[0] = proposals[i - 2]; // Previous proposal
            }

            bytes memory proposalData = encodeProposeInputWithProposals(
                uint48(0),
                proposalCoreState,
                validationProposals,
                proposalBlobRef,
                emptyClaimRecords
            );

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);

            // Create the proposal that was stored
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", proposalBlobRef.blobStartIndex));

            IInbox.Derivation memory derivation = IInbox.Derivation({
                originBlockNumber: uint48(block.number - 1),
                originBlockHash: blockhash(block.number - 1),
                isForcedInclusion: false,
                basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: proposalBlobRef.offset,
                    timestamp: uint48(block.timestamp)
                })
            });

            proposals[i - 1] = IInbox.Proposal({
                id: i,
                proposer: Alice,
                timestamp: uint48(block.timestamp),
                coreStateHash: bytes32(0),
                derivationHash: keccak256(abi.encode(derivation))
            });

            // Store proposal for use in next iteration's validation
            proposals[i - 1].coreStateHash = keccak256(
                abi.encode(
                    IInbox.CoreState({
                        nextProposalId: i + 1,
                        lastFinalizedProposalId: 0,
                        lastFinalizedClaimHash: initialParentHash,
                        bondInstructionsHash: bytes32(0)
                    })
                )
            );
        }

        // Phase 2: Prove proposals in REVERSE order (3, 2, 1)
        bytes32[] memory claimHashes = new bytes32[](numProposals);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);

        // First, calculate all claim hashes in forward order (for parent relationships)
        bytes32 parentHash = initialParentHash;
        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            claims[i] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: parentHash,
                endBlockMiniHeader: IInbox.BlockMiniHeader({
                    number: uint48(100 + i * 10),
                    hash: keccak256(abi.encode(proposals[i].id, "endBlockHash")),
                    stateRoot: keccak256(abi.encode(proposals[i].id, "stateRoot"))
                }),
                designatedProver: Alice,
                actualProver: Alice
            });
            claimHashes[i] = keccak256(abi.encode(claims[i]));
            parentHash = claimHashes[i];
        }

        // Now prove them in reverse order
        for (uint48 i = numProposals; i > 0; i--) {
            uint48 index = i - 1;

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposals[index];
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claims[index];

            bytes memory proveData = encodeProveInput(proveProposals, proveClaims);
            bytes memory proof = bytes("valid_proof");

            vm.prank(Bob);
            inbox.prove(proveData, proof);

            // Verify claim record was stored with correct parent
            bytes32 claimParentHash = index == 0 ? initialParentHash : claimHashes[index - 1];
            bytes32 storedClaimHash = inbox.getClaimRecordHash(proposals[index].id, claimParentHash);
            assertTrue(storedClaimHash != bytes32(0));
        }

        // Phase 3: Attempt finalization - should finalize all in correct order
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);

        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0),
                claimHash: InboxTestLib.hashClaim(claims[i]),
                endBlockMiniHeaderHash: keccak256(abi.encode(claims[i].endBlockMiniHeader))
            });
        }

        // Setup for finalization
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        // Core state will be validated by the contract during propose()

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);

        // Expect final block update
        IInbox.Claim memory lastClaim = claims[numProposals - 1];
        expectSyncedBlockSave(
            lastClaim.endBlockMiniHeader.number,
            lastClaim.endBlockMiniHeader.hash,
            lastClaim.endBlockMiniHeader.stateRoot
        );

        // Submit new proposal that triggers finalization
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);

        // Include the last proposal for validation
        IInbox.Proposal[] memory finalValidationProposals = new IInbox.Proposal[](1);
        finalValidationProposals[0] = proposals[numProposals - 1];

        // When finalizing, we need to provide the endBlockMiniHeader from the last claim
        bytes memory proposeData = InboxTestAdapter.encodeProposeInputWithEndBlock(
            inboxType,
            uint48(0),
            coreState,
            finalValidationProposals,
            blobRef,
            claimRecords,
            lastClaim.endBlockMiniHeader
        );

        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Verify finalization occurred (we can't directly check core state hash
        // but we can verify by checking that the synced block save was called)
    }

    /// @notice Test that unproven proposals block finalization
    /// @dev Validates finalization dependency on complete proof chain:
    ///      1. Creates multiple proposals (1,2,3)
    ///      2. Proves only some proposals (1,3) leaving gap at 2
    ///      3. Attempts finalization and expects stopping at missing proof
    ///      4. Verifies proof requirement enforcement for chain continuity
    function test_unproven_proposals_block_finalization() public {
        setupBlobHashes();
        // Create genesis claim
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockMiniHeader.hash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        // Create 3 proposals
        for (uint48 i = 1; i <= 3; i++) {
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: initialParentHash,
                bondInstructionsHash: bytes32(0)
            });
            // Core state will be validated by the contract during propose()

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);

            // Include proposals array for validation
            bytes memory proposalData;
            if (i == 1) {
                // First proposal needs genesis for validation
                proposalData = encodeProposeInputWithGenesis(
                    uint48(0), proposalCoreState, proposalBlobRef, emptyClaimRecords
                );
            } else {
                // For subsequent proposals, we need to create the previous proposal structure
                (IInbox.Proposal memory prevProposal,) =
                    InboxTestLib.createProposal(i - 1, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
                prevProposal.coreStateHash = keccak256(
                    abi.encode(
                        IInbox.CoreState({
                            nextProposalId: i,
                            lastFinalizedProposalId: 0,
                            lastFinalizedClaimHash: initialParentHash,
                            bondInstructionsHash: bytes32(0)
                        })
                    )
                );

                proposalData = encodeProposeInputForSubsequent(
                    uint48(0), proposalCoreState, prevProposal, proposalBlobRef, emptyClaimRecords
                );
            }

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);
        }

        // Prove only proposals 1 and 3 (skip 2)
        for (uint48 i = 1; i <= 3; i += 2) {
            bytes32 storedProposalHash = inbox.getProposalHash(i);

            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", i % 10));

            // Create proposal with correct coreStateHash that was stored during submission
            IInbox.CoreState memory updatedCoreState = IInbox.CoreState({
                nextProposalId: i + 1,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: initialParentHash,
                bondInstructionsHash: bytes32(0)
            });

            IInbox.Derivation memory derivation = IInbox.Derivation({
                originBlockNumber: uint48(block.number - 1),
                originBlockHash: blockhash(block.number - 1),
                isForcedInclusion: false,
                basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: 0,
                    timestamp: uint48(block.timestamp)
                })
            });

            IInbox.Proposal memory proposal = IInbox.Proposal({
                id: i,
                proposer: Alice,
                timestamp: uint48(block.timestamp),
                coreStateHash: keccak256(abi.encode(updatedCoreState)),
                derivationHash: keccak256(abi.encode(derivation))
            });

            bytes32 parentHash = i == 1 ? initialParentHash : bytes32(uint256(999)); // Dummy parent
                // for 3
            IInbox.Claim memory claim = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: parentHash,
                endBlockMiniHeader: IInbox.BlockMiniHeader({
                    number: uint48(100 + i * 10),
                    hash: keccak256(abi.encode(i, "endBlockHash")),
                    stateRoot: keccak256(abi.encode(i, "stateRoot"))
                }),
                designatedProver: Alice,
                actualProver: Alice
            });

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claim;

            bytes memory proveData = encodeProveInput(proveProposals, proveClaims);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof"));
        }

        // Try to finalize - should only finalize proposal 1 because 2 is missing
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 4,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        // Core state will be validated by the contract during propose()

        // Only provide claim record for proposal 1
        bytes32 storedProposalHashForClaim = inbox.getProposalHash(1);
        IInbox.Claim memory claim1 = IInbox.Claim({
            proposalHash: storedProposalHashForClaim,
            parentClaimHash: initialParentHash,
            endBlockMiniHeader: IInbox.BlockMiniHeader({
                number: 110,
                hash: keccak256(abi.encode(1, "endBlockHash")),
                stateRoot: keccak256(abi.encode(1, "stateRoot"))
            }),
            designatedProver: Alice,
            actualProver: Alice
        });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = IInbox.ClaimRecord({
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0),
            claimHash: InboxTestLib.hashClaim(claim1),
            endBlockMiniHeaderHash: keccak256(abi.encode(claim1.endBlockMiniHeader))
        });

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);

        // Expect only proposal 1 to be finalized
        expectSyncedBlockSave(
            claim1.endBlockMiniHeader.number,
            claim1.endBlockMiniHeader.hash,
            claim1.endBlockMiniHeader.stateRoot
        );

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(4);

        // Create the last proposal for validation
        (IInbox.Proposal memory lastProposal,) =
            InboxTestLib.createProposal(3, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
        lastProposal.coreStateHash = keccak256(
            abi.encode(
                IInbox.CoreState({
                    nextProposalId: 4,
                    lastFinalizedProposalId: 0,
                    lastFinalizedClaimHash: initialParentHash,
                    bondInstructionsHash: bytes32(0)
                })
            )
        );

        // When finalizing, we need to provide the endBlockMiniHeader
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = lastProposal;

        bytes memory proposeData = InboxTestAdapter.encodeProposeInputWithEndBlock(
            inboxType,
            uint48(0),
            coreState,
            proposals,
            blobRef,
            claimRecords,
            claim1.endBlockMiniHeader // Use the header from the claim being finalized
        );

        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Proposal 1 should be finalized, but 2 and 3 should remain unfinalized
        // because 2 is missing its proof
    }
}
