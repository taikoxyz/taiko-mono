// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISlasher {
    event OperatorSlashed(address indexed operator, address indexed avs);
    event OptedIntoSlashing(address indexed operator, address indexed avs);

    /// @notice Called externally by the AVS operator client to allow AVS to slash the operator in
    /// the future
    /// @param avs The address of the AVS
    function optIntoSlashing(address avs) external;

    /// @dev Called internally by the AVS (specifically the Service Manager) to slash the operator
    /// @param operator The address of the operator to be slashed
    function slashOperator(address operator) external;

    /// @notice Checks if the operator has been slashed
    /// @param operator The address of the operator
    /// @return bool True if the operator has been slashed, false otherwise
    function isOperatorSlashed(address operator) external view returns (bool);
}
