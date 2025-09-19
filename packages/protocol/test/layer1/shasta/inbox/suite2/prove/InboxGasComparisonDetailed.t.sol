// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { console } from "forge-std/src/console.sol";

/// @title InboxGasComparisonDetailed
/// @notice Detailed gas comparison test between Inbox and InboxOptimized1 for prove function
/// @dev Tests 1, 2, and 3 aggregatable transitions and outputs a comparison table
contract InboxGasComparisonDetailed is AbstractProveTest {

    // Gas measurements for different transition counts
    struct GasMeasurement {
        uint256 oneTransition;
        uint256 twoTransitions;
        uint256 threeTransitions;
    }

    GasMeasurement internal standardInbox;
    GasMeasurement internal optimizedInbox;

    function setUp() public virtual override {
        // Use standard Inbox deployer first
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    function test_gasComparison_prove_aggregatableTransitions() public {
        console.log("=== Gas Comparison: Prove Function with Aggregatable Transitions ===");
        console.log("Testing Standard Inbox vs InboxOptimized1 with 1, 2, and 3 consecutive transitions");
        console.log("");

        // Test Standard Inbox
        _testStandardInbox();

        // Test Optimized Inbox
        _testOptimizedInbox();

        // Print results table
        _printResultsTable();
    }

    function _testStandardInbox() internal {
        console.log("Testing Standard Inbox...");

        // Test 1 transition
        standardInbox.oneTransition = _measureProveGas(1, false);
        console.log("Standard Inbox - 1 transition:", standardInbox.oneTransition, "gas");

        // Test 2 transitions
        standardInbox.twoTransitions = _measureProveGas(2, false);
        console.log("Standard Inbox - 2 transitions:", standardInbox.twoTransitions, "gas");

        // Test 3 transitions
        standardInbox.threeTransitions = _measureProveGas(3, false);
        console.log("Standard Inbox - 3 transitions:", standardInbox.threeTransitions, "gas");

        console.log("");
    }

    function _testOptimizedInbox() internal {
        console.log("Testing InboxOptimized1...");

        // Switch to optimized deployer
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();

        // Test 1 transition
        optimizedInbox.oneTransition = _measureProveGas(1, true);
        console.log("InboxOptimized1 - 1 transition:", optimizedInbox.oneTransition, "gas");

        // Test 2 transitions
        optimizedInbox.twoTransitions = _measureProveGas(2, true);
        console.log("InboxOptimized1 - 2 transitions:", optimizedInbox.twoTransitions, "gas");

        // Test 3 transitions
        optimizedInbox.threeTransitions = _measureProveGas(3, true);
        console.log("InboxOptimized1 - 3 transitions:", optimizedInbox.threeTransitions, "gas");

        console.log("");
    }

    function _measureProveGas(uint8 transitionCount, bool isOptimized) internal returns (uint256) {
        // Create fresh state for this measurement
        if (!isOptimized) {
            // For standard inbox measurements, switch back if needed
            setDeployer(new InboxDeployer());
            super.setUp();
        }

        // Create consecutive proposals for aggregation
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(transitionCount);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();

        return gasBefore - gasAfter;
    }

    function _printResultsTable() internal view {
        console.log("=== GAS COMPARISON TABLE ===");
        console.log("");
        console.log("| Transitions | Standard Inbox | InboxOptimized1 | Gas Savings | Savings % |");
        console.log("|-------------|----------------|-----------------|-------------|-----------|");

        // 1 transition row
        uint256 savings1 = standardInbox.oneTransition - optimizedInbox.oneTransition;
        uint256 savingsPercent1 = standardInbox.oneTransition > 0 ? (savings1 * 100) / standardInbox.oneTransition : 0;
        console.log("| 1 transition:");
        console.log("  Standard Inbox:    ", standardInbox.oneTransition);
        console.log("  InboxOptimized1:   ", optimizedInbox.oneTransition);
        console.log("  Gas Savings:       ", savings1);
        console.log("  Savings Percent:   ", savingsPercent1);

        // 2 transitions row
        uint256 savings2 = standardInbox.twoTransitions - optimizedInbox.twoTransitions;
        uint256 savingsPercent2 = standardInbox.twoTransitions > 0 ? (savings2 * 100) / standardInbox.twoTransitions : 0;
        console.log("| 2 transitions:");
        console.log("  Standard Inbox:    ", standardInbox.twoTransitions);
        console.log("  InboxOptimized1:   ", optimizedInbox.twoTransitions);
        console.log("  Gas Savings:       ", savings2);
        console.log("  Savings Percent:   ", savingsPercent2);

        // 3 transitions row
        uint256 savings3 = standardInbox.threeTransitions - optimizedInbox.threeTransitions;
        uint256 savingsPercent3 = standardInbox.threeTransitions > 0 ? (savings3 * 100) / standardInbox.threeTransitions : 0;
        console.log("| 3 transitions:");
        console.log("  Standard Inbox:    ", standardInbox.threeTransitions);
        console.log("  InboxOptimized1:   ", optimizedInbox.threeTransitions);
        console.log("  Gas Savings:       ", savings3);
        console.log("  Savings Percent:   ", savingsPercent3);

        console.log("");

        // Summary
        console.log("SUMMARY:");
        console.log("- Standard Inbox processes each transition individually");
        console.log("- InboxOptimized1 aggregates consecutive transitions to save gas");
        console.log("- Aggregation benefit increases with more consecutive transitions");
    }

}