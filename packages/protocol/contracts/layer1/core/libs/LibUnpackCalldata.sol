// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LibUnpackCalldata
/// @notice Library providing low-level calldata unpacking functions for compact binary decoding
/// using inline assembly for maximum gas efficiency.
/// @dev This is the calldata counterpart to LibPackUnpack's memory-based unpack functions.
/// Instead of reading from memory with `mload`, these functions read directly from calldata
/// with `calldataload`, avoiding the cost of copying calldata to memory.
///
/// Calldata Layout:
/// - Functions read from calldata at byte offsets into msg.data
/// - All multi-byte integers use big-endian encoding (matching LibPackUnpack)
/// - Position tracking is left to the caller
///
/// Safety Notes:
/// - No bounds checking on calldata access (gas-optimized design)
/// - Callers are responsible for ensuring data has sufficient length
/// - Reading past calldata length returns zero-padded bytes (EVM behavior)
/// - Suitable for controlled environments where input validation happens upstream
/// @custom:security-contact security@taiko.xyz
library LibUnpackCalldata {
    // ---------------------------------------------------------------
    // Unpack Functions (read from calldata with compact encoding)
    // ---------------------------------------------------------------

    /// @dev Unpack uint8 (1 byte) from calldata at offset.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked uint8 value
    /// @return newPos_ Updated offset after reading (pos + 1)
    function unpackUint8(uint256 _pos) internal pure returns (uint8 value_, uint256 newPos_) {
        assembly {
            value_ := shr(248, calldataload(_pos))
            newPos_ := add(_pos, 1)
        }
    }

    /// @dev Unpack uint16 (2 bytes) from calldata at offset using big-endian encoding.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked uint16 value
    /// @return newPos_ Updated offset after reading (pos + 2)
    function unpackUint16(uint256 _pos) internal pure returns (uint16 value_, uint256 newPos_) {
        assembly {
            value_ := shr(240, calldataload(_pos))
            newPos_ := add(_pos, 2)
        }
    }

    /// @dev Unpack uint24 (3 bytes) from calldata at offset using big-endian encoding.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked uint24 value
    /// @return newPos_ Updated offset after reading (pos + 3)
    function unpackUint24(uint256 _pos) internal pure returns (uint24 value_, uint256 newPos_) {
        assembly {
            value_ := shr(232, calldataload(_pos))
            newPos_ := add(_pos, 3)
        }
    }

    /// @dev Unpack uint32 (4 bytes) from calldata at offset using big-endian encoding.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked uint32 value
    /// @return newPos_ Updated offset after reading (pos + 4)
    function unpackUint32(uint256 _pos) internal pure returns (uint32 value_, uint256 newPos_) {
        assembly {
            value_ := shr(224, calldataload(_pos))
            newPos_ := add(_pos, 4)
        }
    }

    /// @dev Unpack uint48 (6 bytes) from calldata at offset using big-endian encoding.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked uint48 value
    /// @return newPos_ Updated offset after reading (pos + 6)
    function unpackUint48(uint256 _pos) internal pure returns (uint48 value_, uint256 newPos_) {
        assembly {
            value_ := shr(208, calldataload(_pos))
            newPos_ := add(_pos, 6)
        }
    }

    /// @dev Unpack uint256 (32 bytes) from calldata at offset.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked uint256 value
    /// @return newPos_ Updated offset after reading (pos + 32)
    function unpackUint256(uint256 _pos) internal pure returns (uint256 value_, uint256 newPos_) {
        assembly {
            value_ := calldataload(_pos)
            newPos_ := add(_pos, 32)
        }
    }

    /// @dev Unpack bytes32 from calldata at offset.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked bytes32 value
    /// @return newPos_ Updated offset after reading (pos + 32)
    function unpackBytes32(uint256 _pos) internal pure returns (bytes32 value_, uint256 newPos_) {
        assembly {
            value_ := calldataload(_pos)
            newPos_ := add(_pos, 32)
        }
    }

    /// @dev Unpack address (20 bytes) from calldata at offset.
    /// @param _pos Calldata byte offset to read from
    /// @return value_ The unpacked address
    /// @return newPos_ Updated offset after reading (pos + 20)
    function unpackAddress(uint256 _pos) internal pure returns (address value_, uint256 newPos_) {
        assembly {
            value_ := shr(96, calldataload(_pos))
            newPos_ := add(_pos, 20)
        }
    }

    // ---------------------------------------------------------------
    // Utility Functions
    // ---------------------------------------------------------------

    /// @notice Get the calldata offset to the start of a bytes calldata slice.
    /// @dev Unlike the memory variant, calldata slices have no length prefix to skip.
    /// @param _data The bytes calldata slice
    /// @return ptr_ The absolute calldata offset to the data
    function dataPtr(bytes calldata _data) internal pure returns (uint256 ptr_) {
        assembly {
            ptr_ := _data.offset
        }
    }
}
