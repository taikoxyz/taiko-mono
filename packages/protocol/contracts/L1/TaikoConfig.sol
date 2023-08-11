// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "../L1/TaikoData.sol";

/**
 * @title TaikoConfig - Library for retrieving Taiko configuration parameters
 * @notice This library provides functions to access various configuration
 * parameters used in Taiko contracts.
 */
library TaikoConfig {
    /**
     * @dev Retrieves the Taiko configuration parameters.
     * @return config The Taiko configuration object containing various
     * configuration values.
     */
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return TaikoData.Config({
            // Group 1: General Configurations
            // The chain ID of the network where Taiko contracts are deployed.
            chainId: 167_006,
            // Flag indicating whether the relay signal root is enabled or not.
            relaySignalRoot: false,
            // --------------------------------------------------------
            // Group 2: Block-Level Configurations
            // The maximum number of proposals allowed in a single block.
            blockMaxProposals: 403_200,
            // The size of the block ring buffer, allowing extra space for
            // proposals.
            blockRingBufferSize: 403_210,
            // The maximum number of verifications allowed per transaction in a
            // block.
            blockMaxVerificationsPerTx: 10,
            // The maximum gas limit allowed per block.
            blockMaxGasLimit: 6_000_000,
            // The base gas for processing a block.
            blockFeeBaseGas: 20_000,
            // The maximum number of transactions allowed in a single block.
            blockMaxTransactions: 79,
            // The maximum allowed bytes for the proposed transaction list
            // calldata.
            blockMaxTxListBytes: 120_000,
            // The expiration time for the block transaction list.
            blockTxListExpiry: 0,
            // --------------------------------------------------------
            // Group 3: Proof-Related Configurations
            // The cooldown period for regular proofs (in minutes).
            proofRegularCooldown: 30 minutes,
            // The cooldown period for oracle proofs (in minutes).
            proofOracleCooldown: 15 minutes,
            // The minimum time window allowed for a proof submission (in
            // minutes).
            proofMinWindow: 10 minutes,
            // The maximum time window allowed for a proof submission (in
            // minutes).
            proofMaxWindow: 90 minutes,
            // The window multiplier used to calculate proof time windows (in
            // percentage).
            proofWindowMultiplier: 200, // 200%
            // --------------------------------------------------------
            // Group 4: Ethereum Deposit Related Configurations
            // The size of the Ethereum deposit ring buffer.
            ethDepositRingBufferSize: 1024,
            // The minimum number of Ethereum deposits allowed per block.
            ethDepositMinCountPerBlock: 8,
            // The maximum number of Ethereum deposits allowed per block.
            ethDepositMaxCountPerBlock: 32,
            // The minimum amount of Ethereum required for a deposit.
            ethDepositMinAmount: 1 ether,
            // The maximum amount of Ethereum allowed for a deposit.
            ethDepositMaxAmount: 10_000 ether,
            // The gas cost for processing an Ethereum deposit.
            ethDepositGas: 21_000,
            // The maximum fee allowed for an Ethereum deposit.
            ethDepositMaxFee: 1 ether / 10,
            // --------------------------------------------------------
            // Group 5: Tokenomics
            // The multiplier for calculating rewards for an open proposal (in
            // percentage).
            rewardOpenMultipler: 150, // 150%
            // The maximum count of open proposals considered for rewards
            // calculation.
            rewardOpenMaxCount: 201_600, // blockMaxProposals / 2,
            // The maximum penalty for delaying rewards (in basis points).
            rewardMaxDelayPenalty: 250 // 250 bps
         });
    }
}
