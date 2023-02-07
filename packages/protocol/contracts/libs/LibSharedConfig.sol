// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../L1/TaikoData.sol";

library LibSharedConfig {
    /// Returns shared configs for both TaikoL1 and TaikoL2 for production.
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return
            TaikoData.Config({
                chainId: 167,
                // Assuming proof time 1 hour, block time 15 seconds
                // Level of parallelization is 60*60/15 = 240
                // We give it extra 50% more slots, then we have 240*1.5+1=
                maxNumBlocks: 361, // owner:daniel
                // Changed it to a smaller value
                // Assuming block time 15 seconds, we support cross-chain tx
                // to have 1 confirmation within 600 seconds (10 minutes).
                // Then we have: 600/15 = 40.
                blockHashHistory: 40, // owner:daniel
                zkProofsPerBlock: 1, // owner:daniel
                maxVerificationsPerTx: 20, //owner:david - TODO: what's the actual tx gas cost?
                commitConfirmations: 0, // owner:daniel
                maxProofsPerForkChoice: 3, // owner:daniel
                blockMaxGasLimit: 5000000, // owner:david - TODO: do we need to change this?
                maxTransactionsPerBlock: 200, //  owner:david - TODO: do we need to change this?
                maxBytesPerTxList: 1500000, // owner:david - TODO: do we need to change this?
                minTxGasLimit: 21000, // owner:david
                anchorTxGasLimit: 250000, // owner:david
                // TODO(daniel): How is feePremiumLamda calculated.
                slotSmoothingFactor: 59000, // owner:daniel
                rewardBurnBips: 100, // owner:daniel. 100 basis points or 1%
                proposerDepositPctg: 25, // owner:daniel - 25%
                // Moving average factors
                feeBaseMAF: 1024,
                blockTimeMAF: 1024,
                proofTimeMAF: 1024,
                rewardMultiplierPctg: 400, //  owner:daniel - 400%
                feeGracePeriodPctg: 200, // owner:daniel - 200%
                feeMaxPeriodPctg: 400, // owner:daniel - 400%
                blockTimeCap: 60 seconds, // owner:daniel - target block time 15 seconds
                proofTimeCap: 90 minutes,
                bootstrapDiscountHalvingPeriod: 30 days, // owner:daniel
                initialUncleDelay: 60 minutes,
                enableTokenomics: false,
                enablePublicInputsCheck: true,
                enableProofValidation: false,
                enableOracleProver: true
            });
    }
}
