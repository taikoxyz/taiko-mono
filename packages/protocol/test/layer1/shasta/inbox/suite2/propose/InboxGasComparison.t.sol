// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "contracts/layer1/shasta/libs/LibBlobs.sol";
import { InboxTestSetup } from "../common/InboxTestSetup.sol";
import { BlobTestUtils } from "../common/BlobTestUtils.sol";
import { InboxHelper } from "contracts/layer1/shasta/impl/InboxHelper.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { InboxOptimized4Deployer } from "../deployers/InboxOptimized4Deployer.sol";
import { IInboxDeployer } from "../deployers/IInboxDeployer.sol";
import { console2 } from "forge-std/src/console2.sol";

// Import errors from Inbox implementation
import "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxGasComparison
/// @notice Gas comparison test between standard Inbox and InboxOptimized4
/// @dev This test verifies the gas optimization claims from https://github.com/taikoxyz/taiko-mono/issues/20159
contract InboxGasComparison is InboxTestSetup, BlobTestUtils {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address internal currentProposer = Bob;
    InboxHelper internal helper;

    // Storage for comparison results
    uint256 internal standardInboxGas;
    uint256 internal optimized4Gas;

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        // Initialize the helper for encoding/decoding operations
        helper = new InboxHelper();

        // Select a proposer for testing
        currentProposer = _selectProposer(Bob);
    }

    // ---------------------------------------------------------------
    // Gas Comparison Test
    // ---------------------------------------------------------------

    /// @notice Test gas cost comparison between standard Inbox and InboxOptimized4
    /// @dev This test measures the gas cost of proposing one single proposal
    function test_gasComparison_singleProposal() public {
        // Test with standard Inbox
        standardInboxGas = _measureProposalGas(new InboxDeployer(), "Inbox");

        // Test with InboxOptimized4
        optimized4Gas = _measureProposalGas(new InboxOptimized4Deployer(), "InboxOptimized4");

        // Calculate gas savings
        uint256 gasSavings = standardInboxGas > optimized4Gas ?
            standardInboxGas - optimized4Gas : 0;
        uint256 percentageSavings = gasSavings > 0 ?
            (gasSavings * 10000) / standardInboxGas : 0; // Basis points (0.01% precision)

        // Log results for analysis
        console2.log("=== Gas Comparison Results ===");
        console2.log("Standard Inbox gas:     ", standardInboxGas);
        console2.log("InboxOptimized4 gas:    ", optimized4Gas);
        console2.log("Gas savings:            ", gasSavings);
        console2.log("Percentage savings (bp):", percentageSavings);

        // Verify that optimization provides gas savings
        assertGt(standardInboxGas, optimized4Gas, "InboxOptimized4 should use less gas than standard Inbox");

        // Verify minimum expected savings (adjust this threshold based on expected optimization)
        // Using a conservative 0.1% minimum improvement
        assertGt(percentageSavings, 10, "Gas savings should be at least 0.1%");
    }

    // ---------------------------------------------------------------
    // Internal Helper Functions
    // ---------------------------------------------------------------

    /// @notice Measures gas cost for a single proposal with the given deployer
    /// @param _deployer The inbox deployer to use
    /// @param _label Label for gas measurement
    /// @return gasUsed The gas consumed by the proposal operation
    function _measureProposalGas(IInboxDeployer _deployer, string memory _label)
        internal
        returns (uint256 gasUsed)
    {
        // Deploy the specific inbox implementation
        setDeployer(_deployer);
        super.setUp(); // This sets up the inbox with the current deployer

        // Setup blob hashes
        _setupBlobHashes();

        vm.startPrank(currentProposer);

        // Advance block for proper state
        vm.roll(block.number + 1);

        // Create proposal input after block roll to match checkpoint values
        bytes memory proposeData = _createFirstProposeInput();

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);

        // Start gas measurement
        uint256 gasStart = gasleft();

        // Expect the Proposed event with the correct data
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

        // Execute the proposal
        inbox.propose(bytes(""), proposeData);

        // Calculate gas used
        gasUsed = gasStart - gasleft();

        vm.stopPrank();

        // Verify proposal was successful
        bytes32 storedHash = inbox.getProposalHash(1);
        assertTrue(storedHash != bytes32(0), "Proposal hash should be stored");

        return gasUsed;
    }

    /// @notice Creates first propose input following the pattern from AbstractProposeTest
    function _createFirstProposeInput() internal view returns (bytes memory) {
        // For the first proposal after genesis, we need specific state
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        // Parent proposal is genesis (id=0)
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();

        // Create blob reference
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        // Create the propose input
        IInbox.ProposeInput memory input;
        input.coreState = coreState;
        input.parentProposals = parentProposals;
        input.blobReference = blobRef;

        return helper.encodeProposeInput(input);
    }

    /// @notice Builds expected proposed payload for event verification
    function _buildExpectedProposedPayload(uint48 _proposalId)
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        return _buildExpectedProposedPayload(_proposalId, 1, 0, currentProposer);
    }

    /// @notice Encodes proposed event payload for event verification
    function _encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        internal
        view
        returns (bytes memory)
    {
        return helper.encodeProposedEvent(_payload);
    }
}