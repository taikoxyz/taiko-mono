// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EssentialContract.sol";
import "./IResolver.sol";

abstract contract EssentialResolverContract is EssentialContract {
    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    /// @dev Modifier that ensures the caller is the owner or resolved address of a given name.
    /// @param _name The name to check against.
    modifier onlyFromOwnerOrNamed(bytes32 _name) {
        _checkOwnerOrNamed(_name);
        _;
    }

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name.
    /// @param _name The name to check against.
    modifier onlyFromNamed(bytes32 _name) {
        _checkFromNamed(_name);
        _;
    }

    /// @dev Modifier that ensures the caller is a resolved address to either _name1 or _name2
    /// name.
    /// @param _address1 The first name to check against.
    /// @param _address2 The second name to check against.
    modifier onlyFromNamedEither(address _address1, address _address2) {
        _checkFromNamedEither(_address1, _address2);
        _;
    }

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name, if the name is set.
    /// @param _name The name to check against.
    modifier onlyFromOptionalNamed(bytes32 _name) {
        _checkFromOptionalNamed(_name);
        _;
    }
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address _resolver) {
        require(_resolver != address(0), RESOLVER_NOT_FOUND());
        __resolver = _resolver;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

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

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _checkOwnerOrNamed(bytes32 _name) private view {
        require(msg.sender == owner() || msg.sender == resolve(_name, true), ACCESS_DENIED());
    }

    function _checkFromNamed(bytes32 _name) private view {
        require(msg.sender == resolve(_name, true), ACCESS_DENIED());
    }

    function _checkFromNamedEither(address _address1, address _address2) private view {
        require(msg.sender == _address1 || msg.sender == _address2, ACCESS_DENIED());
    }

    function _checkFromOptionalNamed(bytes32 _name) private view {
        address addr = resolve(_name, true);
        require(addr == address(0) || msg.sender == addr, ACCESS_DENIED());
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error RESOLVER_NOT_FOUND();
}
