// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

    /// @dev Resolves both names on the current chain and checks msg.sender equality.
    /// @param _name1 The first name to resolve and check.
    /// @param _name2 The second name to resolve and check.
    modifier onlyFromNamedEither(bytes32 _name1, bytes32 _name2) {
        _checkFromNamedEither(_name1, _name2);
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

    function _checkFromNamedEither(bytes32 _name1, bytes32 _name2) private view {
        address addr1 = resolve(_name1, true);
        address addr2 = resolve(_name2, true);
        require(msg.sender == addr1 || msg.sender == addr2, ACCESS_DENIED());
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
