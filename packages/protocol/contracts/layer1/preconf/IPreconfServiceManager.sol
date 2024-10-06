// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfServiceManager
/// @custom:security-contact security@taiko.xyz
interface IPreconfServiceManager {
    function slashOperator(address operator) external;
}
