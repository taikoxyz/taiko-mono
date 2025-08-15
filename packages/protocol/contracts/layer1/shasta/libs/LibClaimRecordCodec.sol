// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";

/// @title LibClaimRecordCodec
/// @notice Optimized library for encoding/decoding claim record data with bit-packing
/// @dev Optimizations applied:
/// - unchecked blocks for safe arithmetic
/// - bit shifts instead of multiplication
/// - cached memory pointers
/// - efficient 6-byte value packing
/// - single mstore operations where possible
/// @custom:security-contact security@taiko.xyz
library LibClaimRecordCodec {
    // ---------------------------------------------------------------
    // Constants and Errors
    // ---------------------------------------------------------------

    uint256 private constant MAX_BOND_INSTRUCTIONS = 127;
    uint256 private constant MAX_BOND_TYPE = 3;

    error INVALID_DATA_LENGTH();
    error BOND_INSTRUCTIONS_ARRAY_EXCEEDS_MAX();
    error BOND_TYPE_EXCEEDS_MAX();

    // ---------------------------------------------------------------
    // Optimized Encoding
    // ---------------------------------------------------------------

    /// @notice Encodes a ClaimRecord into optimized packed bytes
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data as bytes
    function encode(IInbox.ClaimRecord memory _claimRecord) internal pure returns (bytes memory) {
        // Validate annotated fields
        uint256 bondCount = _claimRecord.bondInstructions.length;
        if (bondCount > MAX_BOND_INSTRUCTIONS) {
            revert BOND_INSTRUCTIONS_ARRAY_EXCEEDS_MAX();
        }

        for (uint256 i = 0; i < bondCount; i++) {
            if (uint256(_claimRecord.bondInstructions[i].bondType) > MAX_BOND_TYPE) {
                revert BOND_TYPE_EXCEEDS_MAX();
            }
        }

        // Calculate size with unchecked
        uint256 size;
        unchecked {
            size = 182 + (bondCount * 47);
        }
        bytes memory result = new bytes(size);

        assembly ("memory-safe") {
            let ptr := add(result, 0x20)
            let cr := _claimRecord

            // Cache frequently used pointers
            let cr20 := add(cr, 0x20)
            let cr40 := add(cr, 0x40)
            let cr60 := add(cr, 0x60)

            // Get claim struct pointer and cache offsets
            let claim := mload(cr20)
            let claim20 := add(claim, 0x20)
            let claim40 := add(claim, 0x40)
            let claim60 := add(claim, 0x60)
            let claim80 := add(claim, 0x80)
            let claima0 := add(claim, 0xa0)
            let claimc0 := add(claim, 0xc0)

            // Pack proposalId (6 bytes) efficiently
            mstore(ptr, shl(208, and(mload(cr), 0xffffffffffff)))

            // Copy proposalHash (32 bytes)
            mstore(add(ptr, 6), mload(claim))

            // Copy parentClaimHash (32 bytes)
            mstore(add(ptr, 38), mload(claim20))

            // Pack endBlockNumber (6 bytes) efficiently
            mstore(add(ptr, 70), shl(208, and(mload(claim40), 0xffffffffffff)))

            // Copy endBlockHash (32 bytes)
            mstore(add(ptr, 76), mload(claim60))

            // Copy endStateRoot (32 bytes)
            mstore(add(ptr, 108), mload(claim80))

            // Pack designatedProver (20 bytes)
            mstore(add(ptr, 140), shl(96, mload(claima0)))

            // Pack actualProver (20 bytes)
            mstore(add(ptr, 160), shl(96, mload(claimc0)))

            // Pack span (1 byte)
            mstore8(add(ptr, 180), mload(cr40))

            // Pack bondInstructions length (1 byte)
            mstore8(add(ptr, 181), bondCount)

            // Pack bond instructions
            ptr := add(ptr, 182)
            let bondArray := mload(cr60)
            let bondData := add(bondArray, 0x20)

            for { let i := 0 } lt(i, bondCount) { i := add(i, 1) } {
                let bond := mload(add(bondData, shl(5, i))) // Use bit shift for *32
                let bond20 := add(bond, 0x20)
                let bond40 := add(bond, 0x40)
                let bond60 := add(bond, 0x60)

                // Pack proposalId (6 bytes) efficiently
                mstore(ptr, shl(208, and(mload(bond), 0xffffffffffff)))

                // Pack bondType (1 byte)
                mstore8(add(ptr, 6), mload(bond20))

                // Pack payer (20 bytes)
                mstore(add(ptr, 7), shl(96, mload(bond40)))

                // Pack receiver (20 bytes)
                mstore(add(ptr, 27), shl(96, mload(bond60)))

                ptr := add(ptr, 47)
            }
        }

        return result;
    }

    // ---------------------------------------------------------------
    // Optimized Decoding
    // ---------------------------------------------------------------

    /// @notice Decodes packed bytes into a ClaimRecord
    /// @param _data The encoded data
    /// @return claimRecord_ The decoded claim record
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        if (_data.length < 182) revert INVALID_DATA_LENGTH();

        assembly ("memory-safe") {
            let ptr := add(_data, 0x20)

            // Cache claimRecord field pointers
            let cr20 := add(claimRecord_, 0x20)
            let cr40 := add(claimRecord_, 0x40)
            let cr60 := add(claimRecord_, 0x60)

            // Decode proposalId (6 bytes) - extract from single word
            mstore(claimRecord_, shr(208, mload(ptr)))

            // Allocate claim struct
            let claim := mload(0x40)
            mstore(0x40, add(claim, 0xe0))
            mstore(cr20, claim)

            // Cache claim field pointers
            let claim20 := add(claim, 0x20)
            let claim40 := add(claim, 0x40)
            let claim60 := add(claim, 0x60)
            let claim80 := add(claim, 0x80)
            let claima0 := add(claim, 0xa0)
            let claimc0 := add(claim, 0xc0)

            // Decode proposalHash (32 bytes)
            mstore(claim, mload(add(ptr, 6)))

            // Decode parentClaimHash (32 bytes)
            mstore(claim20, mload(add(ptr, 38)))

            // Decode endBlockNumber (6 bytes) - extract from single word
            mstore(claim40, shr(208, mload(add(ptr, 70))))

            // Decode endBlockHash (32 bytes)
            mstore(claim60, mload(add(ptr, 76)))

            // Decode endStateRoot (32 bytes)
            mstore(claim80, mload(add(ptr, 108)))

            // Decode designatedProver (20 bytes)
            mstore(claima0, shr(96, mload(add(ptr, 140))))

            // Decode actualProver (20 bytes)
            mstore(claimc0, shr(96, mload(add(ptr, 160))))

            // Decode span (1 byte)
            mstore(cr40, byte(0, mload(add(ptr, 180))))

            // Decode bondInstructions length (1 byte)
            let bondCount := byte(0, mload(add(ptr, 181)))

            // Allocate bond instructions array
            let bondArray := mload(0x40)
            mstore(bondArray, bondCount)

            // Use bit shift for efficient multiplication
            let newFreePtr := add(bondArray, shl(5, add(bondCount, 1)))
            mstore(0x40, newFreePtr)

            mstore(cr60, bondArray)

            // Decode bond instructions
            ptr := add(ptr, 182)
            let bondArrayData := add(bondArray, 0x20)

            for { let i := 0 } lt(i, bondCount) { i := add(i, 1) } {
                // Allocate bond struct
                let bond := mload(0x40)
                mstore(0x40, add(bond, 0x80))

                // Decode proposalId (6 bytes) from single word
                mstore(bond, shr(208, mload(ptr)))

                // Decode bondType (1 byte)
                mstore(add(bond, 0x20), byte(0, mload(add(ptr, 6))))

                // Decode payer (20 bytes)
                mstore(add(bond, 0x40), shr(96, mload(add(ptr, 7))))

                // Decode receiver (20 bytes)
                mstore(add(bond, 0x60), shr(96, mload(add(ptr, 27))))

                // Store bond in array
                mstore(add(bondArrayData, shl(5, i)), bond) // Use bit shift for *32

                ptr := add(ptr, 47)
            }
        }
    }
}
