// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../thirdparty/Lib_BlockHeaderDecoder.sol";

contract TestLibBlockHeaderDecoder {
    function decodeBlockHeader(
        bytes calldata blockHeader,
        bytes32 blockHash,
        bool postEIP1559
    )
        public
        pure
        returns (
            bytes32 _stateRoot,
            uint256 _timestamp,
            bytes32 _transactionsRoot,
            bytes32 _receiptsRoot
        )
    {
        return
            Lib_BlockHeaderDecoder.decodeBlockHeader(
                blockHeader,
                blockHash,
                postEIP1559
            );
    }
}
