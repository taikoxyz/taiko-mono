// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibPackCodec
/// @notice Library providing fundamental packing/unpacking functions for compact encoding using
/// assembly
/// @dev All functions are optimized for gas efficiency and compact storage
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    // ---------------------------------------------------------------
    // Pack Functions (write to buffer with compact encoding)
    // ---------------------------------------------------------------

    /// @notice Pack uint8 (1 byte) at position
    /// @param pos Position in buffer (absolute memory position)
    /// @param value Value to pack
    /// @return newPos Position after writing
    function packUint8(
        bytes memory, // buffer - unused but needed for memory context
        uint256 pos,
        uint8 value
    )
        internal
        pure
        returns (uint256 newPos)
    {
        assembly {
            mstore8(pos, value)
            newPos := add(pos, 1)
        }
    }

    /// @notice Pack uint16 (2 bytes) at position, big-endian
    /// @param pos Position in buffer (absolute memory position)
    /// @param value Value to pack
    /// @return newPos Position after writing
    function packUint16(
        bytes memory, // buffer - unused but needed for memory context
        uint256 pos,
        uint16 value
    )
        internal
        pure
        returns (uint256 newPos)
    {
        assembly {
            mstore8(pos, shr(8, value))
            mstore8(add(pos, 1), value)
            newPos := add(pos, 2)
        }
    }

    /// @notice Pack uint32 (4 bytes) at position, big-endian
    /// @param pos Position in buffer (absolute memory position)
    /// @param value Value to pack
    /// @return newPos Position after writing
    function packUint32(
        bytes memory, // buffer - unused but needed for memory context
        uint256 pos,
        uint32 value
    )
        internal
        pure
        returns (uint256 newPos)
    {
        assembly {
            mstore8(pos, shr(24, value))
            mstore8(add(pos, 1), shr(16, value))
            mstore8(add(pos, 2), shr(8, value))
            mstore8(add(pos, 3), value)
            newPos := add(pos, 4)
        }
    }

    /// @notice Pack uint48 (6 bytes) at position, big-endian
    /// @param pos Position in buffer (absolute memory position)
    /// @param value Value to pack
    /// @return newPos Position after writing
    function packUint48(
        bytes memory, // buffer - unused but needed for memory context
        uint256 pos,
        uint48 value
    )
        internal
        pure
        returns (uint256 newPos)
    {
        assembly {
            mstore8(pos, shr(40, value))
            mstore8(add(pos, 1), shr(32, value))
            mstore8(add(pos, 2), shr(24, value))
            mstore8(add(pos, 3), shr(16, value))
            mstore8(add(pos, 4), shr(8, value))
            mstore8(add(pos, 5), value)
            newPos := add(pos, 6)
        }
    }

    /// @notice Pack uint256 (32 bytes) at position
    /// @param pos Position in buffer (absolute memory position)
    /// @param value Value to pack
    /// @return newPos Position after writing
    function packUint256(
        bytes memory, // buffer - unused but needed for memory context
        uint256 pos,
        uint256 value
    )
        internal
        pure
        returns (uint256 newPos)
    {
        assembly {
            mstore(pos, value)
            newPos := add(pos, 32)
        }
    }

    /// @notice Pack bytes32 at position
    /// @param pos Position in buffer (absolute memory position)
    /// @param value Value to pack
    /// @return newPos Position after writing
    function packBytes32(
        bytes memory, // buffer - unused but needed for memory context
        uint256 pos,
        bytes32 value
    )
        internal
        pure
        returns (uint256 newPos)
    {
        assembly {
            mstore(pos, value)
            newPos := add(pos, 32)
        }
    }

    /// @notice Pack address (20 bytes) at position
    /// @param pos Position in buffer (absolute memory position)
    /// @param value Value to pack
    /// @return newPos Position after writing
    function packAddress(
        bytes memory, // buffer - unused but needed for memory context
        uint256 pos,
        address value
    )
        internal
        pure
        returns (uint256 newPos)
    {
        assembly {
            // Cast address to bytes20 and store
            let v := and(value, 0xffffffffffffffffffffffffffffffffffffffff)
            // Store byte by byte to avoid alignment issues
            mstore8(pos, shr(152, v))
            mstore8(add(pos, 1), shr(144, v))
            mstore8(add(pos, 2), shr(136, v))
            mstore8(add(pos, 3), shr(128, v))
            mstore8(add(pos, 4), shr(120, v))
            mstore8(add(pos, 5), shr(112, v))
            mstore8(add(pos, 6), shr(104, v))
            mstore8(add(pos, 7), shr(96, v))
            mstore8(add(pos, 8), shr(88, v))
            mstore8(add(pos, 9), shr(80, v))
            mstore8(add(pos, 10), shr(72, v))
            mstore8(add(pos, 11), shr(64, v))
            mstore8(add(pos, 12), shr(56, v))
            mstore8(add(pos, 13), shr(48, v))
            mstore8(add(pos, 14), shr(40, v))
            mstore8(add(pos, 15), shr(32, v))
            mstore8(add(pos, 16), shr(24, v))
            mstore8(add(pos, 17), shr(16, v))
            mstore8(add(pos, 18), shr(8, v))
            mstore8(add(pos, 19), v)
            newPos := add(pos, 20)
        }
    }

    // ---------------------------------------------------------------
    // Unpack Functions (read from buffer with compact encoding)
    // ---------------------------------------------------------------

    /// @notice Unpack uint8 (1 byte) from position
    /// @param pos Position in data (absolute memory position)
    /// @return value The unpacked value
    /// @return newPos Position after reading
    function unpackUint8(
        bytes memory,
        uint256 pos // data - unused but needed for memory context
    )
        internal
        pure
        returns (uint8 value, uint256 newPos)
    {
        assembly {
            value := byte(0, mload(pos))
            newPos := add(pos, 1)
        }
    }

    /// @notice Unpack uint16 (2 bytes) from position, big-endian
    /// @param pos Position in data (absolute memory position)
    /// @return value The unpacked value
    /// @return newPos Position after reading
    function unpackUint16(
        bytes memory,
        uint256 pos // data - unused but needed for memory context
    )
        internal
        pure
        returns (uint16 value, uint256 newPos)
    {
        assembly {
            value := or(shl(8, byte(0, mload(pos))), byte(0, mload(add(pos, 1))))
            newPos := add(pos, 2)
        }
    }

    /// @notice Unpack uint32 (4 bytes) from position, big-endian
    /// @param pos Position in data (absolute memory position)
    /// @return value The unpacked value
    /// @return newPos Position after reading
    function unpackUint32(
        bytes memory,
        uint256 pos // data - unused but needed for memory context
    )
        internal
        pure
        returns (uint32 value, uint256 newPos)
    {
        assembly {
            value :=
                or(
                    or(shl(24, byte(0, mload(pos))), shl(16, byte(0, mload(add(pos, 1))))),
                    or(shl(8, byte(0, mload(add(pos, 2)))), byte(0, mload(add(pos, 3))))
                )
            newPos := add(pos, 4)
        }
    }

    /// @notice Unpack uint48 (6 bytes) from position, big-endian
    /// @param pos Position in data (absolute memory position)
    /// @return value The unpacked value
    /// @return newPos Position after reading
    function unpackUint48(
        bytes memory,
        uint256 pos // data - unused but needed for memory context
    )
        internal
        pure
        returns (uint48 value, uint256 newPos)
    {
        assembly {
            value :=
                or(
                    or(
                        or(shl(40, byte(0, mload(pos))), shl(32, byte(0, mload(add(pos, 1))))),
                        or(shl(24, byte(0, mload(add(pos, 2)))), shl(16, byte(0, mload(add(pos, 3)))))
                    ),
                    or(shl(8, byte(0, mload(add(pos, 4)))), byte(0, mload(add(pos, 5))))
                )
            newPos := add(pos, 6)
        }
    }

    /// @notice Unpack uint256 (32 bytes) from position
    /// @param pos Position in data (absolute memory position)
    /// @return value The unpacked value
    /// @return newPos Position after reading
    function unpackUint256(
        bytes memory,
        uint256 pos // data - unused but needed for memory context
    )
        internal
        pure
        returns (uint256 value, uint256 newPos)
    {
        assembly {
            value := mload(pos)
            newPos := add(pos, 32)
        }
    }

    /// @notice Unpack bytes32 from position
    /// @param pos Position in data (absolute memory position)
    /// @return value The unpacked value
    /// @return newPos Position after reading
    function unpackBytes32(
        bytes memory,
        uint256 pos // data - unused but needed for memory context
    )
        internal
        pure
        returns (bytes32 value, uint256 newPos)
    {
        assembly {
            value := mload(pos)
            newPos := add(pos, 32)
        }
    }

    /// @notice Unpack address (20 bytes) from position
    /// @param pos Position in data (absolute memory position)
    /// @return value The unpacked value
    /// @return newPos Position after reading
    function unpackAddress(
        bytes memory,
        uint256 pos // data - unused but needed for memory context
    )
        internal
        pure
        returns (address value, uint256 newPos)
    {
        assembly {
            // Read 20 bytes as address
            value :=
                or(
                    or(
                        or(
                            or(shl(152, byte(0, mload(pos))), shl(144, byte(0, mload(add(pos, 1))))),
                            or(
                                shl(136, byte(0, mload(add(pos, 2)))),
                                shl(128, byte(0, mload(add(pos, 3))))
                            )
                        ),
                        or(
                            or(
                                shl(120, byte(0, mload(add(pos, 4)))),
                                shl(112, byte(0, mload(add(pos, 5))))
                            ),
                            or(
                                shl(104, byte(0, mload(add(pos, 6)))),
                                shl(96, byte(0, mload(add(pos, 7))))
                            )
                        )
                    ),
                    or(
                        or(
                            or(
                                shl(88, byte(0, mload(add(pos, 8)))),
                                shl(80, byte(0, mload(add(pos, 9))))
                            ),
                            or(
                                shl(72, byte(0, mload(add(pos, 10)))),
                                shl(64, byte(0, mload(add(pos, 11))))
                            )
                        ),
                        or(
                            or(
                                or(
                                    shl(56, byte(0, mload(add(pos, 12)))),
                                    shl(48, byte(0, mload(add(pos, 13))))
                                ),
                                or(
                                    shl(40, byte(0, mload(add(pos, 14)))),
                                    shl(32, byte(0, mload(add(pos, 15))))
                                )
                            ),
                            or(
                                or(
                                    shl(24, byte(0, mload(add(pos, 16)))),
                                    shl(16, byte(0, mload(add(pos, 17))))
                                ),
                                or(shl(8, byte(0, mload(add(pos, 18)))), byte(0, mload(add(pos, 19))))
                            )
                        )
                    )
                )
            newPos := add(pos, 20)
        }
    }

    // ---------------------------------------------------------------
    // Utility Functions
    // ---------------------------------------------------------------

    /// @notice Get the memory pointer to the data section of a bytes array
    /// @param data The bytes array
    /// @return ptr The pointer to the actual data (after length prefix)
    function dataPtr(bytes memory data) internal pure returns (uint256 ptr) {
        assembly {
            ptr := add(data, 0x20)
        }
    }

    /// @notice Calculate compact size for ClaimRecord encoding
    /// @param bondInstructionsCount Number of bond instructions
    /// @return size The total size needed
    function calculateClaimRecordSize(uint256 bondInstructionsCount)
        internal
        pure
        returns (uint256 size)
    {
        // Fixed size fields:
        size = 6; // proposalId (uint48)
        size += 32 * 4; // 4 bytes32 fields in Claim
        size += 6; // endBlockNumber (uint48)
        size += 20 * 2; // 2 addresses in Claim
        size += 1; // span (uint8)
        size += 2; // array length (uint16 - max 65535 bond instructions)

        // Variable size:
        // Each bond instruction: proposalId(6) + bondType(1) + payer(20) + receiver(20) = 47 bytes
        size += bondInstructionsCount * 47;
    }
}
