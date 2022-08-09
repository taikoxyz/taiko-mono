// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./LibTxListDecoder.sol";

library LibTxListValidator {
    uint256 public constant MAX_TAIKO_BLOCK_GAS_LIMIT = 5000000;
    uint256 public constant MAX_TAIKO_BLOCK_NUM_TXS = 20;

    function isTxListValid(bytes calldata encoded)
        internal
        pure
        returns (bool)
    {
        try LibTxListDecoder.decodeTxList(encoded) returns (
            TxList memory txList
        ) {
            return
                txList.items.length <= MAX_TAIKO_BLOCK_NUM_TXS &&
                LibTxListDecoder.sumGasLimit(txList) <=
                MAX_TAIKO_BLOCK_GAS_LIMIT;
        } catch (bytes memory) {
            return false;
        }
    }
}
