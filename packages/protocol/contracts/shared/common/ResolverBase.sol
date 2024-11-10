// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IResolver.sol";

/// @title Resolver
/// @notice See the documentation in {IResolver}.
/// @custom:security-contact security@taiko.xyz
abstract contract ResolverBase is IResolver {
    function resolve(
        uint256 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        external
        view
        returns (address addr_)
    {
        addr_ = getAddress(_chainId, _name);
        require(addr_ != address(0) || _allowZeroAddress, RESOLVED_TO_ZERO_ADDRESS());
    }

    function getAddress(uint256 _chainId, bytes32 _name) internal view virtual returns (address);
}
