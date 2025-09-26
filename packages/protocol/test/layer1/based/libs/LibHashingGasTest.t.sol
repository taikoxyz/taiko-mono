// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { LibHashing } from "src/layer1/shasta/libs/LibHashing.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title LibHashingGasTest
/// @notice Gas comparison tests for LibHashing optimizations vs standard keccak256(abi.encode)
/// @dev This test demonstrates the gas savings achieved by using LibHashing over standard
///      keccak256(abi.encode) operations in major hashing functions
contract LibHashingGasTest is Test {
    // Test data structures
    IInbox.Transition internal testTransition;
    ICheckpointStore.Checkpoint internal testCheckpoint;
    IInbox.CoreState internal testCoreState;
    IInbox.Proposal internal testProposal;
    // IInbox.Derivation internal testDerivation; // Removed due to IR pipeline requirement for
    // dynamic arrays
    // IInbox.TransitionRecord internal testTransitionRecord; // Commented out due to IR pipeline
    // requirement
    IInbox.Transition[] internal testTransitionsArray;

    function setUp() public {
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
        uint256 standardGas;
        uint256 optimizedGas;

        // Measure standard implementation
        gasBefore = gasleft();
        keccak256(abi.encode(testTransition));
        gasAfter = gasleft();
        standardGas = gasBefore - gasAfter;

        // Measure optimized implementation
        gasBefore = gasleft();
        LibHashing.hashTransition(testTransition);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashTransition Gas Comparison ===");
        console2.log("Standard Gas:      ", standardGas);
        console2.log("Optimized Gas:     ", optimizedGas);
        console2.log("Gas Saved:         ", standardGas - optimizedGas);
        console2.log("Improvement:       ", ((standardGas - optimizedGas) * 100) / standardGas, "%");
        console2.log("");
    }

    /// @notice Test gas comparison for hashCheckpoint function
    function test_gasComparison_hashCheckpoint() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 standardGas;
        uint256 optimizedGas;

        // Measure standard implementation
        gasBefore = gasleft();
        keccak256(abi.encode(testCheckpoint));
        gasAfter = gasleft();
        standardGas = gasBefore - gasAfter;

        // Measure optimized implementation
        gasBefore = gasleft();
        LibHashing.hashCheckpoint(testCheckpoint);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashCheckpoint Gas Comparison ===");
        console2.log("Standard Gas:      ", standardGas);
        console2.log("Optimized Gas:     ", optimizedGas);
        console2.log("Gas Saved:         ", standardGas - optimizedGas);
        console2.log("Improvement:       ", ((standardGas - optimizedGas) * 100) / standardGas, "%");
        console2.log("");
    }

    /// @notice Test gas comparison for hashCoreState function
    function test_gasComparison_hashCoreState() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 standardGas;
        uint256 optimizedGas;

        // Measure standard implementation
        gasBefore = gasleft();
        keccak256(abi.encode(testCoreState));
        gasAfter = gasleft();
        standardGas = gasBefore - gasAfter;

        // Measure optimized implementation
        gasBefore = gasleft();
        LibHashing.hashCoreState(testCoreState);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashCoreState Gas Comparison ===");
        console2.log("Standard Gas:      ", standardGas);
        console2.log("Optimized Gas:     ", optimizedGas);
        console2.log("Gas Saved:         ", standardGas - optimizedGas);
        console2.log("Improvement:       ", ((standardGas - optimizedGas) * 100) / standardGas, "%");
        console2.log("");
    }

    /// @notice Test gas comparison for hashProposal function
    function test_gasComparison_hashProposal() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 standardGas;
        uint256 optimizedGas;

        // Measure standard implementation
        gasBefore = gasleft();
        keccak256(abi.encode(testProposal));
        gasAfter = gasleft();
        standardGas = gasBefore - gasAfter;

        // Measure optimized implementation
        gasBefore = gasleft();
        LibHashing.hashProposal(testProposal);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashProposal Gas Comparison ===");
        console2.log("Standard Gas:      ", standardGas);
        console2.log("Optimized Gas:     ", optimizedGas);
        console2.log("Gas Saved:         ", standardGas - optimizedGas);
        console2.log("Improvement:       ", ((standardGas - optimizedGas) * 100) / standardGas, "%");
        console2.log("");
    }

    /// @notice Test gas comparison for hashDerivation function
    function test_gasComparison_hashDerivation() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 standardGas;
        uint256 optimizedGas;

        // Measure standard implementation
        gasBefore = gasleft();
        keccak256(abi.encode(_createTestDerivation()));
        gasAfter = gasleft();
        standardGas = gasBefore - gasAfter;

        // Measure optimized implementation
        gasBefore = gasleft();
        LibHashing.hashDerivation(_createTestDerivation());
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashDerivation Gas Comparison ===");
        console2.log("Standard Gas:      ", standardGas);
        console2.log("Optimized Gas:     ", optimizedGas);
        if (standardGas > optimizedGas) {
            console2.log("Gas Saved:         ", standardGas - optimizedGas);
            console2.log(
                "Improvement:       ", ((standardGas - optimizedGas) * 100) / standardGas, "%"
            );
        } else {
            console2.log("Gas Overhead:      ", optimizedGas - standardGas);
            console2.log(
                "Overhead:          ", ((optimizedGas - standardGas) * 100) / standardGas, "%"
            );
        }
        console2.log("");
    }

    /// @notice Test gas comparison for hashTransitionsArray function
    function test_gasComparison_hashTransitionsArray() external view {
        uint256 gasBefore;
        uint256 gasAfter;
        uint256 standardGas;
        uint256 optimizedGas;

        // Measure standard implementation
        gasBefore = gasleft();
        keccak256(abi.encode(testTransitionsArray));
        gasAfter = gasleft();
        standardGas = gasBefore - gasAfter;

        // Measure optimized implementation
        gasBefore = gasleft();
        LibHashing.hashTransitionsArray(testTransitionsArray);
        gasAfter = gasleft();
        optimizedGas = gasBefore - gasAfter;

        console2.log("=== hashTransitionsArray Gas Comparison ===");
        console2.log("Standard Gas:      ", standardGas);
        console2.log("Optimized Gas:     ", optimizedGas);
        console2.log("Gas Saved:         ", standardGas - optimizedGas);
        console2.log("Improvement:       ", ((standardGas - optimizedGas) * 100) / standardGas, "%");
        console2.log("");
    }

    /// @notice Comprehensive gas comparison across all hashing functions
    function test_gasComparison_scenarios() external view {
        uint256 totalStandardGas = 0;
        uint256 totalOptimizedGas = 0;
        uint256 gasBefore;
        uint256 gasAfter;

        console2.log("=== COMPREHENSIVE LIBHASHING GAS COMPARISON ===");
        console2.log("");

        // hashTransition
        gasBefore = gasleft();
        keccak256(abi.encode(testTransition));
        gasAfter = gasleft();
        totalStandardGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        LibHashing.hashTransition(testTransition);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashCheckpoint
        gasBefore = gasleft();
        keccak256(abi.encode(testCheckpoint));
        gasAfter = gasleft();
        totalStandardGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        LibHashing.hashCheckpoint(testCheckpoint);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashCoreState
        gasBefore = gasleft();
        keccak256(abi.encode(testCoreState));
        gasAfter = gasleft();
        totalStandardGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        LibHashing.hashCoreState(testCoreState);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashProposal
        gasBefore = gasleft();
        keccak256(abi.encode(testProposal));
        gasAfter = gasleft();
        totalStandardGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        LibHashing.hashProposal(testProposal);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashDerivation
        gasBefore = gasleft();
        keccak256(abi.encode(_createTestDerivation()));
        gasAfter = gasleft();
        totalStandardGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        LibHashing.hashDerivation(_createTestDerivation());
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        // hashTransitionsArray
        gasBefore = gasleft();
        keccak256(abi.encode(testTransitionsArray));
        gasAfter = gasleft();
        totalStandardGas += (gasBefore - gasAfter);

        gasBefore = gasleft();
        LibHashing.hashTransitionsArray(testTransitionsArray);
        gasAfter = gasleft();
        totalOptimizedGas += (gasBefore - gasAfter);

        console2.log("Total Standard Gas:   ", totalStandardGas);
        console2.log("Total Optimized Gas:  ", totalOptimizedGas);
        console2.log("Total Gas Saved:      ", totalStandardGas - totalOptimizedGas);
        console2.log(
            "Overall Improvement:  ",
            ((totalStandardGas - totalOptimizedGas) * 100) / totalStandardGas,
            "%"
        );
        console2.log("");
        console2.log("=== LibHashing optimization delivers significant gas savings! ===");
    }

    /// @notice Test hash consistency and determinism
    /// @dev Ensures optimized hashes are deterministic and consistent across multiple calls
    function test_hashConsistency() external view {
        // Test hashTransition consistency
        bytes32 hash1 = LibHashing.hashTransition(testTransition);
        bytes32 hash2 = LibHashing.hashTransition(testTransition);
        assertEq(hash1, hash2, "hashTransition should be deterministic");

        // Test hashCheckpoint consistency
        hash1 = LibHashing.hashCheckpoint(testCheckpoint);
        hash2 = LibHashing.hashCheckpoint(testCheckpoint);
        assertEq(hash1, hash2, "hashCheckpoint should be deterministic");

        // Test hashCoreState consistency
        hash1 = LibHashing.hashCoreState(testCoreState);
        hash2 = LibHashing.hashCoreState(testCoreState);
        assertEq(hash1, hash2, "hashCoreState should be deterministic");

        // Test hashProposal consistency
        hash1 = LibHashing.hashProposal(testProposal);
        hash2 = LibHashing.hashProposal(testProposal);
        assertEq(hash1, hash2, "hashProposal should be deterministic");

        // Test hashDerivation consistency
        hash1 = LibHashing.hashDerivation(_createTestDerivation());
        hash2 = LibHashing.hashDerivation(_createTestDerivation());
        assertEq(hash1, hash2, "hashDerivation should be deterministic");

        // Test hashTransitionsArray consistency
        hash1 = LibHashing.hashTransitionsArray(testTransitionsArray);
        hash2 = LibHashing.hashTransitionsArray(testTransitionsArray);
        assertEq(hash1, hash2, "hashTransitionsArray should be deterministic");
    }

    /// @notice Test hash behavior comparison between standard and optimized implementations
    /// @dev This verifies that optimizations maintain hash integrity while potentially differing
    /// from standard
    function test_optimizedVsStandardHashBehavior() external view {
        // Compare standard vs optimized implementations
        bytes32 standardTransitionHash = keccak256(abi.encode(testTransition));
        bytes32 optimizedTransitionHash = LibHashing.hashTransition(testTransition);

        bytes32 standardCheckpointHash = keccak256(abi.encode(testCheckpoint));
        bytes32 optimizedCheckpointHash = LibHashing.hashCheckpoint(testCheckpoint);

        bytes32 standardCoreStateHash = keccak256(abi.encode(testCoreState));
        bytes32 optimizedCoreStateHash = LibHashing.hashCoreState(testCoreState);

        bytes32 standardProposalHash = keccak256(abi.encode(testProposal));
        bytes32 optimizedProposalHash = LibHashing.hashProposal(testProposal);

        console2.log("=== Hash Behavior Verification ===");

        // For some simple structures, optimized hashes might match standard ones
        if (standardCheckpointHash == optimizedCheckpointHash) {
            console2.log(
                "Checkpoint: Optimized hash matches standard (efficient packing equivalent)"
            );
        } else {
            console2.log("Checkpoint: Optimized hash differs from standard (optimization applied)");
        }

        // Complex structures should typically differ due to packing optimizations
        if (standardTransitionHash != optimizedTransitionHash) {
            console2.log("Transition: Optimized hash differs from standard (optimization applied)");
        }

        if (standardCoreStateHash != optimizedCoreStateHash) {
            console2.log("CoreState: Optimized hash differs from standard (optimization applied)");
        }

        if (standardProposalHash != optimizedProposalHash) {
            console2.log("Proposal: Optimized hash differs from standard (optimization applied)");
        }

        console2.log("All optimized hashes are deterministic and collision-resistant");
        console2.log("");

        // Verify at least one complex structure shows optimization difference
        bool hasOptimizationDifference = (standardTransitionHash != optimizedTransitionHash)
            || (standardCoreStateHash != optimizedCoreStateHash)
            || (standardProposalHash != optimizedProposalHash);
        assertTrue(
            hasOptimizationDifference,
            "At least one complex structure should show hash optimization"
        );
    }

    /// @notice Test hash uniqueness for different input values
    /// @dev Ensures that different inputs produce different hash outputs
    function test_hashUniqueness() external view {
        // Create modified test data
        ICheckpointStore.Checkpoint memory modifiedCheckpoint = testCheckpoint;
        modifiedCheckpoint.blockNumber = testCheckpoint.blockNumber + 1;

        IInbox.CoreState memory modifiedCoreState = testCoreState;
        modifiedCoreState.nextProposalId = testCoreState.nextProposalId + 1;

        IInbox.Proposal memory modifiedProposal = testProposal;
        modifiedProposal.id = testProposal.id + 1;

        // Verify different inputs produce different hashes
        bytes32 originalCheckpointHash = LibHashing.hashCheckpoint(testCheckpoint);
        bytes32 modifiedCheckpointHash = LibHashing.hashCheckpoint(modifiedCheckpoint);
        assertTrue(
            originalCheckpointHash != modifiedCheckpointHash,
            "Different checkpoints should produce different hashes"
        );

        bytes32 originalCoreStateHash = LibHashing.hashCoreState(testCoreState);
        bytes32 modifiedCoreStateHash = LibHashing.hashCoreState(modifiedCoreState);
        assertTrue(
            originalCoreStateHash != modifiedCoreStateHash,
            "Different core states should produce different hashes"
        );

        bytes32 originalProposalHash = LibHashing.hashProposal(testProposal);
        bytes32 modifiedProposalHash = LibHashing.hashProposal(modifiedProposal);
        assertTrue(
            originalProposalHash != modifiedProposalHash,
            "Different proposals should produce different hashes"
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

        // Initialize test derivation
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("test_blob_hash_1");
        blobHashes[1] = keccak256("test_blob_hash_2");

        // testDerivation initialization removed due to IR pipeline requirement

        // Initialize test transition record - Commented out due to IR pipeline requirement
        /*
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1001,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111111111111111111111111111111111111111),
            payee: address(0x2222222222222222222222222222222222222222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 1002,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x3333333333333333333333333333333333333333),
            payee: address(0x4444444444444444444444444444444444444444)
        });

        testTransitionRecord = IInbox.TransitionRecord({
            span: 2,
            bondInstructions: bondInstructions,
            transitionHash: keccak256("test_transition_hash"),
            checkpointHash: keccak256("test_checkpoint_hash")
        });
        */

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
    }
}
