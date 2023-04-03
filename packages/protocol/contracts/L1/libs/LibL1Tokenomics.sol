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

library LibL1Tokenomics {
    using LibMath for uint256;

    uint256 constant SCALING_FACTOR_1E18 = 1e18; // For fixed point representation factor
    /// @dev Since we keep the base fee in 10*18 but the actual TKO token is in 10**8
    uint256 constant SCALING_FROM_18_TO_TKO_DEC = 1e10;

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

    function getProverFee(
        TaikoData.State storage state,
        uint32 gasUsed
    ) internal view returns (uint256 feeBase, uint256 fee) {
        feeBase = state.baseFeeProof;
        fee = ((feeBase * gasUsed) / SCALING_FROM_18_TO_TKO_DEC);
    }

    function getProofReward(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 provenAt,
        uint64 proposedAt,
        uint32 usedGas
    ) internal view returns (uint256 newFeeBase, uint256 reward) {
        (reward, , newFeeBase) = calculateBaseProof(
            state,
            config,
            (provenAt - proposedAt),
            usedGas
        );
    }

    /// @notice Update the baseFee for proofs
    /// @param state - The actual state data
    /// @param config - Config data
    /// @param actProofTime - The actual proof time
    /// @param usedGas - Gas in the block
    function calculateBaseProof(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 actProofTime,
        uint32 usedGas
    )
        internal
        view
        returns (
            uint256 reward,
            uint256 newProofTimeIssued,
            uint256 newBaseFeeProof
        )
    {
        uint256 proofTime = state.proofTimeIssued;
        // To protect underflow
        proofTime = (proofTime > config.proofTimeTarget)
            ? proofTime - config.proofTimeTarget
            : uint256(0);

        proofTime += actProofTime;

        newBaseFeeProof = baseFee(
            proofTime,
            config.proofTimeTarget,
            config.adjustmentQuotient
        );

        if (config.allowMinting) {
            reward = ((state.baseFeeProof * usedGas * actProofTime) /
                (config.proofTimeTarget * SCALING_FROM_18_TO_TKO_DEC));
        } else {
            if (config.useTimeWeightedReward) {
                reward = (state.proofFeeTreasury *
                    (actProofTime /
                        (((state.numBlocks - state.lastVerifiedBlockId) *
                            block.timestamp) - state.accProposalTime)));
            } else {
                reward = (state.proofFeeTreasury /
                    (state.numBlocks - state.lastVerifiedBlockId));
            }
        }

        newProofTimeIssued = proofTime;
    }

    /// @notice Calculating the exponential smoothened with (target/quotient)
    /// @param value - Result of cumulativeProofTime
    /// @param target - Target proof time
    /// @param quotient - Quotient
    function baseFee(
        uint256 value,
        uint256 target,
        uint256 quotient
    ) internal pure returns (uint256) {
        uint256 newValue = (expCalculation(value, target, quotient));
        return ((newValue / (target * quotient)));
    }

    /// @notice Calculating the exponential via LibFixedPointMath.sol
    /// @param value - Result of cumulativeProofTime
    /// @param target - Target proof time
    /// @param quotient - Quotient
    function expCalculation(
        uint256 value,
        uint256 target,
        uint256 quotient
    ) internal pure returns (uint256 retVal) {
        // Overflow handled by the code
        return
            uint256(
                Math.exp(
                    int256((value * SCALING_FACTOR_1E18) / (target * quotient))
                )
            );
    }
}
