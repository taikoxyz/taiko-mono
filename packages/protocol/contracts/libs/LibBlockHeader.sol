// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../thirdparty/Lib_RLPWriter.sol";
import "./LibConstants.sol";

struct BlockHeader {
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
}

library LibBlockHeader {
    bytes32 private constant EMPTY_OMMERS_HASH =
        0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347;

    function hashBlockHeader(BlockHeader memory header, bytes32 parentHash)
        internal
        pure
        returns (bytes32)
    {
        // require(parentHash != 0, "invalid parentHash");
        bytes[] memory list = new bytes[](15);
        list[0] = Lib_RLPWriter.writeHash(parentHash);
        list[1] = Lib_RLPWriter.writeHash(header.ommersHash);
        list[2] = Lib_RLPWriter.writeAddress(header.beneficiary);
        list[3] = Lib_RLPWriter.writeHash(header.stateRoot);
        list[4] = Lib_RLPWriter.writeHash(header.transactionsRoot);
        list[5] = Lib_RLPWriter.writeHash(header.receiptsRoot);
        list[6] = Lib_RLPWriter.writeBytes(abi.encodePacked(header.logsBloom));
        list[7] = Lib_RLPWriter.writeUint(header.difficulty);
        list[8] = Lib_RLPWriter.writeUint(header.height);
        list[9] = Lib_RLPWriter.writeUint64(header.gasLimit);
        list[10] = Lib_RLPWriter.writeUint64(header.gasUsed);
        list[11] = Lib_RLPWriter.writeUint64(header.timestamp);
        list[12] = Lib_RLPWriter.writeBytes(header.extraData);
        list[13] = Lib_RLPWriter.writeHash(header.mixHash);
        // According to the ethereum yellow paper, we should treat `nonce`
        // as [8]byte when hashing the block.
        list[14] = Lib_RLPWriter.writeBytes(abi.encodePacked(header.nonce));

        bytes memory rlpHeader = Lib_RLPWriter.writeList(list);
        return keccak256(rlpHeader);
    }

    function isPartiallyValidForTaiko(BlockHeader calldata header)
        internal
        pure
        returns (bool)
    {
        return
            header.ommersHash == EMPTY_OMMERS_HASH &&
            header.gasLimit <= LibConstants.TAIKO_BLOCK_MAX_GAS_LIMIT &&
            header.extraData.length <= 32 &&
            header.difficulty == 0 &&
            header.nonce == 0;
    }
}
