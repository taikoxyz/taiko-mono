// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfServiceManager
/// @custom:security-contact security@taiko.xyz
interface IPreconfServiceManager {
    /// @dev Called by PreconfTaskManager to slash an operator for incorret lookahead or
    /// preconfirmation
    function slashOperator(address _operatoroperator) external;

    /// @dev Called by PreconfTaskManager to prevent withdrawals of stake during preconf or
    /// lookahead dispute period
    function lockStakeUntil(address _operator, uint256 _timestamp) external;
}
