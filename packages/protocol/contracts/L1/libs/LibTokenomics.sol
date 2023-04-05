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

    // @dev Since we keep the base fee in 10*18 but the actual TKO token is in 10**8
    uint256 private constant SCALING_FROM_18_TO_TKO_DEC = 1e10;

    /// Todo: Daniel and Brecht: This is an idea to replace current gasLimit and play around
    /// with the idea of having it a (fine tuneable) parameter - for now (testing) as a constant.
    /// @notice Decimal factor, meaning this is the variable which will be used to multiply
    /// the basefee (a constant =  input.gasLimit).
    ///
    /// @dev To give more context, the fee and reward: (if the proof arrives at around target time)
    /// IF DECIMAL_FACTOR = 1_000_000;
    /// with proofTImeTarget 85 sec (current testnet) apprx.: 782.7 TKO is the reward (both with and without minting)
    /// with proofTimeTarget is 20 mins (on mainnet): apprx.: 55.4 TKO (approx. both with and without minting)

    /// IF DECIMAL_FACTOR = 100_000;
    /// with proofTImeTarget 85 sec (current testnet) apprx.: 78.27 TKO is the reward
    /// with proofTimeTarget is 20 mins (on mainnet): apprx.: 5.54 TKO
    uint32 private constant DECIMAL_FACTOR = 100_000;

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
    ) internal view returns (uint64 basefee, uint64 fee) {
        basefee = state.basefee;
        //Convert to uint256 to avoid overflow during multiplication
        fee = uint64(
            (uint256(basefee) * DECIMAL_FACTOR) / SCALING_FROM_18_TO_TKO_DEC
        );
    }

    function getProofReward(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 provenAt,
        uint64 proposedAt
    ) internal view returns (uint64 newBasefee, uint64 reward) {
        (reward, , newBasefee) = calculateBasefee(
            state,
            config,
            (provenAt - proposedAt)
        );
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

        newBasefee = _calcBasefee(
            proofTimeIssued,
            config.proofTimeTarget,
            config.adjustmentQuotient
        );

        if (config.allowMinting) {
            // Upconvert 1 to uint256 and the rest will be upconverted too to avoid
            // overflow during multiplication
            reward = uint64(
                (uint256(state.basefee) * DECIMAL_FACTOR * proofTime) /
                    (config.proofTimeTarget * SCALING_FROM_18_TO_TKO_DEC)
            );
        } else {
            /// TODO(dani): Verify with functional tests
            uint64 numBlocksBeingProven = state.numBlocks -
                state.lastVerifiedBlockId -
                1;
            if (config.useTimeWeightedReward) {
                // TODO(dani): Theroetically there can be no underflow (in case
                // numBlocksBeingProven == 0 then state.accProposedAt is
                // also 0) - but verify with unit tests !
                uint64 totalNumProvingSeconds = uint64(
                    uint256(numBlocksBeingProven) *
                        block.timestamp -
                        state.accProposedAt
                );
                reward = uint64(
                    (uint256(state.rewardPool) * proofTime) /
                        totalNumProvingSeconds
                );
            } else {
                /// TODO: Verify with functional tests : done on a diff branch but cut this algo out later
                reward = state.rewardPool / numBlocksBeingProven;
            }
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
    ) private pure returns (uint64) {
        uint256 result = _expCalculation(value, target, quotient) /
            (target * quotient);
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
    ) private pure returns (uint256 retVal) {
        // Overflow handled by the code
        uint256 x = (value * Math.SCALING_FACTOR_1E18) / (target * quotient);
        return uint256(Math.exp(int256(x)));
    }
}
