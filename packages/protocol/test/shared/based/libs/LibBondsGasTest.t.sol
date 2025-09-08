// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console } from "forge-std/src/console.sol";
import { LibBonds } from "contracts/shared/based/libs/LibBonds.sol";

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
        return LibBonds.mergeBondInstructions(existing, new_);
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

    /// @notice Test gas costs at various array sizes to find break-even point
    function test_gasComparison_variousSizes() public {
        // Test sizes from 1 to 20 elements total
        for (uint256 totalSize = 1; totalSize <= 20; totalSize++) {
            // Test different splits between existing and new arrays
            for (uint256 existingSize = 0; existingSize <= totalSize; existingSize++) {
                uint256 newSize = totalSize - existingSize;

                LibBonds.BondInstruction[] memory existing =
                    _createBondInstructionsArray(existingSize);
                LibBonds.BondInstruction[] memory newInstructions =
                    _createBondInstructionsArray(newSize);

                // Measure optimized version
                uint256 gasBefore = gasleft();
                mergeBondInstructionsPublic(existing, newInstructions);
                uint256 optimizedGas = gasBefore - gasleft();

                // Measure legacy version
                gasBefore = gasleft();
                mergeBondInstructionsLegacy(existing, newInstructions);
                uint256 legacyGas = gasBefore - gasleft();

                // Log results for analysis
                emit log_named_uint("TotalSize", totalSize);
                emit log_named_uint("ExistingSize", existingSize);
                emit log_named_uint("NewSize", newSize);
                emit log_named_uint("OptimizedGas", optimizedGas);
                emit log_named_uint("LegacyGas", legacyGas);

                if (optimizedGas < legacyGas) {
                    emit log_named_int("GasSaved", int256(legacyGas) - int256(optimizedGas));
                } else {
                    emit log_named_int("GasOverhead", int256(optimizedGas) - int256(legacyGas));
                }
                emit log("---");
            }
        }
    }

    /// @notice Focused test on break-even point (around 8 elements)
    function test_gasComparison_breakEvenPoint() public view {
        for (uint256 totalSize = 6; totalSize <= 12; totalSize++) {
            LibBonds.BondInstruction[] memory existing = _createBondInstructionsArray(totalSize / 2);
            LibBonds.BondInstruction[] memory newInstructions =
                _createBondInstructionsArray(totalSize - totalSize / 2);

            uint256 gasBefore = gasleft();
            mergeBondInstructionsPublic(existing, newInstructions);
            uint256 optimizedGas = gasBefore - gasleft();

            gasBefore = gasleft();
            mergeBondInstructionsLegacy(existing, newInstructions);
            uint256 legacyGas = gasBefore - gasleft();

            console.log("Size:", totalSize);
            console.log("  Optimized gas:", optimizedGas);
            console.log("  Legacy gas:", legacyGas);
            console.log("  Difference:", int256(optimizedGas) - int256(legacyGas));
        }
    }

    /// @notice Benchmark specific scenarios
    function test_gasComparison_scenarios() public {
        TestCase[] memory cases = new TestCase[](6);
        cases[0] = TestCase(1, 1, "Small arrays (2 total)");
        cases[1] = TestCase(2, 2, "Small arrays (4 total)");
        cases[2] = TestCase(4, 4, "Break-even test (8 total)");
        cases[3] = TestCase(5, 5, "Just above break-even (10 total)");
        cases[4] = TestCase(10, 10, "Medium arrays (20 total)");
        cases[5] = TestCase(25, 25, "Large arrays (50 total)");

        for (uint256 i; i < cases.length; ++i) {
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
            console.log(
                "  Improvement:",
                legacyGas > optimizedGas
                    ? string.concat(
                        vm.toString(((legacyGas - optimizedGas) * 100) / legacyGas), "% saved"
                    )
                    : string.concat(
                        vm.toString(((optimizedGas - legacyGas) * 100) / legacyGas), "% overhead"
                    )
            );
            console.log("");
        }
    }

    /// @notice Test correctness of merged arrays
    function test_mergeCorrectness() public {
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
    function test_edgeCases() public {
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
