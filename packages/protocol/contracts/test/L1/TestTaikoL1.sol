// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoL1 } from "../../L1/TaikoL1.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract TestTaikoL1 is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config.chainId = 167;
        // up to 2048 pending blocks
        config.blockMaxProposals = 4;
        config.blockRingBufferSize = 6;
        // This number is calculated from blockMaxProposals to make
        // the 'the maximum value of the multiplier' close to 20.0
        config.blockMaxVerificationsPerTx = 0;
        config.blockMaxGasUsed = 30_000_000;
        config.blockMaxTransactions = 20;
        config.blockMaxTxListBytes = 120_000;
    }
}
