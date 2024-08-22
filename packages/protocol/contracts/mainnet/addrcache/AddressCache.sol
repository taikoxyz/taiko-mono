// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title AddressCache
/// @custom:security-contact security@taiko.xyz
abstract contract AddressCache {
    function getAddress(
        uint64 _chainId,
        bytes32 _name,
        function (uint64, bytes32) view  returns  (address) _getAddress
    )
        internal
        view
        returns (address)
    {
        (bool found, address addr) = getCachedAddress(_chainId, _name);
        return found ? addr : _getAddress(_chainId, _name);
    }

    function getCachedAddress(
        uint64 _chainId,
        bytes32 _name
    )
        internal
        pure
        virtual
        returns (bool found, address addr);
}
