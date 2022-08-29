// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../libs/LibTaikoConstants.sol";
import "../libs/LibTxListDecoder.sol";
import "../libs/LibMerkleProof.sol";
import "../thirdparty/Lib_RLPReader.sol";
import "../thirdparty/Lib_RLPWriter.sol";

/// @dev A library to invalidate a txList using the following rules:
///
/// A txList is valid if and only if:
/// 1. The txList's lenght is no more than `TAIKO_BLOCK_MAX_TXLIST_BYTES`;
/// 2. The txList is well-formed RLP, with no additional trailing bytes;
/// 3. The total number of transactions is no more than `TAIKO_BLOCK_MAX_TXS` and;
/// 4. The sum of all transaction gas limit is no more than  `TAIKO_BLOCK_MAX_GAS_LIMIT`.
///
/// A transaction is valid if and only if:
/// 1. The transaction is well-formed RLP, with no additional trailing bytes (rule#1 in Ethereum yellow paper);
/// 2. The transaction's signature is valid (rule#2 in Ethereum yellow paper), and;
/// 3. The transaction's the gas limit is no smaller than the intrinsic gas `TAIKO_TX_MIN_GAS_LIMIT`(rule#5 in Ethereum yellow paper).
///
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
        if (encoded.length > LibTaikoConstants.TAIKO_BLOCK_MAX_TXLIST_BYTES) {
            return Reason.BINARY_TOO_LARGE;
        }

        try LibTxListDecoder.decodeTxList(encoded) returns (
            LibTxListDecoder.TxList memory txList
        ) {
            if (txList.items.length > LibTaikoConstants.TAIKO_BLOCK_MAX_TXS) {
                return Reason.BLOCK_TOO_MANY_TXS;
            }

            if (
                LibTxListDecoder.sumGasLimit(txList) >
                LibTaikoConstants.TAIKO_BLOCK_MAX_GAS_LIMIT
            ) {
                return Reason.BLOCK_GAS_LIMIT_TOO_LARGE;
            }

            require(txIdx < txList.items.length, "invalid txIdx");
            LibTxListDecoder.Tx memory _tx = txList.items[txIdx];

            if (!verifySignature(_tx)) {
                return Reason.TX_INVALID_SIG;
            }

            if (hint == Reason.TX_GAS_LIMIT_TOO_SMALL) {
                require(
                    _tx.gasLimit >= LibTaikoConstants.TAIKO_TX_MIN_GAS_LIMIT,
                    "bad hint"
                );
                return Reason.TX_GAS_LIMIT_TOO_SMALL;
            }

            revert("failed to prove txlist invalid");
        } catch (bytes memory) {
            return Reason.BINARY_NOT_DECODABLE;
        }
    }

    function verifySignature(LibTxListDecoder.Tx memory transaction)
        internal
        pure
        returns (bool)
    {
        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = parseRecoverPayloads(
            transaction
        );

        (, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, v, r, s);

        return error == ECDSA.RecoverError.NoError;
    }

    function parseRecoverPayloads(LibTxListDecoder.Tx memory transaction)
        internal
        pure
        returns (
            // transaction hash (without singature values)
            bytes32 hash,
            // transaction signature values
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        Lib_RLPReader.RLPItem[] memory txRLPItems;
        if (transaction.txType == 0) {
            // Legacy transactions do not have the EIP-2718 type prefix.
            txRLPItems = Lib_RLPReader.readList(transaction.txData);
        } else {
            txRLPItems = Lib_RLPReader.readList(
                Lib_BytesUtils.slice(transaction.txData, 1)
            );
        }

        // Signature values are always last three RLP items for all kinds of
        // transactions.
        bytes[] memory list = new bytes[](txRLPItems.length - 3);
        for (uint256 i = 0; i < list.length; i++) {
            // For Non-legacy transactions, accessList is always the
            // fourth to last item.
            if (transaction.txType != 0 && i == list.length - 1) {
                list[i] = Lib_RLPReader.readRawBytes(txRLPItems[i]);
                continue;
            }

            list[i] = Lib_RLPWriter.writeBytes(
                Lib_RLPReader.readBytes(txRLPItems[i])
            );
        }

        bytes memory unsignedTxRlp = Lib_RLPWriter.writeList(list);

        // Add the EIP-2718 type prefix for non-legacy transactions.
        if (transaction.txType != 0) {
            unsignedTxRlp = bytes.concat(
                bytes1(transaction.txType),
                unsignedTxRlp
            );
        }

        v = uint8(Lib_RLPReader.readUint256(txRLPItems[txRLPItems.length - 3]));
        r = Lib_RLPReader.readBytes32(txRLPItems[txRLPItems.length - 2]);
        s = Lib_RLPReader.readBytes32(txRLPItems[txRLPItems.length - 1]);

        // Non-legacy txs are defined to use 0 and 1 as their recovery
        // id, add 27 to become equivalent to raw Homestead signatures that
        // used in ecrecover.
        if (transaction.txType != 0) {
            v += 27;
        }

        hash = keccak256(unsignedTxRlp);
    }
}
