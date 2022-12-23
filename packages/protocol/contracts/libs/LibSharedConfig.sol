// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../L1/LibData.sol";

library LibSharedConfig {
    /// Returns shared configs for both TaikoL1 and TaikoL2 for production.
    function getConfig() internal pure returns (LibData.Config memory config) {
        // up to 2048 pending blocks
        config.maxNumBlocks = 2049;
        // This number is calculated from maxNumBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        config.zkProofsPerBlock = 1;
        config.maxVerificationsPerTx = 20;
        config.commitConfirmations = 0;
        config.maxProofsPerForkChoice = 5;
        config.blockMaxGasLimit = 5000000; // TODO
        config.maxTransactionsPerBlock = 20; // TODO
        config.maxBytesPerTxList = 10240; // TODO
        config.minTxGasLimit = 21000; // TODO
        config.anchorTxGasLimit = 250000;
        config.feePremiumLamda = 590;
        config.rewardBurnBips = 100; // 100 basis points or 1%
        config.proposerDepositPctg = 25; // 25%

        // Moving average factors
        config.feeBaseMAF = 1024;
        config.blockTimeMAF = 1024;
        config.proofTimeMAF = 1024;

        config.rewardMultiplierPctg = 400; // 400%
        config.feeGracePeriodPctg = 125; // 125%
        config.feeMaxPeriodPctg = 375; // 375%
        config.blockTimeCap = 48 seconds;
        config.proofTimeCap = 60 minutes;
        config.boostrapDiscountHalvingPeriod = 180 days;
        config.initialUncleDelay = 60 minutes;
        config.enableTokenomics = true;
        config.skipProofValidation = false;
    }
}
