// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { console } from "forge-std/src/console.sol";

/// @title InboxGasComparisonFinal
/// @notice Final gas comparison test between Inbox and InboxOptimized1 for prove function
/// @dev This test creates a comprehensive comparison table showing gas usage for 1, 2, and 3 transitions
contract InboxGasComparisonFinal is AbstractProveTest {

    function setUp() public virtual override {
        // Start with standard Inbox
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    /// @dev Main test that runs the complete gas comparison and outputs a table
    function test_gasComparison_prove_transitions() public {
        console.log("=== INBOX GAS COMPARISON: PROVE FUNCTION ===");
        console.log("");

        // Measure Standard Inbox
        uint256[3] memory standardGas = _measureStandardInbox();

        // Measure InboxOptimized1
        uint256[3] memory optimizedGas = _measureOptimizedInbox();

        // Print comparison table
        _printComparisonTable(standardGas, optimizedGas);
    }

    function _measureStandardInbox() internal returns (uint256[3] memory gas) {
        console.log("Measuring Standard Inbox...");

        // Reset to standard inbox
        setDeployer(new InboxDeployer());
        super.setUp();

        gas[0] = _measureProveGas(1);
        console.log("Standard - 1 transition:", gas[0]);

        // Fresh setup for each measurement
        super.setUp();
        gas[1] = _measureProveGas(2);
        console.log("Standard - 2 transitions:", gas[1]);

        super.setUp();
        gas[2] = _measureProveGas(3);
        console.log("Standard - 3 transitions:", gas[2]);
        console.log("");
    }

    function _measureOptimizedInbox() internal returns (uint256[3] memory gas) {
        console.log("Measuring InboxOptimized1...");

        // Switch to optimized inbox
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();

        gas[0] = _measureProveGas(1);
        console.log("Optimized - 1 transition:", gas[0]);

        super.setUp();
        gas[1] = _measureProveGas(2);
        console.log("Optimized - 2 transitions:", gas[1]);

        super.setUp();
        gas[2] = _measureProveGas(3);
        console.log("Optimized - 3 transitions:", gas[2]);
        console.log("");
    }

    function _measureProveGas(uint8 transitionCount) internal returns (uint256) {
        // Create consecutive proposals for aggregation testing
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(transitionCount);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();

        return gasBefore - gasAfter;
    }

    function _printComparisonTable(uint256[3] memory standardGas, uint256[3] memory optimizedGas) internal view {
        console.log("=== GAS COMPARISON TABLE ===");
        console.log("");
        console.log("| Transitions | Standard Inbox | InboxOptimized1 | Gas Savings | Savings % |");
        console.log("|-------------|----------------|-----------------|-------------|-----------|");

        // 1 transition
        uint256 savings1 = standardGas[0] > optimizedGas[0] ? standardGas[0] - optimizedGas[0] : 0;
        uint256 savingsPercent1 = standardGas[0] > 0 ? (savings1 * 100) / standardGas[0] : 0;
        console.log("| 1 transition|");
        console.log("  Standard:     ", standardGas[0]);
        console.log("  Optimized:    ", optimizedGas[0]);
        console.log("  Savings:      ", savings1);
        console.log("  Percent:      ", savingsPercent1);
        console.log("");

        // 2 transitions
        uint256 savings2 = standardGas[1] > optimizedGas[1] ? standardGas[1] - optimizedGas[1] : 0;
        uint256 savingsPercent2 = standardGas[1] > 0 ? (savings2 * 100) / standardGas[1] : 0;
        console.log("| 2 transitions|");
        console.log("  Standard:     ", standardGas[1]);
        console.log("  Optimized:    ", optimizedGas[1]);
        console.log("  Savings:      ", savings2);
        console.log("  Percent:      ", savingsPercent2);
        console.log("");

        // 3 transitions
        uint256 savings3 = standardGas[2] > optimizedGas[2] ? standardGas[2] - optimizedGas[2] : 0;
        uint256 savingsPercent3 = standardGas[2] > 0 ? (savings3 * 100) / standardGas[2] : 0;
        console.log("| 3 transitions|");
        console.log("  Standard:     ", standardGas[2]);
        console.log("  Optimized:    ", optimizedGas[2]);
        console.log("  Savings:      ", savings3);
        console.log("  Percent:      ", savingsPercent3);
        console.log("");

        console.log("KEY FINDINGS:");
        console.log("- Standard Inbox: Each transition processed individually");
        console.log("- InboxOptimized1: Aggregates consecutive transitions to save storage operations");

        // Calculate total savings across all scenarios
        uint256 totalStandardGas = standardGas[0] + standardGas[1] + standardGas[2];
        uint256 totalOptimizedGas = optimizedGas[0] + optimizedGas[1] + optimizedGas[2];
        uint256 totalSavings = totalStandardGas > totalOptimizedGas ? totalStandardGas - totalOptimizedGas : 0;
        uint256 totalSavingsPercent = totalStandardGas > 0 ? (totalSavings * 100) / totalStandardGas : 0;

        console.log("- Total gas savings across all scenarios:");
        console.log("  Standard total:    ", totalStandardGas);
        console.log("  Optimized total:   ", totalOptimizedGas);
        console.log("  Total savings:     ", totalSavings);
        console.log("  Savings percentage:", totalSavingsPercent);
    }
}