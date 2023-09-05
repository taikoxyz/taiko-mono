// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibRLPWriter } from "../thirdparty/LibRLPWriter.sol";

/// @dev Defines the data structure for an Ethereum block header.
struct BlockHeader {
    bytes32 parentHash;
    bytes32 ommersHash;
    address proposer;
    bytes32 stateRoot;
    bytes32 transactionsRoot;
    bytes32 receiptsRoot;
    bytes32[8] logsBloom;
    uint256 difficulty;
    uint128 height;
    uint64 gasLimit;
    uint64 gasUsed;
    uint64 timestamp;
    bytes extraData;
    bytes32 mixHash;
    uint64 nonce;
    uint256 baseFeePerGas;
    bytes32 withdrawalsRoot;
}

/// @title LibBlockHeader
/// @dev Provides utilities for Ethereum block headers.
library LibBlockHeader {
    /// @dev Returns the hash of a block header.
    /// @param header The block header.
    /// @return The hash of the block header.
    function hashBlockHeader(BlockHeader memory header)
        internal
        pure
        returns (bytes32)
    {
        bytes memory rlpHeader =
            LibRLPWriter.writeList(_getBlockHeaderRLPItemsList(header, 0));
        return keccak256(rlpHeader);
    }

    /// @dev Constructs the RLP item list for a block header.
    /// @param header The block header.
    /// @param extraCapacity Additional capacity for the list.
    /// @return list The RLP item list for the block header.
    function _getBlockHeaderRLPItemsList(
        BlockHeader memory header,
        uint256 extraCapacity
    )
        private
        pure
        returns (bytes[] memory list)
    {
        if (header.withdrawalsRoot != 0) {
            // EIP-4895 transaction
            list = new bytes[](17 + extraCapacity);
        } else if (header.baseFeePerGas != 0) {
            // EIP-1559 transaction
            list = new bytes[](16 + extraCapacity);
        } else {
            // non-EIP-1559 transaction
            list = new bytes[](15 + extraCapacity);
        }
        list[0] = LibRLPWriter.writeHash(header.parentHash);
        list[1] = LibRLPWriter.writeHash(header.ommersHash);
        list[2] = LibRLPWriter.writeAddress(header.proposer);
        list[3] = LibRLPWriter.writeHash(header.stateRoot);
        list[4] = LibRLPWriter.writeHash(header.transactionsRoot);
        list[5] = LibRLPWriter.writeHash(header.receiptsRoot);
        list[6] = LibRLPWriter.writeBytes(abi.encodePacked(header.logsBloom));
        list[7] = LibRLPWriter.writeUint(header.difficulty);
        list[8] = LibRLPWriter.writeUint(header.height);
        list[9] = LibRLPWriter.writeUint64(header.gasLimit);
        list[10] = LibRLPWriter.writeUint64(header.gasUsed);
        list[11] = LibRLPWriter.writeUint64(header.timestamp);
        list[12] = LibRLPWriter.writeBytes(header.extraData);
        list[13] = LibRLPWriter.writeHash(header.mixHash);
        // According to the Ethereum yellow paper, we should treat `nonce`
        // as [8]byte when hashing the block.
        list[14] = LibRLPWriter.writeBytes(abi.encodePacked(header.nonce));
        if (header.baseFeePerGas != 0) {
            // EIP-1559 transaction
            list[15] = LibRLPWriter.writeUint(header.baseFeePerGas);
        }
        if (header.withdrawalsRoot != 0) {
            // EIP-4895 transaction
            list[16] = LibRLPWriter.writeHash(header.withdrawalsRoot);
        }
    }
}
