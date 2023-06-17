// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "../L1/TaikoData.sol";

library TaikoConfig {
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: 167,
            // Two weeks if avg block time is 10 seconds
            maxNumProposedBlocks: 120_960,
            blockRingBufferSize: 120_960 + 10,
            // Each time one more block is verified, there will be ~20k
            // more gas cost.
            maxVerificationsPerTx: 10,
            // Set it to 6M, since its the upper limit of the Alpha-2
            // testnet's circuits.
            blockMaxGasLimit: 6_000_000,
            blockFeeBaseGas: 20_000,
            // Set it to 79  (+1 TaikoL2.anchor transaction = 80),
            // and 80 is the upper limit of the Alpha-2 testnet's circuits.
            maxTransactionsPerBlock: 79,
            // Set it to 120KB, since 128KB is the upper size limit
            // of a geth transaction, so using 120KB for the proposed
            // transactions list calldata, 8K for the remaining tx fields.
            maxBytesPerTxList: 120_000,
            txListCacheExpiry: 0,
            proofCooldownPeriod: 30 minutes,
            systemProofCooldownPeriod: 15 minutes,
            ethDepositRingBufferSize: 1024,
            ethDepositMinCountPerBlock: 8,
            ethDepositMaxCountPerBlock: 32,
            ethDepositMaxAmount: 10_000 ether,
            ethDepositMinAmount: 1 ether,
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10,
            relaySignalRoot: false
        });
    }
}
