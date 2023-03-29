// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";
import {TaikoToken} from "../TaikoToken.sol";
import {ABDKMath64x64} from "../../thirdparty/ABDKMath.sol";

library LibL1Tokenomics {
    using LibMath for uint256;

    uint256 constant SCALING_FACTOR = 1e8; // 10^8 for 8 decimal places = 1 TKO token

    // So floating point as is - in solidity is nonexitent. With exponential calculation
    // we loose a lot of value because we are restricted to integer. So the ABDKMath gives
    // us an int128 value which is a 64.64 fixed point decimal representation number of the
    // float value. In order to get back the floating point, this is the math:
    // floating_point_number = fixed_point_number / 2^64
    // But as mentioned we loose a lot on the .01-.99 range, so instead we shall calculate this
    // floating_point_number = fixed_point_number / 2^57 , meaning we get a 2^7 times bigger number
    // but on the other hand we have higher precision - and can divide the overall result.
    uint8 constant EXPONENTIAL_REWARD_FACTOR = 128;

    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_PARAM();
    error L1_NO_GAS();
    error L1_IMPOSSIBLE_CONVERSION();

    function withdraw(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    ) internal {
        uint256 balance = state.balances[msg.sender];
        if (balance < amount) revert L1_INSUFFICIENT_TOKEN();

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

    function getBlockFee(
        TaikoData.State storage state,
        TaikoData.Config memory config
    )
        internal
        view
        returns (uint64 newFeeBase, uint64 fee, uint64 depositAmount)
    {
        if (state.numBlocks <= config.constantFeeRewardBlocks) {
            fee = state.feeBase;
            newFeeBase = state.feeBase;
        } else {
            (newFeeBase, ) = getTimeAdjustedFee({
                feeConfig: config.proposingConfig,
                feeBase: state.feeBase,
                isProposal: true,
                timeUsed: block.timestamp - state.lastProposedAt,
                timeAverage: state.avgBlockTime
            });
            fee = getSlotsAdjustedFee({
                state: state,
                config: config,
                isProposal: true,
                feeBase: newFeeBase
            });
        }

        unchecked {
            depositAmount = uint64((fee * config.proposerDepositPctg) / 100);
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
        returns (uint64 newFeeBase, uint64 reward, uint64 premiumRate)
    {
        if (proposedAt > provenAt) revert L1_INVALID_PARAM();

        if (state.lastVerifiedBlockId <= config.constantFeeRewardBlocks) {
            reward = state.feeBase;
            newFeeBase = state.feeBase;
            // premiumRate = 0;
        } else {
            (newFeeBase, premiumRate) = getTimeAdjustedFee({
                feeConfig: config.provingConfig,
                feeBase: state.feeBase,
                isProposal: false,
                timeUsed: provenAt - proposedAt,
                timeAverage: state.avgProofTime
            });
            reward = getSlotsAdjustedFee({
                state: state,
                config: config,
                isProposal: false,
                feeBase: newFeeBase
            });
        }
        unchecked {
            reward = uint64((reward * (10000 - config.rewardBurnBips)) / 10000);
        }
    }

    // Implement "Slot-availability Multipliers", see the whitepaper.
    function getSlotsAdjustedFee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bool isProposal,
        uint64 feeBase
    ) internal view returns (uint64) {
        unchecked {
            // m is the `n'` in the whitepaper
            uint256 m = 1000 *
                config.maxNumProposedBlocks +
                config.slotSmoothingFactor;
            // n is the number of unverified blocks
            uint256 n = 1000 *
                (state.numBlocks - state.lastVerifiedBlockId - 1);
            // k is `m − n + 1` or `m − n - 1`in the whitepaper
            uint256 k = isProposal ? m - n - 1000 : m - n + 1000;
            return uint64((feeBase * (m - 1000) * m) / (m - n) / k);
        }
    }

    // Implement "Incentive Multipliers", see the whitepaper.
    function getTimeAdjustedFee(
        TaikoData.FeeConfig memory feeConfig,
        uint64 feeBase,
        bool isProposal,
        uint256 timeUsed, // seconds
        uint256 timeAverage // milliseconds
    ) internal pure returns (uint64 newFeeBase, uint64 premiumRate) {
        if (timeAverage == 0) {
            return (feeBase, 0);
        }
        unchecked {
            uint256 p = feeConfig.dampingFactorBips; // [0-10000]
            uint256 a = timeAverage;
            uint256 t = (timeUsed * 1000).min(a * 2); // millisconds

            newFeeBase = uint64((feeBase * (10000 + (t * p) / a - p)) / 10000);

            if (isProposal) {
                newFeeBase = (feeBase * 2) - newFeeBase;
            } else if (p > 0) {
                premiumRate = uint64(((t.max(a) - a) * 10000) / a);
            }
        }
    }

    /// @notice Update the baseFee for proofs
    /// @param cumulativeProofTime - Current proof time issued
    /// @param proofTimeTarget - Proof time target
    /// @param actProofTime - The actual proof time
    /// @param usedGas - Gas in the block
    /// @param quotient - Adjustmnet quotient
    function calculateBaseProof(
        uint256 cumulativeProofTime,
        uint64 proofTimeTarget,
        uint64 actProofTime,
        uint32 usedGas,
        uint8 quotient
    )
        internal
        view
        returns (
            uint256 reward,
            uint256 newProofTimeIssued,
            uint64 newBaseFeeProof
        )
    {
        console2.log("usedGas is: ", usedGas);
        console2.log("cumulativeProofTime is: ", cumulativeProofTime);

        console2.log("proofTimeTarget is: ", proofTimeTarget);
        console2.log("actProofTime is: ", actProofTime);
        if (proofTimeTarget == 0) {
            // Let's discuss proper value, but make it 20 seconds first time user, so to
            // be realistic a little bit while also avoid division by zero
            proofTimeTarget = 20000;
        }
        // To protect underflow
        newProofTimeIssued = (cumulativeProofTime > proofTimeTarget)
            ? cumulativeProofTime - proofTimeTarget
            : uint256(0);

        newProofTimeIssued += actProofTime;

        console2.log("Increased cumulativeProofTime is: ", newProofTimeIssued);

        newBaseFeeProof = baseFee(
            newProofTimeIssued / 1000, //Hence in milliseconds
            proofTimeTarget / 1000, //Hence in milliseconds
            quotient
        );

        reward =
            ((newBaseFeeProof * usedGas) *
                ((actProofTime * SCALING_FACTOR) / proofTimeTarget)) /
            (SCALING_FACTOR * EXPONENTIAL_REWARD_FACTOR);

        console2.log("All cumulativeProofTime: ", newProofTimeIssued);
        console2.log("New newBaseFeeProof: ", newBaseFeeProof);
        console2.log("Reward: ", reward);
    }

    /// @notice Calculating the exponential smoothened with (target/quotient)
    /// @param value - Result of cumulativeProofTime / usedGas
    /// @param target - Reward targer per gas
    /// @param quotient - Quotient
    function baseFee(
        uint256 value,
        uint256 target,
        uint256 quotient
    ) internal view returns (uint64) {
        // If SCALING_FACTOR not applied : target * quotient will be bigger, therefore the result is 0
        return
            uint64(
                ((expCalculation(value, target, quotient) * SCALING_FACTOR) /
                    (target * quotient))
            );
    }

    /// @notice Calculating the exponential via ABDKMath64x64
    /// @param value - Result of cumulativeProofTime / usedGas
    /// @param target - Reward targer per gas
    /// @param quotient - Quotient
    function expCalculation(
        uint256 value,
        uint256 target,
        uint256 quotient
    ) internal view returns (uint64 retVal) {
        console2.log("----In expCalculation() of LibL1Tokenomics.sol -----");
        // console2.log("value: ", value);
        // console2.log("target: ", target);
        // console2.log("quotient: ", quotient);

        int128 valueInt128 = ABDKMath64x64.exp(
            ABDKMath64x64.divu(value, target * quotient)
        );

        unchecked {
            if (!(valueInt128 >= 0)) {
                revert L1_IMPOSSIBLE_CONVERSION();
            }

            //On purpose downshift/divide only 2^57, so that we have higher precisions!!!
            retVal = uint64(uint128(valueInt128 >> 57));
        }
    }
}
