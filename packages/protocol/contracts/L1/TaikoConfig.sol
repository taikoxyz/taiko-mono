// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { TaikoData } from "../L1/TaikoData.sol";

library TaikoConfig {
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: 167,
            // Two weeks if avg block time is 10 seconds
            maxNumProposedBlocks: 120_960,
            ringBufferSize: 120_960 + 10,
            // Each time one more block is verified, there will be ~20k
            // more gas cost.
            maxVerificationsPerTx: 10,
            // Set it to 6M, since its the upper limit of the Alpha-2
            // testnet's circuits.
            blockMaxGasLimit: 6_000_000,
            // Set it to 79  (+1 TaikoL2.anchor transaction = 80),
            // and 80 is the upper limit of the Alpha-2 testnet's circuits.
            maxTransactionsPerBlock: 79,
            minEthDepositsPerBlock: 8,
            maxEthDepositsPerBlock: 32,
            maxEthDepositAmount: 10_000 ether,
            minEthDepositAmount: 1 ether,
            // Set it to 120KB, since 128KB is the upper size limit
            // of a geth transaction, so using 120KB for the proposed
            // transactions list calldata, 8K for the remaining tx fields.
            maxBytesPerTxList: 120_000,
            proofCooldownPeriod: 30 minutes,
            systemProofCooldownPeriod: 15 minutes,
            // Only need 1 real zkp per 10 blocks.
            // If block number is N, then only when N % 10 == 0, the real ZKP
            // is needed. For mainnet, this must be 0 or 1.
            realProofSkipSize: 10,
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10,
            txListCacheExpiry: 0,
            auctionWindowInSec: 120,
            auctionBatchModulo: 5,
            auctionBatchSize: 100,
            auctionSmallestGasPerBlockBid: 1, // in wei
            bidDiffBp: 1000, // 10.000 BP = 100%
            relaySignalRoot: false
        });
    }
}
