// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPreconfServiceManager {
    event StakeLockedUntil(address indexed operator, uint256 timestamp);

    error SenderIsNotAllowed();
    error OperatorAlreadySlashed();

    /// @dev Only callable by the registry
    function registerOperatorToAVS(address operator, bytes calldata operatorSignature) external;

    /// @dev Only callable by the registry
    function deregisterOperatorFromAVS(address operator) external;

    /// @dev Only Callable by PreconfTaskManager to prevent withdrawals of stake during preconf or
    /// lookahead dispute period
    function lockStakeUntil(address operator, uint256 timestamp) external;

    /// @dev Only Callable by PreconfTaskManager to slash an operator for incorrect lookahead or
    /// preconfirmation
    function slashOperator(address operator) external;
}
