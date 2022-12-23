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

library LibConfig {
    function getConfigs() public pure returns (LibData.Config memory config) {
        config.K_CHAIN_ID = 167;
        // up to 2048 pending blocks
        config.K_MAX_NUM_BLOCKS = 2049;
        // This number is calculated from K_MAX_NUM_BLOCKS to make
        // the 'the maximum value of the multiplier' close to 20.0
        config.K_ZKPROOFS_PER_BLOCK = 1;
        config.K_MAX_VERIFICATIONS_PER_TX = 20;
        config.K_COMMIT_DELAY_CONFIRMS = 0;
        config.K_MAX_PROOFS_PER_FORK_CHOICE = 5;
        config.K_BLOCK_MAX_GAS_LIMIT = 5000000; // TODO
        config.K_BLOCK_MAX_TXS = 20; // TODO
        config.K_TXLIST_MAX_BYTES = 10240; // TODO
        config.K_TX_MIN_GAS_LIMIT = 21000; // TODO
        config.K_ANCHOR_TX_GAS_LIMIT = 250000;
        config.K_FEE_PREMIUM_LAMDA = 590;
        config.K_REWARD_BURN_BP = 100; // 100 basis points or 1%
        config.K_PROPOSER_DEPOSIT_PCTG = 25; // 25%

        // Moving average factors
        config.K_FEE_BASE_MAF = 1024;
        config.K_BLOCK_TIME_MAF = 1024;
        config.K_PROOF_TIME_MAF = 1024;

        config.K_REWARD_MULTIPLIER_PCTG = 400; // 400%
        config.K_FEE_GRACE_PERIOD_PCTG = 125; // 125%
        config.K_FEE_MAX_PERIOD_PCTG = 375; // 375%
        config.K_BLOCK_TIME_CAP = 48 seconds;
        config.K_PROOF_TIME_CAP = 60 minutes;
        config.K_HALVING = 180 days;
        config.K_INITIAL_UNCLE_DELAY = 60 minutes;

        config.K_ENABLE_TOKENOMICS = true;
    }
}
