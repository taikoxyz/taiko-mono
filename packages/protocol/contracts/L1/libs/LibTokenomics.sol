// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {ChainData} from "../../common/IXchainSync.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";
import {TaikoToken} from "../TaikoToken.sol";

library LibTokenomics {
    using LibMath for uint256;
    uint256 private constant TWEI_TO_WEI = 1E12;

    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_PARAM();

    function withdraw(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    ) internal {
        uint256 balance = state.balances[msg.sender];
        if (balance <= amount) revert L1_INSUFFICIENT_TOKEN();

        unchecked {
            state.balances[msg.sender] -= amount;
        }

        TaikoToken(resolver.resolve("taiko_token", false)).mint(
            msg.sender,
            amount
        );
    }

    function deposit(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    ) internal {
        if (amount > 0) {
            TaikoToken(resolver.resolve("taiko_token", false)).burn(
                msg.sender,
                amount
            );
            state.balances[msg.sender] += amount;
        }
    }

    function fromTwei(uint64 amount) internal pure returns (uint256) {
        if (amount == 0) {
            return TWEI_TO_WEI;
        } else {
            return amount * TWEI_TO_WEI;
        }
    }

    function toTwei(uint256 amount) internal pure returns (uint64) {
        uint256 _twei = amount / TWEI_TO_WEI;
        if (_twei > type(uint64).max) {
            return type(uint64).max;
        } else if (_twei == 0) {
            return uint64(1);
        } else {
            return uint64(_twei);
        }
    }

    function getBlockFee(
        TaikoData.State storage state,
        TaikoData.Config memory config
    )
        internal
        view
        returns (uint256 newFeeBase, uint256 fee, uint256 depositAmount)
    {
        uint256 feeBase = fromTwei(state.feeBaseTwei);
        if (state.nextBlockId <= config.constantFeeRewardBlocks) {
            fee = feeBase;
            newFeeBase = feeBase;
        } else {
            (newFeeBase, ) = getTimeAdjustedFee({
                feeConfig: config.proposingConfig,
                feeBase: feeBase,
                isProposal: true,
                tNow: block.timestamp,
                tLast: state.lastProposedAt,
                tAvg: state.avgBlockTime
            });
            fee = getSlotsAdjustedFee({
                state: state,
                config: config,
                isProposal: true,
                feeBase: newFeeBase
            });
        }

        if (config.bootstrapDiscountHalvingPeriod > 0) {
            unchecked {
                uint256 halves = uint256(
                    block.timestamp - state.genesisTimestamp
                ) / config.bootstrapDiscountHalvingPeriod;
                uint256 gamma = 1024 - (1024 >> (1 + halves));
                fee = (fee * gamma) / 1024;
            }
        }

        unchecked {
            depositAmount = (fee * config.proposerDepositPctg) / 100;
        }
    }

    function getProofReward(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 provenAt,
        uint64 proposedAt
    )
        internal
        view
        returns (uint256 newFeeBase, uint256 reward, uint256 tRelBp)
    {
        if (proposedAt > provenAt) revert L1_INVALID_PARAM();

        uint256 feeBase = fromTwei(state.feeBaseTwei);
        if (state.lastBlockId <= config.constantFeeRewardBlocks) {
            reward = feeBase;
            newFeeBase = feeBase;
            // tRelBp = 0;
        } else {
            (newFeeBase, tRelBp) = getTimeAdjustedFee({
                feeConfig: config.provingConfig,
                feeBase: feeBase,
                isProposal: false,
                tNow: provenAt,
                tLast: proposedAt,
                tAvg: state.avgProofTime
            });
            reward = getSlotsAdjustedFee({
                state: state,
                config: config,
                isProposal: false,
                feeBase: newFeeBase
            });
        }
        unchecked {
            reward = (reward * (10000 - config.rewardBurnBips)) / 10000;
        }
    }

    // Implement "Slot-availability Multipliers", see the whitepaper.
    function getSlotsAdjustedFee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bool isProposal,
        uint256 feeBase
    ) internal view returns (uint256) {
        unchecked {
            // m is the `n'` in the whitepaper
            uint256 m = 1000 *
                (config.maxNumBlocks - 1) +
                config.slotSmoothingFactor;
            // n is the number of unverified blocks
            uint256 n = 1000 * (state.nextBlockId - state.lastBlockId - 1);
            // k is `m − n + 1` or `m − n - 1`in the whitepaper
            uint256 k = isProposal ? m - n - 1000 : m - n + 1000;
            return (feeBase * (m - 1000) * m) / (m - n) / k;
        }
    }

    // Implement "Incentive Multipliers", see the whitepaper.
    function getTimeAdjustedFee(
        TaikoData.FeeConfig memory feeConfig,
        uint256 feeBase,
        bool isProposal,
        uint256 tNow, // seconds
        uint256 tLast, // seconds
        uint256 tAvg // milliseconds
    ) internal pure returns (uint256 newFeeBase, uint256 tRelBp) {
        if (tAvg == 0 || tNow == tLast) {
            return (feeBase, 0);
        }

        unchecked {
            tAvg = tAvg.min(feeConfig.avgTimeCap);
            uint256 max = (feeConfig.maxPeriodPctg * tAvg) / 100;
            uint256 grace = (feeConfig.gracePeriodPctg * tAvg) / 100;
            uint256 t = ((tNow - tLast) * 1000).max(grace).min(max);
            tRelBp = (10000 * (t - grace)) / (max - grace); // [0-10000]
            uint256 alpha = 10000 + (tRelBp * feeConfig.multiplerPctg) / 100;

            if (isProposal) {
                newFeeBase = (feeBase * 10000) / alpha; // fee
            } else {
                newFeeBase = (feeBase * alpha) / 10000; // reward
            }
        }
    }
}
