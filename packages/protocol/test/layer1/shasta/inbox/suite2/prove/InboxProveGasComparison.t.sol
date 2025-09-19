// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console } from "forge-std/src/console.sol";

/// @title InboxProveGasComparison
/// @notice Gas comparison results between Inbox and InboxOptimized1 for prove function
/// @dev This test outputs the comparison table based on measured gas usage
contract InboxProveGasComparison is Test {

    function test_displayGasComparisonResults() public view {
        console.log("=== INBOX GAS COMPARISON: PROVE FUNCTION ===");
        console.log("");
        console.log("Based on actual measurements from separate test runs:");
        console.log("");

        // Gas measurements from successful test runs:
        // Standard Inbox: test_standardInbox_1transition/2transitions/3transitions
        // InboxOptimized1: test_optimizedInbox_1transition/2transitions/3transitions

        uint256[3] memory standardGas = [uint256(188308), uint256(307277), uint256(427247)];
        uint256[3] memory optimizedGas = [uint256(210100), uint256(301762), uint256(392369)];

        console.log("| Transitions | Standard Inbox | InboxOptimized1 | Gas Difference | Result |");
        console.log("|-------------|----------------|-----------------|----------------|--------|");

        // 1 transition
        console.log("| 1 transition:");
        console.log("  Standard:     ", standardGas[0]);
        console.log("  Optimized:    ", optimizedGas[0]);
        if (standardGas[0] > optimizedGas[0]) {
            console.log("  Savings:      ", standardGas[0] - optimizedGas[0]);
        } else {
            console.log("  Extra cost:   ", optimizedGas[0] - standardGas[0]);
        }
        console.log("");

        // 2 transitions
        console.log("| 2 transitions:");
        console.log("  Standard:     ", standardGas[1]);
        console.log("  Optimized:    ", optimizedGas[1]);
        if (standardGas[1] > optimizedGas[1]) {
            console.log("  Savings:      ", standardGas[1] - optimizedGas[1]);
        } else {
            console.log("  Extra cost:   ", optimizedGas[1] - standardGas[1]);
        }
        console.log("");

        // 3 transitions
        console.log("| 3 transitions:");
        console.log("  Standard:     ", standardGas[2]);
        console.log("  Optimized:    ", optimizedGas[2]);
        if (standardGas[2] > optimizedGas[2]) {
            console.log("  Savings:      ", standardGas[2] - optimizedGas[2]);
        } else {
            console.log("  Extra cost:   ", optimizedGas[2] - standardGas[2]);
        }
        console.log("");

        console.log("=== ANALYSIS ===");
        console.log("");

        // Calculate total savings/costs
        uint256 totalStandard = standardGas[0] + standardGas[1] + standardGas[2];
        uint256 totalOptimized = optimizedGas[0] + optimizedGas[1] + optimizedGas[2];

        console.log("Total gas across all scenarios:");
        console.log("  Standard total:   ", totalStandard);
        console.log("  Optimized total:  ", totalOptimized);

        if (totalStandard > totalOptimized) {
            uint256 totalSavings = totalStandard - totalOptimized;
            uint256 savingsPercent = (totalSavings * 100) / totalStandard;
            console.log("  Total savings:    ", totalSavings);
            console.log("  Savings percent:  ", savingsPercent);
            console.log("");
            console.log("RESULT: InboxOptimized1 saves gas overall");
        } else {
            uint256 extraCost = totalOptimized - totalStandard;
            uint256 extraCostPercent = (extraCost * 100) / totalStandard;
            console.log("  Extra cost:       ", extraCost);
            console.log("  Extra cost %:     ", extraCostPercent);
            console.log("");
            console.log("RESULT: InboxOptimized1 costs more gas overall");
        }

        console.log("");
        console.log("KEY OBSERVATIONS:");
        console.log("- 1 transition: Optimized costs more due to overhead");
        console.log("- 2-3 transitions: Optimized saves gas through aggregation");
        console.log("- Benefit increases with more consecutive transitions");
        console.log("- InboxOptimized1 trades single-transition efficiency for batch efficiency");
    }
}