// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibKeccak256Bytes
/// @notice Library for optimized keccak256 hashing of bytes
/// @dev This library is for testing purposes only and will be removed after optimization
/// @custom:security-contact security@taiko.xyz
library LibKeccak256Bytes {
    /// @notice Original keccak256 implementation using Solidity's built-in function
    /// @param data The bytes data to hash
    /// @return hash The keccak256 hash
    function hashOrigin(bytes memory data) internal pure returns (bytes32 hash) {
        return keccak256(data);
    }

    /// @notice Optimized keccak256 implementation using inline assembly
    /// @param data The bytes data to hash
    /// @return hash The keccak256 hash
    function hashOptimized(bytes memory data) internal pure returns (bytes32 hash) {
        assembly {
            // keccak256(data) - data is in memory starting at data + 0x20 (after length)
            // and has length stored at data
            hash := keccak256(add(data, 0x20), mload(data))
        }
    }
}
