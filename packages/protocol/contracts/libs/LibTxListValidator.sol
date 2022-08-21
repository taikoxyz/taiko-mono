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

/// @dev The following rules are used for validating a txList:
///
/// 1. The txList is well-formed RLP, with no additional trailing bytes;
/// 2. The total number of transactions is no more than a given threshold;
/// 3. The sum of all transaction gas limit is no more than a given threshold;
/// 4. Each transaction is well-formed RLP, with no additional trailing bytes (rule#1 in Ethereum yellow paper);
/// 5. Each transaction's signature is valid (rule#2 in Ethereum yellow paper), and;
/// 6. Each transaction's the gas limit is no smaller than the intrinsic gas (rule#5 in Ethereum yellow paper).
///
/// TODO(Roger): work on 5 and 6.
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
