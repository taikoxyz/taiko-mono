// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {TaikoL1} from "../../L1/TaikoL1.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract TestTaikoL1 is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config.chainId = 167;
        // up to 2048 pending blocks
        config.maxNumProposedBlocks = 4;
        config.ringBufferSize = 6;
        // This number is calculated from maxNumProposedBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        config.maxVerificationsPerTx = 0;
        config.blockMaxGasLimit = 30000000;
        config.maxTransactionsPerBlock = 20;
        config.maxBytesPerTxList = 120000;
        config.minTxGasLimit = 21000;
    }
}
