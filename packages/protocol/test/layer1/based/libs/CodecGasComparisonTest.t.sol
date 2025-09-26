// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { ICodec } from "src/layer1/shasta/iface/ICodec.sol";
import { CodecSimple } from "src/layer1/shasta/impl/CodecSimple.sol";
import { CodecOptimized } from "src/layer1/shasta/impl/CodecOptimized.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title CodecGasComparisonTest
/// @notice Gas comparison tests between CodecSimple and CodecOptimized
/// @dev This test demonstrates the gas savings achieved by using CodecOptimized over
///      CodecSimple for hashing functions via the ICodec interface
contract CodecGasComparisonTest is Test {
    ICodec internal codecSimple;
    ICodec internal codecOptimized;

    // Test data structures
    IInbox.Transition internal testTransition;
    ICheckpointStore.Checkpoint internal testCheckpoint;
    IInbox.CoreState internal testCoreState;
    IInbox.Proposal internal testProposal;
    IInbox.Transition[] internal testTransitionsArray;
    IInbox.TransitionMetadata[] internal testMetadataArray;

    function setUp() public {
        codecSimple = ICodec(address(new CodecSimple()));
        codecOptimized = ICodec(address(new CodecOptimized()));

        _initializeTestData();
    }

    /// @notice Helper function to create test derivation
    /// @return derivation Test derivation with sample data
    function _createTestDerivation() internal pure returns (IInbox.Derivation memory derivation) {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("test_blob_hash_1");
        blobHashes[1] = keccak256("test_blob_hash_2");

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 1024,
                timestamp: 1_672_531_200
            })
        });

        return IInbox.Derivation({
            originBlockNumber: 12_345_677,
            originBlockHash: keccak256("test_origin_block_hash"),
            basefeeSharingPctg: 10,
            sources: sources
        });
    }

    /// @notice Test gas comparison for hashTransition function
    function test_gasComparison_hashTransition() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 simpleGas;
        uint256 optimizedGas;

        // Measure CodecSimple implementation
        gasBefore = gasleft();
        codecSimple.hashTransition(testTransition);
        gasAfter = gasleft();
        simpleGas = gasBefore - gasAfter;

        // Measure CodecOptimized implementation
        gasBefore = gasleft();
        codecOptimized.hashTransition(testTransition);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashTransition Gas Comparison ===");
        console2.log("CodecSimple Gas:   ", simpleGas);
        console2.log("CodecOptimized Gas:", optimizedGas);
        if (simpleGas > optimizedGas) {
            console2.log("Gas Saved:         ", simpleGas - optimizedGas);
            console2.log("Improvement:       ", ((simpleGas - optimizedGas) * 100) / simpleGas, "%");
        } else {
            console2.log("Gas Overhead:      ", optimizedGas - simpleGas);
            console2.log("Overhead:          ", ((optimizedGas - simpleGas) * 100) / simpleGas, "%");
        }
        console2.log("");
    }

    /// @notice Test gas comparison for hashCheckpoint function
    function test_gasComparison_hashCheckpoint() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 simpleGas;
        uint256 optimizedGas;

        // Measure CodecSimple implementation
        gasBefore = gasleft();
        codecSimple.hashCheckpoint(testCheckpoint);
        gasAfter = gasleft();
        simpleGas = gasBefore - gasAfter;

        // Measure CodecOptimized implementation
        gasBefore = gasleft();
        codecOptimized.hashCheckpoint(testCheckpoint);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashCheckpoint Gas Comparison ===");
        console2.log("CodecSimple Gas:   ", simpleGas);
        console2.log("CodecOptimized Gas:", optimizedGas);
        if (simpleGas > optimizedGas) {
            console2.log("Gas Saved:         ", simpleGas - optimizedGas);
            console2.log("Improvement:       ", ((simpleGas - optimizedGas) * 100) / simpleGas, "%");
        } else {
            console2.log("Gas Overhead:      ", optimizedGas - simpleGas);
            console2.log("Overhead:          ", ((optimizedGas - simpleGas) * 100) / simpleGas, "%");
        }
        console2.log("");
    }

    /// @notice Test gas comparison for hashCoreState function
    function test_gasComparison_hashCoreState() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 simpleGas;
        uint256 optimizedGas;

        // Measure CodecSimple implementation
        gasBefore = gasleft();
        codecSimple.hashCoreState(testCoreState);
        gasAfter = gasleft();
        simpleGas = gasBefore - gasAfter;

        // Measure CodecOptimized implementation
        gasBefore = gasleft();
        codecOptimized.hashCoreState(testCoreState);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashCoreState Gas Comparison ===");
        console2.log("CodecSimple Gas:   ", simpleGas);
        console2.log("CodecOptimized Gas:", optimizedGas);
        if (simpleGas > optimizedGas) {
            console2.log("Gas Saved:         ", simpleGas - optimizedGas);
            console2.log("Improvement:       ", ((simpleGas - optimizedGas) * 100) / simpleGas, "%");
        } else {
            console2.log("Gas Overhead:      ", optimizedGas - simpleGas);
            console2.log("Overhead:          ", ((optimizedGas - simpleGas) * 100) / simpleGas, "%");
        }
        console2.log("");
    }

    /// @notice Test gas comparison for hashProposal function
    function test_gasComparison_hashProposal() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 simpleGas;
        uint256 optimizedGas;

        // Measure CodecSimple implementation
        gasBefore = gasleft();
        codecSimple.hashProposal(testProposal);
        gasAfter = gasleft();
        simpleGas = gasBefore - gasAfter;

        // Measure CodecOptimized implementation
        gasBefore = gasleft();
        codecOptimized.hashProposal(testProposal);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashProposal Gas Comparison ===");
        console2.log("CodecSimple Gas:   ", simpleGas);
        console2.log("CodecOptimized Gas:", optimizedGas);
        if (simpleGas > optimizedGas) {
            console2.log("Gas Saved:         ", simpleGas - optimizedGas);
            console2.log("Improvement:       ", ((simpleGas - optimizedGas) * 100) / simpleGas, "%");
        } else {
            console2.log("Gas Overhead:      ", optimizedGas - simpleGas);
            console2.log("Overhead:          ", ((optimizedGas - simpleGas) * 100) / simpleGas, "%");
        }
        console2.log("");
    }

    /// @notice Test gas comparison for hashDerivation function
    function test_gasComparison_hashDerivation() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 simpleGas;
        uint256 optimizedGas;

        IInbox.Derivation memory derivation = _createTestDerivation();

        // Measure CodecSimple implementation
        gasBefore = gasleft();
        codecSimple.hashDerivation(derivation);
        gasAfter = gasleft();
        simpleGas = gasBefore - gasAfter;

        // Measure CodecOptimized implementation
        gasBefore = gasleft();
        codecOptimized.hashDerivation(derivation);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashDerivation Gas Comparison ===");
        console2.log("CodecSimple Gas:   ", simpleGas);
        console2.log("CodecOptimized Gas:", optimizedGas);
        if (simpleGas > optimizedGas) {
            console2.log("Gas Saved:         ", simpleGas - optimizedGas);
            console2.log("Improvement:       ", ((simpleGas - optimizedGas) * 100) / simpleGas, "%");
        } else {
            console2.log("Gas Overhead:      ", optimizedGas - simpleGas);
            console2.log("Overhead:          ", ((optimizedGas - simpleGas) * 100) / simpleGas, "%");
        }
        console2.log("");
    }

    /// @notice Test gas comparison for hashTransitionsWithMetadata function
    function test_gasComparison_hashTransitionsWithMetadata() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 simpleGas;
        uint256 optimizedGas;

        // Measure CodecSimple implementation
        gasBefore = gasleft();
        codecSimple.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        gasAfter = gasleft();
        simpleGas = gasBefore - gasAfter;

        // Measure CodecOptimized implementation
        gasBefore = gasleft();
        codecOptimized.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashTransitionsWithMetadata Gas Comparison ===");
        console2.log("CodecSimple Gas:   ", simpleGas);
        console2.log("CodecOptimized Gas:", optimizedGas);
        if (simpleGas > optimizedGas) {
            console2.log("Gas Saved:         ", simpleGas - optimizedGas);
            console2.log("Improvement:       ", ((simpleGas - optimizedGas) * 100) / simpleGas, "%");
        } else {
            console2.log("Gas Overhead:      ", optimizedGas - simpleGas);
            console2.log("Overhead:          ", ((optimizedGas - simpleGas) * 100) / simpleGas, "%");
        }
        console2.log("");
    }

    /// @notice Comprehensive gas comparison across all hashing functions
    function test_gasComparison_comprehensive() external view {
        uint256 totalSimpleGas = 0;
        uint256 totalOptimizedGas = 0;
        uint256 gasBefore;
        uint256 gasAfter;

        console2.log("=== COMPREHENSIVE ICodec GAS COMPARISON ===");
        console2.log("");

        // hashTransition
        gasBefore = gasleft();
        codecSimple.hashTransition(testTransition);
        gasAfter = gasleft();
        totalSimpleGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        codecOptimized.hashTransition(testTransition);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashCheckpoint
        gasBefore = gasleft();
        codecSimple.hashCheckpoint(testCheckpoint);
        gasAfter = gasleft();
        totalSimpleGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        codecOptimized.hashCheckpoint(testCheckpoint);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashCoreState
        gasBefore = gasleft();
        codecSimple.hashCoreState(testCoreState);
        gasAfter = gasleft();
        totalSimpleGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        codecOptimized.hashCoreState(testCoreState);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashProposal
        gasBefore = gasleft();
        codecSimple.hashProposal(testProposal);
        gasAfter = gasleft();
        totalSimpleGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        codecOptimized.hashProposal(testProposal);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashDerivation
        IInbox.Derivation memory derivation = _createTestDerivation();
        gasBefore = gasleft();
        codecSimple.hashDerivation(derivation);
        gasAfter = gasleft();
        totalSimpleGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        codecOptimized.hashDerivation(derivation);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashTransitionsWithMetadata
        gasBefore = gasleft();
        codecSimple.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        gasAfter = gasleft();
        totalSimpleGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        codecOptimized.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        console2.log("Total CodecSimple Gas:   ", totalSimpleGas);
        console2.log("Total CodecOptimized Gas:", totalOptimizedGas);
        if (totalSimpleGas > totalOptimizedGas) {
            console2.log("Total Gas Saved:         ", totalSimpleGas - totalOptimizedGas);
            console2.log(
                "Overall Improvement:     ",
                ((totalSimpleGas - totalOptimizedGas) * 100) / totalSimpleGas,
                "%"
            );
        } else {
            console2.log("Total Gas Overhead:      ", totalOptimizedGas - totalSimpleGas);
            console2.log(
                "Overall Overhead:        ",
                ((totalOptimizedGas - totalSimpleGas) * 100) / totalSimpleGas,
                "%"
            );
        }
        console2.log("");
        console2.log("=== ICodec comparison complete! ===");
    }

    /// @notice Test hash consistency between both implementations
    /// @dev Verifies both implementations are deterministic
    function test_hashConsistency() external view {
        // Test hashTransition consistency
        bytes32 simpleHash1 = codecSimple.hashTransition(testTransition);
        bytes32 simpleHash2 = codecSimple.hashTransition(testTransition);
        assertEq(simpleHash1, simpleHash2, "CodecSimple hashTransition should be deterministic");

        bytes32 optimizedHash1 = codecOptimized.hashTransition(testTransition);
        bytes32 optimizedHash2 = codecOptimized.hashTransition(testTransition);
        assertEq(
            optimizedHash1, optimizedHash2, "CodecOptimized hashTransition should be deterministic"
        );

        // Test hashCheckpoint consistency
        simpleHash1 = codecSimple.hashCheckpoint(testCheckpoint);
        simpleHash2 = codecSimple.hashCheckpoint(testCheckpoint);
        assertEq(simpleHash1, simpleHash2, "CodecSimple hashCheckpoint should be deterministic");

        optimizedHash1 = codecOptimized.hashCheckpoint(testCheckpoint);
        optimizedHash2 = codecOptimized.hashCheckpoint(testCheckpoint);
        assertEq(
            optimizedHash1, optimizedHash2, "CodecOptimized hashCheckpoint should be deterministic"
        );

        // Test hashCoreState consistency
        simpleHash1 = codecSimple.hashCoreState(testCoreState);
        simpleHash2 = codecSimple.hashCoreState(testCoreState);
        assertEq(simpleHash1, simpleHash2, "CodecSimple hashCoreState should be deterministic");

        optimizedHash1 = codecOptimized.hashCoreState(testCoreState);
        optimizedHash2 = codecOptimized.hashCoreState(testCoreState);
        assertEq(
            optimizedHash1, optimizedHash2, "CodecOptimized hashCoreState should be deterministic"
        );

        // Test hashProposal consistency
        simpleHash1 = codecSimple.hashProposal(testProposal);
        simpleHash2 = codecSimple.hashProposal(testProposal);
        assertEq(simpleHash1, simpleHash2, "CodecSimple hashProposal should be deterministic");

        optimizedHash1 = codecOptimized.hashProposal(testProposal);
        optimizedHash2 = codecOptimized.hashProposal(testProposal);
        assertEq(
            optimizedHash1, optimizedHash2, "CodecOptimized hashProposal should be deterministic"
        );

        // Test hashTransitionsWithMetadata consistency
        simpleHash1 =
            codecSimple.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        simpleHash2 =
            codecSimple.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        assertEq(
            simpleHash1,
            simpleHash2,
            "CodecSimple hashTransitionsWithMetadata should be deterministic"
        );

        optimizedHash1 =
            codecOptimized.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        optimizedHash2 =
            codecOptimized.hashTransitionsWithMetadata(testTransitionsArray, testMetadataArray);
        assertEq(
            optimizedHash1,
            optimizedHash2,
            "CodecOptimized hashTransitionsWithMetadata should be deterministic"
        );
    }

    /// @notice Test hash uniqueness for different input values
    /// @dev Ensures that different inputs produce different hash outputs for both implementations
    function test_hashUniqueness() external view {
        // Create modified test data
        ICheckpointStore.Checkpoint memory modifiedCheckpoint = testCheckpoint;
        modifiedCheckpoint.blockNumber = testCheckpoint.blockNumber + 1;

        IInbox.CoreState memory modifiedCoreState = testCoreState;
        modifiedCoreState.nextProposalId = testCoreState.nextProposalId + 1;

        IInbox.Proposal memory modifiedProposal = testProposal;
        modifiedProposal.id = testProposal.id + 1;

        // Verify different inputs produce different hashes for CodecSimple
        bytes32 originalCheckpointHash = codecSimple.hashCheckpoint(testCheckpoint);
        bytes32 modifiedCheckpointHash = codecSimple.hashCheckpoint(modifiedCheckpoint);
        assertTrue(
            originalCheckpointHash != modifiedCheckpointHash,
            "CodecSimple: Different checkpoints should produce different hashes"
        );

        bytes32 originalCoreStateHash = codecSimple.hashCoreState(testCoreState);
        bytes32 modifiedCoreStateHash = codecSimple.hashCoreState(modifiedCoreState);
        assertTrue(
            originalCoreStateHash != modifiedCoreStateHash,
            "CodecSimple: Different core states should produce different hashes"
        );

        bytes32 originalProposalHash = codecSimple.hashProposal(testProposal);
        bytes32 modifiedProposalHash = codecSimple.hashProposal(modifiedProposal);
        assertTrue(
            originalProposalHash != modifiedProposalHash,
            "CodecSimple: Different proposals should produce different hashes"
        );

        // Verify different inputs produce different hashes for CodecOptimized
        originalCheckpointHash = codecOptimized.hashCheckpoint(testCheckpoint);
        modifiedCheckpointHash = codecOptimized.hashCheckpoint(modifiedCheckpoint);
        assertTrue(
            originalCheckpointHash != modifiedCheckpointHash,
            "CodecOptimized: Different checkpoints should produce different hashes"
        );

        originalCoreStateHash = codecOptimized.hashCoreState(testCoreState);
        modifiedCoreStateHash = codecOptimized.hashCoreState(modifiedCoreState);
        assertTrue(
            originalCoreStateHash != modifiedCoreStateHash,
            "CodecOptimized: Different core states should produce different hashes"
        );

        originalProposalHash = codecOptimized.hashProposal(testProposal);
        modifiedProposalHash = codecOptimized.hashProposal(modifiedProposal);
        assertTrue(
            originalProposalHash != modifiedProposalHash,
            "CodecOptimized: Different proposals should produce different hashes"
        );
    }

    /// @notice Initialize test data structures with realistic values
    function _initializeTestData() private {
        // Initialize test transition
        testTransition = IInbox.Transition({
            proposalHash: keccak256("test_proposal_hash"),
            parentTransitionHash: keccak256("test_parent_transition_hash"),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 12_345_678,
                blockHash: keccak256("test_block_hash"),
                stateRoot: keccak256("test_state_root")
            })
        });

        // Initialize test checkpoint
        testCheckpoint = ICheckpointStore.Checkpoint({
            blockNumber: 12_345_678,
            blockHash: keccak256("test_block_hash"),
            stateRoot: keccak256("test_state_root")
        });

        // Initialize test core state
        testCoreState = IInbox.CoreState({
            nextProposalId: 1001,
            nextProposalBlockId: 0,
            lastFinalizedProposalId: 1000,
            lastFinalizedTransitionHash: keccak256("test_finalized_transition"),
            bondInstructionsHash: keccak256("test_bond_instructions")
        });

        // Initialize test proposal
        testProposal = IInbox.Proposal({
            id: 1001,
            timestamp: 1_672_531_200, // 2023-01-01 00:00:00 UTC
            endOfSubmissionWindowTimestamp: 1_672_531_260, // 2023-01-01 00:01:00 UTC
            proposer: address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12),
            coreStateHash: keccak256("test_core_state_hash"),
            derivationHash: keccak256("test_derivation_hash")
        });

        // Initialize test transitions array with multiple entries
        testTransitionsArray.push(testTransition);
        testTransitionsArray.push(
            IInbox.Transition({
                proposalHash: keccak256("test_proposal_hash_2"),
                parentTransitionHash: keccak256("test_parent_transition_hash_2"),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 12_345_679,
                    blockHash: keccak256("test_block_hash_2"),
                    stateRoot: keccak256("test_state_root_2")
                })
            })
        );
        testTransitionsArray.push(
            IInbox.Transition({
                proposalHash: keccak256("test_proposal_hash_3"),
                parentTransitionHash: keccak256("test_parent_transition_hash_3"),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 12_345_680,
                    blockHash: keccak256("test_block_hash_3"),
                    stateRoot: keccak256("test_state_root_3")
                })
            })
        );

        // Initialize test metadata array with corresponding metadata for each transition
        testMetadataArray.push(
            IInbox.TransitionMetadata({
                designatedProver: address(0x1111111111111111111111111111111111111111),
                actualProver: address(0x1111111111111111111111111111111111111111)
            })
        );
        testMetadataArray.push(
            IInbox.TransitionMetadata({
                designatedProver: address(0x2222222222222222222222222222222222222222),
                actualProver: address(0x2222222222222222222222222222222222222222)
            })
        );
        testMetadataArray.push(
            IInbox.TransitionMetadata({
                designatedProver: address(0x3333333333333333333333333333333333333333),
                actualProver: address(0x3333333333333333333333333333333333333333)
            })
        );
    }
}
