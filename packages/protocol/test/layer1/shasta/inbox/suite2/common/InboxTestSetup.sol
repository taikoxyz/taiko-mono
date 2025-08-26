// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../helpers/InboxTestHelper.sol";
import { PreconfWhitelistSetup } from "./PreconfWhitelistSetup.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { ForcedInclusionStore } from "contracts/layer1/shasta/impl/ForcedInclusionStore.sol";
import { IForcedInclusionStore } from "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import { IProofVerifier } from "contracts/layer1/shasta/iface/IProofVerifier.sol";
import { IProposerChecker } from "contracts/layer1/shasta/iface/IProposerChecker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISyncedBlockManager } from "src/shared/based/iface/ISyncedBlockManager.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgrades/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    MockERC20,
    MockSyncedBlockManager,
    MockProofVerifier
} from "../mocks/MockContracts.sol";

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
    ISyncedBlockManager internal syncedBlockManager;
    IProofVerifier internal proofVerifier;
    IProposerChecker internal proposerChecker;

    // Dependencies
    IForcedInclusionStore internal forcedInclusionStore;
    
    // Proposer helper (using composition instead of inheritance to avoid diamond problem)
    PreconfWhitelistSetup internal proposerHelper;

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();
        
        // Create proposer helper
        proposerHelper = new PreconfWhitelistSetup();
        
        // Deploy dependencies
        _setupDependencies();

        // Setup mocks
        _setupMocks();

        // Deploy inbox through implementation-specific method
        inbox = deployInbox(
            address(bondToken),
            address(syncedBlockManager),
            address(proofVerifier),
            address(proposerChecker),
            address(forcedInclusionStore)
        );

        _upgradeDependencies(address(inbox));

        // Advance block to ensure we have block history
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);
    }

    /// @dev We usually avoid mocks as much as possible since they might make testing flaky
    /// @dev We use mocks for the dependencies that are not important, well tested and with uniform
    /// behavior(e.g. ERC20) or that are not implemented yet
    function _setupMocks() internal {
        bondToken = new MockERC20();
        syncedBlockManager = new MockSyncedBlockManager();
        proofVerifier = new MockProofVerifier();
    }

    /// @dev Deploy the real contracts that will be used as dependencies of the inbox
    ///      Some of these may need to be upgraded later because of circular references
    function _setupDependencies() internal virtual {
        // Deploy ForcedInclusionStore
        address forcedInclusionStoreImplementation =
            address(new ForcedInclusionStore(INCLUSION_DELAY, FEE_IN_GWEI, address(0)));

        forcedInclusionStore = IForcedInclusionStore(
            deploy({
                name: "",
                impl: forcedInclusionStoreImplementation,
                data: abi.encodeCall(ForcedInclusionStore.init, (owner))
            })
        );

        // Deploy PreconfWhitelist directly as proposer checker
        proposerChecker = proposerHelper._deployPreconfWhitelist(owner);
    }
    
    /// @dev Helper function to select a proposer (delegates to proposer helper)
    function _selectProposer(address _proposer) internal returns (address) {
        return proposerHelper._selectProposer(proposerChecker, _proposer);
    }

    /// @dev Upgrade the dependencies of the inbox
    ///      This is used to upgrade the dependencies of the inbox after the inbox is deployed
    ///      and the dependencies are not upgradable
    function _upgradeDependencies(address _inbox) internal {
        address newForcedInclusionStore =
            address(new ForcedInclusionStore(INCLUSION_DELAY, FEE_IN_GWEI, _inbox));

        vm.prank(owner);
        UUPSUpgradeable(address(forcedInclusionStore)).upgradeTo(newForcedInclusionStore);
    }

    // ---------------------------------------------------------------
    // Abstract Functions
    // ---------------------------------------------------------------

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        virtual
        returns (Inbox);
}