// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBondManager
/// @notice Interface for managing bonds in the Based3 protocol
/// @custom:security-contact security@taiko.xyz
interface IBondManager {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents a bond for a given address.
    struct Bond {
        uint256 balance; // Bond balance
        uint48 withdrawalRequestedAt; // 0 = active, >0 = withdrawal requested timestamp
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bond is debited from an address
    /// @param account The account from which the bond was debited
    /// @param amount The amount debited
    event BondDebited(address indexed account, uint256 amount);

    /// @notice Emitted when a bond is credited to an address
    /// @param account The account to which the bond was credited
    /// @param amount The amount credited
    event BondCredited(address indexed account, uint256 amount);

    /// @notice Emitted when a bond is deposited into the manager
    /// @param account The account that deposited the bond
    /// @param amount The amount deposited
    event BondDeposited(address indexed account, uint256 amount);

    /// @notice Emitted when a bond is deposited for another address
    /// @param depositor The account that made the deposit
    /// @param recipient The account that received the bond credit
    /// @param amount The amount deposited
    event BondDepositedFor(address indexed depositor, address indexed recipient, uint256 amount);

    /// @notice Emitted when a bond is withdrawn from the manager
    /// @param account The account that withdrew the bond
    /// @param amount The amount withdrawn
    event BondWithdrawn(address indexed account, uint256 amount);

    /// @notice Emitted when a withdrawal is requested
    event WithdrawalRequested(address indexed account, uint256 withdrawableAt);

    /// @notice Emitted when a withdrawal request is cancelled
    event WithdrawalCancelled(address indexed account);

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Debits a bond from an address with best effort
    /// @dev Best effort means that if `_bond` is greater than the balance, the entire balance is
    /// debited instead
    /// @param _address The address to debit the bond from
    /// @param _bond The amount of bond to debit
    /// @return amountDebited_ The actual amount debited
    function debitBond(
        address _address,
        uint256 _bond
    )
        external
        returns (uint256 amountDebited_);

    /// @notice Credits a bond to an address
    /// @param _address The address to credit the bond to
    /// @param _bond The amount of bond to credit
    function creditBond(address _address, uint256 _bond) external;

    /// @notice Gets the bond balance of an address
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function getBondBalance(address _address) external view returns (uint256);

    /// @notice Deposit ERC20 bond tokens into the manager.
    /// @param _amount The amount to deposit.
    function deposit(uint256 _amount) external;

    /// @notice Deposit ERC20 bond tokens for another address.
    /// @param _recipient The address to credit the bond to.
    /// @param _amount The amount to deposit.
    function depositTo(address _recipient, uint256 _amount) external;

    /// @notice Withdraw bond to a recipient.
    /// @dev On L1, withdrawal is subject to time-based security. On L2, withdrawals are
    /// unrestricted.
    /// @param _to The recipient of withdrawn funds.
    /// @param _amount The amount to withdraw.
    function withdraw(address _to, uint256 _amount) external;

    /// @notice Checks if an account has sufficient bond and hasn't requested withdrawal
    /// @param _address The address to check
    /// @param _additionalBond The additional bond required the account has to have on top of the
    /// minimum bond
    /// @return True if the account has sufficient bond and is active
    function hasSufficientBond(
        address _address,
        uint256 _additionalBond
    )
        external
        view
        returns (bool);

    /// @notice Request to start the withdrawal process
    /// @dev Account cannot perform bond-restricted actions after requesting withdrawal
    function requestWithdrawal() external;

    /// @notice Cancel withdrawal request to reactivate the account
    /// @dev Can be called during or after the withdrawal delay period
    function cancelWithdrawal() external;
}
