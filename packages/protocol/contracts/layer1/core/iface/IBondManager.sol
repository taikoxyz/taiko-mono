// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBondManager
/// @notice Interface for managing bonds on L1 in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
interface IBondManager {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bond is debited from an address.
    /// @param account The account from which the bond was debited.
    /// @param amount The amount debited.
    event BondDebited(address indexed account, uint256 amount);

    /// @notice Emitted when a bond is credited to an address.
    /// @param account The account to which the bond was credited.
    /// @param amount The amount credited.
    event BondCredited(address indexed account, uint256 amount);

    /// @notice Emitted when a bond is deposited into the manager.
    /// @param depositor The account that made the deposit.
    /// @param recipient The account that received the bond credit.
    /// @param amount The amount deposited.
    event BondDeposited(address indexed depositor, address indexed recipient, uint256 amount);

    /// @notice Emitted when a bond is withdrawn from the manager.
    /// @param account The account that withdrew the bond.
    /// @param amount The amount withdrawn.
    event BondWithdrawn(address indexed account, uint256 amount);

    /// @notice Emitted when a liveness bond is processed.
    /// @param payer The account whose bond was debited.
    /// @param payee The account receiving the reward.
    /// @param caller The account credited when payer == payee.
    /// @param debitedAmount The amount debited from the payer.
    /// @param payeeAmount The amount credited to the payee.
    /// @param callerAmount The amount credited to the caller.
    event LivenessBondProcessed(
        address indexed payer,
        address indexed payee,
        address indexed caller,
        uint256 debitedAmount,
        uint256 payeeAmount,
        uint256 callerAmount
    );

    // ---------------------------------------------------------------
    // Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Deposit ERC20 bond tokens for the caller.
    /// @param _amount The amount to deposit.
    function deposit(uint256 _amount) external;

    /// @notice Deposit ERC20 bond tokens for a recipient.
    /// @dev Recipient must be non-zero.
    /// @param _recipient The address to credit the bond to.
    /// @param _amount The amount to deposit.
    function depositTo(address _recipient, uint256 _amount) external;

    /// @notice Withdraw bond to a recipient.
    /// @param _to The recipient of withdrawn funds.
    /// @param _amount The amount to withdraw.
    function withdraw(address _to, uint256 _amount) external;

    /// @notice Returns the liveness bond amount.
    /// @return livenessBond_ The liveness bond amount.
    function livenessBond() external view returns (uint256 livenessBond_);

    // ---------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------

    /// @notice Gets the bond balance of an address.
    /// @param _address The address to get the bond balance for.
    /// @return bondBalance_ The bond balance of the address.
    function getBondBalance(address _address) external view returns (uint256 bondBalance_);

    /// @notice Checks if an account has sufficient bond to cover the liveness bond.
    /// @param _address The address to check.
    /// @param _additionalBond The additional bond required the account has to have on top of the
    /// liveness bond.
    /// @return hasBond_ True if the account has sufficient bond for a proposal.
    function hasSufficientBond(
        address _address,
        uint256 _additionalBond
    )
        external
        view
        returns (bool hasBond_);
}
