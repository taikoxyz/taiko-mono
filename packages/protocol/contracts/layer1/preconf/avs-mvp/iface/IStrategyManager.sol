// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategyManager {
    event Deposit(
        address indexed staker, address indexed token, address indexed strategy, uint256 shares
    );

    /// @notice Deposits ERC20 tokens into a specified strategy
    /// @param strategy The address of the strategy to deposit into
    /// @param token The address of the ERC20 token to deposit
    /// @param amount The amount of tokens to deposit
    /// @return shares The number of shares received in the strategy
    function depositIntoStrategy(
        address strategy,
        address token,
        uint256 amount
    )
        external
        payable
        returns (uint256 shares);
}
