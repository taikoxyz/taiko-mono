// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "../L1/TaikoData.sol";

/// @title TaikoConfig
/// @notice This library provides functions to access various configuration
/// parameters used in Taiko contracts.
library TaikoConfig {
    /// @dev See {TaikoData.Config} for explanations of each parameter.
    /// @return config The Taiko configuration object containing various
    /// configuration values.
    function getConfig() internal pure returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: 167_006,
            relaySignalRoot: false,
            blockMaxProposals: 403_200,
            blockRingBufferSize: 403_210,
            // This number is calculated from blockMaxProposals to make the
            // maximum value of the multiplier close to 20.0
            blockMaxVerificationsPerTx: 10,
            blockMaxGasLimit: 6_000_000,
            blockFeeBaseGas: 20_000,
            blockMaxTransactions: 79,
            blockMaxTxListBytes: 120_000,
            blockTxListExpiry: 0,
            proofRegularCooldown: 30 minutes,
            proofOracleCooldown: 15 minutes,
            proofMinWindow: 10 minutes,
            proofMaxWindow: 90 minutes,
            proofWindowMultiplier: 200, // 200%
            ethDepositRingBufferSize: 1024,
            ethDepositMinCountPerBlock: 8,
            ethDepositMaxCountPerBlock: 32,
            ethDepositMinAmount: 1 ether,
            ethDepositMaxAmount: 10_000 ether,
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10,
            rewardOpenMultipler: 150, // 150%
            rewardOpenMaxCount: 201_600, // blockMaxProposals / 2,
            rewardMaxDelayPenalty: 250 // 250 bps
         });
    }
}
