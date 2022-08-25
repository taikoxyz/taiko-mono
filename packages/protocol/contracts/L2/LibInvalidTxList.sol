// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibTaikoConstants.sol";
import "../libs/LibTxListDecoder.sol";
import "../libs/LibMerkleProof.sol";

/// @dev A library to invalidate a txList using the following rules:
///
/// A txList is valid if and only if:
/// 1. The txList's lenght is no more than a given threshold;
/// 2. The txList is well-formed RLP, with no additional trailing bytes;
/// 3. The total number of transactions is no more than a given threshold and;
/// 4. The sum of all transaction gas limit is no more than a given threshold.
///
/// A transaction is valid if and only if:
/// 1. The transaction is well-formed RLP, with no additional trailing bytes (rule#1 in Ethereum yellow paper);
/// 2. The transaction's signature is valid (rule#2 in Ethereum yellow paper), and;
/// 3. The transaction's the gas limit is no smaller than the intrinsic gas (rule#5 in Ethereum yellow paper).
library LibInvalidTxList {
    enum Reason {
        OK,
        BINARY_TOO_LARGE,
        BINARY_NOT_DECODABLE,
        BLOCK_TOO_MANY_TXS,
        BLOCK_GAS_LIMIT_TOO_LARGE,
        TX_INVALID_SIG,
        TX_GAS_LIMIT_TOO_SMALL
    }

    function isTxListInvalid(
        bytes calldata encoded,
        Reason hint,
        uint256 txIdx
    ) internal pure returns (Reason) {
        if (encoded.length > LibTaikoConstants.MAX_TX_LIST_DATA_SIZE) {
            return Reason.BINARY_TOO_LARGE;
        }

        try LibTxListDecoder.decodeTxList(encoded) returns (
            LibTxListDecoder.TxList memory txList
        ) {
            if (
                txList.items.length > LibTaikoConstants.MAX_TAIKO_BLOCK_NUM_TXS
            ) {
                return Reason.BLOCK_TOO_MANY_TXS;
            }

            if (
                LibTxListDecoder.sumGasLimit(txList) >
                LibTaikoConstants.MAX_TAIKO_BLOCK_GAS_LIMIT
            ) {
                return Reason.BLOCK_GAS_LIMIT_TOO_LARGE;
            }

            require(txIdx < txList.items.length, "invalid txIdx");
            LibTxListDecoder.Tx memory _tx = txList.items[txIdx];

            if (hint == Reason.TX_INVALID_SIG) {
                // TODO:
                // require(....)
                return Reason.TX_INVALID_SIG;
            }

            if (hint == Reason.TX_GAS_LIMIT_TOO_SMALL) {
                // TODO:
                // require(....)
                return Reason.TX_GAS_LIMIT_TOO_SMALL;
            }

            revert("failed to prove txlist invalid");
        } catch (bytes memory) {
            return Reason.BINARY_NOT_DECODABLE;
        }
    }
}
