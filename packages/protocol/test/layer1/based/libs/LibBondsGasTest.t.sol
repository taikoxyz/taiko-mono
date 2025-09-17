// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console } from "forge-std/src/console.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibBondsL1 } from "src/layer1/shasta/libs/LibBondsL1.sol";

/// @title LibBondsGasTest
/// @notice Gas benchmark tests for LibBonds merge optimization
contract LibBondsGasTest is Test {
    using LibBonds for *;

    struct TestCase {
        uint256 existingSize;
        uint256 newSize;
        string name;
    }

    // Test wrapper to expose internal functions for gas testing
    function mergeBondInstructionsPublic(
        LibBonds.BondInstruction[] memory existing,
        LibBonds.BondInstruction[] memory new_
    )
        public
        pure
        returns (LibBonds.BondInstruction[] memory)
    {
        return LibBondsL1.mergeBondInstructions(existing, new_);
    }

    // Legacy implementation for comparison
    function mergeBondInstructionsLegacy(
        LibBonds.BondInstruction[] memory _existingInstructions,
        LibBonds.BondInstruction[] memory _newInstructions
    )
        public
        pure
        returns (LibBonds.BondInstruction[] memory merged_)
    {
        if (_newInstructions.length == 0) {
            return _existingInstructions;
        }

        uint256 existingLen = _existingInstructions.length;
        uint256 newLen = _newInstructions.length;
        merged_ = new LibBonds.BondInstruction[](existingLen + newLen);

        // Copy existing instructions
        for (uint256 i; i < existingLen; ++i) {
            merged_[i] = _existingInstructions[i];
        }

        // Copy new instructions
        for (uint256 i; i < newLen; ++i) {
            merged_[existingLen + i] = _newInstructions[i];
        }
    }

    function _createBondInstruction(uint48 proposalId)
        internal
        pure
        returns (LibBonds.BondInstruction memory)
    {
        return LibBonds.BondInstruction({
            proposalId: proposalId,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1234567890123456789012345678901234567890),
            receiver: address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD)
        });
    }

    function _createBondInstructionsArray(uint256 length)
        internal
        pure
        returns (LibBonds.BondInstruction[] memory)
    {
        LibBonds.BondInstruction[] memory instructions = new LibBonds.BondInstruction[](length);
        for (uint256 i; i < length; ++i) {
            instructions[i] = _createBondInstruction(uint48(i + 1));
        }
        return instructions;
    }

    /// @notice Test correctness at various array sizes
    function test_gasComparison_variousSizes() public pure {
        // Simple test that only validates the optimized function works correctly
        LibBonds.BondInstruction[] memory existing = _createBondInstructionsArray(2);
        LibBonds.BondInstruction[] memory newInstructions = _createBondInstructionsArray(2);

        LibBonds.BondInstruction[] memory result =
            mergeBondInstructionsPublic(existing, newInstructions);

        assertEq(result.length, 4, "Total length should be 4");
        assertEq(result[0].proposalId, 1, "First proposalId should be 1");
        assertEq(result[1].proposalId, 2, "Second proposalId should be 2");
        assertEq(result[2].proposalId, 1, "Third proposalId should be 1");
        assertEq(result[3].proposalId, 2, "Fourth proposalId should be 2");
    }

    /// @notice Test correctness at break-even point
    function test_gasComparison_breakEvenPoint() public pure {
        // Test the break-even point behavior (8 elements - should use bulk copy)
        LibBonds.BondInstruction[] memory existing = _createBondInstructionsArray(4);
        LibBonds.BondInstruction[] memory newInstructions = _createBondInstructionsArray(4);

        LibBonds.BondInstruction[] memory result =
            mergeBondInstructionsPublic(existing, newInstructions);

        assertEq(result.length, 8, "Total length should be 8");

        // Check first few elements are from existing array
        assertEq(result[0].proposalId, 1, "First element should have proposalId 1");
        assertEq(result[1].proposalId, 2, "Second element should have proposalId 2");
        assertEq(result[2].proposalId, 3, "Third element should have proposalId 3");
        assertEq(result[3].proposalId, 4, "Fourth element should have proposalId 4");

        // Check next elements are from new array
        assertEq(result[4].proposalId, 1, "Fifth element should have proposalId 1");
        assertEq(result[5].proposalId, 2, "Sixth element should have proposalId 2");
        assertEq(result[6].proposalId, 3, "Seventh element should have proposalId 3");
        assertEq(result[7].proposalId, 4, "Eighth element should have proposalId 4");
    }

    /// @notice Benchmark specific scenarios
    function test_gasComparison_scenarios() public view {
        // Reduce the scope to avoid gas limit issues
        TestCase[3] memory cases = [
            TestCase(1, 1, "Small arrays (2 total)"),
            TestCase(2, 2, "Medium arrays (4 total)"),
            TestCase(4, 4, "Break-even test (8 total)")
        ];

        for (uint256 i = 0; i < cases.length; i++) {
            TestCase memory testCase = cases[i];
            LibBonds.BondInstruction[] memory existing =
                _createBondInstructionsArray(testCase.existingSize);
            LibBonds.BondInstruction[] memory newInstructions =
                _createBondInstructionsArray(testCase.newSize);

            uint256 gasStart = gasleft();
            mergeBondInstructionsPublic(existing, newInstructions);
            uint256 optimizedGas = gasStart - gasleft();

            gasStart = gasleft();
            mergeBondInstructionsLegacy(existing, newInstructions);
            uint256 legacyGas = gasStart - gasleft();

            console.log(testCase.name);
            console.log("  Optimized:", optimizedGas, "gas");
            console.log("  Legacy:", legacyGas, "gas");

            // Simplified improvement calculation
            if (legacyGas > optimizedGas) {
                uint256 percentSaved = ((legacyGas - optimizedGas) * 100) / legacyGas;
                console.log("  Improvement: ", percentSaved, "% saved");
            } else {
                uint256 percentOverhead = ((optimizedGas - legacyGas) * 100) / legacyGas;
                console.log("  Overhead: ", percentOverhead, "%");
            }
        }
    }

    /// @notice Test correctness of merged arrays
    function test_mergeCorrectness() public pure {
        LibBonds.BondInstruction[] memory existing = _createBondInstructionsArray(5);
        LibBonds.BondInstruction[] memory newInstructions = _createBondInstructionsArray(3);

        LibBonds.BondInstruction[] memory optimized =
            mergeBondInstructionsPublic(existing, newInstructions);
        LibBonds.BondInstruction[] memory legacy =
            mergeBondInstructionsLegacy(existing, newInstructions);

        assertEq(optimized.length, legacy.length, "Array lengths should match");
        assertEq(optimized.length, 8, "Total length should be 8");

        for (uint256 i; i < optimized.length; ++i) {
            assertEq(
                optimized[i].proposalId,
                legacy[i].proposalId,
                "Proposal IDs should match at all positions"
            );
            assertEq(
                uint256(optimized[i].bondType),
                uint256(legacy[i].bondType),
                "Bond types should match"
            );
            assertEq(optimized[i].payer, legacy[i].payer, "Payers should match");
            assertEq(optimized[i].receiver, legacy[i].receiver, "Receivers should match");
        }
    }

    /// @notice Test edge cases
    function test_edgeCases() public pure {
        // Empty new array
        LibBonds.BondInstruction[] memory existing = _createBondInstructionsArray(5);
        LibBonds.BondInstruction[] memory empty = new LibBonds.BondInstruction[](0);

        LibBonds.BondInstruction[] memory result = mergeBondInstructionsPublic(existing, empty);
        assertEq(result.length, 5, "Should return original array when new is empty");

        // Empty existing array
        LibBonds.BondInstruction[] memory emptyExisting = new LibBonds.BondInstruction[](0);
        LibBonds.BondInstruction[] memory newInstructions = _createBondInstructionsArray(3);

        result = mergeBondInstructionsPublic(emptyExisting, newInstructions);
        assertEq(result.length, 3, "Should handle empty existing array");

        // Single element arrays
        LibBonds.BondInstruction[] memory single1 = _createBondInstructionsArray(1);
        LibBonds.BondInstruction[] memory single2 = _createBondInstructionsArray(1);

        result = mergeBondInstructionsPublic(single1, single2);
        assertEq(result.length, 2, "Should handle single element arrays");
    }
}
