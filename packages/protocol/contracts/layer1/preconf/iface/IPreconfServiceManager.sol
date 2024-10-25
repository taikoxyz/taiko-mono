// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPreconfServiceManager {
    event StakeLockedUntil(address indexed operator, uint256 timestamp);

    error SenderIsNotAllowed();
    error OperatorAlreadySlashed();

    /// @notice Registers an operator to AVS
    /// @dev Only callable by the registry
    /// @param operator The address of the operator to register
    /// @param operatorSignature The signature of the operator
    function registerOperatorToAVS(address operator, bytes calldata operatorSignature) external;

    /// @notice Deregisters an operator from AVS
    /// @dev Only callable by the registry
    /// @param operator The address of the operator to deregister
    function deregisterOperatorFromAVS(address operator) external;

    /// @notice Locks the stake of an operator until a specified timestamp
    /// @dev Only Callable by PreconfTaskManager to prevent withdrawals of stake during preconf or
    /// lookahead dispute period
    /// @param operator The address of the operator whose stake is to be locked
    /// @param timestamp The timestamp until which the stake is locked
    function lockStakeUntil(address operator, uint256 timestamp) external;

    /// @notice Slashes an operator for incorrect lookahead or preconfirmation
    /// @dev Only Callable by PreconfTaskManager to slash an operator for incorrect lookahead or
    /// preconfirmation
    /// @param operator The address of the operator to slash
    function slashOperator(address operator) external;
}
