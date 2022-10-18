// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../libs/LibBlockHeader.sol";

contract TestLibBlockHeader {
    function hashBlockHeader(BlockHeader calldata header)
        public
        pure
        returns (bytes32)
    {
        return LibBlockHeader.hashBlockHeader(header);
    }

    function rlpBlockHeader(BlockHeader calldata header)
        public
        pure
        returns (bytes memory)
    {
        bytes[] memory list = new bytes[](15);
        list[0] = Lib_RLPWriter.writeHash(header.parentHash);
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
        return rlpHeader;
    }
}
