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
                maxNumBlocks: 2049, // up to 2048 pending blocks
                blockHashHistory: 100000,
                // This number is calculated from maxNumBlocks to make
                // the 'the maximum value of the multiplier' close to 20.0
                zkProofsPerBlock: 1,
                maxVerificationsPerTx: 20,
                commitConfirmations: 0,
                maxProofsPerForkChoice: 5,
                blockMaxGasLimit: 5000000, // TODO
                maxTransactionsPerBlock: 20, // TODO
                maxBytesPerTxList: 10240, // TODO
                minTxGasLimit: 21000, // TODO
                anchorTxGasLimit: 250000,
                slotSmoothingFactor: 590000,
                rewardBurnBips: 100, // 100 basis points or 1%
                proposerDepositPctg: 25, // 25%
                // Moving average factors
                feeBaseMAF: 1024,
                blockTimeMAF: 1024,
                proofTimeMAF: 1024,
                rewardMultiplierPctg: 400, // 400%
                feeGracePeriodPctg: 125, // 125%
                feeMaxPeriodPctg: 375, // 375%
                blockTimeCap: 48 seconds,
                proofTimeCap: 60 minutes,
                bootstrapDiscountHalvingPeriod: 180 days,
                initialUncleDelay: 60 minutes,
                enableTokenomics: false,
                enablePublicInputsCheck: true,
                enableProofValidation: false,
                enableOracleProver: true
            });
    }
}
