// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/eigenlayer-mvp/IStrategyManager.sol";
import "../iface/eigenlayer-mvp/IDelegationManager.sol";

contract StrategyManager is IStrategyManager {
    IDelegationManager internal immutable delegation;

    uint256 internal constant ETH_DEPOSIT = 1 ether;

    constructor(IDelegationManager _delegation) {
        delegation = _delegation;
    }

    function depositIntoStrategy(
        address strategy,
        address token,
        uint256 amount
    )
        external
        payable
        returns (uint256 shares)
    {
        require(strategy == address(0), "StrategyManager: Only ETH strategy supported");
        require(token == address(0), "StrategyManager: Only ETH deposits supported");
        require(
            msg.value == ETH_DEPOSIT && amount == ETH_DEPOSIT,
            "StrategyManager: Invalid ETH deposit"
        );

        // In the MVP, the shares equal the sent amount as we do not have any form of reward accrual
        shares = amount;

        delegation.increaseDelegatedShares(msg.sender, strategy, shares);

        emit Deposit(msg.sender, token, strategy, shares);
    }
}
