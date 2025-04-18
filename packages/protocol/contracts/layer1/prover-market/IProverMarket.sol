// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverMarket
/// @custom:security-contact security@taiko.xyz
interface IProverMarket {
    /// @notice Emitted when a new prover wins the auction.
    event ProverChanged(address indexed prover, uint256 fee, uint256 exitTimestamp);

    /// @notice Emitted when the prover is used by TaikoInbox for a given batch.
    event ProverAssigned(address indexed prover, uint256 fee, uint64 indexed batchId);

    /// @notice Returns the current winning prover and proving fee per batch.
    /// @dev address(0) and 0 will be returned if there is no current prover.
    /// @return prover_ The address of the current winning prover.
    /// @return fee_ The proving fee per batch.
    function getCurrentProver() external view returns (address prover_, uint256 fee_);

    /// @notice Called by TaikoInbox when the prover market is used.
    /// @param _prover The address of the prover.
    /// @param _fee The proving fee per batch.
    /// @param _batchId The batch id.
    function onProverAssigned(address _prover, uint256 _fee, uint64 _batchId) external;
}
