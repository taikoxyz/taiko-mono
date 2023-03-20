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
                maxNumBlocks: 2049, // owner:daniel. maxNumBlocks-1 is the max number of pending blocks.
                blockHashHistory: 40, // owner:daniel
                maxVerificationsPerTx: 10, //owner:david. Each time one more block is verified, there will be ~20k more gas cost.
                blockMaxGasLimit: 6000000, // owner:david. Set it to 6M, since its the upper limit of the Alpha-2 testnet's circuits.
                maxTransactionsPerBlock: 79, //  owner:david. Set it to 79  (+1 TaikoL2.anchor transaction = 80), and 80 is the upper limit of the Alpha-2 testnet's circuits.
                maxBytesPerTxList: 120000, // owner:david. Set it to 120KB, since 128KB is the upper size limit of a geth transaction, so using 120KB for the proposed transactions list calldata, 8K for the remaining tx fields.
                minTxGasLimit: 21000, // owner:david
                slotSmoothingFactor: 946649, // owner:daniel
                anchorTxGasLimit: 180000, // owner: david
                rewardBurnBips: 100, // owner:daniel. 100 basis points or 1%
                proposerDepositPctg: 25, // owner:daniel - 25%
                // Moving average factors
                feeBaseMAF: 1024,
                bootstrapDiscountHalvingPeriod: 30 days, // owner:daniel
                constantFeeRewardBlocks: 1024, // owner:daniel
                snapshotInterval: 2000,
                enableSoloProposer: true,
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
