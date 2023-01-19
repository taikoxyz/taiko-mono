// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../L1/TaikoData.sol";

library LibSharedConfig {
    /// Returns shared configs for both TaikoL1 and TaikoL2 for production.
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return
            TaikoData.Config({
                chainId: 167,
                // Assuming proof time 1 hour, block time 10 seconds
                // Level of parallelization is 60*60/10 = 360
                // We give it extra 50% more slots, then we have 360*1.5+1=
                maxNumBlocks: 541,
                // Changed it to a smaller value
                // Assuming block time 10 seconds, we support cross-chain tx
                // to have 1 confirmation within 600 seconds (10 minutes).
                // Then we have: 600/10 = 60.
                blockHashHistory: 60,
                zkProofsPerBlock: 1,
                maxVerificationsPerTx: 20,
                commitConfirmations: 0,
                maxProofsPerForkChoice: 3,
                blockMaxGasLimit: 5000000, // TODO
                maxTransactionsPerBlock: 200, // TODO
                maxBytesPerTxList: 1500000, // TODO(david): verify this
                minTxGasLimit: 21000, // TODO(david): verify this
                anchorTxGasLimit: 250000,
                feePremiumLamda: 590, // TODO(daniel): how is this calculated
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
                proofTimeCap: 90 minutes,
                bootstrapDiscountHalvingPeriod: 180 days,
                initialUncleDelay: 60 minutes,
                enableTokenomics: false,
                enablePublicInputsCheck: true
            });
    }
}
