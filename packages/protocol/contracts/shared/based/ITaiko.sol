// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ITaiko
/// @notice This interface is used for contracts identified by the "taiko" label in the address
/// resolver, specifically the TaikoInbox and TaikoAnchor contracts.
/// @custom:security-contact security@taiko.xyz
interface ITaiko {
    /// @notice Checks if the contract is a TaikoInbox contract or a TaikoAnchor contract.
    /// @return True if the contract is a TaikoInbox contract, false if it is a TaikoAnchor
    /// contract.
    function v4IsInbox() external pure returns (bool);
}
