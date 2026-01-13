// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverWhitelist
/// @notice Interface for checking if an address is authorized to prove blocks
/// @custom:security-contact security@taiko.xyz
interface IProverWhitelist {
    /// @notice Checks if an address is a whitelisted prover
    /// @param _prover The address to check
    /// @return isWhitelisted_ True if the address is whitelisted, false otherwise
    /// @return proverCount_ The total number of whitelisted provers
    function isProverWhitelisted(address _prover)
        external
        view
        returns (bool isWhitelisted_, uint256 proverCount_);
}
