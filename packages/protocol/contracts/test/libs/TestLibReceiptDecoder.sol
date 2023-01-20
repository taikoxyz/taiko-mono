// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../libs/LibReceiptDecoder.sol";

contract TestLibReceiptDecoder {
    event TestLibReceiptDecoderEvent(uint256 indexed a, bytes32 b);

    function emitTestEvent(uint256 a, bytes32 b) public {
        emit TestLibReceiptDecoderEvent(a, b);
    }

    function decodeReceipt(
        bytes calldata encoded
    ) public pure returns (LibReceiptDecoder.Receipt memory receipt) {
        return LibReceiptDecoder.decodeReceipt(encoded);
    }
}
