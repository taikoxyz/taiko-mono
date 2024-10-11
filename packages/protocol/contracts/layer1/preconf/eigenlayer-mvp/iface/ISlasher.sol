// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISlasher {
    event OperatorSlashed(address indexed operator, address indexed avs);
    event OptedIntoSlashing(address indexed operator, address indexed avs);

    /// @dev Called externally by the AVS operator client to allow AVS to slash the operator in the
    /// future
    function optIntoSlashing(address avs) external;

    /// @dev Called internally by the AVS (specifically the Service Manager) to slash the operator
    function slashOperator(address operator) external;

    function isOperatorSlashed(address operator) external view returns (bool);
}
