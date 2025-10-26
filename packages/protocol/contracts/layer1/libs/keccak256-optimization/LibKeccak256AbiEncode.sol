// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibKeccak256AbiEncode
/// @notice Library for optimized keccak256 hashing of abi.encode results
/// @dev This library is for testing purposes only and will be removed after optimization
/// @custom:security-contact security@taiko.xyz
library LibKeccak256AbiEncode {
    /// @notice Original keccak256 implementation for LibPublicInput use case
    /// @param str String literal "VERIFY_PROOF"
    /// @param chainId Chain ID
    /// @param verifierContract Verifier contract address
    /// @param aggregatedProvingHash Aggregated proving hash
    /// @param newInstance New instance address
    /// @return hash The keccak256 hash
    function hashOrigin(
        string memory str,
        uint64 chainId,
        address verifierContract,
        bytes32 aggregatedProvingHash,
        address newInstance
    )
        internal
        pure
        returns (bytes32 hash)
    {
        return keccak256(abi.encode(str, chainId, verifierContract, aggregatedProvingHash, newInstance));
    }

    /// @notice Optimized keccak256 implementation using inline assembly
    /// @param str String literal "VERIFY_PROOF"
    /// @param chainId Chain ID
    /// @param verifierContract Verifier contract address
    /// @param aggregatedProvingHash Aggregated proving hash
    /// @param newInstance New instance address
    /// @return hash The keccak256 hash
    function hashOptimized(
        string memory str,
        uint64 chainId,
        address verifierContract,
        bytes32 aggregatedProvingHash,
        address newInstance
    )
        internal
        pure
        returns (bytes32 hash)
    {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // Store string data (32 bytes for offset, 32 bytes for length, then string data)
            // The abi.encode of a string creates: offset (32 bytes), then at that offset: length + data
            mstore(ptr, 0xa0) // offset to string data (5 * 32 bytes = 160 = 0xa0)
            mstore(add(ptr, 0x20), chainId) // uint64 is padded to 32 bytes
            mstore(add(ptr, 0x40), verifierContract) // address is padded to 32 bytes
            mstore(add(ptr, 0x60), aggregatedProvingHash) // bytes32
            mstore(add(ptr, 0x80), newInstance) // address is padded to 32 bytes

            // Store string length and data at offset 0xa0
            let strLen := mload(str)
            mstore(add(ptr, 0xa0), strLen)
            // Copy string data (VERIFY_PROOF is 12 bytes, fits in one word)
            mstore(add(ptr, 0xc0), mload(add(str, 0x20)))

            // Calculate total length: 5 * 32 + 32 (string length) + 32 (string data rounded up)
            // = 160 + 64 = 224 = 0xe0
            hash := keccak256(ptr, 0xe0)
        }
    }
}
