// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBondManager2
/// @notice Interface for managing bonds in the Taiko protocol.
/// @dev This interface defines functions for depositing, withdrawing, and querying bond balances.
/// @custom:security-contact security@taiko.xyz
interface IBondManager2 {
    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when tokens are deposited into a user's bond balance.
    /// @param user The address of the user who deposited the tokens.
    /// @param amount The amount of tokens deposited.
    event BondDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn from a user's bond balance.
    /// @param user The address of the user who withdrew the tokens.
    /// @param amount The amount of tokens withdrawn.
    event BondWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are credited back to a user's bond balance.
    /// @param user The address of the user whose bond balance is credited.
    /// @param amount The amount of tokens credited.
    event BondCredited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are debited from a user's bond balance.
    /// @param user The address of the user whose bond balance is debited.
    /// @param amount The amount of tokens debited.
    event BondDebited(address indexed user, uint256 amount);

    // -------------------------------------------------------------------------
    // Bond Operations
    // -------------------------------------------------------------------------

    /// @notice Deposits tokens into the contract to be used as bond.
    /// @dev If the bond token is Ether, msg.value must be equal to _amount.
    /// @param _amount The amount of tokens to deposit.
    function deposit4(uint256 _amount) external payable;

    /// @notice Withdraws a specified amount of tokens from the user's bond balance.
    /// @param _amount The amount of tokens to withdraw.
    function withdraw4(uint256 _amount) external;

    // -------------------------------------------------------------------------
    // Getters
    // -------------------------------------------------------------------------

    /// @notice Returns the bond balance of a specific user.
    /// @param _user The address of the user.
    /// @return The bond balance of the user.
    function balanceOf4(address _user) external view returns (uint256);

    /// @notice Retrieves the bond token address.
    /// @dev Returns address(0) if Ether is used as the bond token.
    /// @return The bond token address.
    function token4() external view returns (address);
}
