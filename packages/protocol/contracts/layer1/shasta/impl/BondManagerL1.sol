// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BondManager } from "contracts/shared/shasta/impl/BondManager.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { IBondManagerL1 } from "../iface/IBondManagerL1.sol";
import { IInbox } from "../iface/IInbox.sol";

/// @title BondManagerL1
/// @notice L1 implementation of BondManager with finalization guards
/// @custom:security-contact security@taiko.xyz
contract BondManagerL1 is BondManager, IBondManagerL1 {
    // -------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------

    /// @notice Minimum bond required on L1 to propose. uint96-bounded.
    uint96 public immutable minBond;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------

    /// @notice Initializes the L1 BondManager
    /// @param _authorized The address of the authorized contract (Inbox)
    /// @param _bondToken The ERC20 bond token address
    /// @param _minBond The minimum bond required for proposers
    constructor(
        address _authorized,
        address _bondToken,
        uint96 _minBond
    )
        BondManager(_authorized, _bondToken)
    {
        minBond = _minBond;
    }

    // -------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------

    /// @inheritdoc IBondManagerL1
    function notifyProposed(address proposer, uint48 proposalId) external onlyAuthorized {
        Bond storage bond_ = bond[proposer];
        if (bond_.balance < minBond) revert InsufficientBond();
        bond_.maxProposedId = proposalId;
    }

    /// @notice Withdraw bond to a recipient with finalization guard
    /// @dev On L1, we only allow withdrawals that do not have unfinalized proposals or that are
    /// down to the minimum bond.
    function withdraw(
        address to,
        uint96 amount,
        IInbox.CoreState calldata coreState
    )
        external
        override(BondManager, IBondManager)
    {
        // Verify core state hash
        bytes32 expected = IInbox(authorized).getCoreStateHash();
        if (keccak256(abi.encode(coreState)) != expected) revert InvalidState();

        // Check for unfinalized proposals
        Bond storage bond_ = bond[msg.sender];
        bool hasUnfinalized = bond_.maxProposedId > coreState.lastFinalizedProposalId;
        if (hasUnfinalized) {
            // Allow withdrawal only down to minBond
            require(bond_.balance - amount >= minBond, UnfinalizedProposals());
        }

        // Use common withdrawal logic
        _withdraw(msg.sender, to, amount);
    }
}
