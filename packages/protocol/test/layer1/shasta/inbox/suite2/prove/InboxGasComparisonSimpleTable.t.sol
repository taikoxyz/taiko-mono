// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { console } from "forge-std/src/console.sol";

/// @title InboxGasComparisonSimpleTable
/// @notice Simple gas comparison between Inbox and InboxOptimized1 with table output
contract InboxGasComparisonSimpleTable is AbstractProveTest {

    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    /// @dev Tests 1 transition with standard inbox
    function test_standardInbox_1transition() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(1);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        console.log("Standard Inbox - 1 transition:", gasUsed, "gas");
    }

    /// @dev Tests 2 transitions with standard inbox
    function test_standardInbox_2transitions() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(2);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        console.log("Standard Inbox - 2 transitions:", gasUsed, "gas");
    }

    /// @dev Tests 3 transitions with standard inbox
    function test_standardInbox_3transitions() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(3);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        console.log("Standard Inbox - 3 transitions:", gasUsed, "gas");
    }
}

/// @title InboxOptimized1GasTest
/// @notice Gas test for InboxOptimized1
contract InboxOptimized1GasTest is AbstractProveTest {

    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }

    /// @dev Tests 1 transition with optimized inbox
    function test_optimizedInbox_1transition() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(1);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        console.log("InboxOptimized1 - 1 transition:", gasUsed, "gas");
    }

    /// @dev Tests 2 transitions with optimized inbox
    function test_optimizedInbox_2transitions() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(2);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        console.log("InboxOptimized1 - 2 transitions:", gasUsed, "gas");
    }

    /// @dev Tests 3 transitions with optimized inbox
    function test_optimizedInbox_3transitions() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(3);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        uint256 gasBefore = gasleft();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        console.log("InboxOptimized1 - 3 transitions:", gasUsed, "gas");
    }
}