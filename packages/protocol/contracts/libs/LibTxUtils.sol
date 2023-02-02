// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../libs/LibTxDecoder.sol";
import "../thirdparty/LibBytesUtils.sol";
import "../thirdparty/LibRLPReader.sol";
import "../thirdparty/LibRLPWriter.sol";

/// @author david <david@taiko.xyz>
library LibTxUtils {
    error ErrTxUtilsInvalidRLPItemsLength(uint expectedLength);
    error ErrTxUtilsInvalidTxtype();

    function hashUnsignedTx(
        uint256 chainId,
        LibTxDecoder.Tx memory transaction
    )
        internal
        pure
        returns (
            // transaction hash (without singature values)
            bytes32 hash
        )
    {
        LibRLPReader.RLPItem[] memory txRLPItems;
        if (transaction.txType == 0) {
            // Legacy transactions do not have the EIP-2718 type prefix.
            txRLPItems = LibRLPReader.readList(transaction.txData);
        } else {
            txRLPItems = LibRLPReader.readList(
                LibBytesUtils.slice(transaction.txData, 1)
            );
        }

        if (transaction.txType == 0) {
            // Legacy transactions
            if (txRLPItems.length != 9)
                revert ErrTxUtilsInvalidRLPItemsLength(9);
        } else if (transaction.txType == 1) {
            // EIP-2930 transactions
            if (txRLPItems.length != 11)
                revert ErrTxUtilsInvalidRLPItemsLength(11);
        } else if (transaction.txType == 2) {
            // EIP-1559 transactions
            if (txRLPItems.length != 12)
                revert ErrTxUtilsInvalidRLPItemsLength(12);
        } else {
            revert ErrTxUtilsInvalidTxtype();
        }

        // Signature values are always last three RLP items for all kinds of
        // transactions.
        bytes[] memory list = new bytes[](
            transaction.txType == 0 ? txRLPItems.length : txRLPItems.length - 3
        );

        for (uint256 i = 0; i < list.length; ++i) {
            // For Non-legacy transactions, accessList is always the
            // fourth to last item.
            if (transaction.txType != 0 && i == list.length - 1) {
                list[i] = LibRLPReader.readRawBytes(txRLPItems[i]);
                continue;
            }

            list[i] = LibRLPWriter.writeBytes(
                LibRLPReader.readBytes(txRLPItems[i])
            );

            // For legacy transactions, there are three more RLP items to
            // encode defined in EIP-155.
            if (transaction.txType == 0 && i == list.length - 4) {
                list[i + 1] = LibRLPWriter.writeUint(chainId);
                list[i + 2] = LibRLPWriter.writeUint64(0);
                list[i + 3] = LibRLPWriter.writeUint64(0);
                break;
            }
        }

        bytes memory unsignedTxRlp = LibRLPWriter.writeList(list);

        // Add the EIP-2718 type prefix for non-legacy transactions.
        if (transaction.txType != 0) {
            unsignedTxRlp = bytes.concat(
                bytes1(transaction.txType),
                unsignedTxRlp
            );
        }

        hash = keccak256(unsignedTxRlp);
    }

    function recoverSender(
        uint256 chainId,
        LibTxDecoder.Tx memory transaction
    ) internal pure returns (address) {
        return
            ecrecover(
                hashUnsignedTx(chainId, transaction),
                transaction.v + 27,
                bytes32(transaction.r),
                bytes32(transaction.s)
            );
    }
}
