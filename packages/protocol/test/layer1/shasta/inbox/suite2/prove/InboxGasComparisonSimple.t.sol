// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { console } from "forge-std/src/console.sol";

/// @title InboxGasComparisonSimple
/// @notice Simple gas comparison test between Inbox and InboxOptimized1 for prove function
contract InboxGasComparisonSimple is AbstractProveTest {
    // Gas measurements
    uint256 internal standardInbox1;
    uint256 internal optimizedInbox1;

    function setUp() public virtual override {
        // Use standard Inbox deployer first
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    function test_gasComparison_prove_singleTransition() public {
        console.log("=== Gas Comparison: Prove Function ===");
        console.log("Testing Standard Inbox vs InboxOptimized1");
        console.log("");

        // Test Standard Inbox
        _testStandardInbox();

        // Test Optimized Inbox
        _testOptimizedInbox();

        // Print results
        _printResults();
    }

    function _testStandardInbox() internal {
        console.log("Testing Standard Inbox...");

        IInbox.Proposal memory proposal = _proposeAndGetProposal();
        bytes memory proveData = _createProveInput(proposal);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        standardInbox1 = gasBefore - gasAfter;

        console.log("Standard Inbox gas used:", standardInbox1);
    }

    function _testOptimizedInbox() internal {
        console.log("Testing Optimized Inbox...");

        // Switch to optimized deployer
        setDeployer(new InboxOptimized1Deployer());
        setUp();

        IInbox.Proposal memory proposal = _proposeAndGetProposal();
        bytes memory proveData = _createProveInput(proposal);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        optimizedInbox1 = gasBefore - gasAfter;

        console.log("Optimized Inbox gas used:", optimizedInbox1);
    }

    function _printResults() internal view {
        console.log("=== RESULTS ===");

        uint256 savings = standardInbox1 - optimizedInbox1;

        console.log("Standard Inbox:", standardInbox1, "gas");
        console.log("InboxOptimized1:", optimizedInbox1, "gas");
        console.log("Gas Savings:", savings, "gas");

        if (standardInbox1 > 0) {
            uint256 savingsPercent = (savings * 100) / standardInbox1;
            console.log("Savings percentage:", savingsPercent, "%");
        }
    }
}