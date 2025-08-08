// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBondManager
/// @notice Interface for managing bonds in the Based3 protocol
/// @custom:security-contact security@taiko.xyz
interface IBondManager {
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
}
