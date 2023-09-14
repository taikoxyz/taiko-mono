// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Proxied } from "../common/Proxied.sol";
import { TaikoData } from "./TaikoData.sol";
import { TaikoL1Base } from "./TaikoL1Base.sol";
import { LibTransition } from "./libs/LibTransition.sol";

contract TaikoL1 is TaikoL1Base {
    function getConfig()
        public
        pure
        virtual
        override
        returns (TaikoData.Config memory)
    {
        return TaikoData.Config({
            chainId: 167_007,
            relaySignalRoot: false,
            blockMaxProposals: 403_200,
            blockRingBufferSize: 403_210,
            // This number is calculated from blockMaxProposals to make the
            // maximum value of the multiplier close to 20.0
            blockMaxVerificationsPerTx: 10,
            blockMaxGasLimit: 8_000_000,
            blockFeeBaseGas: 20_000,
            blockMaxTxListBytes: 120_000,
            blockTxListExpiry: 0,
            proposerRewardPerSecond: 25e16, // 0.25 Taiko token
            proposerRewardMax: 32e18, // 32 Taiko token
            proofRegularCooldown: 30 minutes,
            proofOracleCooldown: 15 minutes,
            proofWindow: 90 minutes,
            proverBondOp: 10_240e18,
            proverBondZk: 10_240e17,
            skipProverAssignmentVerificaiton: false,
            ethDepositRingBufferSize: 1024,
            ethDepositMinCountPerBlock: 8,
            ethDepositMaxCountPerBlock: 32,
            ethDepositMinAmount: 1 ether,
            ethDepositMaxAmount: 10_000 ether,
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10
        });
    }

    function getTierConfig()
        public
        pure
        virtual
        override
        returns (TaikoData.TierConfig memory tierConfig)
    {
        tierConfig.tierData[LibTransition.TIER_ID_NONE] = TaikoData.TierData({
            id : LibTransition.TIER_ID_NONE,
            proofRegularCooldown: 60 minutes,
            proofOracleCooldown: 30 minutes,
            proofWindow: 60 minutes,
            proverBond: 20_240e18,
            challengerBond: 25_240e18
        });

        tierConfig.tierData[LibTransition.TIER_ID_1] = TaikoData.TierData({
            id : LibTransition.TIER_ID_1,
            proofRegularCooldown: 60 minutes,
            proofOracleCooldown: 30 minutes,
            proofWindow: 60 minutes,
            proverBond: 15_240e18,
            challengerBond: 20_240e18
        });

        tierConfig.tierData[LibTransition.TIER_ID_2] = TaikoData.TierData({
            id : LibTransition.TIER_ID_2,
            proofRegularCooldown: 60 minutes,
            proofOracleCooldown: 30 minutes,
            proofWindow: 60 minutes,
            proverBond: 10_240e18,
            challengerBond: 15_240e18 // Still can challange, but then it goes to 'GUARDIAN' level
        });

        tierConfig.tierData[LibTransition.TIER_ID_GUARDIAN] = TaikoData.TierData({
            id : LibTransition.TIER_ID_GUARDIAN,
            proofRegularCooldown: 60 minutes,
            proofOracleCooldown: 30 minutes,
            proofWindow: 60 minutes,
            proverBond: 0,
            challengerBond: 0
        });

        tierConfig.maxId = LibTransition.TIER_ID_GUARDIAN;
    }
}

/// @title TaikoL1
/// @notice Proxied version of the parent contract.
contract ProxiedTaikoL1 is Proxied, TaikoL1 { }
