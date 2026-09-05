// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain component configuration interface
/// @custom:security-contact security@taiko.xyz
interface IComponentConfigV2 {
    /// @notice Returns the immutable component configuration commitment.
    /// @dev Callers authenticate the component runtime before making this exact fixed-width read.
    /// @return configHash_ The component's canonical configuration hash.
    function componentConfigHashV2() external view returns (bytes32 configHash_);
}
