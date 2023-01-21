// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../thirdparty/LibBlockHeaderDecoder.sol";

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
            LibBlockHeaderDecoder.decodeBlockHeader(
                blockHeader,
                blockHash,
                postEIP1559
            );
    }
}
