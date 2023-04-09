// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";
import {TaikoToken} from "../TaikoToken.sol";
import {
    LibFixedPointMath as Math
} from "../../thirdparty/LibFixedPointMath.sol";

library LibTokenomics {
    using LibMath for uint256;

    /// @dev Explanation of the scaling factor
    // The calculation depends on the proofTime (and proofTimeTarget)
    /// Since the exp function (or _calcBasefee() gives us:
    // with proof time around 20 mins:
    // somewhere around 0.000055442419735305 = 55442419735305 (in 10**18 fixed) = 5.5 (in TKO with 1e5 factor)

    // with proof time around 85s (current testnet):
    // somewhere around 0.000782716513910190 = 782716513910190 (in 10**18 fixed) = 78 (in TKO with 1e5 factor)

    /// @dev Fee will depends on the proofTime (and proofTimeTarget).
    uint64 private constant SCALING_FROM_18_FIXED_EXP_TO_TKO_AMOUNT = 1e5;

    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_PARAM();

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

    function getProverFee(
        TaikoData.State storage state
    ) internal view returns (uint64 fee) {
        return state.basefee;
    }

    function getProofReward(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 provenAt,
        uint64 proposedAt
    ) internal view returns (uint64 reward) {
        (reward, , ) = calculateBasefee(state, config, (provenAt - proposedAt));
    }

    /// @notice Update the baseFee for proofs
    /// @param state - The actual state data
    /// @param config - Config data
    /// @param proofTime - The actual proof time
    function calculateBasefee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 proofTime
    )
        internal
        view
        returns (uint64 reward, uint64 newProofTimeIssued, uint64 newBasefee)
    {
        uint64 proofTimeIssued = state.proofTimeIssued;
        // To protect underflow
        proofTimeIssued = (proofTimeIssued > config.proofTimeTarget)
            ? proofTimeIssued - config.proofTimeTarget
            : uint64(0);

        proofTimeIssued += proofTime;

        newBasefee =
            _calcBasefee(
                proofTimeIssued,
                config.proofTimeTarget,
                config.adjustmentQuotient
            ) /
            SCALING_FROM_18_FIXED_EXP_TO_TKO_AMOUNT;

        /// TODO(dani): Verify with functional tests
        uint64 numBlocksBeingProven = state.numBlocks -
            state.lastVerifiedBlockId -
            1;
        if (numBlocksBeingProven == 0) {
            reward = uint64(0);
        } else {
            uint64 totalNumProvingSeconds = uint64(
                uint256(numBlocksBeingProven) *
                    block.timestamp -
                    state.accProposedAt
            );

            reward = uint64(
                (
                    uint256(
                        (state.rewardPool * proofTime) / totalNumProvingSeconds
                    )
                )
            );

            // // todo:(dani) Validate algo and check which seems best among the 3
            // reward_opt2 = uint64(
            //     (
            //         uint256(
            //             (state.rewardPool * proofTime) / (totalNumProvingSeconds * 2)
            //         )
            //     )
            // );

            // reward_opt3 = uint64(
            //     (
            //         uint256(
            //             (state.rewardPool * proofTime) /
            //             (numBlocksBeingProven - 1) * config.proofTimeTarget + proofTime
            //         )
            //     )
            // );
        }

        newProofTimeIssued = proofTimeIssued;
    }

    /// @notice Calculating the exponential smoothened with (target/quotient)
    /// @param value - Result of cumulativeProofTime
    /// @param target - Target proof time
    /// @param quotient - Quotient
    function _calcBasefee(
        uint256 value,
        uint256 target,
        uint256 quotient
    ) private view returns (uint64) {
        uint256 exp_result = _expCalculation(value, target, quotient);
        uint256 result = exp_result / 1e4; // 1e4 is 'empirical' in a sense of experience that this works
        // console2.log("result: ", result);
        // console2.log("exp_result: ", exp_result);
        // console2.log("value: ", value);
        // console2.log("target: ", target);
        // console2.log("quotient: ", quotient);
        if (result > type(uint64).max) return type(uint64).max;

        return uint64(result);
    }

    /// @notice Calculating the exponential via LibFixedPointMath.sol
    /// @param value - Result of cumulativeProofTime
    /// @param target - Target proof time
    /// @param quotient - Quotient
    function _expCalculation(
        uint256 value,
        uint256 target,
        uint256 quotient
    ) private view returns (uint256 retVal) {
        // x should be around 30 to give 10TKO back
        uint256 x = (value) / (target * quotient);
        // In order the newBaseFee be 10TKo, this equotion needs to be like this:
        // 30 = (value * Math.SCALING_FACTOR_1E18) / 28.800 (28.800 comes from 1800 * 16)
        // 864000 = value * Math.SCALING_FACTOR_1E18
        // So basicall value is 864 and SCALING_FACTOR is 1e3
        //console2.log("x: ", x);
        // Cap it or it would throw otherwise
        if (x > Math.MAX_EXP_INPUT) {
            x = Math.MAX_EXP_INPUT;
        }
        return uint256(Math.exp(int256(x)));
    }
}
