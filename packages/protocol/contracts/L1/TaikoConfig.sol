// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {TaikoData} from "../L1/TaikoData.sol";

library TaikoConfig {
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return
            TaikoData.Config({
                chainId: 167,
                // maxNumBlocks-1 is the max number of pending blocks.
                maxNumBlocks: 2049,
                blockHashHistory: 2048,
                //Each time one more block is verified, there will be ~20k
                // more gas cost.
                maxVerificationsPerTx: 10,
                // Set it to 6M, since its the upper limit of the Alpha-2
                // testnet's circuits.
                blockMaxGasLimit: 6000000,
                //   Set it to 79  (+1 TaikoL2.anchor transaction = 80),
                // and 80 is the upper limit of the Alpha-2 testnet's circuits.
                maxTransactionsPerBlock: 79,
                // Set it to 120KB, since 128KB is the upper size limit
                // of a geth transaction, so using 120KB for the proposed
                // transactions list calldata, 8K for the remaining tx fields.
                maxBytesPerTxList: 120000,
                minTxGasLimit: 21000,
                slotSmoothingFactor: 946649,
                anchorTxGasLimit: 180000,
                // 100 basis points or 1%
                rewardBurnBips: 100,
                proposerDepositPctg: 25, // - 25%
                // Moving average factors
                feeBaseMAF: 1024,
                bootstrapDiscountHalvingPeriod: 1 seconds, // owner:daniel
                constantFeeRewardBlocks: 1024,
                txListCacheExpiry: 0,
                enableSoloProposer: false,
                enableOracleProver: true,
                enableTokenomics: true,
                skipZKPVerification: false,
                proposingConfig: TaikoData.FeeConfig({
                    avgTimeMAF: 1024,
                    avgTimeCap: 60 seconds * 1000,
                    gracePeriodPctg: 200,
                    maxPeriodPctg: 400,
                    multiplerPctg: 300
                }),
                provingConfig: TaikoData.FeeConfig({
                    avgTimeMAF: 1024,
                    avgTimeCap: 30 minutes * 1000,
                    gracePeriodPctg: 200,
                    maxPeriodPctg: 400,
                    multiplerPctg: 300
                })
            });
    }
}
