// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../L1/TaikoData.sol";
import "../libs/LibTxDecoder.sol";
import "../libs/LibTxUtils.sol";
import "../thirdparty/LibRLPReader.sol";
import "../thirdparty/LibRLPWriter.sol";

/**
 * A library to invalidate a txList using the following rules:
 *
 * A txList is valid if and only if:
 * 1. The txList's length is no more than `maxBytesPerTxList`.
 * 2. The txList is well-formed RLP, with no additional trailing bytes.
 * 3. The total number of transactions is no more than
 *    `maxTransactionsPerBlock`.
 * 4. The sum of all transaction gas limit is no more than
 *    `blockMaxGasLimit`.
 *
 * A transaction is valid if and only if:
 * 1. The transaction is well-formed RLP, with no additional trailing bytes
 *    (rule #1 in Ethereum yellow paper).
 * 2. The transaction's signature is valid (rule #2 in Ethereum yellow paper).
 * 3. The transaction's the gas limit is no smaller than the intrinsic gas
 *    `minTxGasLimit` (rule #5 in Ethereum yellow paper).
 *
 * @title LibInvalidTxList
 * @author david <david@taiko.xyz>
 */
library LibInvalidTxList {
    // NOTE: If the order of this enum changes, then some test cases that using
    // this enum in generate_genesis.test.ts may also needs to be
    // modified accordingly.
    error ERR_PARAMS_NOT_DEFAULTS();
    error ERR_INVALID_TX_IDX();
    error ERR_INVALID_HINT();
    error ERR_VERIFICAITON_FAILURE();

    enum Hint {
        NONE,
        TX_INVALID_SIG,
        TX_GAS_LIMIT_TOO_SMALL
    }

    function verifyTxListInvalid(
        TaikoData.Config memory config,
        bytes calldata encoded,
        Hint hint,
        uint256 txIdx
    ) internal pure {
        if (encoded.length > config.maxBytesPerTxList) {
            _checkParams(hint, txIdx);
            return;
        }

        try LibTxDecoder.decodeTxList(config.chainId, encoded) returns (
            LibTxDecoder.TxList memory txList
        ) {
            if (txList.items.length > config.maxTransactionsPerBlock) {
                _checkParams(hint, txIdx);
                return;
            }

            if (LibTxDecoder.sumGasLimit(txList) > config.blockMaxGasLimit) {
                _checkParams(hint, txIdx);
                return;
            }

            if (txIdx >= txList.items.length) {
                revert ERR_INVALID_TX_IDX();
            }

            LibTxDecoder.Tx memory _tx = txList.items[txIdx];

            if (hint == Hint.TX_INVALID_SIG) {
                if (
                    LibTxUtils.recoverSender(config.chainId, _tx) != address(0)
                ) {
                    revert ERR_INVALID_HINT();
                }
                return;
            }

            if (hint == Hint.TX_GAS_LIMIT_TOO_SMALL) {
                if (_tx.gasLimit >= config.minTxGasLimit) {
                    revert ERR_INVALID_HINT();
                }
                return;
            }

            revert ERR_VERIFICAITON_FAILURE();
        } catch (bytes memory) {
            _checkParams(hint, txIdx);
        }
    }

    // Checks hint and txIdx both have 0 values.
    function _checkParams(Hint hint, uint256 txIdx) private pure {
        if (hint != Hint.NONE || txIdx != 0) revert ERR_PARAMS_NOT_DEFAULTS();
    }
}
