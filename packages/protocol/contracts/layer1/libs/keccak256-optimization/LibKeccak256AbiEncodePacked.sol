// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibKeccak256AbiEncodePacked
/// @notice Library for optimized keccak256 hashing of abi.encodePacked results
/// @dev This library is for testing purposes only and will be removed after optimization
/// @custom:security-contact security@taiko.xyz
library LibKeccak256AbiEncodePacked {
    /// @notice Original keccak256 implementation for SgxVerifier use case
    /// @param publicInputs Array of bytes32 values
    /// @return hash The keccak256 hash
    function hashOrigin(bytes32[] memory publicInputs) internal pure returns (bytes32 hash) {
        return keccak256(abi.encodePacked(publicInputs));
    }

    /// @notice Optimized keccak256 implementation using inline assembly
    /// @param publicInputs Array of bytes32 values
    /// @return hash The keccak256 hash
    function hashOptimized(bytes32[] memory publicInputs) internal pure returns (bytes32 hash) {
        assembly {
            // publicInputs array in memory:
            // [length (32 bytes)][element0 (32 bytes)][element1 (32 bytes)]...
            // abi.encodePacked packs them without padding, but since they're bytes32, they're already tightly packed
            // For abi.encodePacked of bytes32[], we just hash length * 32 bytes starting after the length field
            let length := mload(publicInputs)
            hash := keccak256(add(publicInputs, 0x20), mul(length, 0x20))
        }
    }
}
