// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverMarket
/// @custom:security-contact security@taiko.xyz
interface IProverMarket {
    /// @notice Emitted when a new prover wins the auction.
    event ProverChanged(address indexed prover, uint256 fee, uint256 exitTimestamp);

    /// @notice Returns the current winning prover and proving fee per batch.
    /// @dev address(0) and 0 will be returned if there is no current prover.
    /// @return prover_ The address of the current winning prover.
    /// @return fee_ The proving fee per batch.
    function getCurrentProver() external view returns (address prover_, uint256 fee_);
}
