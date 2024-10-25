// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDelegationManager {
    event OperatorSharesIncreased(
        address indexed operator, address staker, address strategy, uint256 shares
    );

    /// @dev Called internally in EL by Strategy Manager to increase delegated shares
    /// @param operator The address of the operator
    /// @param strategy The address of the strategy
    /// @param shares The number of shares to increase
    function increaseDelegatedShares(address operator, address strategy, uint256 shares) external;

    /// @notice Called by the AVS Stake Registry to get operator shares
    /// @param operator The address of the operator
    /// @param strategies The array of strategy addresses
    /// @return An array of shares corresponding to each strategy
    function getOperatorShares(
        address operator,
        address[] memory strategies
    )
        external
        view
        returns (uint256[] memory);
}
