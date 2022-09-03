// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibInvalidTxList.sol";

contract TestLibInvalidTxList {
    function parseRecoverPayloads(LibTxDecoder.Tx memory transaction)
        public
        pure
        returns (
            bytes32 hash,
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        return LibInvalidTxList.parseRecoverPayloads(transaction);
    }

    function verifySignature(LibTxDecoder.Tx memory transaction)
        public
        pure
        returns (address)
    {
        return LibInvalidTxList.verifySignature(transaction);
    }
}
