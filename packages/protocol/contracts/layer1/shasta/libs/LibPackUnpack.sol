// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibPackUnpack
/// @notice Library providing low-level packing/unpacking functions for compact binary encoding
/// using inline assembly for maximum gas efficiency.
/// @dev This library implements a trust-the-caller pattern with no bounds checking for optimal
/// performance. Callers are responsible for:
/// - Allocating sufficient memory for pack operations
/// - Ensuring data has sufficient length for unpack operations
/// - Tracking position offsets correctly
///
/// Memory Layout:
/// - Pack functions write directly to memory at absolute positions
/// - Unpack functions read from memory at absolute positions
/// - All multi-byte integers use big-endian encoding
/// - Position tracking is left to the caller
///
/// Safety Notes:
/// - No overflow protection on position increments (caller's responsibility)
/// - No bounds checking on memory access (gas-optimized design)
/// - Suitable for controlled environments where input validation happens upstream
///
/// Usage Example:
/// ```solidity
/// bytes memory buffer = new bytes(100);
/// uint256 pos = LibPackUnpack.dataPtr(buffer);
/// pos = LibPackUnpack.packUint32(pos, 12345);
/// pos = LibPackUnpack.packAddress(pos, msg.sender);
/// ```
/// @custom:security-contact security@taiko.xyz
library LibPackUnpack {
    // ---------------------------------------------------------------
    // Pack Functions (write to buffer with compact encoding)
    // ---------------------------------------------------------------

    /// @notice Pack uint8 (1 byte) at position
    /// @dev Writes a single byte to memory at the specified position.
    /// @param _pos Absolute memory position to write at
    /// @param _value The uint8 value to pack (0-255)
    /// @return newPos_ Updated position after writing (pos + 1)
    function packUint8(uint256 _pos, uint8 _value) internal pure returns (uint256 newPos_) {
        assembly {
            mstore8(_pos, _value)
            newPos_ := add(_pos, 1)
        }
    }

    /// @notice Pack uint16 (2 bytes) at position using big-endian encoding
    /// @dev Optimized to use mstore instead of 2 individual mstore8 operations.
    /// @param _pos Absolute memory position to write at
    /// @param _value The uint16 value to pack (0-65535)
    /// @return newPos_ Updated position after writing (pos + 2)
    function packUint16(uint256 _pos, uint16 _value) internal pure returns (uint256 newPos_) {
        assembly {
            // Shift value left by 30 bytes (240 bits) to align at the start of a 32-byte word
            let shifted := shl(240, _value)

            // Store the shifted value at position
            mstore(_pos, shifted)

            newPos_ := add(_pos, 2)
        }
    }

    /// @notice Pack uint24 (3 bytes) at position using big-endian encoding
    /// @dev Optimized to use mstore instead of 3 individual mstore8 operations.
    /// @param _pos Absolute memory position to write at
    /// @param _value The uint24 value to pack (0-16777215)
    /// @return newPos_ Updated position after writing (pos + 3)
    function packUint24(uint256 _pos, uint24 _value) internal pure returns (uint256 newPos_) {
        assembly {
            // Shift value left by 29 bytes (232 bits) to align at the start of a 32-byte word
            let shifted := shl(232, _value)

            // Store the shifted value at position
            mstore(_pos, shifted)

            newPos_ := add(_pos, 3)
        }
    }

    /// @notice Pack uint32 (4 bytes) at position using big-endian encoding
    /// @dev Optimized to use mstore instead of 4 individual mstore8 operations.
    /// @param _pos Absolute memory position to write at
    /// @param _value The uint32 value to pack (0-4294967295)
    /// @return newPos_ Updated position after writing (pos + 4)
    function packUint32(uint256 _pos, uint32 _value) internal pure returns (uint256 newPos_) {
        assembly {
            // Shift value left by 28 bytes (224 bits) to align at the start of a 32-byte word
            let shifted := shl(224, _value)

            // Store the shifted value at position
            mstore(_pos, shifted)

            newPos_ := add(_pos, 4)
        }
    }

    /// @notice Pack uint48 (6 bytes) at position using big-endian encoding
    /// @dev Optimized to use mstore instead of 6 individual mstore8 operations.
    /// Common use case: block numbers that exceed uint32 range.
    /// @param _pos Absolute memory position to write at
    /// @param _value The uint48 value to pack (0-281474976710655)
    /// @return newPos_ Updated position after writing (pos + 6)
    function packUint48(uint256 _pos, uint48 _value) internal pure returns (uint256 newPos_) {
        assembly {
            // Shift value left by 26 bytes (208 bits) to align at the start of a 32-byte word
            let shifted := shl(208, _value)

            // Store the shifted value at position
            mstore(_pos, shifted)

            newPos_ := add(_pos, 6)
        }
    }

    /// @notice Pack uint256 (32 bytes) at position
    /// @dev Uses single mstore for efficiency, writes full 32-byte word.
    /// @param _pos Absolute memory position to write at (best if 32-byte aligned)
    /// @param _value The uint256 value to pack
    /// @return newPos_ Updated position after writing (pos + 32)
    function packUint256(uint256 _pos, uint256 _value) internal pure returns (uint256 newPos_) {
        assembly {
            mstore(_pos, _value)
            newPos_ := add(_pos, 32)
        }
    }

    /// @notice Pack bytes32 at position
    /// @dev Direct 32-byte write, commonly used for hashes and identifiers.
    /// @param _pos Absolute memory position to write at (best if 32-byte aligned)
    /// @param _value The bytes32 value to pack (hash, identifier, etc.)
    /// @return newPos_ Updated position after writing (pos + 32)
    function packBytes32(uint256 _pos, bytes32 _value) internal pure returns (uint256 newPos_) {
        assembly {
            mstore(_pos, _value)
            newPos_ := add(_pos, 32)
        }
    }

    /// @notice Pack address (20 bytes) at position
    /// @dev Optimized to use mstore instead of 20 individual mstore8 operations.
    /// Handles alignment by using a single mstore with proper shifting.
    /// @param _pos Absolute memory position to write at
    /// @param _value The address to pack
    /// @return newPos_ Updated position after writing (pos + 20)
    function packAddress(uint256 _pos, address _value) internal pure returns (uint256 newPos_) {
        assembly {
            // Shift address left by 12 bytes (96 bits) to align it properly in a 32-byte word
            // This places the 20-byte address at the start of the word with 12 bytes of padding
            let shifted := shl(96, _value)

            // Store the shifted address at position
            // This writes 32 bytes, but we only care about the first 20
            mstore(_pos, shifted)

            newPos_ := add(_pos, 20)
        }
    }

    // ---------------------------------------------------------------
    // Unpack Functions (read from buffer with compact encoding)
    // ---------------------------------------------------------------

    /// @notice Unpack uint8 (1 byte) from position
    /// @dev Reads single byte from memory. No validation of data availability.
    /// @param _pos Absolute memory position to read from
    /// @return value_ The unpacked uint8 value
    /// @return newPos_ Updated position after reading (pos + 1)
    function unpackUint8(uint256 _pos) internal pure returns (uint8 value_, uint256 newPos_) {
        assembly {
            value_ := byte(0, mload(_pos))
            newPos_ := add(_pos, 1)
        }
    }

    /// @notice Unpack uint16 (2 bytes) from position using big-endian encoding
    /// @dev Reads 2 bytes and combines: (byte0 << 8) | byte1.
    /// @param _pos Absolute memory position to read from
    /// @return value_ The unpacked uint16 value
    /// @return newPos_ Updated position after reading (pos + 2)
    function unpackUint16(uint256 _pos) internal pure returns (uint16 value_, uint256 newPos_) {
        assembly {
            value_ := or(shl(8, byte(0, mload(_pos))), byte(0, mload(add(_pos, 1))))
            newPos_ := add(_pos, 2)
        }
    }

    /// @notice Unpack uint24 (3 bytes) from position using big-endian encoding
    /// @dev Reads 3 bytes and reconstructs uint24 from big-endian format.
    /// @param _pos Absolute memory position to read from
    /// @return value_ The unpacked uint24 value
    /// @return newPos_ Updated position after reading (pos + 3)
    function unpackUint24(uint256 _pos) internal pure returns (uint24 value_, uint256 newPos_) {
        assembly {
            value_ :=
                or(
                    or(shl(16, byte(0, mload(_pos))), shl(8, byte(0, mload(add(_pos, 1))))),
                    byte(0, mload(add(_pos, 2)))
                )
            newPos_ := add(_pos, 3)
        }
    }

    /// @notice Unpack uint32 (4 bytes) from position using big-endian encoding
    /// @dev Reads 4 bytes and reconstructs uint32 from big-endian format.
    /// @param _pos Absolute memory position to read from
    /// @return value_ The unpacked uint32 value
    /// @return newPos_ Updated position after reading (pos + 4)
    function unpackUint32(uint256 _pos) internal pure returns (uint32 value_, uint256 newPos_) {
        assembly {
            value_ :=
                or(
                    or(shl(24, byte(0, mload(_pos))), shl(16, byte(0, mload(add(_pos, 1))))),
                    or(shl(8, byte(0, mload(add(_pos, 2)))), byte(0, mload(add(_pos, 3))))
                )
            newPos_ := add(_pos, 4)
        }
    }

    /// @notice Unpack uint48 (6 bytes) from position using big-endian encoding
    /// @dev Reads 6 bytes for compact timestamp/counter values.
    /// Reconstructs value from big-endian byte sequence.
    /// @param _pos Absolute memory position to read from
    /// @return value_ The unpacked uint48 value
    /// @return newPos_ Updated position after reading (pos + 6)
    function unpackUint48(uint256 _pos) internal pure returns (uint48 value_, uint256 newPos_) {
        assembly {
            value_ :=
                or(
                    or(
                        or(shl(40, byte(0, mload(_pos))), shl(32, byte(0, mload(add(_pos, 1))))),
                        or(shl(24, byte(0, mload(add(_pos, 2)))), shl(16, byte(0, mload(add(_pos, 3)))))
                    ),
                    or(shl(8, byte(0, mload(add(_pos, 4)))), byte(0, mload(add(_pos, 5))))
                )
            newPos_ := add(_pos, 6)
        }
    }

    /// @notice Unpack uint256 (32 bytes) from position
    /// @dev Single mload for efficiency. Reads full 32-byte word.
    /// @param _pos Absolute memory position to read from (best if 32-byte aligned)
    /// @return value_ The unpacked uint256 value
    /// @return newPos_ Updated position after reading (pos + 32)
    function unpackUint256(uint256 _pos) internal pure returns (uint256 value_, uint256 newPos_) {
        assembly {
            value_ := mload(_pos)
            newPos_ := add(_pos, 32)
        }
    }

    /// @notice Unpack bytes32 from position
    /// @dev Direct 32-byte read for hashes and identifiers.
    /// @param _pos Absolute memory position to read from (best if 32-byte aligned)
    /// @return value_ The unpacked bytes32 value
    /// @return newPos_ Updated position after reading (pos + 32)
    function unpackBytes32(uint256 _pos) internal pure returns (bytes32 value_, uint256 newPos_) {
        assembly {
            value_ := mload(_pos)
            newPos_ := add(_pos, 32)
        }
    }

    /// @notice Unpack address (20 bytes) from position
    /// @dev Reads 20 bytes byte-by-byte and reconstructs address.
    /// Handles unaligned positions correctly.
    /// @param _pos Absolute memory position to read from
    /// @return value_ The unpacked address
    /// @return newPos_ Updated position after reading (pos + 20)
    function unpackAddress(uint256 _pos) internal pure returns (address value_, uint256 newPos_) {
        assembly {
            // Read 20 bytes as address
            value_ :=
                or(
                    or(
                        or(
                            or(shl(152, byte(0, mload(_pos))), shl(144, byte(0, mload(add(_pos, 1))))),
                            or(
                                shl(136, byte(0, mload(add(_pos, 2)))),
                                shl(128, byte(0, mload(add(_pos, 3))))
                            )
                        ),
                        or(
                            or(
                                shl(120, byte(0, mload(add(_pos, 4)))),
                                shl(112, byte(0, mload(add(_pos, 5))))
                            ),
                            or(
                                shl(104, byte(0, mload(add(_pos, 6)))),
                                shl(96, byte(0, mload(add(_pos, 7))))
                            )
                        )
                    ),
                    or(
                        or(
                            or(
                                shl(88, byte(0, mload(add(_pos, 8)))),
                                shl(80, byte(0, mload(add(_pos, 9))))
                            ),
                            or(
                                shl(72, byte(0, mload(add(_pos, 10)))),
                                shl(64, byte(0, mload(add(_pos, 11))))
                            )
                        ),
                        or(
                            or(
                                or(
                                    shl(56, byte(0, mload(add(_pos, 12)))),
                                    shl(48, byte(0, mload(add(_pos, 13))))
                                ),
                                or(
                                    shl(40, byte(0, mload(add(_pos, 14)))),
                                    shl(32, byte(0, mload(add(_pos, 15))))
                                )
                            ),
                            or(
                                or(
                                    shl(24, byte(0, mload(add(_pos, 16)))),
                                    shl(16, byte(0, mload(add(_pos, 17))))
                                ),
                                or(shl(8, byte(0, mload(add(_pos, 18)))), byte(0, mload(add(_pos, 19))))
                            )
                        )
                    )
                )
            newPos_ := add(_pos, 20)
        }
    }

    // ---------------------------------------------------------------
    // Utility Functions
    // ---------------------------------------------------------------

    /// @notice Get the memory pointer to the data section of a bytes array
    /// @dev Skips the 32-byte length prefix to point at actual data.
    /// Essential for converting bytes memory to absolute position for pack/unpack operations.
    /// @param _data The bytes array to get data pointer from
    /// @return ptr_ The absolute memory pointer to the actual data (data location + 0x20)
    function dataPtr(bytes memory _data) internal pure returns (uint256 ptr_) {
        assembly {
            ptr_ := add(_data, 0x20)
        }
    }
}
