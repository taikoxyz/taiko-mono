// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Proxied } from "../common/Proxied.sol";
import { TaikoData } from "./TaikoData.sol";
import { TaikoL1Base } from "./TaikoL1Base.sol";

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
            blockMaxGasLimit: 6_000_000,
            blockFeeBaseGas: 20_000,
            blockMaxTxListBytes: 120_000,
            blockTxListExpiry: 0,
            proposerRewardPerSecond: 25e16, // 0.25 Taiko token
            proposerRewardMax: 32e18, // 32 Taiko token
            proofRegularCooldown: 30 minutes,
            proofOracleCooldown: 15 minutes,
            proofWindow: 90 minutes,
            proofBond: 1024e18,
            skipProverAssignmentVerificaiton: false,
            feeTokenIsEther: true,
            feeTokenDepositRingBufferSize: 1024,
            feeTokenDepositMinCountPerBlock: 8,
            feeTokenDepositMaxCountPerBlock: 32,
            feeTokenDepositMinAmount: 1 ether,
            feeTokenDepositMaxAmount: 10_000 ether,
            feeTokenDepositGas: 21_000,
            feeTokenDepositMaxFee: 1 ether / 10
        });
    }
}

/// @title TaikoL1
/// @notice Proxied version of the parent contract.
contract ProxiedTaikoL1 is Proxied, TaikoL1 { }
