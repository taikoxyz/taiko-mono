// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "./InboxTestHelper.sol";
import { PreconfWhitelistSetup } from "./PreconfWhitelistSetup.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { IProofVerifier } from "src/layer1/shasta/iface/IProofVerifier.sol";
import { IProposerChecker } from "src/layer1/shasta/iface/IProposerChecker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { MockERC20, MockCheckpointProvider, MockProofVerifier } from "../mocks/MockContracts.sol";
import { IInboxDeployer } from "../deployers/IInboxDeployer.sol";

/// @title InboxTestSetup
/// @notice Common setup logic for Inbox tests - handles deployment and dependencies
abstract contract InboxTestSetup is InboxTestHelper {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    Inbox internal inbox;
    address internal owner = Alice;

    // Mock contracts
    IERC20 internal bondToken;
    ICheckpointStore internal checkpointManager;
    IProofVerifier internal proofVerifier;
    IProposerChecker internal proposerChecker;

    // Deployer for creating inbox instances
    IInboxDeployer internal inboxDeployer;

    // Proposer helper (using composition instead of inheritance to avoid diamond problem)
    PreconfWhitelistSetup internal proposerHelper;

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    /// @dev Set the deployer to use for creating inbox instances
    function setDeployer(IInboxDeployer _deployer) internal {
        inboxDeployer = _deployer;
    }

    function setUp() public virtual override {
        super.setUp();

        // Create proposer helper
        proposerHelper = new PreconfWhitelistSetup();

        // Deploy dependencies
        _setupDependencies();

        // Setup mocks
        _setupMocks();

        // Deploy inbox using the deployer
        require(address(inboxDeployer) != address(0), "Deployer not set");
        inbox = inboxDeployer.deployInbox(
            address(bondToken),
            address(proofVerifier),
            address(proposerChecker)
        );

        _initializeEncodingHelper(inboxDeployer.getTestContractName());

        // Advance block to ensure we have block history
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);
    }

    /// @dev We usually avoid mocks as much as possible since they might make testing flaky
    /// @dev We use mocks for the dependencies that are not important, well tested and with uniform
    /// behavior(e.g. ERC20) or that are not implemented yet
    function _setupMocks() internal {
        bondToken = new MockERC20();
        checkpointManager = new MockCheckpointProvider();
        proofVerifier = new MockProofVerifier();
    }

    /// @dev Deploy the real contracts that will be used as dependencies of the inbox
    function _setupDependencies() internal virtual {
        // Deploy PreconfWhitelist directly as proposer checker
        proposerChecker = proposerHelper._deployPreconfWhitelist(owner);
    }

    /// @dev Helper function to select a proposer (delegates to proposer helper)
    function _selectProposer(address _proposer) internal returns (address) {
        return proposerHelper._selectProposer(proposerChecker, _proposer);
    }

    /// @dev Returns the name of the test contract for snapshot identification
    /// @dev Delegates to the deployer to get the appropriate name
    function getTestContractName() internal view virtual returns (string memory) {
        require(address(inboxDeployer) != address(0), "Deployer not set");
        if (bytes(inboxContractName).length != 0) {
            return inboxContractName;
        }
        return inboxDeployer.getTestContractName();
    }
}
