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
        checkpointManager = address(new StubCheckpointManager());
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
        IInbox.Transition memory genesisTransition;
        genesisTransition.checkpoint.blockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisTransition));

        // Phase 1: Create multiple proposals sequentially
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            // Calculate correct block for this proposal
            uint256 targetBlock = InboxTestLib.calculateProposalBlock(i, 2); // Base block 2
            vm.roll(targetBlock);

            // Calculate the correct nextProposalBlockId based on the current proposal
            uint48 nextBlockId;
            if (i == 1) {
                nextBlockId = 2; // Genesis value for first proposal (prevents blockhash(0))
            } else {
                // For subsequent proposals, it's previous proposal's block + 1
                uint256 prevProposalBlock = InboxTestLib.calculateProposalBlock(i - 1, 2);
                nextBlockId = uint48(prevProposalBlock + 1);
            }

            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                nextProposalBlockId: nextBlockId,
                lastFinalizedProposalId: 0,
                lastFinalizedTransitionHash: initialParentHash,
                bondInstructionsHash: bytes32(0)
            });
            // Core state will be validated by the contract during propose()

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.TransitionRecord[] memory emptyTransitionRecords =
                new IInbox.TransitionRecord[](0);

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
                emptyTransitionRecords
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
                endOfSubmissionWindowTimestamp: uint48(0), // Set to 0 as returned by
                    // mockProposerAllowed
                coreStateHash: bytes32(0),
                derivationHash: keccak256(abi.encode(derivation))
            });

            // Store proposal for use in next iteration's validation
            // The contract increments nextProposalId and sets nextProposalBlockId to block.number +
            // 2
            proposals[i - 1].coreStateHash = keccak256(
                abi.encode(
                    IInbox.CoreState({
                        nextProposalId: i + 1,
                        nextProposalBlockId: uint48(block.number + 1), // Single increment from
                            // contract
                        lastFinalizedProposalId: 0,
                        lastFinalizedTransitionHash: initialParentHash,
                        bondInstructionsHash: bytes32(0)
                    })
                )
            );
        }

        // Phase 2: Prove proposals in REVERSE order (3, 2, 1)
        bytes32[] memory transitionHashes = new bytes32[](numProposals);
        IInbox.Transition[] memory transitions = new IInbox.Transition[](numProposals);

        // First, calculate all transition hashes in forward order (for parent relationships)
        bytes32 parentHash = initialParentHash;
        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            transitions[i] = IInbox.Transition({
                proposalHash: storedProposalHash,
                parentTransitionHash: parentHash,
                checkpoint: ICheckpointManager.Checkpoint({
                    blockNumber: uint48(100 + i * 10),
                    blockHash: keccak256(abi.encode(proposals[i].id, "endBlockHash")),
                    stateRoot: keccak256(abi.encode(proposals[i].id, "stateRoot"))
                })
            });
            transitionHashes[i] = keccak256(abi.encode(transitions[i]));
            parentHash = transitionHashes[i];
        }

        // Now prove them in reverse order
        for (uint48 i = numProposals; i > 0; i--) {
            uint48 index = i - 1;

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposals[index];
            IInbox.Transition[] memory proveTransitions = new IInbox.Transition[](1);
            proveTransitions[0] = transitions[index];

            bytes memory proveData = encodeProveInput(proveProposals, proveTransitions);
            bytes memory proof = bytes("valid_proof");

            vm.prank(Bob);
            inbox.prove(proveData, proof);

            // Verify transition record was stored with correct parent
            bytes32 transitionParentHash =
                index == 0 ? initialParentHash : transitionHashes[index - 1];
            (, bytes26 recordHash) =
                inbox.getTransitionRecordHash(proposals[index].id, transitionParentHash);
            assertTrue(recordHash != bytes26(0));
        }

        // Phase 3: Attempt finalization - should finalize all in correct order
        IInbox.TransitionRecord[] memory transitionRecords =
            new IInbox.TransitionRecord[](numProposals);

        for (uint48 i = 0; i < numProposals; i++) {
            transitionRecords[i] = IInbox.TransitionRecord({
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0),
                transitionHash: InboxTestLib.hashTransition(transitions[i]),
                checkpointHash: keccak256(abi.encode(transitions[i].checkpoint))
            });
        }

        // Setup for finalization - calculate correct nextProposalBlockId
        uint256 lastProposalBlock = InboxTestLib.calculateProposalBlock(numProposals, 2);
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            nextProposalBlockId: uint48(lastProposalBlock + 1), // Previous proposal's block + 1
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        // Core state will be validated by the contract during propose()

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);

        // Advance time to pass the finalization grace period (5 minutes)
        vm.warp(block.timestamp + 5 minutes + 1);

        // Expect final block update
        IInbox.Transition memory lastTransition = transitions[numProposals - 1];
        expectCheckpointSaved(lastTransition.checkpoint);

        // Submit new proposal that triggers finalization
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);

        // Include the last proposal for validation
        IInbox.Proposal[] memory finalValidationProposals = new IInbox.Proposal[](1);
        finalValidationProposals[0] = proposals[numProposals - 1];

        // When finalizing, we need to provide the checkpoint from the last transition
        bytes memory proposeData = InboxTestAdapter.encodeProposeInputWithEndBlock(
            inboxType,
            uint48(0),
            coreState,
            finalValidationProposals,
            blobRef,
            transitionRecords,
            lastTransition.checkpoint
        );

        // Roll to the next valid proposal block
        uint256 nextProposalBlock = InboxTestLib.calculateProposalBlock(numProposals + 1, 2);
        vm.roll(nextProposalBlock);
        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Verify finalization occurred (we can't directly check core state hash
        // but we can verify by checking that the checkpoint save was called)
    }

    /// @notice Test that unproven proposals block finalization
    /// @dev Validates finalization dependency on complete proof chain:
    ///      1. Creates multiple proposals (1,2,3)
    ///      2. Proves only some proposals (1,3) leaving gap at 2
    ///      3. Attempts finalization and expects stopping at missing proof
    ///      4. Verifies proof requirement enforcement for chain continuity
    function test_unproven_proposals_block_finalization() public {
        setupBlobHashes();
        // Create genesis transition
        IInbox.Transition memory genesisTransition;
        genesisTransition.checkpoint.blockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisTransition));

        // Store proposals for later use
        IInbox.Proposal[] memory storedProposals = new IInbox.Proposal[](3);

        // Create 3 proposals - use the unified submitProposal method
        for (uint48 i = 1; i <= 3; i++) {
            IInbox.Proposal memory proposal = submitProposal(i, Alice);
            storedProposals[i - 1] = proposal;
        }

        // Prove only proposals 1 and 3 (skip 2)
        for (uint48 i = 1; i <= 3; i += 2) {
            bytes32 storedProposalHash = inbox.getProposalHash(i);

            // Use the stored proposals that were actually constructed during creation
            IInbox.Proposal memory proposal = storedProposals[i - 1];

            bytes32 parentHash = i == 1 ? initialParentHash : bytes32(uint256(999)); // Dummy parent
                // for 3
            IInbox.Transition memory transition = IInbox.Transition({
                proposalHash: storedProposalHash,
                parentTransitionHash: parentHash,
                checkpoint: ICheckpointManager.Checkpoint({
                    blockNumber: uint48(100 + i * 10),
                    blockHash: keccak256(abi.encode(i, "endBlockHash")),
                    stateRoot: keccak256(abi.encode(i, "stateRoot"))
                })
            });

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal;
            IInbox.Transition[] memory proveTransitions = new IInbox.Transition[](1);
            proveTransitions[0] = transition;

            bytes memory proveData = encodeProveInput(proveProposals, proveTransitions);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof"));
        }

        // Try to finalize - should only finalize proposal 1 because 2 is missing
        // Calculate correct nextProposalBlockId based on the last proposal
        uint256 lastProposalBlock = InboxTestLib.calculateProposalBlock(3, 2);
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 4,
            nextProposalBlockId: uint48(lastProposalBlock + 1), // Previous proposal's block + 1
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        // Core state will be validated by the contract during propose()

        // Only provide transition record for proposal 1
        bytes32 storedProposalHashForTransition = inbox.getProposalHash(1);
        IInbox.Transition memory transition1 = IInbox.Transition({
            proposalHash: storedProposalHashForTransition,
            parentTransitionHash: initialParentHash,
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 110,
                blockHash: keccak256(abi.encode(1, "endBlockHash")),
                stateRoot: keccak256(abi.encode(1, "stateRoot"))
            })
        });

        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](1);
        transitionRecords[0] = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: InboxTestLib.hashTransition(transition1),
            checkpointHash: keccak256(abi.encode(transition1.checkpoint))
        });

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);

        // Advance time to pass the finalization grace period (5 minutes)
        vm.warp(block.timestamp + 5 minutes + 1);

        // Expect only proposal 1 to be finalized
        expectCheckpointSaved(transition1.checkpoint);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(4);

        // Use the stored proposal that was actually submitted
        IInbox.Proposal memory lastProposal = storedProposals[2];

        // When finalizing, we need to provide the checkpoint
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = lastProposal;

        bytes memory proposeData = InboxTestAdapter.encodeProposeInputWithEndBlock(
            inboxType,
            uint48(0),
            coreState,
            proposals,
            blobRef,
            transitionRecords,
            transition1.checkpoint // Use the header from the transition being finalized
        );

        // Roll to the next valid proposal block
        uint256 nextProposalBlock = InboxTestLib.calculateProposalBlock(4, 2);
        vm.roll(nextProposalBlock);
        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Proposal 1 should be finalized, but 2 and 3 should remain unfinalized
        // because 2 is missing its proof
    }
}
