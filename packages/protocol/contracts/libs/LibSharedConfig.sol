// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../L1/TaikoData.sol";

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
initialUncleDelay: 10 minutes
maxNumBlocks: 61
zkProofsPerBlock: 1
slotSmoothingFactor: 16789
*/

library LibSharedConfig {
    /// Returns shared configs for both TaikoL1 and TaikoL2 for production.
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return
            TaikoData.Config({
                chainId: 167,
                maxNumBlocks: 61, // owner:daniel
                blockHashHistory: 40, // owner:daniel
                zkProofsPerBlock: 1, // owner:daniel
                maxVerificationsPerTx: 10, //owner:david. Each time one more block is verified, there will be ~20k more gas cost
                commitConfirmations: 0, // owner:daniel
                maxProofsPerForkChoice: 3, // owner:daniel
                blockMaxGasLimit: 5000000, // owner:david
                maxTransactionsPerBlock: 79, //  owner:david
                maxBytesPerTxList: 120000, // owner:david
                minTxGasLimit: 21000, // owner:david
                anchorTxGasLimit: 250000, // owner:david
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
                blockTimeCap: 60 seconds, // owner:daniel
                proofTimeCap: 30 minutes, // owner:daniel
                bootstrapDiscountHalvingPeriod: 30 days, // owner:daniel
                initialUncleDelay: 10 minutes,
                enableTokenomics: true,
                enablePublicInputsCheck: true,
                enableProofValidation: true,
                enableOracleProver: true
            });
    }
}
