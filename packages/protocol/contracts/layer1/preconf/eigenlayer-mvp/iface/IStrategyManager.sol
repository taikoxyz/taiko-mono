// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IStrategyManager {
    event Deposit(address staker, address token, address strategy, uint256 shares);

    /// @dev In EL this function is non-payable and solely for staking ERC20 tokens
    function depositIntoStrategy(
        address strategy,
        address token,
        uint256 amount
    )
        external
        payable
        returns (uint256 shares);
}
