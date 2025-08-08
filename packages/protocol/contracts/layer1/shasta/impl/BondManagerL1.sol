// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BondManager } from "contracts/shared/shasta/impl/BondManager.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { IBondManagerL1 } from "../iface/IBondManagerL1.sol";

/// @title BondManagerL1
/// @notice L1 implementation of BondManager with time-based withdrawal mechanism
/// @custom:security-contact security@taiko.xyz
contract BondManagerL1 is BondManager, IBondManagerL1 {
    // -------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------

    /// @notice Minimum bond required on L1 to propose
    uint96 public immutable minBond;

    /// @notice Time delay required before withdrawal after request
    /// @dev WARNING: In theory proposal can remain unfinalized indefinitely, but in practice after
    ///      the `extendedProvingWindow` the incentives are very strong for a prover to come in.
    ///      A safe value for this is `extendedProvingWindow` + buffer.
    uint48 public immutable withdrawalDelay;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------

    /// @notice Initializes the L1 BondManager
    /// @param _authorized The address of the authorized contract (Inbox)
    /// @param _bondToken The ERC20 bond token address
    /// @param _minBond The minimum bond required for proposers
    /// @param _withdrawalDelay The delay period for withdrawals (e.g., 7 days)
    constructor(
        address _authorized,
        address _bondToken,
        uint96 _minBond,
        uint48 _withdrawalDelay
    )
        BondManager(_authorized, _bondToken)
    {
        minBond = _minBond;
        withdrawalDelay = _withdrawalDelay;
    }

    // -------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------

    /// @inheritdoc IBondManagerL1
    function isProposerActive(address proposer) external view returns (bool) {
        Bond storage bond_ = bond[proposer];
        return bond_.balance >= minBond && bond_.withdrawalRequestedAt == 0;
    }

    /// @inheritdoc IBondManagerL1
    function requestWithdrawal() external {
        Bond storage bond_ = bond[msg.sender];
        require(bond_.balance > 0, NoBondToWithdraw());
        require(bond_.withdrawalRequestedAt == 0, WithdrawalAlreadyRequested());

        bond_.withdrawalRequestedAt = uint48(block.timestamp);
        emit WithdrawalRequested(msg.sender, block.timestamp + withdrawalDelay);
    }

    /// @inheritdoc IBondManagerL1
    function reactivate() external {
        Bond storage bond_ = bond[msg.sender];
        require(bond_.withdrawalRequestedAt > 0, NoWithdrawalRequested());

        bond_.withdrawalRequestedAt = 0;
        emit WithdrawalCancelled(msg.sender);
    }

    /// @notice Withdraw bond to a recipient with time-based security
    /// @dev Allows immediate withdrawal of excess above minBond for active proposers,
    ///      or full withdrawal after delay period for exiting proposers
    function withdraw(address to, uint96 amount) external override(BondManager, IBondManager) {
        Bond storage bond_ = bond[msg.sender];

        bool beforeWithdrawalDelay = block.timestamp < bond_.withdrawalRequestedAt + withdrawalDelay;
        if (bond_.withdrawalRequestedAt == 0 || beforeWithdrawalDelay) {
            // Active proposer or withdrawal delay not passed yet, can only withdraw excess above
            // minBond
            require(bond_.balance - amount >= minBond, MustMaintainMinBond());
        } else {
            // Exiting proposer - check if withdrawal delay has passed
            require(!beforeWithdrawalDelay, WithdrawalDelayNotMet());
        }

        _withdraw(msg.sender, to, amount);
    }

    // -------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------

    error NoBondToWithdraw();
    error WithdrawalAlreadyRequested();
    error NoWithdrawalRequested();
    error WithdrawalDelayNotMet();
    error MustMaintainMinBond();
}
