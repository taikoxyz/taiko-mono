// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IDelegationManager.sol";
import "../iface/IStrategyManager.sol";

contract DelegationManager is IDelegationManager {
    IStrategyManager internal immutable strategyManager;

    mapping(address operator => uint256 shares) internal operatorShares;

    constructor(IStrategyManager _strategyManager) {
        strategyManager = _strategyManager;
    }

    modifier onlyStrategyManager() {
        require(
            msg.sender == address(strategyManager),
            "DelegationManager: Only Strategy Manager allowed"
        );
        _;
    }

    /// @dev In this MVP, operator and staker are used interchangeably
    function increaseDelegatedShares(
        address operator,
        address strategy,
        uint256 shares
    )
        external
        onlyStrategyManager
    {
        require(strategy == address(0), "DelegationManager: Only ETH strategy supported");
        operatorShares[operator] += shares;
        emit OperatorSharesIncreased(operator, operator, strategy, shares);
    }

    /// @dev This has been modified from the original EL implementation to accomodate for slashing
    function getOperatorShares(
        address operator,
        address[] memory strategies
    )
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory shares = new uint256[](strategies.length);

        for (uint256 i; i < strategies.length; ++i) {
            require(strategies[i] == address(0), "DelegationManager: Only ETH strategy supported");
            shares[i] = operatorShares[operator];
        }
        return shares;
    }
}
