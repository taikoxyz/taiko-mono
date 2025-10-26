// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IBridge.sol";

/// @title LibHashMessage
/// @notice Optimized keccak256 hashing for bridge messages
/// @custom:security-contact security@taiko.xyz
library LibHashMessage {
    /// @notice Original implementation using abi.encode
    /// @param _message The message to hash
    /// @return Hash of the message
    function hashOriginal(IBridge.Message memory _message) internal pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_MESSAGE", _message));
    }

    /// @notice Optimized implementation using inline assembly
    /// @dev Replicates abi.encode behavior but with optimized memory operations
    /// @param _message The message to hash
    /// @return result_ Hash of the message
    function hashOptimized(IBridge.Message memory _message)
        internal
        pure
        returns (bytes32 result_)
    {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // Based on debug output, abi.encode("TAIKO_MESSAGE", message) produces:
            // Word 0: 0x40 (offset to string)
            // Word 1: 0x80 (offset to struct)
            // Word 2: 0x0d (string length = 13)
            // Word 3: "TAIKO_MESSAGE" left-aligned
            // Word 4+: struct data

            // Write offsets
            mstore(ptr, 0x0000000000000000000000000000000000000000000000000000000000000040)
            mstore(add(ptr, 0x20), 0x0000000000000000000000000000000000000000000000000000000000000080)

            // Write string length
            mstore(add(ptr, 0x40), 0x000000000000000000000000000000000000000000000000000000000000000d)

            // Write string data "TAIKO_MESSAGE" (13 bytes)
            mstore(add(ptr, 0x60), 0x5441494b4f5f4d45535341474500000000000000000000000000000000000000)

            // Now write Message struct fields starting at offset 0x80
            let msgStart := add(ptr, 0x80)

            // Copy all fixed-size fields (10 * 32 bytes)
            mstore(msgStart, mload(_message))                // id (uint64)
            mstore(add(msgStart, 0x20), mload(add(_message, 0x20)))    // fee (uint64)
            mstore(add(msgStart, 0x40), mload(add(_message, 0x40)))    // gasLimit (uint32)
            mstore(add(msgStart, 0x60), mload(add(_message, 0x60)))    // from (address)
            mstore(add(msgStart, 0x80), mload(add(_message, 0x80)))    // srcChainId (uint64)
            mstore(add(msgStart, 0xa0), mload(add(_message, 0xa0)))    // srcOwner (address)
            mstore(add(msgStart, 0xc0), mload(add(_message, 0xc0)))    // destChainId (uint64)
            mstore(add(msgStart, 0xe0), mload(add(_message, 0xe0)))    // destOwner (address)
            mstore(add(msgStart, 0x100), mload(add(_message, 0x100))) // to (address)
            mstore(add(msgStart, 0x120), mload(add(_message, 0x120))) // value (uint256)

            // Dynamic bytes field (data)
            // Get the pointer to the actual data
            let dataPtr := mload(add(_message, 0x140))
            let dataLen := mload(dataPtr)

            // Write offset to data (relative to struct start) = 0x160
            mstore(add(msgStart, 0x140), 0x0000000000000000000000000000000000000000000000000000000000000160)

            // Write data length
            mstore(add(msgStart, 0x160), dataLen)

            // Copy data bytes if any
            if gt(dataLen, 0) {
                let src := add(dataPtr, 0x20)
                let dst := add(msgStart, 0x180)
                let words := div(add(dataLen, 31), 32)

                for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                    mstore(add(dst, mul(i, 0x20)), mload(add(src, mul(i, 0x20))))
                }

                // Total size: 0x80 (header) + 0x180 (fixed fields + data offset + data len) + rounded data
                result_ := keccak256(ptr, add(0x200, mul(words, 0x20)))
            }

            if iszero(dataLen) {
                // For empty data: 0x80 (header) + 0x180 (all fixed fields)
                result_ := keccak256(ptr, 0x200)
            }
        }
    }
}
