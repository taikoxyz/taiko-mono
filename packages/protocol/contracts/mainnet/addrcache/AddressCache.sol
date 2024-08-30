// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title AddressCache
/// @custom:security-contact security@taiko.xyz
abstract contract AddressCache {
    /// @notice This function retrieves the address associated with a given chain ID and name.
    ///  If the address is not found in the cache, it falls back to the provided function.
    /// @param _chainId The chain ID for which the address is to be retrieved.
    /// @param _name The name associated with the address to be retrieved.
    /// @param _fallbackFunc The fallback function to be used if the address is not found in the
    /// cache.
    /// @return The address associated with the given chain ID and name.
    function getAddress(
        uint64 _chainId,
        bytes32 _name,
        function (uint64, bytes32) view  returns  (address) _fallbackFunc
    )
        internal
        view
        returns (address)
    {
        (bool found, address addr) = getCachedAddress(_chainId, _name);
        return found ? addr : _fallbackFunc(_chainId, _name);
    }

    /// @notice This function retrieves the cached address associated with a given chain ID and
    /// name.
    /// @dev This function is virtual and should be overridden in derived contracts.
    /// @param _chainId The chain ID for which the address is to be retrieved.
    /// @param _name The name associated with the address to be retrieved.
    /// @return found_ A boolean indicating whether the address was found in the cache.
    /// @return addr_ The address associated with the given chain ID and name, if found in the
    /// cache.
    function getCachedAddress(
        uint64 _chainId,
        bytes32 _name
    )
        internal
        pure
        virtual
        returns (bool found_, address addr_);
}
