// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibRLPWriter } from "../thirdparty/LibRLPWriter.sol";

/**
 * @title BlockHeader Struct
 * @notice Defines the data structure for an Ethereum block header.
 */
struct BlockHeader {
    bytes32 parentHash; // Hash of the parent block.
    bytes32 ommersHash; // Hash of the ommers data.
    address beneficiary; // Address of the beneficiary (miner).
    bytes32 stateRoot; // State root after applying the block's transactions.
    bytes32 transactionsRoot; // Merkle root of the block's transactions.
    bytes32 receiptsRoot; // Merkle root of the block's receipts.
    bytes32[8] logsBloom; // Bloom filter for logs in the block.
    uint256 difficulty; // Mining difficulty.
    uint128 height; // Block number.
    uint64 gasLimit; // Gas limit for the block.
    uint64 gasUsed; // Total gas used by all transactions in the block.
    uint64 timestamp; // Unix timestamp.
    bytes extraData; // Extra data (e.g., miner's arbitrary data).
    bytes32 mixHash; // Proof-of-Work related data.
    uint64 nonce; // Proof-of-Work nonce.
    uint256 baseFeePerGas; // Base fee per gas (introduced in EIP-1559).
    bytes32 withdrawalsRoot; // Merkle root for withdrawals (introduced in
        // EIP-4895).
}

/**
 * @title LibBlockHeader Library
 * @notice Provides functions to handle Ethereum block headers.
 */
library LibBlockHeader {
    function hashBlockHeader(BlockHeader memory header)
        internal
        pure
        returns (bytes32)
    {
        bytes memory rlpHeader =
            LibRLPWriter.writeList(_getBlockHeaderRLPItemsList(header, 0));
        return keccak256(rlpHeader);
    }

    /**
     * @dev Constructs the RLP item list for a block header.
     * Different Ethereum Improvement Proposals (EIPs) may add different fields,
     * and this function accounts for those variations.
     * @param header The block header.
     * @param extraCapacity Additional capacity for the list.
     * @return list The RLP item list for the block header.
     */
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
        list[2] = LibRLPWriter.writeAddress(header.beneficiary);
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
        // According to the ethereum yellow paper, we should treat `nonce`
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
