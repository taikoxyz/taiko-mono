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
                // Two weeks if avg block time is 10 seconds
                maxNumProposedBlocks: 120960,
                ringBufferSize: 120960 + 10,
                // Each time one more block is verified, there will be ~20k
                // more gas cost.
                maxVerificationsPerTx: 10,
                // Set it to 6M, since its the upper limit of the Alpha-2
                // testnet's circuits.
                blockMaxGasLimit: 6000000,
                // Set it to 79  (+1 TaikoL2.anchor transaction = 80),
                // and 80 is the upper limit of the Alpha-2 testnet's circuits.
                maxTransactionsPerBlock: 79,
                minEthDepositsPerBlock: 8,
                maxEthDepositsPerBlock: 32,
                maxEthDepositAmount: 10000 ether,
                minEthDepositAmount: 1 ether,
                // Set it to 120KB, since 128KB is the upper size limit
                // of a geth transaction, so using 120KB for the proposed
                // transactions list calldata, 8K for the remaining tx fields.
                maxBytesPerTxList: 120000,
                minTxGasLimit: 21000,
                proofCooldownPeriod: 5 minutes,
                txListCacheExpiry: 0,
                proofTimeTarget: 1800, // 85s based on A2 testnet status, or set to 1800 for 30mins (mainnet mock)
                adjustmentQuotient: 16,
                relaySignalRoot: false,
                enableSoloProposer: false
            });
    }
}
