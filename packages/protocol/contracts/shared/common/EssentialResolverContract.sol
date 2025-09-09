// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IResolver.sol";
import "./EssentialContract.sol";

abstract contract EssentialResolverContract is EssentialContract {
    error RESOLVER_NOT_FOUND();

    constructor(address _resolver) {
        __resolver = _resolver;
    }

    /// @dev Modifier that ensures the caller is the owner or resolved address of a given name.
    /// @param _name The name to check against.
    modifier onlyFromOwnerOrNamed(bytes32 _name) {
        require(msg.sender == owner() || msg.sender == resolve(_name, true), ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name.
    /// @param _name The name to check against.
    modifier onlyFromNamed(bytes32 _name) {
        require(msg.sender == resolve(_name, true), ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is a resolved address to either _name1 or _name2
    /// name.
    /// @param _address1 The first name to check against.
    /// @param _address2 The second name to check against.
    modifier onlyFromNamedEither(address _address1, address _address2) {
        require(msg.sender == _address1 || msg.sender == _address2, ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name, if the name is set.
    /// @param _name The name to check against.
    modifier onlyFromOptionalNamed(bytes32 _name) {
        address addr = resolve(_name, true);
        require(addr == address(0) || msg.sender == addr, ACCESS_DENIED());
        _;
    }

    /// @notice Resolves a name to an address on a specific chain
    /// @param _chainId The chain ID to resolve the name on
    /// @param _name The name to resolve
    /// @param _allowZeroAddress Whether to allow resolving to the zero address
    /// @return The resolved address
    function resolve(
        uint64 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        internal
        view
        returns (address)
    {
        return IResolver(resolver()).resolve(_chainId, _name, _allowZeroAddress);
    }

    /// @notice Resolves a name to an address on the current chain
    /// @param _name The name to resolve
    /// @param _allowZeroAddress Whether to allow resolving to the zero address
    /// @return The resolved address
    function resolve(bytes32 _name, bool _allowZeroAddress) internal view returns (address) {
        return IResolver(resolver()).resolve(block.chainid, _name, _allowZeroAddress);
    }
}
