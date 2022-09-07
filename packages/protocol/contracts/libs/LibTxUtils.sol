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
import "../thirdparty/Lib_BytesUtils.sol";
import "../thirdparty/Lib_RLPReader.sol";
import "../thirdparty/Lib_RLPWriter.sol";

library LibTxUtils {
    function hashUnsignedTx(LibTxDecoder.Tx memory transaction)
        internal
        pure
        returns (
            // transaction hash (without singature values)
            bytes32 hash
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

        hash = keccak256(unsignedTxRlp);
    }

    function recoverSender(LibTxDecoder.Tx memory transaction)
        internal
        pure
        returns (address)
    {
        return
            ecrecover(
                hashUnsignedTx(transaction),
                transaction.v + 27,
                bytes32(transaction.r),
                bytes32(transaction.s)
            );
    }
}
