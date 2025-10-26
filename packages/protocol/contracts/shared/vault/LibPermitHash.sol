// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibPermitHash
/// @notice Library for optimizing keccak256 hash computation in ERC20 Permit
library LibPermitHash {
    /// @notice Original keccak256 implementation
    /// @param typeHash The EIP-712 typehash
    /// @param owner The token owner
    /// @param spender The spender address
    /// @param value The permit amount
    /// @param nonce The current nonce
    /// @param deadline The permit deadline
    /// @return The hash of the permit struct
    function hashOriginal(
        bytes32 typeHash,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(typeHash, owner, spender, value, nonce, deadline));
    }

    /// @notice Optimized keccak256 implementation using inline assembly
    /// @param typeHash The EIP-712 typehash
    /// @param owner The token owner
    /// @param spender The spender address
    /// @param value The permit amount
    /// @param nonce The current nonce
    /// @param deadline The permit deadline
    /// @return hash The hash of the permit struct
    function hashOptimized(
        bytes32 typeHash,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    )
        internal
        pure
        returns (bytes32 hash)
    {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // abi.encode pads each value to 32 bytes: 6 values × 32 bytes = 192 bytes
            // Store typeHash (32 bytes)
            mstore(ptr, typeHash)
            // Store owner (address padded to 32 bytes)
            mstore(add(ptr, 0x20), owner)
            // Store spender (address padded to 32 bytes)
            mstore(add(ptr, 0x40), spender)
            // Store value (uint256)
            mstore(add(ptr, 0x60), value)
            // Store nonce (uint256)
            mstore(add(ptr, 0x80), nonce)
            // Store deadline (uint256)
            mstore(add(ptr, 0xa0), deadline)

            // Compute keccak256 of the 192 bytes
            hash := keccak256(ptr, 0xc0)
        }
    }
}
