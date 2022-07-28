// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./LibTaikoConsts.sol";
struct TxList {
    bytes32 todo;
}

library LibTxList {
    function decodeTxList(bytes calldata encoded)
        public
        pure
        returns (TxList memory txList)
    {
        // throw exception if failed
    }

    function sumGasLimit(TxList memory txList) internal pure returns (uint256) {
        // TODO
    }
}

library LibTxListValidator {
    function isTxListValid(bytes calldata encoded)
        internal
        pure
        returns (bool)
    {
        try LibTxList.decodeTxList(encoded) returns (TxList memory txList) {
            // TODO: check list length
            return
                LibTxList.sumGasLimit(txList) <=
                LibTaikoConsts.MAX_TAIKO_BLOCK_GAS_LIMIT;
        } catch (bytes memory) {
            return false;
        }
    }
}
