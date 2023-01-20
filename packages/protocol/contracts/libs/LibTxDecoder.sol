// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../thirdparty/LibBytesUtils.sol";
import "../thirdparty/LibRLPReader.sol";

/// @author david <david@taiko.xyz>
library LibTxDecoder {
    struct TransactionLegacy {
        uint256 nonce;
        uint256 gasPrice;
        uint256 gasLimit;
        address destination;
        uint256 amount;
        bytes data;
        uint8 v;
        uint256 r;
        uint256 s;
    }

    struct Transaction2930 {
        uint256 chainId;
        uint256 nonce;
        uint256 gasPrice;
        uint256 gasLimit;
        address destination;
        uint256 amount;
        bytes data;
        AccessItem[] accessList;
        uint8 signatureYParity;
        uint256 signatureR;
        uint256 signatureS;
    }

    struct Transaction1559 {
        uint256 chainId;
        uint256 nonce;
        uint256 maxPriorityFeePerGas;
        uint256 maxFeePerGas;
        uint256 gasLimit;
        address destination;
        uint256 amount;
        bytes data;
        AccessItem[] accessList;
        uint8 signatureYParity;
        uint256 signatureR;
        uint256 signatureS;
    }

    struct AccessItem {
        address addr;
        bytes32[] slots;
    }

    struct Tx {
        uint8 txType;
        address destination;
        bytes data;
        uint256 gasLimit;
        uint8 v;
        uint256 r;
        uint256 s;
        bytes txData;
    }

    struct TxList {
        Tx[] items;
    }

    function decodeTxList(
        uint256 chainId,
        bytes calldata encoded
    ) public pure returns (TxList memory txList) {
        if (encoded.length == 0) {
            return txList;
        }
        LibRLPReader.RLPItem[] memory txs = LibRLPReader.readList(encoded);

        Tx[] memory _txList = new Tx[](txs.length);
        for (uint256 i = 0; i < txs.length; ++i) {
            _txList[i] = decodeTx(chainId, LibRLPReader.readBytes(txs[i]));
        }

        txList = TxList(_txList);
    }

    function decodeTx(
        uint256 chainId,
        bytes memory txBytes
    ) public pure returns (Tx memory _tx) {
        uint8 txType;
        assembly {
            txType := byte(0, mload(add(txBytes, 32)))
        }

        _tx.txData = txBytes;

        // @see https://eips.ethereum.org/EIPS/eip-2718#backwards-compatibility
        if (txType >= 0xc0 && txType <= 0xfe) {
            // Legacy tx:
            _tx.txType = 0;
            LibRLPReader.RLPItem[] memory txBody = LibRLPReader.readList(
                txBytes
            );
            TransactionLegacy memory txLegacy = decodeLegacyTx(chainId, txBody);
            _tx.gasLimit = txLegacy.gasLimit;
            _tx.destination = txLegacy.destination;
            _tx.v = txLegacy.v;
            _tx.r = txLegacy.r;
            _tx.s = txLegacy.s;
            _tx.data = txLegacy.data;
        } else if (txType <= 0x7f) {
            _tx.txType = txType;
            LibRLPReader.RLPItem[] memory txBody = LibRLPReader.readList(
                LibBytesUtils.slice(txBytes, 1)
            );

            if (txType == 1) {
                Transaction2930 memory tx2930 = decodeTx2930(txBody);
                _tx.gasLimit = tx2930.gasLimit;
                _tx.destination = tx2930.destination;
                _tx.v = tx2930.signatureYParity;
                _tx.r = tx2930.signatureR;
                _tx.s = tx2930.signatureS;
                _tx.data = tx2930.data;
            } else if (_tx.txType == 2) {
                Transaction1559 memory tx1559 = decodeTx1559(txBody);
                _tx.gasLimit = tx1559.gasLimit;
                _tx.destination = tx1559.destination;
                _tx.v = tx1559.signatureYParity;
                _tx.r = tx1559.signatureR;
                _tx.s = tx1559.signatureS;
                _tx.data = tx1559.data;
            } else {
                revert("invalid txType");
            }
        } else {
            revert("invalid prefix");
        }
    }

    function hashTxList(
        bytes calldata encoded
    ) internal pure returns (bytes32) {
        return keccak256(encoded);
    }

    function decodeLegacyTx(
        uint256 chainId,
        LibRLPReader.RLPItem[] memory body
    ) internal pure returns (TransactionLegacy memory txLegacy) {
        require(body.length == 9, "invalid items length");

        txLegacy.nonce = LibRLPReader.readUint256(body[0]);
        txLegacy.gasPrice = LibRLPReader.readUint256(body[1]);
        txLegacy.gasLimit = LibRLPReader.readUint256(body[2]);
        txLegacy.destination = LibRLPReader.readAddress(body[3]);
        txLegacy.amount = LibRLPReader.readUint256(body[4]);
        txLegacy.data = LibRLPReader.readBytes(body[5]);
        // EIP-155 is enabled on L2
        txLegacy.v = uint8(
            LibRLPReader.readUint256(body[6]) - chainId * 2 + 35
        );
        txLegacy.r = LibRLPReader.readUint256(body[7]);
        txLegacy.s = LibRLPReader.readUint256(body[8]);
    }

    function decodeTx2930(
        LibRLPReader.RLPItem[] memory body
    ) internal pure returns (Transaction2930 memory tx2930) {
        require(body.length == 11, "invalid items length");

        tx2930.chainId = LibRLPReader.readUint256(body[0]);
        tx2930.nonce = LibRLPReader.readUint256(body[1]);
        tx2930.gasPrice = LibRLPReader.readUint256(body[2]);
        tx2930.gasLimit = LibRLPReader.readUint256(body[3]);
        tx2930.destination = LibRLPReader.readAddress(body[4]);
        tx2930.amount = LibRLPReader.readUint256(body[5]);
        tx2930.data = LibRLPReader.readBytes(body[6]);
        tx2930.accessList = decodeAccessList(LibRLPReader.readList(body[7]));
        tx2930.signatureYParity = uint8(LibRLPReader.readUint256(body[8]));
        tx2930.signatureR = LibRLPReader.readUint256(body[9]);
        tx2930.signatureS = LibRLPReader.readUint256(body[10]);
    }

    function decodeTx1559(
        LibRLPReader.RLPItem[] memory body
    ) internal pure returns (Transaction1559 memory tx1559) {
        require(body.length == 12, "invalid items length");

        tx1559.chainId = LibRLPReader.readUint256(body[0]);
        tx1559.nonce = LibRLPReader.readUint256(body[1]);
        tx1559.maxPriorityFeePerGas = LibRLPReader.readUint256(body[2]);
        tx1559.maxFeePerGas = LibRLPReader.readUint256(body[3]);
        tx1559.gasLimit = LibRLPReader.readUint256(body[4]);
        tx1559.destination = LibRLPReader.readAddress(body[5]);
        tx1559.amount = LibRLPReader.readUint256(body[6]);
        tx1559.data = LibRLPReader.readBytes(body[7]);
        tx1559.accessList = decodeAccessList(LibRLPReader.readList(body[8]));
        tx1559.signatureYParity = uint8(LibRLPReader.readUint256(body[9]));
        tx1559.signatureR = LibRLPReader.readUint256(body[10]);
        tx1559.signatureS = LibRLPReader.readUint256(body[11]);
    }

    function decodeAccessList(
        LibRLPReader.RLPItem[] memory accessListRLP
    ) internal pure returns (AccessItem[] memory accessList) {
        accessList = new AccessItem[](accessListRLP.length);
        for (uint256 i = 0; i < accessListRLP.length; ++i) {
            LibRLPReader.RLPItem[] memory items = LibRLPReader.readList(
                accessListRLP[i]
            );
            address addr = LibRLPReader.readAddress(items[0]);
            LibRLPReader.RLPItem[] memory slotListRLP = LibRLPReader.readList(
                items[1]
            );
            bytes32[] memory slots = new bytes32[](slotListRLP.length);
            for (uint256 j = 0; j < slotListRLP.length; ++j) {
                slots[j] = LibRLPReader.readBytes32(slotListRLP[j]);
            }
            accessList[i] = AccessItem(addr, slots);
        }
    }

    function sumGasLimit(
        TxList memory txList
    ) internal pure returns (uint256 sum) {
        Tx[] memory items = txList.items;
        for (uint256 i = 0; i < items.length; ++i) {
            sum += items[i].gasLimit;
        }
    }
}
