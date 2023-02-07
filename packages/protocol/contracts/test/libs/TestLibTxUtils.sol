// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../libs/LibTxUtils.sol";

contract TestLibTxUtils {
    function hashUnsignedTx(
        uint256 chainId,
        LibTxDecoder.Tx memory transaction
    ) public pure returns (bytes32 hash) {
        return LibTxUtils.hashUnsignedTx(chainId, transaction);
    }

    function recoverSender(
        uint256 chainId,
        LibTxDecoder.Tx memory transaction
    ) public pure returns (address) {
        return LibTxUtils.recoverSender(chainId, transaction);
    }
}
