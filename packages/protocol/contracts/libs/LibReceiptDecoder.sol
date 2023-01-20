// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../thirdparty/LibBytesUtils.sol";
import "../thirdparty/LibRLPReader.sol";

/**
 * @author david <david@taiko.xyz>
 */
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

    function decodeReceipt(
        bytes calldata encoded
    ) public pure returns (Receipt memory receipt) {
        // Non-legacy transaction receipts should first remove the type prefix.
        LibRLPReader.RLPItem[] memory rlpItems = LibRLPReader.readList(
            encoded[0] >= 0x0 && encoded[0] <= 0x7f
                ? LibBytesUtils.slice(encoded, 1)
                : encoded
        );

        require(rlpItems.length == 4, "invalid items length");

        receipt.status = uint64(LibRLPReader.readUint256(rlpItems[0]));
        receipt.cumulativeGasUsed = uint64(
            LibRLPReader.readUint256(rlpItems[1])
        );
        receipt.logsBloom = decodeLogsBloom(rlpItems[2]);
        receipt.logs = decodeLogs(LibRLPReader.readList(rlpItems[3]));
    }

    function decodeLogsBloom(
        LibRLPReader.RLPItem memory logsBloomRlp
    ) internal pure returns (bytes32[8] memory logsBloom) {
        bytes memory bloomBytes = LibRLPReader.readBytes(logsBloomRlp);
        require(bloomBytes.length == 256, "invalid logs bloom");

        return abi.decode(bloomBytes, (bytes32[8]));
    }

    function decodeLogs(
        LibRLPReader.RLPItem[] memory logsRlp
    ) internal pure returns (Log[] memory) {
        Log[] memory logs = new Log[](logsRlp.length);

        for (uint256 i = 0; i < logsRlp.length; ++i) {
            LibRLPReader.RLPItem[] memory rlpItems = LibRLPReader.readList(
                logsRlp[i]
            );
            logs[i].contractAddress = LibRLPReader.readAddress(rlpItems[0]);
            logs[i].topics = decodeTopics(LibRLPReader.readList(rlpItems[1]));
            logs[i].data = LibRLPReader.readBytes(rlpItems[2]);
        }

        return logs;
    }

    function decodeTopics(
        LibRLPReader.RLPItem[] memory topicsRlp
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory topics = new bytes32[](topicsRlp.length);

        for (uint256 i = 0; i < topicsRlp.length; ++i) {
            topics[i] = LibRLPReader.readBytes32(topicsRlp[i]);
        }

        return topics;
    }
}
