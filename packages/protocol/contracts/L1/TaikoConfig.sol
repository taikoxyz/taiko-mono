// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {TaikoData} from "../L1/TaikoData.sol";

/*
> cd taiko-mono/packages/protocol/utils/generate_config
> python3 main.py
Expected block time (seconds): 20
Expected proof time (minutes): 10
Slot availability multiplier: 20
Number of ZKPs required per block before verificaiton: 1
Extra slots (e.g, 50 means 50% more slots): 100
---------
min num slots: 30
---------
maxNumBlocks: 61
slotSmoothingFactor: 16789
*/

library TaikoConfig {
    /// Returns shared configs for both TaikoL1 and TaikoL2 for production.
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
                anchorTxGasLimit: 260000, // owner:david
                slotSmoothingFactor: 16789, // owner:daniel
                rewardBurnBips: 100, // owner:daniel. 100 basis points or 1%
                proposerDepositPctg: 25, // owner:daniel - 25%
                // Moving average factors
                feeBaseMAF: 1024,
                blockTimeMAF: 1024,
                proofTimeMAF: 1024,
                rewardMultiplierPctg: 400, //  owner:daniel - 400%
                feeGracePeriodPctg: 200, // owner:daniel - 200%
                feeMaxPeriodPctg: 400, // owner:daniel - 400%
                blockTimeCap: 60 seconds * 1000, // owner:daniel
                proofTimeCap: 30 minutes * 1000, // owner:daniel
                bootstrapDiscountHalvingPeriod: 30 days, // owner:daniel
                constantFeeRewardBlocks: 1024, // owner:daniel
                enableSoloProposer: true,
                enableOracleProver: true,
                enableTokenomics: true,
                skipZKPVerification: false
            });
    }
}
