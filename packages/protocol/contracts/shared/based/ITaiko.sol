// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ITaiko
/// @notice This interface is used for contracts identified by the "taiko" label in the address
/// resolver, specifically the TaikoInbox and TaikoAnchor contracts.
/// @custom:security-contact security@taiko.xyz
interface ITaiko {
    /// @notice Determines the operational layer of the contract, whether it is on Layer 1 (L1) or
    /// Layer 2 (L2).
    /// @return True if the contract is operating on L1, false if on L2.
    function isOnL1() external pure returns (bool);
}
