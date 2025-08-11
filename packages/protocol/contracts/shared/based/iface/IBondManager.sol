// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBondManager
/// @notice Interface for managing bonds in the Based3 protocol
/// @custom:security-contact security@taiko.xyz
interface IBondManager {
    /// @notice Represents a bond for a given address.
    struct Bond {
        uint96 balance;
        uint48 withdrawalRequestedAt; // 0 = active, >0 = withdrawal requested timestamp
    }

    // -------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------

    /// @notice Emitted when a bond is debited from an address
    /// @param account The account from which the bond was debited
    /// @param amount The amount debited
    event BondDebited(address indexed account, uint96 amount);

    /// @notice Emitted when a bond is credited to an address
    /// @param account The account to which the bond was credited
    /// @param amount The amount credited
    event BondCredited(address indexed account, uint96 amount);

    /// @notice Emitted when a bond is deposited into the manager
    /// @param account The account that deposited the bond
    /// @param amount The amount deposited
    event BondDeposited(address indexed account, uint96 amount);

    /// @notice Emitted when a bond is withdrawn from the manager
    /// @param account The account that withdrew the bond
    /// @param amount The amount withdrawn
    event BondWithdrawn(address indexed account, uint96 amount);

    // -------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------

    /// @notice Debits a bond from an address with best effort
    /// @param _address The address to debit the bond from
    /// @param _bond The amount of bond to debit
    /// @return amountDebited_ The actual amount debited
    function debitBond(address _address, uint96 _bond) external returns (uint96 amountDebited_);

    /// @notice Credits a bond to an address
    /// @param _address The address to credit the bond to
    /// @param _bond The amount of bond to credit
    function creditBond(address _address, uint96 _bond) external;

    /// @notice Gets the bond balance of an address
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function getBondBalance(address _address) external view returns (uint96);

    /// @notice Deposit ERC20 bond tokens into the manager.
    /// @param amount The amount to deposit.
    function deposit(uint96 amount) external;

    /// @notice Withdraw bond to a recipient.
    /// @dev On L1, withdrawal is subject to time-based security. On L2, withdrawals are
    /// unrestricted.
    /// @param to The recipient of withdrawn funds.
    /// @param amount The amount to withdraw.
    function withdraw(address to, uint96 amount) external;
}
