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
            // 1 block batch consist of 100 blocks, so divided block ring buffer
            // by 100
            // to be kind of in-sync, but it does not have to be fully in sync,
            // they are decoupled
            auctionRingBufferSize: 1209,
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
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10,
            txListCacheExpiry: 0,
            auctionWindow: 120,
            auctionProofWindowMultiplier: 2,
            auctionDepositMultipler: 10,
            auctionMaxFeePerGasMultipler: 5,
            auctonMaxAheadOfProposals: 10,
            auctionBatchSize: 100,
            auctionMaxProofWindow: 7200,
            relaySignalRoot: false
        });
    }
}
