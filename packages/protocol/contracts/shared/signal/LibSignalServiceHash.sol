// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibSignalServiceHash
/// @notice Library for optimizing keccak256 hash computation in SignalService
library LibSignalServiceHash {
    /// @notice Original keccak256 implementation
    /// @param _chainId The chainId of the signal
    /// @param _app The address that initiated the signal
    /// @param _signal The signal (message) that was sent
    /// @return The hash of the signal slot
    function hashOriginal(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("SIGNAL", _chainId, _app, _signal));
    }

    /// @notice Optimized keccak256 implementation using inline assembly
    /// @param _chainId The chainId of the signal
    /// @param _app The address that initiated the signal
    /// @param _signal The signal (message) that was sent
    /// @return hash The hash of the signal slot
    function hashOptimized(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        internal
        pure
        returns (bytes32 hash)
    {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // abi.encodePacked packs data tightly:
            // "SIGNAL" (6 bytes) + _chainId (8 bytes) + _app (20 bytes) + _signal (32 bytes) = 66 bytes total

            // Pack data efficiently in memory:
            // Store first 32 bytes: "SIGNAL" (6 bytes) + _chainId (8 bytes) + first 18 bytes of _app
            // "SIGNAL" = 0x5349474e414c (6 bytes)
            // Left shift "SIGNAL" by 208 bits (26 bytes) to position it at the start
            // Then OR with _chainId shifted by 144 bits (18 bytes) to place it after "SIGNAL"
            // Then OR with _app shifted right by 16 bits to get first 18 bytes of address
            let firstSlot := or(
                shl(208, 0x5349474e414c),
                or(
                    shl(144, _chainId),
                    shr(16, _app)
                )
            )
            mstore(ptr, firstSlot)

            // Store second 32 bytes: last 2 bytes of _app + _signal (32 bytes)
            // Shift _app left by 240 bits to get last 2 bytes at the start
            // OR with _signal to place it after
            let secondSlot := or(shl(240, _app), shr(16, _signal))
            mstore(add(ptr, 32), secondSlot)

            // Store remaining 2 bytes of _signal in third slot
            mstore(add(ptr, 64), shl(240, _signal))

            // Compute keccak256 of the 66 bytes
            hash := keccak256(ptr, 66)
        }
    }
}
