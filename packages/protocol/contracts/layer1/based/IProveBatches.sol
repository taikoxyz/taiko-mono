// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProveBatches
/// @notice This interface defines the v4ProveBatches function.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
interface IProveBatches {
    /// @notice Proves state transitions for multiple batches with a single aggregated proof.
    /// @param _params ABI-encoded parameter containing:
    /// - metas: Array of metadata for each batch being proved.
    /// - transitions: Array of batch transitions to be proved.
    /// @param _proof The aggregated cryptographic proof proving the batches transitions.
    function v4ProveBatches(bytes calldata _params, bytes calldata _proof) external;
}
