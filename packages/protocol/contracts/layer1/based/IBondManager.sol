// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBondManager
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
interface IBondManager {
    /// @notice Emitted when tokens are deposited into a user's bond balance.
    /// @param user The address of the user who deposited the tokens.
    /// @param amount The amount of tokens deposited.
    event BondDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn from a user's bond balance.
    /// @param user The address of the user who withdrew the tokens.
    /// @param amount The amount of tokens withdrawn.
    event BondWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a token is credited back to a user's bond balance.
    /// @param user The address of the user whose bond balance is credited.
    /// @param amount The amount of tokens credited.
    event BondCredited(address indexed user, uint256 amount);

    /// @notice Emitted when a token is debited from a user's bond balance.
    /// @param user The address of the user whose bond balance is debited.
    /// @param amount The amount of tokens debited.
    event BondDebited(address indexed user, uint256 amount);

    /// @notice Deposits TAIKO tokens into the contract to be used as liveness bond.
    /// @param _amount The amount of TAIKO tokens to deposit.
    function v4DepositBond(uint256 _amount) external payable;

    /// @notice Withdraws a specified amount of TAIKO tokens from the contract.
    /// @param _amount The amount of TAIKO tokens to withdraw.
    function v4WithdrawBond(uint256 _amount) external;

    /// @notice Returns the TAIKO token balance of a specific user.
    /// @param _user The address of the user.
    /// @return The TAIKO token balance of the user.
    function v4BondBalanceOf(address _user) external view returns (uint256);

    /// @notice Retrieves the Bond token address. If Ether is used as bond, this function returns
    /// address(0).
    /// @return The Bond token address.
    function v4BondToken() external view returns (address);
}
