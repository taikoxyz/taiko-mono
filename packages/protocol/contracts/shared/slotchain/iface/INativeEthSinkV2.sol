// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain V2 native-ETH sink
/// @notice Accepts native ETH sent with empty calldata by a Slot Chain V2 custody component.
/// @dev Implementations may execute arbitrary code, including callbacks. Callers must apply
///      checks-effects-interactions and their protocol-specific reentrancy guard before transfer.
/// @custom:security-contact security@taiko.xyz
interface INativeEthSinkV2 {
    /// @notice Receives native ETH with empty calldata.
    receive() external payable;
}
