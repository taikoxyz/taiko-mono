// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ISnapshot

interface ISnapshot {
    function snapshot() external returns (uint256);
}
