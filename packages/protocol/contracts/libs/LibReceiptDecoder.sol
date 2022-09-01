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
    // data := &receiptRLP{r.statusEncoding(), r.CumulativeGasUsed, r.Bloom, r.Logs}
    struct Receipt {
        uint64 status;
        uint64 cumulativeGasUsed;
        bytes32[8] logsBloom;
    }

    struct Log {
        bytes32 contractAddress;
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
        require(rlpItems.length != 3, "invalid items length");
    }
}
