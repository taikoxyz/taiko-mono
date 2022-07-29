// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./LibConstants.sol";
import "../thirdparty/Lib_RLPReader.sol";

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
    bool signatureYParity;
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
    bool signatureYParity;
    uint256 signatureR;
    uint256 signatureS;
}

struct AccessItem {
    address addr;
    bytes32[] slots;
}

struct Tx {
    uint8 txType;
    uint256 gasLimit;
    bytes txData;
}

struct TxList {
    Tx[] items;
}

library LibTxList {
    function decodeTxList(bytes calldata encoded)
        public
        pure
        returns (TxList memory txList)
    {
        Lib_RLPReader.RLPItem[] memory txs = Lib_RLPReader.readList(encoded);
        require(txs.length > 0, "empty txList");

        Tx[] memory _txList = new Tx[](txs.length);
        for (uint256 i = 0; i < txs.length; i++) {
            (uint8 txType, uint256 gasLimit, bytes memory txData) = decodeTx(
                txs[i]
            );
            _txList[i] = Tx(txType, gasLimit, txData);
        }

        txList = TxList(_txList);
    }

    function decodeTx(Lib_RLPReader.RLPItem memory txItem)
        public
        pure
        returns (
            uint8 txType,
            uint256 gasLimit,
            bytes memory txData
        )
    {
        txData = Lib_RLPReader.readRawBytes(txItem); // TODO readBytes? not sure, need some tests

        uint8 prefix;
        assembly {
            prefix := byte(0, mload(txData))
        }

        // @see https://eips.ethereum.org/EIPS/eip-2718#backwards-compatibility
        if (prefix >= 0xc0 && prefix <= 0xfe) {
            // Legacy tx:
            txType = 0;
            TransactionLegacy memory txLegacy = decodeLegacyTx(txItem);
            gasLimit = txLegacy.gasLimit;
        } else if (prefix <= 0x7f) {
            Lib_RLPReader.RLPItem[] memory typeAndTx = Lib_RLPReader.readList(
                txItem
            );
            require(typeAndTx.length == 2, "invalid newtype tx");
            txType = uint8(Lib_RLPReader.readUint256(typeAndTx[0]));

            if (txType == 1) {
                Transaction2930 memory tx2930 = decodeTx2930(typeAndTx[1]);
                gasLimit = tx2930.gasLimit;
            } else if (txType == 2) {
                Transaction1559 memory tx1559 = decodeTx1559(typeAndTx[1]);
                gasLimit = tx1559.gasLimit;
            } else {
                revert("invalid txType");
            }
        } else {
            revert("invalid prefix");
        }
    }

    function decodeLegacyTx(Lib_RLPReader.RLPItem memory txBody)
        public
        pure
        returns (TransactionLegacy memory txLegacy)
    {
        Lib_RLPReader.RLPItem[] memory body = Lib_RLPReader.readList(txBody);
        require(body.length == 9, "invalid items length");

        txLegacy.nonce = Lib_RLPReader.readUint256(body[0]);
        txLegacy.gasPrice = Lib_RLPReader.readUint256(body[1]);
        txLegacy.gasLimit = Lib_RLPReader.readUint256(body[2]);
        txLegacy.destination = Lib_RLPReader.readAddress(body[3]);
        txLegacy.amount = Lib_RLPReader.readUint256(body[4]);
        txLegacy.data = Lib_RLPReader.readBytes(body[5]);
        txLegacy.v = uint8(Lib_RLPReader.readUint256(body[6]));
        txLegacy.r = Lib_RLPReader.readUint256(body[7]);
        txLegacy.s = Lib_RLPReader.readUint256(body[8]);
    }

    function decodeTx2930(Lib_RLPReader.RLPItem memory txBody)
        public
        pure
        returns (Transaction2930 memory tx2930)
    {
        Lib_RLPReader.RLPItem[] memory body = Lib_RLPReader.readList(txBody);
        require(body.length == 11, "invalid items length");

        tx2930.chainId = Lib_RLPReader.readUint256(body[0]);
        tx2930.nonce = Lib_RLPReader.readUint256(body[1]);
        tx2930.gasPrice = Lib_RLPReader.readUint256(body[2]);
        tx2930.gasLimit = Lib_RLPReader.readUint256(body[3]);
        tx2930.destination = Lib_RLPReader.readAddress(body[4]);
        tx2930.amount = Lib_RLPReader.readUint256(body[5]);
        tx2930.data = Lib_RLPReader.readBytes(body[6]);
        tx2930.accessList = decodeAccessList(Lib_RLPReader.readList(body[7]));
        tx2930.signatureYParity = Lib_RLPReader.readBool(body[8]);
        tx2930.signatureR = Lib_RLPReader.readUint256(body[9]);
        tx2930.signatureS = Lib_RLPReader.readUint256(body[10]);
    }

    function decodeTx1559(Lib_RLPReader.RLPItem memory txBody)
        public
        pure
        returns (Transaction1559 memory tx1559)
    {
        Lib_RLPReader.RLPItem[] memory body = Lib_RLPReader.readList(txBody);
        require(body.length == 12, "invalid items length");

        tx1559.chainId = Lib_RLPReader.readUint256(body[0]);
        tx1559.nonce = Lib_RLPReader.readUint256(body[1]);
        tx1559.maxPriorityFeePerGas = Lib_RLPReader.readUint256(body[2]);
        tx1559.maxFeePerGas = Lib_RLPReader.readUint256(body[3]);
        tx1559.gasLimit = Lib_RLPReader.readUint256(body[4]);
        tx1559.destination = Lib_RLPReader.readAddress(body[5]);
        tx1559.amount = Lib_RLPReader.readUint256(body[6]);
        tx1559.data = Lib_RLPReader.readBytes(body[7]);
        tx1559.accessList = decodeAccessList(Lib_RLPReader.readList(body[8]));
        tx1559.signatureYParity = Lib_RLPReader.readBool(body[9]);
        tx1559.signatureR = Lib_RLPReader.readUint256(body[10]);
        tx1559.signatureS = Lib_RLPReader.readUint256(body[11]);
    }

    function decodeAccessList(Lib_RLPReader.RLPItem[] memory accessListRLP)
        public
        pure
        returns (AccessItem[] memory accessList)
    {
        accessList = new AccessItem[](accessListRLP.length);
        for (uint256 i = 0; i < accessListRLP.length; i++) {
            Lib_RLPReader.RLPItem[] memory items = Lib_RLPReader.readList(
                accessListRLP[i]
            );
            address addr = Lib_RLPReader.readAddress(items[0]);
            Lib_RLPReader.RLPItem[] memory slotListRLP = Lib_RLPReader.readList(
                items[1]
            );
            bytes32[] memory slots = new bytes32[](slotListRLP.length);
            for (uint256 j = 0; j < slotListRLP.length; j++) {
                slots[j] = Lib_RLPReader.readBytes32(slotListRLP[j]);
            }
            accessList[i] = AccessItem(addr, slots);
        }
    }

    function sumGasLimit(TxList memory txList)
        internal
        pure
        returns (uint256 sum)
    {
        Tx[] memory items = txList.items;
        for (uint256 i = 0; i < items.length; i++) {
            sum += items[i].gasLimit;
        }
    }
}

library LibTxListValidator {
    function isTxListValid(bytes calldata encoded)
        internal
        pure
        returns (bool)
    {
        try LibTxList.decodeTxList(encoded) returns (TxList memory txList) {
            return
                txList.items.length <= LibConstants.MAX_TAIKO_BLOCK_NUM_TXS &&
                LibTxList.sumGasLimit(txList) <=
                LibConstants.MAX_TAIKO_BLOCK_GAS_LIMIT;
        } catch (bytes memory) {
            return false;
        }
    }
}
