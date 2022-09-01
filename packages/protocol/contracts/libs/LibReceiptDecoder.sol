// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../thirdparty/Lib_BytesUtils.sol";
import "../thirdparty/Lib_RLPReader.sol";

library LibReceiptDecoder {
    struct Receipt {
        uint64 status;
        uint64 cumulativeGasUsed;
        bytes32[8] logsBloom;
        Log[] logs;
    }

    struct Log {
        address contractAddress;
        bytes32[] topics;
        bytes data;
    }

    function decodeReceipt(bytes calldata encoded)
        public
        pure
        returns (Receipt memory receipt)
    {
        Lib_RLPReader.RLPItem[] memory rlpItems = Lib_RLPReader.readList(
            encoded
        );
        require(rlpItems.length != 4, "invalid items length");

        receipt.status = uint64(Lib_RLPReader.readUint256(rlpItems[0]));
        receipt.cumulativeGasUsed = uint64(
            Lib_RLPReader.readUint256(rlpItems[1])
        );
        receipt.logsBloom = decodeLogsBloom(rlpItems[2]);
        receipt.logs = decodeLogs(Lib_RLPReader.readList(rlpItems[3]));
    }

    function decodeLogsBloom(Lib_RLPReader.RLPItem memory logsBloomRlp)
        internal
        pure
        returns (bytes32[8] memory logsBloom)
    {
        bytes memory bloomBytes = Lib_RLPReader.readBytes(logsBloomRlp);
        require(bloomBytes.length == 256, "invalid logs bloom");

        return abi.decode(bloomBytes, (bytes32[8]));
    }

    function decodeLogs(Lib_RLPReader.RLPItem[] memory logsRlp)
        internal
        pure
        returns (Log[] memory logs)
    {
        for (uint256 i = 0; i < logsRlp.length; i++) {
            Lib_RLPReader.RLPItem[] memory rlpItems = Lib_RLPReader.readList(
                logsRlp[i]
            );

            logs[i].contractAddress = Lib_RLPReader.readAddress(rlpItems[0]);
            logs[i].topics = decodeTopics(Lib_RLPReader.readList(rlpItems[1]));
            logs[i].data = Lib_RLPReader.readBytes(rlpItems[2]);
        }
    }

    function decodeTopics(Lib_RLPReader.RLPItem[] memory topicsRlp)
        internal
        pure
        returns (bytes32[] memory topics)
    {
        for (uint256 i = 0; i < topicsRlp.length; i++) {
            topics[i] = Lib_RLPReader.readBytes32(topicsRlp[i]);
        }
    }
}
