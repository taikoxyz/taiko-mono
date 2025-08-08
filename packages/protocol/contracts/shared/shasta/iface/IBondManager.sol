// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";

/// @title IBondManager
/// @notice Interface for managing bonds in the Based3 protocol
/// @custom:security-contact security@taiko.xyz
interface IBondManager {
    /// @notice Represents a bond for a given address.
    /// @dev On L2, the `maxProposedId` is not used.
    struct Bond {
        uint48 maxProposedId;
        uint96 balance;
    }

    // -------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------

    /// @notice Emitted when a bond is debited from an address
    /// @param account The account from which the bond was debited
    /// @param amount The amount debited
    event BondDebited(address indexed account, uint256 amount);

    /// @notice Emitted when a bond is credited to an address
    /// @param account The account to which the bond was credited
    /// @param amount The amount credited
    event BondCredited(address indexed account, uint256 amount);

    // -------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------

    /// @notice Debits a bond from an address with best effort
    /// @param _address The address to debit the bond from
    /// @param _bond The amount of bond to debit
    /// @return amountDebited_ The actual amount debited
    function debitBond(address _address, uint256 _bond) external returns (uint256 amountDebited_);

    /// @notice Credits a bond to an address
    /// @param _address The address to credit the bond to
    /// @param _bond The amount of bond to credit
    function creditBond(address _address, uint256 _bond) external;

    /// @notice Gets the bond balance of an address
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function getBondBalance(address _address) external view returns (uint256);

    // -------------------------------------------------------------------------
    // New Functions (Shasta withdraw flow)
    // -------------------------------------------------------------------------

    /// @notice Notifies the bond manager that a proposal was created by a proposer and checks that the proposer has enough balance.
    /// @dev Called only by the authorized inbox contract.
    /// @param proposer The proposer address.
    /// @param proposalId The proposal id.
    /// @param minBondBalance The minimum bond balance required for the proposer.
    function notifyProposed(address proposer, uint48 proposalId, uint256 minBondBalance) external;

    /// @notice Withdraw bond to a recipient.
    /// @dev On L1, this enforces that the caller has no unfinalized proposals by verifying
    ///      the provided core state against the inbox's current core state hash. On L2, the
    ///      guard is skipped and only balance checks apply in the implementation.
    /// @param to The recipient of withdrawn funds.
    /// @param amount The amount to withdraw.
    /// @param coreState The core state to validate (ignored on L2 implementations).
    function withdraw(address to, uint256 amount, IInbox.CoreState calldata coreState) external;
}
