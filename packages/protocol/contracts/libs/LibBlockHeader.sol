// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import "../thirdparty/optimism/rlp/RLPWriter.sol";

struct BlockHeader {
    bytes32 parentHash;
    bytes32 ommersHash;
    address beneficiary;
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

// TODO(daniel): add back tests
library LibBlockHeader {
    function hashBlockHeader(BlockHeader memory header) internal pure returns (bytes32) {
        bytes memory rlpHeader = RLPWriter.writeList(_getBlockHeaderRLPItemsList(header, 0));
        return keccak256(rlpHeader);
    }

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
        list[0] = RLPWriter.writeUint(uint(header.parentHash));
        list[1] = RLPWriter.writeUint(uint(header.ommersHash));
        list[2] = RLPWriter.writeAddress(header.beneficiary);
        list[3] = RLPWriter.writeUint(uint(header.stateRoot));
        list[4] = RLPWriter.writeUint(uint(header.transactionsRoot));
        list[5] = RLPWriter.writeUint(uint(header.receiptsRoot));
        list[6] = RLPWriter.writeBytes(abi.encodePacked(header.logsBloom));
        list[7] = RLPWriter.writeUint(header.difficulty);
        list[8] = RLPWriter.writeUint(header.height);
        list[9] = RLPWriter.writeUint64(header.gasLimit);
        list[10] = RLPWriter.writeUint64(header.gasUsed);
        list[11] = RLPWriter.writeUint64(header.timestamp);
        list[12] = RLPWriter.writeBytes(header.extraData);
        list[13] = RLPWriter.writeUint(uint(header.mixHash));
        // According to the ethereum yellow paper, we should treat `nonce`
        // as [8]byte when hashing the block.
        list[14] = RLPWriter.writeBytes(abi.encodePacked(header.nonce));
        if (header.baseFeePerGas != 0) {
            // EIP-1559 transaction
            list[15] = RLPWriter.writeUint(header.baseFeePerGas);
        }
        if (header.withdrawalsRoot != 0) {
            // EIP-4895 transaction
            list[16] = RLPWriter.writeHash(header.withdrawalsRoot);
        }
    }
}
