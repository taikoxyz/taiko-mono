// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPWriter.sol";

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

library LibBlockHeader {
    bytes32 private constant EMPTY_OMMERS_HASH =
        0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347;

    function hashBlockHeader(BlockHeader memory header) internal pure returns (bytes32) {
        bytes memory rlpHeader = RLPWriter.writeList(getBlockHeaderRLPItemsList(header, 0));
        return keccak256(rlpHeader);
    }

    function getBlockHeaderRLPItemsList(
        BlockHeader memory header,
        uint256 extraCapacity
    )
        internal
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
        list[0] = RLPWriter.writeUint(uint256(header.parentHash));
        list[1] = RLPWriter.writeUint(uint256(header.ommersHash));
        list[2] = RLPWriter.writeAddress(header.beneficiary);
        list[3] = RLPWriter.writeUint(uint256(header.stateRoot));
        list[4] = RLPWriter.writeUint(uint256(header.transactionsRoot));
        list[5] = RLPWriter.writeUint(uint256(header.receiptsRoot));
        list[6] = RLPWriter.writeBytes(abi.encodePacked(header.logsBloom));
        list[7] = RLPWriter.writeUint(header.difficulty);
        list[8] = RLPWriter.writeUint(header.height);
        list[9] = RLPWriter.writeUint(uint256(header.gasLimit));
        list[10] = RLPWriter.writeUint(uint256(header.gasUsed));
        list[11] = RLPWriter.writeUint(uint256(header.timestamp));
        list[12] = RLPWriter.writeBytes(header.extraData);
        list[13] = RLPWriter.writeUint(uint256(header.mixHash));
        // According to the ethereum yellow paper, we should treat `nonce`
        // as [8]byte when hashing the block.
        list[14] = RLPWriter.writeBytes(abi.encodePacked(header.nonce));
        if (header.baseFeePerGas != 0) {
            // EIP-1559 transaction
            list[15] = RLPWriter.writeUint(header.baseFeePerGas);
        }
        if (header.withdrawalsRoot != 0) {
            // EIP-4895 transaction
            list[16] = RLPWriter.writeUint(uint256(header.withdrawalsRoot));
        }
    }
}
