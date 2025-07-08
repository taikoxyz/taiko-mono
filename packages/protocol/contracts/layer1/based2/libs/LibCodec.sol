// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodec
/// @custom:security-contact security@taiko.xyz
/// @notice A library for encoding and decoding TransitionMeta structs to optimize storage and gas
/// costs.
/// @dev This library provides functions to pack and unpack arrays of TransitionMeta structs
/// into/from
/// tightly packed byte arrays. Each TransitionMeta is packed into exactly 122 bytes to minimize
/// storage costs while maintaining data integrity.
library LibCodec {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Packs an array of TransitionMeta structs into a tightly packed byte array.
    /// @dev The packed format uses exactly 122 bytes per TransitionMeta:
    /// - blockHash: 32 bytes
    /// - stateRoot: 32 bytes
    /// - prover: 20 bytes (address)
    /// - proofTiming: 1 byte (uint8 enum)
    /// - createdAt: 6 bytes (uint48)
    /// - byAssignedProver: 1 byte (bool)
    /// - lastBlockId: 6 bytes (uint48)
    /// - provabilityBond: 12 bytes (uint96)
    /// - livenessBond: 12 bytes (uint96)
    /// Total: 122 bytes per TransitionMeta
    /// @param _tranMetas Array of TransitionMeta structs to pack
    /// @return encoded_ The packed byte array
    function packTransitionMetas(I.TransitionMeta[] memory _tranMetas)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 length = _tranMetas.length;

        // Each TransitionMeta takes 122 bytes when packed
        encoded_ = new bytes(length * 122);

        uint256 offset;
        for (uint256 i; i < length; ++i) {
            I.TransitionMeta memory meta = _tranMetas[i];

            // Pack data in the order of the struct fields
            assembly {
                let ptr := add(encoded_, add(0x20, offset))

                // blockHash (32 bytes)
                mstore(ptr, mload(meta))
                ptr := add(ptr, 32)

                // stateRoot (32 bytes)
                mstore(ptr, mload(add(meta, 0x20)))
                ptr := add(ptr, 32)

                // prover (20 bytes) - store in lower 20 bytes
                mstore(ptr, shl(96, mload(add(meta, 0x40))))
                ptr := add(ptr, 20)

                // proofTiming (1 byte)
                mstore8(ptr, mload(add(meta, 0x60)))
                ptr := add(ptr, 1)

                // createdAt (6 bytes) - store in lower 6 bytes
                let createdAt := mload(add(meta, 0x80))
                mstore(ptr, shl(208, createdAt))
                ptr := add(ptr, 6)

                // byAssignedProver (1 byte)
                mstore8(ptr, mload(add(meta, 0xa0)))
                ptr := add(ptr, 1)

                // lastBlockId (6 bytes) - store in lower 6 bytes
                let lastBlockId := mload(add(meta, 0xc0))
                mstore(ptr, shl(208, lastBlockId))
                ptr := add(ptr, 6)

                // provabilityBond (12 bytes) - store in lower 12 bytes
                let provabilityBond := mload(add(meta, 0xe0))
                mstore(ptr, shl(160, provabilityBond))
                ptr := add(ptr, 12)

                // livenessBond (12 bytes) - store in lower 12 bytes
                let livenessBond := mload(add(meta, 0x100))
                mstore(ptr, shl(160, livenessBond))
            }

            offset += 122;
        }
    }

    /// @notice Unpacks a byte array back into an array of TransitionMeta structs.
    /// @dev Reverses the packing performed by packTransitionMetas. The input must be
    /// a multiple of 122 bytes, with each 122-byte segment representing one TransitionMeta.
    /// @param _encoded The packed byte array to unpack
    /// @return tranMetas_ Array of unpacked TransitionMeta structs
    function unpackTransitionMetas(bytes calldata _encoded)
        internal
        pure
        returns (I.TransitionMeta[] memory tranMetas_)
    {
        require(_encoded.length % 122 == 0, InvalidDataLength());

        // Calculate length from encoded data size
        uint256 length = _encoded.length / 122;

        tranMetas_ = new I.TransitionMeta[](length);

        uint256 offset;
        for (uint256 i; i < length; ++i) {
            I.TransitionMeta memory meta;

            assembly {
                let dataOffset := add(_encoded.offset, offset)

                // blockHash (32 bytes)
                meta := mload(0x40) // allocate memory
                mstore(meta, calldataload(dataOffset))

                // stateRoot (32 bytes)
                mstore(add(meta, 0x20), calldataload(add(dataOffset, 32)))

                // prover (20 bytes) - right-aligned in 32-byte slot
                let proverData := calldataload(add(dataOffset, 64))
                mstore(add(meta, 0x40), shr(96, proverData))

                // proofTiming (1 byte) - stored as uint8 enum
                let proofTiming := byte(0, calldataload(add(dataOffset, 84)))
                mstore(add(meta, 0x60), proofTiming)

                // createdAt (6 bytes) - stored as uint48
                let createdAtData := calldataload(add(dataOffset, 85))
                mstore(add(meta, 0x80), shr(208, createdAtData))

                // byAssignedProver (1 byte) - stored as bool
                let byAssignedProver := byte(0, calldataload(add(dataOffset, 91)))
                mstore(add(meta, 0xa0), byAssignedProver)

                // lastBlockId (6 bytes) - stored as uint48
                let lastBlockIdData := calldataload(add(dataOffset, 92))
                mstore(add(meta, 0xc0), shr(208, lastBlockIdData))

                // provabilityBond (12 bytes) - stored as uint96
                let provabilityBondData := calldataload(add(dataOffset, 98))
                mstore(add(meta, 0xe0), shr(160, provabilityBondData))

                // livenessBond (12 bytes) - stored as uint96
                let livenessBondData := calldataload(add(dataOffset, 110))
                mstore(add(meta, 0x100), shr(160, livenessBondData))

                // Update free memory pointer
                mstore(0x40, add(meta, 0x120))
            }

            tranMetas_[i] = meta;
            offset += 122;
        }
    }

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error ArrayTooLarge();
    error InvalidDataLength();
    error EmptyInput();
}
