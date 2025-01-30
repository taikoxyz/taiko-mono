// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IResolver
/// @notice This contract acts as a bridge for name-to-address resolution.
/// @custom:security-contact security@taiko.xyz
interface IResolver {
    error RESOLVED_TO_ZERO_ADDRESS();

    /// @notice Resolves a name to its address deployed on a specified chain.
    /// @param _chainId The chainId of interest.
    /// @param _name Name whose address is to be resolved.
    /// @param _allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return Address associated with the given name on the specified
    /// chain.
    function resolve(
        uint256 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        external
        view
        returns (address);
}
