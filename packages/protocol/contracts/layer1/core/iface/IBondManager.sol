// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IBondManager
/// @notice Interface for managing bonds on L1 in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
interface IBondManager {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents a bond for a given address.
    struct Bond {
        /// @notice The bond balance in gwei.
        uint64 balance;
        /// @notice The timestamp when the withdrawal was requested.
        /// @dev 0 = active, >0 = withdrawal requested timestamp
        uint48 withdrawalRequestedAt;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bond is deposited.
    /// @param depositor The account that made the deposit.
    /// @param recipient The account that received the bond credit.
    /// @param amount The amount deposited in gwei.
    event BondDeposited(address indexed depositor, address indexed recipient, uint64 amount);

    /// @notice Emitted when a bond is withdrawn.
    /// @param account The account that withdrew the bond.
    /// @param amount The amount withdrawn in gwei.
    event BondWithdrawn(address indexed account, uint64 amount);

    /// @notice Emitted when a withdrawal is requested.
    /// @param account The account requesting withdrawal.
    /// @param withdrawableAt The timestamp when withdrawal becomes unrestricted.
    event WithdrawalRequested(address indexed account, uint48 withdrawableAt);

    /// @notice Emitted when a withdrawal request is cancelled.
    /// @param account The account cancelling the withdrawal request.
    event WithdrawalCancelled(address indexed account);

    /// @notice Emitted when a liveness bond is settled.
    /// @param payer The account that paid the liveness bond.
    /// @param payee The account that received the liveness bond.
    /// @param livenessBond The value of the liveness bond in gwei.
    /// @param credited The amount of the liveness bond that was credited to the payee in gwei.
    /// @param slashed The amount of the liveness bond that was slashed in gwei.
    event LivenessBondSettled(
        address indexed payer,
        address indexed payee,
        uint64 livenessBond,
        uint64 credited,
        uint64 slashed
    );

    // ---------------------------------------------------------------
    // Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Deposits bond tokens for the caller.
    /// @dev Clears the caller's pending withdrawal request, if any.
    /// @param _amount The amount to deposit in gwei.
    function deposit(uint64 _amount) external;

    /// @notice Deposits bond tokens for a recipient.
    /// @dev Recipient must be non-zero. Does not cancel the recipient's pending withdrawal,
    /// even if the recipient is the caller.
    /// @param _recipient The address to credit the bond to.
    /// @param _amount The amount to deposit in gwei.
    function depositTo(address _recipient, uint64 _amount) external;

    /// @notice Withdraws bond to a recipient.
    /// @dev Withdrawals are subject to a delay so bond operations can be resolved properly.
    /// The user can always withdraw any excess amount without delays.
    /// If this withdrawal debits the entire bond balance, any pending withdrawal request is
    /// cleared.
    /// @param _to The recipient of withdrawn funds.
    /// @param _amount The amount to withdraw in gwei.
    function withdraw(address _to, uint64 _amount) external;

    /// @notice Requests to start the withdrawal process.
    /// @dev Account cannot perform bond-restricted actions after requesting withdrawal.
    function requestWithdrawal() external;

    /// @notice Cancels withdrawal request to reactivate the account.
    /// @dev Can be called during or after the withdrawal delay period.
    function cancelWithdrawal() external;

    // ---------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------

    /// @notice Gets the bond state of an address.
    /// @param _address The address to get the bond state for.
    /// @return bond_ The bond struct for the address.
    function getBond(address _address) external view returns (Bond memory bond_);
}
