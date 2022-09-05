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

import "../libs/LibConstants.sol";
import "../libs/LibTxDecoder.sol";
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
        BLOCK_NO_TXS,
        BLOCK_GAS_LIMIT_TOO_LARGE,
        TX_INVALID_SIG,
        TX_GAS_LIMIT_TOO_SMALL
    }

    function isTxListInvalid(
        bytes calldata encoded,
        Reason hint,
        uint256 txIdx
    ) internal pure returns (Reason) {
        if (encoded.length > LibConstants.TAIKO_BLOCK_MAX_TXLIST_BYTES) {
            return Reason.BINARY_TOO_LARGE;
        }

        try LibTxDecoder.decodeTxList(encoded) returns (
            LibTxDecoder.TxList memory txList
        ) {
            if (txList.items.length == 0) {
                return Reason.BLOCK_NO_TXS;
            }

            if (txList.items.length > LibConstants.TAIKO_BLOCK_MAX_TXS) {
                return Reason.BLOCK_TOO_MANY_TXS;
            }

            if (
                LibTxDecoder.sumGasLimit(txList) >
                LibConstants.TAIKO_BLOCK_MAX_GAS_LIMIT
            ) {
                return Reason.BLOCK_GAS_LIMIT_TOO_LARGE;
            }

            require(txIdx < txList.items.length, "invalid txIdx");
            LibTxDecoder.Tx memory _tx = txList.items[txIdx];

            if (hint == Reason.TX_INVALID_SIG) {
                require(
                    verifySignature(_tx) == address(0),
                    "bad hint TX_INVALID_SIG"
                );
                return Reason.TX_INVALID_SIG;
            }

            if (hint == Reason.TX_GAS_LIMIT_TOO_SMALL) {
                require(
                    _tx.gasLimit >= LibConstants.TAIKO_TX_MIN_GAS_LIMIT,
                    "bad hint"
                );
                return Reason.TX_GAS_LIMIT_TOO_SMALL;
            }

            revert("failed to prove txlist invalid");
        } catch (bytes memory) {
            return Reason.BINARY_NOT_DECODABLE;
        }
    }

    function verifySignature(LibTxDecoder.Tx memory transaction)
        internal
        pure
        returns (address)
    {
        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = parseRecoverPayloads(
            transaction
        );

        (address recoveredAddress, ECDSA.RecoverError error) = ECDSA.tryRecover(
            hash,
            v,
            r,
            s
        );

        if (error != ECDSA.RecoverError.NoError) {
            return address(0);
        }

        return recoveredAddress;
    }

    function parseRecoverPayloads(LibTxDecoder.Tx memory transaction)
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

        if (transaction.txType == 0) {
            // Legacy transactions
            require(txRLPItems.length == 9, "invalid rlp items");
        } else if (transaction.txType == 1) {
            // EIP-2930 transactions
            require(txRLPItems.length == 11, "invalid rlp items");
        } else if (transaction.txType == 2) {
            // EIP-1559 transactions
            require(txRLPItems.length == 12, "invalid rlp items");
        } else {
            revert("invalid txType");
        }

        // Signature values are always last three RLP items for all kinds of
        // transactions.
        bytes[] memory list = new bytes[](
            transaction.txType == 0 ? txRLPItems.length : txRLPItems.length - 3
        );

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

            // For legacy transactions, there are three more RLP items to
            // encode defined in EIP-155.
            if (transaction.txType == 0 && i == list.length - 4) {
                list[i + 1] = Lib_RLPWriter.writeUint(
                    LibConstants.TAIKO_CHAIN_ID
                );
                list[i + 2] = Lib_RLPWriter.writeUint64(0);
                list[i + 3] = Lib_RLPWriter.writeUint64(0);
                break;
            }
        }

        bytes memory unsignedTxRlp = Lib_RLPWriter.writeList(list);

        // Add the EIP-2718 type prefix for non-legacy transactions.
        if (transaction.txType != 0) {
            unsignedTxRlp = bytes.concat(
                bytes1(transaction.txType),
                unsignedTxRlp
            );
        }

        v = normalizeV(transaction.txType, txRLPItems[txRLPItems.length - 3]);
        r = Lib_RLPReader.readBytes32(txRLPItems[txRLPItems.length - 2]);
        s = Lib_RLPReader.readBytes32(txRLPItems[txRLPItems.length - 1]);

        hash = keccak256(unsignedTxRlp);
    }

    // The signature value v used by `ecrecover(hash, v, r, s)` should either
    // be 27 or 28, EIP-1559 / EIP-2930 txs are defined to use {0,1} as recovery
    // id and EIP-155 txs use {0,1} + CHAIN_ID * 2 + 35, so normalize them
    // at first.
    function normalizeV(uint8 txType, Lib_RLPReader.RLPItem memory rlpItem)
        internal
        pure
        returns (uint8)
    {
        uint256 v = Lib_RLPReader.readUint256(rlpItem);

        if (txType == 0) {
            v -= LibConstants.TAIKO_CHAIN_ID * 2 + 35;
        }

        return uint8(v) + 27;
    }
}
